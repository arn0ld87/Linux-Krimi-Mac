// The serial bridge runs inside the Linux guest as PID 1.
package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"
)

const (
	home         = "/home/azubi"
	work         = "/srv/rechenwerk/uebung"
	userID       = 1000
	coffeeID     = 1001
	maxFileBytes = 64 * 1024
	maxOutput    = 32 * 1024
)

var missionFiles = map[string]string{
	"csv":   work + "/kaffeekasse.csv",
	"meta":  home + "/belege/kasse-meta.txt",
	"lines": home + "/belege/kasse-zeilen.txt",
}

type request struct {
	ID       string            `json:"id"`
	Command  string            `json:"command"`
	Cwd      string            `json:"cwd"`
	Seed     map[string]string `json:"seed"`
	Episode  int               `json:"episode"`
	Step     string            `json:"step"`
	Answer   string            `json:"answer"`
	Desktop  string            `json:"desktop"`
	Terminal string            `json:"terminal"`
	Bytes    []byte            `json:"terminalBytes"`
	Size     terminalSize      `json:"terminalSize"`
}

type response struct {
	ID              string            `json:"id,omitempty"`
	Ready           bool              `json:"ready,omitempty"`
	Cwd             string            `json:"cwd,omitempty"`
	Output          string            `json:"output,omitempty"`
	Failed          bool              `json:"failed,omitempty"`
	Files           map[string]string `json:"files"`
	Checks          []string          `json:"checks,omitempty"`
	Accepted        bool              `json:"accepted,omitempty"`
	Error           string            `json:"error,omitempty"`
	TerminalOutput  []byte            `json:"terminalOutput,omitempty"`
	TerminalPrompt  bool              `json:"terminalPrompt,omitempty"`
	TerminalClosed  bool              `json:"terminalClosed,omitempty"`
	TerminalDesktop bool              `json:"terminalDesktop,omitempty"`
}

func main() {
	encoder := json.NewEncoder(os.Stdout)
	var outputLock sync.Mutex
	send := func(reply response) error {
		outputLock.Lock()
		defer outputLock.Unlock()
		return encoder.Encode(reply)
	}
	terminal := interactiveTerminal{emit: send}
	if err := mountDisk(); err != nil {
		_ = encoder.Encode(response{Error: err.Error()})
		select {}
	}
	_ = encoder.Encode(response{Ready: true})
	scanner := bufio.NewScanner(os.Stdin)
	scanner.Buffer(make([]byte, 8192), 1024*1024)
	var active *mission
	prepared := false
	for scanner.Scan() {
		var req request
		if json.Unmarshal(scanner.Bytes(), &req) != nil {
			continue
		}
		var reply response
		switch req.Terminal {
		case "input":
			terminal.send(req.Bytes)
			continue
		case "resize":
			terminal.resize(req.Size)
			continue
		case "start", "maintenance":
			if !prepared {
				reply.Error = "Die Linux-Mission ist noch nicht bereit."
			} else if err := terminal.start(validCwd(req.Cwd), req.Size, req.Terminal == "maintenance"); err != nil {
				reply.Error = "Terminal: " + err.Error()
			}
		default:
			if req.Seed == nil {
				req.Cwd = terminal.cwd(req.Cwd)
			}
			reply = handle(req, &active)
			if req.Seed != nil && reply.Error == "" {
				prepared = true
			}
		}
		reply.ID = req.ID
		if send(reply) != nil {
			break
		}
	}
	select {}
}

func mountDisk() error {
	for _, module := range []string{"virtio_blk", "ext4"} {
		if data, err := exec.Command("/sbin/modprobe", module).CombinedOutput(); err != nil {
			return fmt.Errorf("modprobe %s: %w (%s)", module, err, data)
		}
	}
	if err := os.MkdirAll("/data", 0o755); err != nil {
		return err
	}
	device := "/dev/vda"
	disk, err := os.Open(device)
	if err != nil {
		return err
	}
	header := make([]byte, 4096)
	_, err = disk.ReadAt(header, 0)
	_ = disk.Close()
	if err != nil {
		return err
	}
	if bytes.Equal(header, make([]byte, len(header))) {
		if data, err := exec.Command("/sbin/mke2fs", "-q", "-t", "ext4", "-F", device).CombinedOutput(); err != nil {
			return fmt.Errorf("mke2fs: %w (%s)", err, data)
		}
	} else if !bytes.Equal(header[1080:1082], []byte{0x53, 0xef}) {
		return errors.New("Das Linux-Abbild enthält kein gültiges ext4-Dateisystem")
	}
	return syscall.Mount(device, "/data", "ext4",
		syscall.MS_NOSUID|syscall.MS_NODEV|syscall.MS_SYNCHRONOUS, "")
}

func handle(req request, active **mission) response {
	if req.Seed != nil {
		var err error
		if req.Episode == 0 {
			err = prepareMission(req.Seed)
		} else {
			*active, err = prepareBrowserMission(req.Episode)
		}
		if err != nil {
			return response{Error: err.Error()}
		}
		reply := response{Cwd: validCwd(req.Cwd)}
		addEvidence(&reply, *active)
		return reply
	}

	result := response{Cwd: validCwd(req.Cwd)}
	if req.Desktop != "" {
		if *active == nil || ((*active).Episode.ID != 2 && (*active).Desktop == nil) {
			result.Error = "Kein Linux-Bildschirm für diese Episode"
		} else if err := (*active).desktopAction(req.Desktop); err != nil {
			result.Error = err.Error()
		}
	} else if req.Step != "" && *active != nil {
		if check, ok := (*active).Responses[req.Step]; ok {
			result.Accepted = runCheck(check.Script, req.Answer)
		}
	} else if req.Command != "" {
		result = run(req.Command, result.Cwd)
	}
	addEvidence(&result, *active)
	return result
}

func prepareMission(seed map[string]string) error {
	for _, pair := range [][2]string{{"/data/home", home}, {"/data/uebung", work}} {
		for _, name := range pair {
			if err := os.MkdirAll(name, 0o755); err != nil {
				return err
			}
		}
		if err := syscall.Mount(pair[0], pair[1], "", syscall.MS_BIND, ""); err != nil {
			return err
		}
	}
	for _, account := range []struct{ file, line string }{
		{"/etc/passwd", "\nazubi:x:1000:1000:Azubi:/home/azubi:/bin/sh\nkaffee:x:1001:1000:Kaffeeautomat:/nonexistent:/sbin/nologin\n"},
		{"/etc/group", "\nazubi:x:1000:\n"},
	} {
		if err := appendFile(account.file, account.line); err != nil {
			return err
		}
	}
	if _, err := os.Stat("/data/mission-ready"); !errors.Is(err, os.ErrNotExist) {
		return err
	}
	for path, permissions := range map[string]os.FileMode{home: 0o755, home + "/belege": 0o755, "/tmp": 0o777} {
		if err := os.MkdirAll(path, permissions); err != nil {
			return err
		}
		if err := os.Chmod(path, permissions); err != nil {
			return err
		}
		if path != "/tmp" {
			if err := os.Chown(path, userID, userID); err != nil {
				return err
			}
		}
	}
	for key, file := range missionFiles {
		if value, exists := seed[key]; exists {
			if err := os.WriteFile(file, []byte(value), 0o664); err != nil {
				return err
			}
			owner := userID
			if key == "csv" {
				owner = coffeeID
			}
			if err := os.Chown(file, owner, userID); err != nil {
				return err
			}
			if err := os.Chmod(file, 0o664); err != nil {
				return err
			}
		}
	}
	bak := work + "/kaffeekasse.bak"
	if err := os.WriteFile(bak, []byte(seed["backup"]), 0o644); err != nil {
		return err
	}
	for path, stamp := range map[string]time.Time{
		bak:                 time.Date(2026, 4, 16, 22, 5, 0, 0, time.UTC),
		missionFiles["csv"]: time.Date(2026, 4, 17, 3, 12, 0, 0, time.UTC),
	} {
		if err := os.Chtimes(path, stamp, stamp); err != nil {
			return err
		}
	}
	return os.WriteFile("/data/mission-ready", nil, 0o600)
}

func appendFile(path, text string) error {
	f, err := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0)
	if err != nil {
		return err
	}
	defer f.Close()
	_, err = f.WriteString(text)
	return err
}

func validCwd(path string) string {
	if filepath.IsAbs(path) {
		if stat, err := os.Stat(path); err == nil && stat.IsDir() {
			return path
		}
	}
	return home
}

func readFiles(paths map[string]string) map[string]string {
	files := make(map[string]string)
	for key, path := range paths {
		if info, err := os.Lstat(path); err != nil || !info.Mode().IsRegular() {
			continue
		}
		f, err := os.OpenFile(path, os.O_RDONLY|syscall.O_NOFOLLOW|syscall.O_NONBLOCK, 0)
		if err != nil {
			continue
		}
		data, err := io.ReadAll(io.LimitReader(f, maxFileBytes+1))
		_ = f.Close()
		if err == nil && len(data) <= maxFileBytes {
			files[key] = string(data)
		}
	}
	return files
}

func run(line, cwd string) response {
	state, err := os.CreateTemp("/run", "staffel-cwd-")
	if err != nil {
		return response{Cwd: cwd, Error: err.Error()}
	}
	defer os.Remove(state.Name())
	defer state.Close()
	// FD 3 carries the resulting cwd separately from stdout and stderr.
	script := `eval "$1"; result=$?; /bin/pwd -P >&3; exit "$result"`
	command := exec.Command("/bin/sh", "-c", script, "sh", line)
	command.Dir = cwd
	command.Env = []string{"PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", "HOME=" + home,
		"USER=azubi", "LOGNAME=azubi", "TZ=UTC", "LANG=C.UTF-8", "TIME_STYLE=long-iso"}
	command.ExtraFiles = []*os.File{state}
	command.SysProcAttr = &syscall.SysProcAttr{
		Credential: &syscall.Credential{Uid: userID, Gid: userID, Groups: []uint32{userID}},
		Setpgid:    true,
	}
	var output limitedOutput
	command.Stdout, command.Stderr = &output, &output
	if err := command.Start(); err != nil {
		return response{Cwd: cwd, Error: err.Error()}
	}
	exited := make(chan error, 1)
	go func() { exited <- command.Wait() }()
	timer := time.NewTimer(8 * time.Second)
	defer timer.Stop()
	select {
	case err = <-exited:
		_ = syscall.Kill(-command.Process.Pid, syscall.SIGKILL)
	case <-timer.C:
		_ = syscall.Kill(-command.Process.Pid, syscall.SIGKILL)
		<-exited
		err = errors.New("Zeitlimit für den Linux-Befehl erreicht")
	}
	text := output.String()
	if output.truncated {
		text += "\n[Ausgabe gekürzt]\n"
	}
	if err != nil && strings.TrimSpace(text) == "" {
		text = err.Error()
	}
	if _, seekErr := state.Seek(0, io.SeekStart); seekErr == nil {
		if data, readErr := io.ReadAll(io.LimitReader(state, 4096)); readErr == nil {
			if path := strings.TrimSuffix(string(data), "\n"); filepath.IsAbs(path) {
				cwd = validCwd(path)
			}
		}
	}
	return response{Cwd: cwd, Output: text, Failed: err != nil}
}

type limitedOutput struct {
	bytes.Buffer
	truncated bool
}

func (output *limitedOutput) Write(data []byte) (int, error) {
	size := len(data)
	if remaining := maxOutput - output.Len(); remaining < size {
		data = data[:remaining]
		output.truncated = true
	}
	_, _ = output.Buffer.Write(data)
	return size, nil
}

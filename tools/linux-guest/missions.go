package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
)

type mission struct {
	Episode     struct{ ID int }
	Setup       string
	Check       map[string]string
	Responses   map[string]struct{ Script string }
	Sudo        []string
	EvidenceIDs []string
	Desktop     *struct {
		Directory string
		Editor    string
		Photo     string
	}
}

const missionPath = "/staffel-missions/Missions.json"

func prepareBrowserMission(id int) (*mission, error) {
	raw, err := os.ReadFile(missionPath)
	if err != nil {
		return nil, err
	}
	var episodes []mission
	if err := json.Unmarshal(raw, &episodes); err != nil {
		return nil, err
	}
	for i := range episodes {
		if episodes[i].Episode.ID == id {
			return &episodes[i], episodes[i].prepare()
		}
	}
	return nil, errors.New("Unbekannte Linux-Mission")
}

func (m *mission) prepare() error {
	for _, target := range []string{home, "/var/log", "/etc/sudoers.d", "/etc/crontabs", "/usr/local/bin", "/usr/local/sbin", "/srv/rechenwerk"} {
		source := filepath.Join("/data", target)
		for _, folder := range []string{source, target} {
			if err := os.MkdirAll(folder, 0o755); err != nil {
				return err
			}
		}
		if err := syscall.Mount(source, target, "", syscall.MS_BIND, ""); err != nil {
			return err
		}
	}
	if err := os.MkdirAll(home+"/belege", 0o755); err != nil {
		return err
	}
	for _, folder := range []string{home, home + "/belege"} {
		if err := os.Chown(folder, userID, userID); err != nil {
			return err
		}
	}
	if err := appendFile("/etc/passwd", "\nazubi:x:1000:1000:Azubi:/home/azubi:/bin/sh\n"); err != nil {
		return err
	}
	if err := appendFile("/etc/group", "\nazubi:x:1000:\n"); err != nil {
		return err
	}
	if err := appendFile("/etc/hosts", "\n127.0.1.1 rw-srv01\n"); err != nil {
		return err
	}
	for user, id := range map[string]int{"timo": 1101, "nadia": 1102, "margit": 1103, "abgleich": 1105} {
		if data, err := exec.Command("/bin/busybox", "adduser", "-D", "-H", "-u", strconv.Itoa(id),
			"-h", "/home/"+user, "-s", "/sbin/nologin", user).CombinedOutput(); err != nil {
			return fmt.Errorf("Linux-Konto %s: %w: %s", user, err, data)
		}
	}
	sudoers := "root ALL=(ALL:ALL) ALL\n@includedir /etc/sudoers.d\n"
	if len(m.Sudo) > 0 {
		sudoers += "azubi ALL=(root) NOPASSWD: " + strings.Join(m.Sudo, ", ") + "\n"
	}
	if err := os.WriteFile("/etc/sudoers", []byte(sudoers), 0o440); err != nil {
		return err
	}

	marker := "/data/browser-mission-" + strconv.Itoa(m.Episode.ID)
	if _, err := os.Stat(marker); errors.Is(err, os.ErrNotExist) {
		ctx, cancel := context.WithTimeout(context.Background(), 24*time.Second)
		defer cancel()
		cmd := rootShell(ctx, m.Setup, "")
		if data, err := cmd.CombinedOutput(); err != nil {
			return fmt.Errorf("Episode %d: %w: %s", m.Episode.ID, err, data)
		}
		return os.WriteFile(marker, nil, 0o600)
	} else if err != nil {
		return err
	}

	if m.Episode.ID == 2 {
		return resumeCron()
	}
	return nil
}

func resumeCron() error {
	if output, err := exec.Command("/usr/sbin/crond", "-c", "/etc/crontabs").CombinedOutput(); err != nil {
		return fmt.Errorf("crond: %w: %s", err, output)
	}
	cron, err := os.ReadFile("/etc/crontabs/abgleich")
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil || !strings.Contains(string(cron), "rw-abgleich") {
		return err
	}
	process := exec.Command("/usr/local/sbin/rw-abgleich")
	process.SysProcAttr = &syscall.SysProcAttr{
		Credential: &syscall.Credential{Uid: 1105, Gid: 1105},
	}
	if err := process.Start(); err != nil {
		return err
	}
	go func() { _ = process.Wait() }()
	return nil
}

func (m *mission) desktopAction(action string) error {
	if action == "start" {
		ctx, cancel := context.WithTimeout(context.Background(), 13*time.Second)
		defer cancel()
		mode := "terminal"
		if m.Desktop != nil {
			mode = "desktop"
		}
		if data, err := exec.CommandContext(ctx, "/staffel-desktop/start.sh", mode).CombinedOutput(); err != nil {
			return fmt.Errorf("Linux-Bildschirm: %w: %s", err, data)
		}
		return nil
	}
	folder := home
	editor := ""
	photo := home + "/fotos/IMG_0417.png"
	if m.Desktop != nil {
		if !filepath.IsLocal(m.Desktop.Directory) {
			return errors.New("Ungültiger Fallordner")
		}
		folder = filepath.Join(home, m.Desktop.Directory)
		photo = ""
		if filepath.IsLocal(m.Desktop.Editor) {
			editor = filepath.Join(folder, m.Desktop.Editor)
		}
		if filepath.IsLocal(m.Desktop.Photo) {
			photo = filepath.Join(folder, m.Desktop.Photo)
		}
	}
	programs := map[string][]string{
		"terminal": {"/usr/bin/xterm", "-T", "Ostwind | azubi"},
		"files":    {"/usr/bin/pcmanfm", folder},
		"editor":   {"/usr/bin/mousepad"},
	}
	if photo != "" {
		programs["photo"] = []string{"/usr/bin/feh", photo}
	}
	if editor != "" {
		programs["editor"] = append(programs["editor"], editor)
	}
	args, exists := programs[action]
	if !exists {
		return errors.New("Unbekannte Bildschirmaktion")
	}
	cmd := exec.Command(args[0], args[1:]...)
	cmd.Dir = folder
	cmd.Env = []string{"DISPLAY=:0", "HOME=" + home, "PATH=/usr/bin:/bin",
		"LANG=C.UTF-8", "XDG_RUNTIME_DIR=/tmp/ostwind-azubi", "LIBGL_ALWAYS_SOFTWARE=1"}
	cmd.SysProcAttr = &syscall.SysProcAttr{
		Credential: &syscall.Credential{Uid: userID, Gid: userID, Groups: []uint32{userID}},
	}
	if err := cmd.Start(); err != nil {
		return err
	}
	go func() { _ = cmd.Wait() }()
	return nil
}

func addEvidence(result *response, active *mission) {
	if active == nil {
		result.Files = readFiles(missionFiles)
		return
	}
	paths := make(map[string]string, len(active.EvidenceIDs))
	for _, id := range active.EvidenceIDs {
		paths[id] = home + "/belege/" + id + ".txt"
	}
	result.Files = readFiles(paths)
	for id, shell := range active.Check {
		if runCheck(shell, "") {
			result.Checks = append(result.Checks, id)
		}
	}
}

func runCheck(script, answer string) bool {
	timeout := 800 * time.Millisecond
	if strings.Contains(script, "sudo -l -U nadia") {
		timeout = 3 * time.Second
	}
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	return rootShell(ctx, script, answer).Run() == nil
}

func rootShell(ctx context.Context, script, answer string) *exec.Cmd {
	cmd := exec.CommandContext(ctx, "/bin/bash", "-c", script)
	cmd.Env = []string{"PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
		"HOME=/root", "LANG=C", "LC_ALL=C", "TZ=UTC", "ANTWORT=" + answer}
	return cmd
}

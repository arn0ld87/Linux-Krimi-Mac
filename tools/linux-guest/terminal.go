package main

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"sync"
	"syscall"
	"unsafe"
)

var (
	promptMarker  = []byte("\x1b]633;StaffelPrompt\x07")
	desktopMarker = []byte("\x1b]633;StaffelDesktop\x07")
)

type terminalSize struct {
	Rows uint16 `json:"rows"`
	Cols uint16 `json:"cols"`
	X    uint16 `json:"-"`
	Y    uint16 `json:"-"`
}

type terminalSession struct {
	master *os.File
	shell  *exec.Cmd
	input  chan []byte
	done   chan struct{}
	root   bool
}

type interactiveTerminal struct {
	mu      sync.Mutex
	current *terminalSession
	emit    func(response) error
}

func (t *interactiveTerminal) start(cwd string, size terminalSize, admin bool) error {
	t.stop()
	master, slave, err := openTerminalPTY()
	if err != nil {
		return err
	}
	defer slave.Close()
	if err := resizeTerminal(master, size); err != nil {
		master.Close()
		return err
	}
	username, directory := "azubi", home
	attributes := &syscall.SysProcAttr{Setsid: true, Setctty: true, Ctty: 0}
	if admin {
		username, directory, cwd = "root", "/root", "/root"
	} else {
		attributes.Credential = &syscall.Credential{Uid: userID, Gid: userID, Groups: []uint32{userID}}
	}
	shell := exec.Command("/bin/bash", "--noprofile", "--rcfile", "/staffel-terminal.bashrc", "-i")
	shell.Dir = cwd
	shell.Env = []string{
		"PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
		"TERM=xterm-256color", "LANG=C.UTF-8", "TZ=UTC", "TIME_STYLE=long-iso",
		"HOME=" + directory, "USER=" + username, "LOGNAME=" + username,
	}
	shell.Stdin, shell.Stdout, shell.Stderr, shell.SysProcAttr = slave, slave, slave, attributes
	if err := shell.Start(); err != nil {
		master.Close()
		return err
	}
	session := &terminalSession{master: master, shell: shell, input: make(chan []byte, 128), done: make(chan struct{}), root: admin}
	t.mu.Lock()
	t.current = session
	t.mu.Unlock()
	go func() {
		for {
			select {
			case <-session.done:
				return
			case data := <-session.input:
				if _, err := master.Write(data); err != nil {
					return
				}
			}
		}
	}()
	go t.relay(session)
	return nil
}

func openTerminalPTY() (*os.File, *os.File, error) {
	master, err := os.OpenFile("/dev/ptmx", os.O_RDWR|syscall.O_NOCTTY|syscall.O_NONBLOCK, 0)
	if err != nil {
		return nil, nil, err
	}
	var index uint32
	var unlocked uint32
	if err = terminalIOCTL(master, syscall.TIOCSPTLCK, unsafe.Pointer(&unlocked)); err == nil {
		err = terminalIOCTL(master, syscall.TIOCGPTN, unsafe.Pointer(&index))
	}
	if err == nil {
		var slave *os.File
		slave, err = os.OpenFile(fmt.Sprintf("/dev/pts/%d", index), os.O_RDWR|syscall.O_NOCTTY, 0)
		if err == nil {
			return master, slave, nil
		}
	}
	master.Close()
	return nil, nil, err
}

func terminalIOCTL(file *os.File, op uintptr, arg unsafe.Pointer) error {
	raw, err := file.SyscallConn()
	if err != nil {
		return err
	}
	var status syscall.Errno
	if err := raw.Control(func(fd uintptr) {
		_, _, status = syscall.Syscall(syscall.SYS_IOCTL, fd, op, uintptr(arg))
	}); err != nil {
		return err
	}
	if status != 0 {
		return status
	}
	return nil
}

func resizeTerminal(master *os.File, size terminalSize) error {
	size.Rows = min(300, max(2, size.Rows))
	size.Cols = min(500, max(8, size.Cols))
	return terminalIOCTL(master, syscall.TIOCSWINSZ, unsafe.Pointer(&size))
}

func (t *interactiveTerminal) resize(size terminalSize) {
	t.mu.Lock()
	defer t.mu.Unlock()
	if t.current != nil {
		_ = resizeTerminal(t.current.master, size)
	}
}

func (t *interactiveTerminal) send(data []byte) {
	t.mu.Lock()
	defer t.mu.Unlock()
	if t.current == nil {
		return
	}
	select {
	case t.current.input <- data:
	default:
		_ = t.emit(response{TerminalOutput: []byte("\r\n[Eingabepuffer voll]\r\n")})
	}
}

func (t *interactiveTerminal) cwd(fallback string) string {
	t.mu.Lock()
	defer t.mu.Unlock()
	if t.current != nil && !t.current.root {
		if path, err := os.Readlink(fmt.Sprintf("/proc/%d/cwd", t.current.shell.Process.Pid)); err == nil {
			return validCwd(path)
		}
	}
	return validCwd(fallback)
}

func (t *interactiveTerminal) stop() {
	t.mu.Lock()
	session := t.current
	t.current = nil
	t.mu.Unlock()
	if session != nil {
		close(session.done)
		_ = session.master.Close()
		_ = session.shell.Process.Kill()
	}
}

func (t *interactiveTerminal) relay(session *terminalSession) {
	buffer := make([]byte, 8192)
	var tail []byte
	for {
		n, err := session.master.Read(buffer)
		if n > 0 {
			data := buffer[:n]
			markers := append(tail, data...)
			prompt, desktop := bytes.Contains(markers, promptMarker), bytes.Contains(markers, desktopMarker)
			// Buffer only enough for a split marker, and don't repeat one already sent.
			start := max(len(markers)-max(len(promptMarker), len(desktopMarker))+1, 0)
			if prompt {
				start = max(start, bytes.LastIndex(markers, promptMarker)+len(promptMarker))
			}
			if desktop {
				start = max(start, bytes.LastIndex(markers, desktopMarker)+len(desktopMarker))
			}
			tail = bytes.Clone(markers[start:])
			t.mu.Lock()
			if t.current != session {
				t.mu.Unlock()
				break
			}
			writeErr := t.emit(response{TerminalOutput: data, TerminalPrompt: prompt, TerminalDesktop: desktop && !session.root})
			t.mu.Unlock()
			if writeErr != nil {
				break
			}
		}
		if err != nil || n == 0 {
			break
		}
	}
	_ = session.master.Close()
	_ = session.shell.Wait()
	t.mu.Lock()
	defer t.mu.Unlock()
	if t.current == session {
		t.current = nil
		close(session.done)
		_ = t.emit(response{TerminalClosed: true})
	}
}

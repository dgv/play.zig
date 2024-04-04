// Copyright 2011 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"bytes"
	"encoding/json"
	"io/ioutil"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"strings"
)

type Output struct {
	Errors    string   `json:omitempty`
	Error     string   `json:omitempty`
	Events    []Events `json:omitempty`
	Body      string   `json:omitempty`
	VetErrors string   `json:omitempty`
}

type Events struct {
	Message string
	Kind    string
	Delay   int
}

func init() {
	http.HandleFunc("/compile", compileHandler)
}

func compileHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method == "POST" {
		body, _ := ioutil.ReadAll(r.Body)
		out, err := zigRun(body)
		json.NewEncoder(w).Encode(Output{Errors: err, Events: []Events{{Message: out, Kind: "stdout", Delay: 0}}, VetErrors: ""})
	}
}

func zigRun(code []byte) (stdout string, stderr string) {
	f, _ := os.CreateTemp("", "playzig-*.zig")
	var outb, errb bytes.Buffer

	defer f.Close()
	defer os.Remove(f.Name())

	_c, _ := url.QueryUnescape(string(code))
	f.Write([]byte(_c[15:]))

	cmd := exec.Command("timeout", "5s", "zig", "run", f.Name())
	if _, err := exec.LookPath("firejail"); err == nil {
		cmd = exec.Command("timeout", "5s", "firejail", "--net=none", "--rlimit-as=1024", "zig", "run", f.Name())
	}
	cmd.Stdout = &outb
	cmd.Stderr = &errb
	err := cmd.Run()
	stderr = errb.String()
	if err != nil && errb.String() != "" {
		stderr = strings.Replace(errb.String(), f.Name(), "prog.zig", -1)
		if len(stderr) > 1024 {
			stderr = stderr[:1024]
		}
	}
	stdout = outb.String()
	if len(stdout) > 1024 {
		stdout = stdout[:1024]
	}
	return stdout + "\n", stderr + "\n"
}

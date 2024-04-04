// Copyright 2012 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"bytes"
	"encoding/json"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"net/url"

	"os/exec"
)

func init() {
	http.HandleFunc("/fmt", fmtHandler)
}

func fmtHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method == "POST" {
		body, _ := ioutil.ReadAll(r.Body)
		out, err := zigFmt(body)
		json.NewEncoder(w).Encode(Output{Error: err, Body: out})
	}
}

func zigFmt(code []byte) (stdout string, stderr string) {
	cmd := exec.Command("zig", "fmt", "--stdin")
	var outb, errb bytes.Buffer
	stdin, err := cmd.StdinPipe()
	defer stdin.Close()
	cmd.Stdout = &outb
	cmd.Stderr = &errb
	err = cmd.Start()
	if err != nil {
		log.Println(err.Error())
	}
	_c, _ := url.QueryUnescape(string(code))
	io.WriteString(stdin, _c[5:])
	stdin.Close()
	cmd.Wait()
	stderr = errb.String()
	if errb.String() != "" {
		stderr = errb.String()[8:]
	}
	return outb.String(), stderr
}

// Copyright 2011 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"fmt"
	"io"
	"log"
	"net/http"
)

const compileUrl = "http://localhost:8077/compile"

func init() {
	http.HandleFunc("/compile", compile)
}

func compile(w http.ResponseWriter, r *http.Request) {
	if err := passThru(w, r, compileUrl); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprintln(w, "Compile server error.")
	}
}

func passThru(w io.Writer, req *http.Request, runUrl string) error {
	defer req.Body.Close()
	req.Header.Set("User-Agent", "go-vim")
	r, err := http.Post(runUrl, req.Header.Get("Content-type"), req.Body)
	if err != nil {
		log.Fatalf("making POST request: %v", err)
		return err
	}
	defer r.Body.Close()
	if _, err := io.Copy(w, r.Body); err != nil {
		log.Fatalf("copying response Body: %v", err)
		return err
	}
	return nil
}

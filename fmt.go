// Copyright 2012 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"fmt"
	"net/http"
)

const fmtUrl = "http://localhost:8077/fmt"

func init() {
	http.HandleFunc("/fmt", fmtHandler)
}

func fmtHandler(w http.ResponseWriter, r *http.Request) {
	if err := passThru(w, r, fmtUrl); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprintln(w, "Fmt server error.")
	}
}

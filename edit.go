// Copyright 2011 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"fmt"
	"net/http"
	"os"
	"strings"
	"text/template"
)

const hostname = "zig.fly.dev"

func init() {
	http.HandleFunc("/", edit)
}

var editTemplate = template.Must(template.ParseFiles("edit.html"))

type editData struct {
	Snippet  *Snippet
	Ziglings string
}

func edit(w http.ResponseWriter, r *http.Request) {
	// Redirect foo.play.golang.org to play.golang.org.
	if strings.HasSuffix(r.Host, "."+hostname) {
		http.Redirect(w, r, "http://"+hostname, http.StatusFound)
		return
	}
	snip := &Snippet{Body: []byte(hello)}

	ziglingsHTML := ziglingsList
	if f := r.URL.Query().Get("zigling"); f != "" {
		z, err := os.ReadFile(fmt.Sprintf("./ziglings/exercises/%s", f))
		if err != nil {
			http.Error(w, "zigling not found", http.StatusNotFound)
			return
		}
		ziglingsHTML = strings.Replace(ziglingsHTML, f+"\">", f+"\" selected>", 1)
		snip = &Snippet{Body: z}
	}

	if strings.HasPrefix(r.URL.Path, "/p/") {
		id := r.URL.Path[3:]
		serveText := false
		if strings.HasSuffix(id, ".zig") {
			id = id[:len(id)-3]
			serveText = true
		}
		s, err := db.get(id)
		snip = &Snippet{Body: s}
		if err != nil {
			http.Error(w, "Snippet not found", http.StatusNotFound)
			return
		}
		if serveText {
			w.Header().Set("Content-type", "text/plain")
			w.Write(s)
			return
		}
	}

	editTemplate.Execute(w, &editData{snip, ziglingsHTML})
}

const hello = `const std = @import("std");
const builtin = @import("builtin");

pub fn main() !void {
    std.debug.print("Hello from Zig {}", .{builtin.zig_version});
}
`

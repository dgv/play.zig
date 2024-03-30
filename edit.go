// Copyright 2011 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	//"context"
	"net/http"
	"strings"
	"text/template"

	//"cloud.google.com/go/datastore"
	//"google.golang.org/appengine/log"
)

const hostname = "play.golang.org"

func init() {
	http.HandleFunc("/", edit)
}

var editTemplate = template.Must(template.ParseFiles("edit.html"))

type editData struct {
	Snippet *Snippet
}

func edit(w http.ResponseWriter, r *http.Request) {
	// Redirect foo.play.golang.org to play.golang.org.
	if strings.HasSuffix(r.Host, "."+hostname) {
		http.Redirect(w, r, "http://"+hostname, http.StatusFound)
		return
	}

	snip := &Snippet{Body: []byte(hello)}
	/*
	if strings.HasPrefix(r.URL.Path, "/p/") {
		ctx := context.Background()
		id := r.URL.Path[3:]
		serveText := false
		if strings.HasSuffix(id, ".zig") {
			id = id[:len(id)-3]
			serveText = true
		}
		key := datastore.NameKey("Snippet", id, nil)
		err := datastoreClient.Get(ctx, key, snip)
		if err != nil {
			if err != datastore.ErrNoSuchEntity {
				log.Errorf(ctx, "loading Snippet: %v", err)
			}
			http.Error(w, "Snippet not found", http.StatusNotFound)
			return
		}
		if serveText {
			w.Header().Set("Content-type", "text/plain")
			w.Write(snip.Body)
			return
		}
	}
	*/
	editTemplate.Execute(w, &editData{snip})
}

const hello = `const std = @import("std");
const builtin = @import("builtin");

pub fn main() !void {
    std.debug.print("Hello from Zig version: {}", .{builtin.zig_version});
}
`

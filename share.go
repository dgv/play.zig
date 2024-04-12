// Copyright 2011 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"bytes"
	"crypto/sha256"
	"database/sql"
	"encoding/base64"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"

	_ "github.com/mattn/go-sqlite3"
)

const (
	salt           = "Zig playground salt\n"
	maxSnippetSize = 64 * 1024
)

type Snippet struct {
	Body []byte
}

func (s *Snippet) Id() string {
	h := sha256.New()
	io.WriteString(h, salt)
	h.Write(s.Body)
	sum := h.Sum(nil)
	b := make([]byte, base64.URLEncoding.EncodedLen(len(sum)))
	base64.URLEncoding.Encode(b, sum)
	// Web sites don’t always linkify a trailing underscore, making it seem like
	// the link is broken. If there is an underscore at the end of the substring,
	// extend it until there is not.
	hashLen := 11
	for hashLen <= len(b) && b[hashLen-1] == '_' {
		hashLen++
	}
	return string(b)[:hashLen]
}

func init() {
	http.HandleFunc("/share", share)
}

func (d *DB) initDB() (err error) {
	d.DB, err = sql.Open("sqlite3", "file:snippets.db")
	statement, err := d.Prepare("CREATE TABLE IF NOT EXISTS snippets (key TEXT PRIMARY KEY, value TEXT)")
	statement.Exec()
	return
}

func (d *DB) put(id string, code []byte) (err error) {
	tx, err := d.Begin()
	statement, err := tx.Prepare("INSERT INTO snippets (key, value) VALUES (?, ?)")
	statement.Exec(id, string(code))
	err = tx.Commit()
	return
}

func (d *DB) get(id string) (code []byte, err error) {
	row, err := d.Prepare("SELECT value FROM snippets WHERE key = ?")
	defer row.Close()
	var value string
	err = row.QueryRow(id).Scan(&value)
	return []byte(value), err
}

func share(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Forbidden", http.StatusForbidden)
		return
	}
	if url := os.Getenv("SHARE_PASSTHRU_URL"); url != "" {
		if err := passThru(url, w, r); err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			fmt.Fprintln(w, "Share server error.")
			return
		}
		return
	}

	var body bytes.Buffer
	_, err := io.Copy(&body, io.LimitReader(r.Body, maxSnippetSize+1))
	if err != nil {
		//log.Errorf(r.Context(), "reading Body: %v", err)
		http.Error(w, "Server Error", http.StatusInternalServerError)
		return
	}
	r.Body.Close()
	snip := &Snippet{Body: body.Bytes()}
	id := snip.Id()
	db.put(id, body.Bytes())
	fmt.Fprint(w, id)
}

func passThru(url string, w io.Writer, req *http.Request) error {
	defer req.Body.Close()
	req.Header.Set("User-Agent", "play.zig")
	r, err := http.Post(url+"/share", req.Header.Get("Content-type"), req.Body)
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

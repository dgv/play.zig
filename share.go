// Copyright 2011 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"io"
	"net/http"

	//"cloud.google.com/go/datastore"
	//"google.golang.org/appengine/log"
)

const (
	salt           = "Go playground salt\n"
	maxSnippetSize = 64 * 1024
)

type Snippet struct {
	Body []byte `datastore:",noindex"`
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

func share(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Forbidden", http.StatusForbidden)
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
	/*
	key := datastore.NameKey("Snippet", id, nil)
	_, err = datastoreClient.Put(r.Context(), key, snip)
	if err != nil {
		log.Errorf(r.Context(), "putting Snippet: %v", err)
		http.Error(w, "Server Error", http.StatusInternalServerError)
		return
	}
	*/
	fmt.Fprint(w, id)
}

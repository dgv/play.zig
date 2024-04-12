package main

import (
	"context"
	"net/http"
	"os"

	"cloud.google.com/go/datastore"
)

var datastoreClient *datastore.Client

func init() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "https://zig.fly.dev", http.StatusSeeOther)
	})
}

func main() {
	ctx := context.Background()
	datastoreClient, _ = datastore.NewClient(ctx, os.Getenv("GOOGLE_CLOUD_PROJECT"))
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		panic(err)
	}
}

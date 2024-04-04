package main

import (
	"net/http"
	"os"
	"log"
	"database/sql"
)

type DB struct {
	*sql.DB
}
var db DB

func main() {
	err := db.initDB()
	defer db.Close()
	if err != nil {
		log.Fatal("initdb:", err.Error())
	}
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	fileHandler := http.FileServer(http.Dir("./static/"))
	logger := func(rw http.ResponseWriter, r *http.Request) {
		fileHandler.ServeHTTP(rw, r)
	}
	http.HandleFunc("/static/", logger)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		panic(err)
	}
}

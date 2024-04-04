package main

import (
	"database/sql"
	"log"
	"net/http"
	"os"
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

	http.Handle("/static/", http.StripPrefix("/static/", http.FileServer(http.Dir("./static/"))))
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		panic(err)
	}
}

package main

import (
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/ldez/go-git-cmd-wrapper/v2/clone"
	"github.com/ldez/go-git-cmd-wrapper/v2/git"
)

type DB struct {
	*sql.DB
}

var db DB
var ziglingsList string

const ziglingsURL string = "https://codeberg.org/ziglings/exercises"

func init() {
	_, err := os.Stat("./ziglings")
	if os.IsNotExist(err) {
		_, err := git.Clone(clone.Repository(ziglingsURL), clone.Directory("ziglings"))
		if err != nil {
			log.Fatal(err)
		}
	}
	entries, err := os.ReadDir("./ziglings/exercises")
	if err != nil {
		log.Fatal(err)
	}

	for _, e := range entries {
		ziglingsList += fmt.Sprintf(`<option value="%s">%s</option>`, e.Name(), e.Name())
	}
}

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
	log.Println("play.zig listening at :" + port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

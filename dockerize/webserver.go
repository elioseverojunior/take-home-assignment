package main

import (
	"dockerize/webserver/articlehandler"
	"bufio"
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	_ "github.com/go-sql-driver/mysql"
)

func init() {
	if _, noLog := os.Stat("/log.txt"); os.IsNotExist(noLog) {
		newLog, err := os.Create("/log.txt")
		if err != nil {
			log.Fatal(err)
		}
		newLog.Close()
	}
	dbString := readConfig("server.confi")
	var err error
	db, err := sql.Open("mysql", dbString)
	check(err)
	err = db.Ping()
	check(err)
	dbChecker := time.NewTicker(time.Minute)
	articlehandler.PassDataBase(db)
	go checkDB(dbChecker, db)
	
}

func main() {
	http.Handle("/", http.FileServer(http.Dir("./src")))
	http.HandleFunc("/articles/", articlehandler.ReturnArticle)
	http.HandleFunc("/index.html", articlehandler.ReturnHomePage)
	http.HandleFunc("/api/articles", articlehandler.ReturnArticlesForHomePage)
	log.Fatal(http.ListenAndServe(":8080", nil))
}

func readConfig(s string) string {
	config, err := os.Open(s)
	check(err)
	defer config.Close()

	scanner := bufio.NewScanner(config)
	scanner.Scan()
	return scanner.Text()

}

func check(err error) {
	if err != nil {
		errorLog, osError := os.OpenFile("/log.txt", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
		if osError != nil {
			log.Fatal(err)
		}
		defer errorLog.Close()
		textLogger := log.New(errorLog, "go-webserver", log.LstdFlags)
		switch err {
		case http.ErrMissingFile:
			log.Print(err)
			textLogger.Fatalln("File missing/cannot be accessed : ", err)
		case sql.ErrTxDone:
			log.Print(err)
			textLogger.Fatalln("SQL connection failure : ", err)
		}
		log.Println("An error has occured : ", err)
	}
}

func checkDB(t *time.Ticker, db *sql.DB) {
	for i := range t.C {
		err := db.Ping()
		if err != nil {
			fmt.Println("Db connection failed at : ", i)
			check(err)
		} else {
			fmt.Println("Db connection successful : ", i)
		}
	}
}


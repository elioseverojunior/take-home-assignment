package main

import (
	"bufio"
	"context"
	"database/sql"
	"dockerize/version"
	"errors"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	_ "github.com/go-sql-driver/mysql"

	logger "dockerize/logging"
	"dockerize/webserver/articlehandler"
)

var (
	log = logger.InitLogrusLogger()
)

func readConfig(s string) string {
	config, err := os.Open(s)
	check(err)
	defer config.Close()

	scanner := bufio.NewScanner(config)
	scanner.Scan()
	return scanner.Text()
}

func init() {
	// TODO: Needs to check how to connect with MySQL Server using configuration connections strings
	//db, err := sql.Open("mysql",
	//    os.Getenv("MYSQL_USER")+":"+
	//        os.Getenv("MYSQL_PASSWORD")+
	//        "@tcp("+os.Getenv("MYSQL_HOST")+":"+
	//        os.Getenv("MYSQL_PORT")+")/"+os.Getenv("MYSQL_DATABASE"))
	//db, err := sql.Open("mysql", "blogpost_user:@blogpostP@ssw0rd@tcp(10.87.33.212:3306)/blog")
	dbString := readConfig("server.config")
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
	log.Printf(
		"Starting the service... commit: %s, build time: %s, release: %s",
		version.Commit, version.BuildTime, version.Release,
	)
	http.Handle("/", http.FileServer(http.Dir("./src")))
	http.HandleFunc("/articles/", logger.LoggerHandler(articlehandler.ReturnArticle))
	http.HandleFunc("/index.html", logger.LoggerHandler(articlehandler.ReturnHomePage))
	http.HandleFunc("/api/articles", logger.LoggerHandler(articlehandler.ReturnArticlesForHomePage))
	http.HandleFunc("/api/version", logger.LoggerHandler(version.VersionInfo))

	server := &http.Server{
		Addr:    ":8080",
		Handler: nil,
	}

	go func() {
		if err := server.ListenAndServe(); !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("HTTP server error: %v", err)
		}
		log.Println("Stopped serving new connections.")
	}()

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	<-sigChan

	shutdownCtx, shutdownRelease := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutdownRelease()

	if err := server.Shutdown(shutdownCtx); err != nil {
		log.Fatalf("HTTP shutdown error: %v", err)
	}
	log.Println("Graceful shutdown complete.")
}

func check(err error) {
	if err != nil {
		switch err {
		case http.ErrMissingFile:
			log.Print(err)
			log.Fatalln("File missing/cannot be accessed : ", err)
		case sql.ErrTxDone:
			log.Print(err)
			log.Fatalln("SQL connection failure : ", err)
		}
		log.Println("An error has occurred : ", err)
	}
}

func checkDB(t *time.Ticker, db *sql.DB) {
	for i := range t.C {
		err := db.Ping()
		if err != nil {
			log.Println("Db connection failed at : ", i)
			check(err)
		} else {
			log.Println("Db connection successful : ", i)
		}
	}
}

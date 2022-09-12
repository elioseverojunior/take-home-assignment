package articlehandler

import (
	"database/sql"
	logger "dockerize/logging"
	"dockerize/models"
	"encoding/json"
	"html/template"
	"net/http"
	"strconv"
	"strings"
)

var (
	log   = logger.InitLogrusLogger()
	sqldb *sql.DB
)

// Article Struct
type Article struct {
	ID       uint        `db:"idblog_posts" json:"id"`
	Title    string      `db:"title" json:"title"`
	PostText string      `db:"post_text" json:"post_text"`
	Date     string      `db:"date" json:"date"`
	ImageURL string      `db:"image_url" json:"image_url"`
	Tags     models.Tags `db:"tags" json:"tags"`
}

type postBin struct {
	Posters []Article
}

// PassDataBase passes the mysql_baseline to the articleHandlers.
func PassDataBase(db *sql.DB) {
	sqldb = db
}

// ReturnArticle Returns an individual Article after receiving a request containing a "/Article/" within the URL
func ReturnArticle(w http.ResponseWriter, r *http.Request) {
	requestURI := strings.SplitAfter(r.RequestURI, "/")
	articleID, err := strconv.Atoi(requestURI[len(requestURI)-1])
	articleTemplate, err := template.ParseFiles("./src/articles/article.html")
	article := getArticle(articleID)
	err = articleTemplate.Execute(w, article)
	//Article, err := json.Marshal(getArticle(articleID))
	if err != nil {
		log.Fatal("Fatal parsing error : ", err)
	}
}

// ReturnArticlesForHomePage returns a JSON response containing data on the Articles
func ReturnArticlesForHomePage(w http.ResponseWriter, r *http.Request) {
	articles, err := json.Marshal(frontPagePosts())
	if err != nil {
		log.Fatal("JSON FAIL", err)
	}
	w.Header().Set("Content-Type", "application/json")
	w.Write(articles)
}

// ReturnHomePage Returns the index.html of the site, now populated by VUE.js components dynamically.
func ReturnHomePage(w http.ResponseWriter, r *http.Request) {
	http.ServeFile(w, r, "./src/index.html")
}

func frontPagePosts() postBin {
	returnPost, err := sqldb.Query("SELECT * FROM blog.blog_posts LIMIT 5")
	if err != nil {
		log.Fatal("sqldb statement failed : ", err)
	}
	var dbResults []Article
	defer returnPost.Close()
	for returnPost.Next() {
		var bp Article
		err := returnPost.Scan(&bp.ID, &bp.Title, &bp.PostText, &bp.Date, &bp.ImageURL, &bp.Tags)
		if err != nil {
			log.Fatal(err)
		}
		log.Printf("%v\n", bp)
		//bp.PostText = bp.PostText[0:40] # TODO: Needs to check why it's reading first 40 chars of PostText
		dbResults = append(dbResults, bp)
	}
	pb := postBin{
		dbResults,
	}
	return pb
}

func getArticle(id int) Article {
	var bp = Article{}
	s, err := sqldb.Prepare("SELECT * from blog.blog_posts WHERE idblog_posts = ?")
	if err != nil {
		log.Fatal("Statement prep failed : ", err)
	}
	returnArticle := s.QueryRow(id)
	returnArticle.Scan(&bp.ID, &bp.Title, &bp.PostText, &bp.Date, &bp.ImageURL, &bp.Tags)
	return bp
}

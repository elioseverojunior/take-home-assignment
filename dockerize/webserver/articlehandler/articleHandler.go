package articlehandler

import (
	"database/sql"
	"html/template"
	"log"
	"net/http"
	"strconv"
	"strings"
	"encoding/json"
)

type article struct {
	ID       int
	Title    string
	PostText string
	Date     string
	ImageURL string
	Tags     []string
}

type postBin struct {
	Posters []article
}

var sqldb *sql.DB

//PassDataBase passes the database to the articleHandlers.
func PassDataBase(db *sql.DB) {
	sqldb = db
}

//ReturnArticle Returns an individual article after recieveing a request containing a "/article/" within the URL
func ReturnArticle(w http.ResponseWriter, r *http.Request) {
	requestURI := strings.SplitAfter(r.RequestURI, "/")
	articleID, err := strconv.Atoi(requestURI[len(requestURI)-1])
	template, err := template.ParseFiles("./src/articles/article.html")
	article := getArticle(articleID)
	err = template.Execute(w, article)
	//article, err := json.Marshal(getArticle(articleID))
	if err != nil {
		log.Fatal("Fatal parsing error : ", err)
	}
}
//ReturnArticlesForHomePage returns a JSON response containing data on the Articles
func ReturnArticlesForHomePage(w http.ResponseWriter, r *http.Request){
	articles, err := json.Marshal(frontPagePosts())
	if err != nil {
		log.Fatal("JSON FAIL", err)
	}
	w.Header().Set("Content-Type", "application/json")
	w.Write(articles)

}



//ReturnHomePage Returns the index.html of the site, now populated by VUE.js components dynamically. 
func ReturnHomePage(w http.ResponseWriter, r *http.Request) {

	http.ServeFile(w, r, "./src/index.html")

}

func frontPagePosts() postBin {
	returnPost, err := sqldb.Query("SELECT * FROM blog.blog_posts LIMIT 5")
	if err != nil {
		log.Fatal("sqldb statement failed : ", err)
	}
	var dbResults []article
	defer returnPost.Close()
	for returnPost.Next() {
		var bp article
		returnPost.Scan(&bp.ID, &bp.Title, &bp.PostText, &bp.Date)
		bp.PostText = bp.PostText[0:40]
		dbResults = append(dbResults, bp)
	}
	pb := postBin{
		dbResults,
	}
	return pb
}

func getArticle(id int) article {
	var ar = article{}
	s, err := sqldb.Prepare("SELECT * from blog.blog_posts WHERE idblog_posts = ?")
	if err != nil {
		log.Fatal("Statement prep failed : ", err)
	}
	returnArticle := s.QueryRow(id)
	returnArticle.Scan(&ar.ID, &ar.Title, &ar.PostText, &ar.Date)
	return ar
}


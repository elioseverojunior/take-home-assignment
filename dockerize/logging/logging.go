package logging

import (
	"bufio"
	"fmt"
	"github.com/sirupsen/logrus"
	"github.com/x-cray/logrus-prefixed-formatter"
	"net"
	"net/http"
	"os"
	"time"
)

// Acts as an adapter for http.ResponseWriter type to store request and
// response data.
type writer struct {
	http.ResponseWriter

	reqClientIP  string
	reqHost      string
	reqMethod    string
	reqPath      string
	reqProto     string
	reqSize      int64 // bytes
	reqTime      string
	reqUserAgent string
	resStatus    int
	resSize      int // bytes
}

var log = InitLogrusLogger()

func InitLogrusLogger() *logrus.Logger {
	return &logrus.Logger{
		Out:   os.Stdout,
		Level: logrus.TraceLevel,
		Formatter: &prefixed.TextFormatter{
			DisableColors:   false,
			TimestampFormat: "2006-01-02T15:04:05.068+00:00",
			FullTimestamp:   true,
			ForceFormatting: true,
		},
	}
}

// LoggerHandler helps logging request and response related data.
func LoggerHandler(h http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		t := time.Now()

		wr := newWriter(w, r, t)

		h.ServeHTTP(wr, r)

		log.WithFields(logrus.Fields{
			"http_req_client_ip":  wr.reqClientIP,
			"http_req_duration":   time.Since(t).Milliseconds(),
			"http_req_host":       wr.reqHost,
			"http_req_method":     wr.reqMethod,
			"http_req_path":       wr.reqPath,
			"http_req_protocol":   wr.reqProto,
			"http_req_size":       wr.reqSize,
			"http_req_time":       wr.reqTime,
			"http_req_user_agent": wr.reqUserAgent,
			"http_res_size":       wr.resSize,
			"http_res_status":     wr.resStatus,
		}).Log(logrus.GetLevel())
	}
}

func newWriter(w http.ResponseWriter, r *http.Request, t time.Time) *writer {
	return &writer{
		ResponseWriter: w,

		reqClientIP:  r.Header.Get("X-Forwarded-For"),
		reqMethod:    r.Method,
		reqHost:      r.Host,
		reqPath:      r.RequestURI,
		reqProto:     r.Proto,
		reqSize:      r.ContentLength,
		reqTime:      t.Format(time.RFC3339),
		reqUserAgent: r.UserAgent(),
	}
}

// WriteHeader Overrides http.ResponseWriter type.
func (w *writer) WriteHeader(status int) {
	if w.resStatus == 0 {
		w.resStatus = status
		w.ResponseWriter.WriteHeader(status)
	}
}

// Overrides http.ResponseWriter type.
func (w *writer) Write(body []byte) (int, error) {
	if w.resStatus == 0 {
		w.WriteHeader(http.StatusOK)
	}

	var err error
	w.resSize, err = w.ResponseWriter.Write(body)

	return w.resSize, err
}

// Flush Overrides http.Flusher type.
func (w *writer) Flush() {
	if fl, ok := w.ResponseWriter.(http.Flusher); ok {
		if w.resStatus == 0 {
			w.WriteHeader(http.StatusOK)
		}

		fl.Flush()
	}
}

// Hijack Overrides http.Hijacker type.
func (w *writer) Hijack() (net.Conn, *bufio.ReadWriter, error) {
	hj, ok := w.ResponseWriter.(http.Hijacker)
	if !ok {
		return nil, nil, fmt.Errorf("the hijacker interface is not supported")
	}

	return hj.Hijack()
}

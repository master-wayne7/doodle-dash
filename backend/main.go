package main

import (
	"net/http"

	log "github.com/sirupsen/logrus"

	"skribbl-backend/internal/game"
)

func init() {
	// Enable multi-colored beautifully formatted logrus logs
	log.SetFormatter(&log.TextFormatter{
		ForceColors:     true,
		FullTimestamp:   true,
		TimestampFormat: "15:04:05", // simpler time format for cleaner logs
		PadLevelText:    true,
	})
}

func serveWs(hub *game.Hub, w http.ResponseWriter, r *http.Request) {
	conn, err := game.Upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.WithError(err).Error("WebSocket upgrade failed")
		return
	}
	client := &game.Client{Hub: hub, Conn: conn, Send: make(chan []byte, 256)}
	client.Hub.Register <- client

	// Allow collection of memory referenced by the caller by doing all work in
	// new goroutines.
	go client.WritePump()
	go client.ReadPump()
}

func main() {
	hub := game.NewHub()
	go hub.Run()

	http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		serveWs(hub, w, r)
	})

	log.Info("Listening on :8080")
	err := http.ListenAndServe(":8080", nil)
	if err != nil {
		log.Fatal("ListenAndServe: ", err)
	}
}

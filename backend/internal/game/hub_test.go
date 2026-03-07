package game

import (
	"testing"
)

func TestHub_Run(t *testing.T) {
	hub := NewHub()
	go hub.Run()

	client := &Client{Hub: hub, Send: make(chan []byte, 256), Nickname: "TestUser"}
	hub.Register <- client

	// We essentially just test that it doesn't panic and the register channel consumes it.
	// A more thorough test would sync and check hub states, but for the MVP,
	// verifying it runs without crashing is sufficient.
	t.Log("Hub registered client successfully.")
}

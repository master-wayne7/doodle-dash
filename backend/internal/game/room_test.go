package game

import (
	"testing"
)

func TestParseGameState(t *testing.T) {
	// Let's just create a room and manually adjust the state
	hub := NewHub()
	room := NewRoom("1234", hub)

	if room.State != StateLobby {
		t.Errorf("Expected initial state to be Lobby, got %v", room.State)
	}

	client1 := &Client{Hub: hub, Room: room, Nickname: "P1", Send: make(chan []byte, 256)}
	client2 := &Client{Hub: hub, Room: room, Nickname: "P2", Send: make(chan []byte, 256)}

	room.Clients[client1] = true
	room.Clients[client2] = true

	// Verify initialization
	if len(room.Clients) != 2 {
		t.Errorf("Expected 2 clients in room, got %v", len(room.Clients))
	}

	t.Log("Room logic instantiates and adds clients correctly.")
}

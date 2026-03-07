package game

import (
	"math/rand"
	"sync"
	"time"

	log "github.com/sirupsen/logrus"
)

type Hub struct {
	Rooms      map[string]*Room
	Clients    map[*Client]bool
	Register   chan *Client
	Unregister chan *Client
	DeleteRoom chan string

	mu sync.Mutex
}

func NewHub() *Hub {
	return &Hub{
		Rooms:      make(map[string]*Room),
		Clients:    make(map[*Client]bool),
		Register:   make(chan *Client),
		Unregister: make(chan *Client),
		DeleteRoom: make(chan string),
	}
}

func (h *Hub) Run() {
	for {
		select {
		case client := <-h.Register:
			h.mu.Lock()
			h.Clients[client] = true
			h.mu.Unlock()
		case client := <-h.Unregister:
			h.mu.Lock()
			if _, ok := h.Clients[client]; ok {
				delete(h.Clients, client)
				close(client.Send)
			}
			h.mu.Unlock()
		case roomID := <-h.DeleteRoom:
			h.mu.Lock()
			delete(h.Rooms, roomID)
			h.mu.Unlock()
		}
	}
}

func (h *Hub) ProcessMessage(c *Client, msg map[string]interface{}) {
	msgType, ok := msg["type"].(string)
	if !ok {
		return
	}

	if msgType == "join_room" {
		roomID, ok := msg["room_id"].(string)
		nickname, _ := msg["nickname"].(string)

		h.mu.Lock()
		if !ok || roomID == "" {
			// Find an available room
			for id, r := range h.Rooms {
				r.mu.Lock()
				numClients := len(r.Clients)
				r.mu.Unlock()
				if numClients < 8 {
					roomID = id
					log.WithFields(log.Fields{
						"room": roomID,
					}).Info("Matchmaking found an open room")
					break
				}
			}
			if roomID == "" {
				// Generate random room id
				roomID = generateRandomString(6)
				log.WithFields(log.Fields{
					"room": roomID,
				}).Info("Matchmaking created a new room")
			}
		}

		if nickname == "" {
			nickname = "Guest"
		}

		c.Nickname = nickname

		room, exists := h.Rooms[roomID]
		if !exists {
			room = NewRoom(roomID, h)
			h.Rooms[roomID] = room
			log.WithFields(log.Fields{"room": roomID}).Info("New room instantiated")
			go room.Run()
		}
		h.mu.Unlock()

		c.Room = room

		// Send joined_room
		log.WithFields(log.Fields{
			"nickname": nickname,
			"room":     roomID,
		}).Info("Player joined room")
		c.Send <- []byte(`{"type": "joined_room", "room_id": "` + roomID + `"}`)

		room.Join <- c
	}
}

const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

var seededRand *rand.Rand = rand.New(rand.NewSource(time.Now().UnixNano()))

func generateRandomString(length int) string {
	b := make([]byte, length)
	for i := range b {
		b[i] = charset[seededRand.Intn(len(charset))]
	}
	return string(b)
}

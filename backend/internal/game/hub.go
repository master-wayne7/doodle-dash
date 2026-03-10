package game

import (
	"math/rand"
	"sync"
	"time"

	log "github.com/sirupsen/logrus"
)

// / Hub maintains the set of active rooms and unattached clients, and handles message routing.
type Hub struct {
	Rooms      map[string]*Room
	Clients    map[*Client]bool
	Register   chan *Client
	Unregister chan *Client
	DeleteRoom chan string

	mu sync.Mutex
}

// / NewHub initializes and returns a new empty Hub.
func NewHub() *Hub {
	return &Hub{
		Rooms:      make(map[string]*Room),
		Clients:    make(map[*Client]bool),
		Register:   make(chan *Client, 256),
		Unregister: make(chan *Client, 256),
		DeleteRoom: make(chan string, 128),
	}
}

// / Run starts the Hub's main event loop for client registration, unregistration, and room deletion.
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
				client.closeOnce.Do(func() {
					close(client.Send)
				})
			}
			h.mu.Unlock()
		case roomID := <-h.DeleteRoom:
			h.mu.Lock()
			if room, ok := h.Rooms[roomID]; ok {
				close(room.Quit)
				delete(h.Rooms, roomID)
			}
			h.mu.Unlock()
		}
	}
}

// / ProcessMessage parses incoming messages from clients not yet fully assigned to a room context (like joining a room).
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
		c.ID = generateRandomString(12)
		c.JoinedAt = time.Now()

		if avatarMap, ok := msg["avatar"].(map[string]interface{}); ok {
			c.Avatar.Color = int(avatarMap["color"].(float64))
			c.Avatar.Eyes = int(avatarMap["eyes"].(float64))
			c.Avatar.Mouth = int(avatarMap["mouth"].(float64))
		} else {
			c.Avatar = Avatar{Color: 11, Eyes: 30, Mouth: 23}
		}

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
		c.Send <- []byte(`{"type": "joined_room", "room_id": "` + roomID + `", "player_id": "` + c.ID + `"}`)

		// Joining room is done outside the Hub lock to prevent deadlock
		room.Join <- c
	}
}

const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

var seededRand *rand.Rand = rand.New(rand.NewSource(time.Now().UnixNano()))

// / generateRandomString creates a random alphanumeric string of a given length, primarily used for IDs.
func generateRandomString(length int) string {
	b := make([]byte, length)
	for i := range b {
		b[i] = charset[seededRand.Intn(len(charset))]
	}
	return string(b)
}

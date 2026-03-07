package game

import (
	"encoding/json"
	"net/http"
	"time"

	log "github.com/sirupsen/logrus"

	"github.com/gorilla/websocket"
)

const (
	writeWait      = 10 * time.Second
	pongWait       = 60 * time.Second
	pingPeriod     = (pongWait * 9) / 10
	maxMessageSize = 1024 * 10
)

var Upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	// Allow all origins for development
	CheckOrigin: func(r *http.Request) bool { return true },
}

type Client struct {
	Hub         *Hub
	Room        *Room
	Conn        *websocket.Conn
	Send        chan []byte
	ID          string
	Nickname    string
	Score       int
	TurnScore   int
	IsDrawer    bool
	GuessedWord bool
	JoinedAt    time.Time
	Voted       bool
}

// ReadPump pumps messages from the websocket connection to the room.
func (c *Client) ReadPump() {
	defer func() {
		if c.Room != nil {
			c.Room.Leave <- c
		} else {
			c.Hub.Unregister <- c
		}
		c.Conn.Close()
	}()
	c.Conn.SetReadLimit(maxMessageSize)
	c.Conn.SetReadDeadline(time.Now().Add(pongWait))
	c.Conn.SetPongHandler(func(string) error { c.Conn.SetReadDeadline(time.Now().Add(pongWait)); return nil })

	for {
		_, message, err := c.Conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.WithError(err).Error("Unexpected WebSocket close error")
			}
			break
		}

		var rawMsg map[string]interface{}
		if err := json.Unmarshal(message, &rawMsg); err != nil {
			log.WithError(err).Error("Invalid JSON structure")
			continue
		}

		// Pre-process certain message types here if needed,
		// or send raw to Room for handling.
		if c.Room != nil {
			c.Room.ProcessMessage(c, rawMsg)
		} else {
			// Handle out-of-room messages (like join_room)
			c.Hub.ProcessMessage(c, rawMsg)
		}
	}
}

// WritePump pumps messages from the room to the websocket connection.
func (c *Client) WritePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.Conn.Close()
	}()
	for {
		select {
		case message, ok := <-c.Send:
			c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				c.Conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := c.Conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)

			// Add queued messages to the current websocket message.
			n := len(c.Send)
			for i := 0; i < n; i++ {
				w.Write([]byte{'\n'})
				w.Write(<-c.Send)
			}

			if err := w.Close(); err != nil {
				return
			}
		case <-ticker.C:
			c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.Conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
func (c *Client) SendPrivateMessage(content string) {
	msg, _ := json.Marshal(map[string]interface{}{
		"type":     "chat",
		"sender":   "System",
		"content":  content,
		"isSystem": "true",
		"isShadow": "true", // Use shadow styling for private proximity messages
	})
	select {
	case c.Send <- msg:
	default:
	}
}

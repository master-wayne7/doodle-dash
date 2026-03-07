package game

import (
	"encoding/json"
)

func (r *Room) broadcastMessage(message []byte) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.broadcastMessageLocked(message)
}

func (r *Room) broadcastMessageLocked(message []byte) {
	for client := range r.Clients {
		select {
		case client.Send <- message:
		default:
			close(client.Send)
			delete(r.Clients, client)
		}
	}
}

func (r *Room) broadcastSystemMessage(msg string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.broadcastSystemMessageLocked(msg)
}

func (r *Room) broadcastSystemMessageLocked(msg string) {
	b, _ := json.Marshal(map[string]interface{}{
		"type":    "system",
		"content": msg,
	})
	r.broadcastMessageLocked(b)
}

func (r *Room) broadcastGameState() {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.broadcastGameStateLocked()
}

func (r *Room) broadcastGameStateLocked() {
	var drawerNickname string
	if r.Drawer != nil {
		drawerNickname = r.Drawer.Nickname
	}

	word := ""
	if r.State == StateTurnEnd || r.State == StateGameOver {
		word = r.CurrentWord
	}

	for client := range r.Clients {
		isDrawer := (r.Drawer != nil && client == r.Drawer)
		clientWord := word
		if isDrawer && r.State == StateDrawing {
			clientWord = r.CurrentWord
		}

		b, _ := json.Marshal(map[string]interface{}{
			"type":       "game_state",
			"state":      r.State,
			"round":      r.RoundNumber,
			"max_rounds": r.MaxRounds,
			"drawer":     drawerNickname,
			"hint":       r.getHintLocked(isDrawer),
			"word":       clientWord,
			"time_left":  r.TimeLeft,
		})
		select {
		case client.Send <- b:
		default:
			close(client.Send)
			delete(r.Clients, client)
		}
	}
}

func (r *Room) sendGameStateTo(c *Client) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.sendGameStateToLocked(c)
}

func (r *Room) sendGameStateToLocked(c *Client) {
	var drawerNickname string
	if r.Drawer != nil {
		drawerNickname = r.Drawer.Nickname
	}

	isDrawer := (r.Drawer != nil && c == r.Drawer)

	word := ""
	if r.State == StateTurnEnd || r.State == StateGameOver {
		word = r.CurrentWord
	} else if isDrawer && r.State == StateDrawing {
		word = r.CurrentWord
	}

	b, _ := json.Marshal(map[string]interface{}{
		"type":       "game_state",
		"state":      r.State,
		"round":      r.RoundNumber,
		"max_rounds": r.MaxRounds,
		"drawer":     drawerNickname,
		"hint":       r.getHintLocked(isDrawer),
		"word":       word,
		"time_left":  r.TimeLeft,
	})
	select {
	case c.Send <- b:
	default:
	}
}

func (r *Room) broadcastTimerLocked() {
	b, _ := json.Marshal(map[string]interface{}{
		"type":      "timer",
		"time_left": r.TimeLeft,
		"hint":      r.getHintLocked(false),
	})
	r.broadcastMessageLocked(b)
}

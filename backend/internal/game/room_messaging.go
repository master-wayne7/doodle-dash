package game

import (
	"encoding/json"
)

// / broadcastMessage sends a raw byte message to all clients currently in the room.
// / It acquires the room lock before calling the internal locked version.
func (r *Room) broadcastMessage(message []byte) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.broadcastMessageLocked(message)
}

// / broadcastMessageLocked sends a raw byte message to all clients.
// / The caller must hold the room's mutex (`r.mu`). If a client's channel is full or closed, they are removed.
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

// / broadcastSystemMessage sends a structured system-level chat message to all clients.
func (r *Room) broadcastSystemMessage(msg string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.broadcastSystemMessageLocked(msg)
}

// / broadcastSystemMessageLocked sends a structured system message without acquiring the lock.
func (r *Room) broadcastSystemMessageLocked(msg string) {
	b, _ := json.Marshal(map[string]interface{}{
		"type":    "system",
		"content": msg,
	})
	r.broadcastMessageLocked(b)
}

// / broadcastGameState sends the current full game state to all players.
func (r *Room) broadcastGameState() {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.broadcastGameStateLocked()
}

// / broadcastGameStateLocked sends the current game state to all players.
// / It obfuscates the word for non-drawers during the drawing phase.
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
		if r.State == StateDrawing {
			if isDrawer || client.GuessedWord {
				clientWord = r.CurrentWord
			}
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

// / sendGameStateTo sends the current game state to a specific client.
func (r *Room) sendGameStateTo(c *Client) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.sendGameStateToLocked(c)
}

// / sendGameStateToLocked sends the current state to a specific client without acquiring the lock.
func (r *Room) sendGameStateToLocked(c *Client) {
	var drawerNickname string
	if r.Drawer != nil {
		drawerNickname = r.Drawer.Nickname
	}

	isDrawer := (r.Drawer != nil && c == r.Drawer)

	word := ""
	if r.State == StateTurnEnd || r.State == StateGameOver {
		word = r.CurrentWord
	} else if r.State == StateDrawing {
		if isDrawer || c.GuessedWord {
			word = r.CurrentWord
		}
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

// / broadcastTimerLocked sends the remaining time and the current hint to all clients.
func (r *Room) broadcastTimerLocked() {
	b, _ := json.Marshal(map[string]interface{}{
		"type":      "timer",
		"time_left": r.TimeLeft,
		"hint":      r.getHintLocked(false),
	})
	r.broadcastMessageLocked(b)
}

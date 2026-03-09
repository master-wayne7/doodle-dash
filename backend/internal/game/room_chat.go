package game

import (
	"encoding/json"
	"fmt"
	"strings"
)

// / ProcessMessage routes incoming client messages to the appropriate handler based on the message type.
func (r *Room) ProcessMessage(c *Client, msg map[string]interface{}) {
	msgType, _ := msg["type"].(string)

	switch msgType {
	case "chat":
		r.handleChat(c, msg)
	case "draw":
		r.handleDraw(c, msg)
	case "choose_word":
		r.handleWordSelection(c, msg)
	case "vote":
		r.handleVote(c, msg)
	case "vote_kick":
		r.handleVoteKick(c, msg)
	}
}

// / handleChat processes chat messages, checks for correct word guesses, and broadcasts the chat to others.
func (r *Room) handleChat(c *Client, msg map[string]interface{}) {
	content, _ := msg["content"].(string)

	if r.State == StateDrawing && c != r.Drawer && !c.GuessedWord {
		if strings.EqualFold(strings.TrimSpace(content), r.CurrentWord) {
			r.markGuessed(c)
			return
		}
	}

	isShadow := "false"
	if c.GuessedWord || (r.Drawer != nil && c == r.Drawer) {
		isShadow = "true"
	}

	b, _ := json.Marshal(map[string]interface{}{
		"type":     "chat",
		"sender":   c.Nickname,
		"content":  content,
		"isShadow": isShadow,
	})

	if isShadow == "true" {
		r.mu.Lock()
		for client := range r.Clients {
			if (r.Drawer != nil && client == r.Drawer) || client.GuessedWord {
				select {
				case client.Send <- b:
				default:
				}
			}
		}
		r.mu.Unlock()
	} else {
		r.broadcastMessage(b)
	}

	if r.State == StateDrawing && !c.GuessedWord && !c.IsDrawer {
		dist := levenshteinDistance(content, r.CurrentWord)
		if dist > 0 && dist <= closeThreshold(len(r.CurrentWord)) {
			c.SendPrivateMessage(fmt.Sprintf("%s is close!", content))
		}
	}
}

// / markGuessed updates a client's state after correctly guessing the word, awards points, and checks if the turn should end.
func (r *Room) markGuessed(c *Client) {
	c.GuessedWord = true
	points := (r.TimeLeft * 10) + (len(r.Clients) * 5)
	if points < 10 {
		points = 10
	}
	c.TurnScore += points

	if r.Drawer != nil {
		r.Drawer.TurnScore += points / (len(r.Clients) - 1)
	}

	r.broadcastSystemMessage(fmt.Sprintf("%s guessed the word!", c.Nickname))
	r.broadcastPlayerList()

	r.mu.Lock()
	allGuessed := true
	for client := range r.Clients {
		if !client.IsDrawer && !client.GuessedWord {
			allGuessed = false
		}
	}
	r.mu.Unlock()

	if allGuessed {
		r.endTurn()
	}
}

// / handleDraw processes drawing events from the current drawer and broadcasts them to all other clients.
func (r *Room) handleDraw(c *Client, msg map[string]interface{}) {
	if r.State == StateDrawing && c == r.Drawer {
		r.mu.Lock()
		r.DrawHistory = append(r.DrawHistory, msg)
		r.mu.Unlock()
		b, _ := json.Marshal(msg)
		r.broadcastMessage(b)
	}
}

// / handleWordSelection processes the drawer's choice of word from the provided options.
func (r *Room) handleWordSelection(c *Client, msg map[string]interface{}) {
	if r.State == StateChoosing && c == r.Drawer {
		word, _ := msg["word"].(string)
		for _, w := range r.WordChoices {
			if w == word {
				r.selectWord(word)
				return
			}
		}
	}
}

// / handleVote processes positive or negative votes on the current drawing and broadcasts the updated status.
func (r *Room) handleVote(c *Client, msg map[string]interface{}) {
	if r.State == StateDrawing && !c.IsDrawer && !c.Voted {
		voteType, _ := msg["vote"].(string)
		c.Voted = true
		r.broadcastSystemMessage(fmt.Sprintf("%s has %sd the drawing!", c.Nickname, voteType))
		b, _ := json.Marshal(map[string]interface{}{
			"type": "vote_update", "sender": c.Nickname, "vote": voteType,
		})
		r.broadcastMessage(b)
		r.broadcastPlayerList()
	}
}

// / handleVoteKick processes a player's vote to kick another player. If the threshold is reached, the target is removed.
func (r *Room) handleVoteKick(c *Client, msg map[string]interface{}) {
	targetID, _ := msg["target"].(string)
	if targetID == c.ID {
		return // Can't kick yourself
	}

	r.mu.Lock()
	if r.VoteKicks[targetID] == nil {
		r.VoteKicks[targetID] = make(map[string]bool)
	}
	r.VoteKicks[targetID][c.ID] = true

	votes := len(r.VoteKicks[targetID])
	playerCount := len(r.Clients)

	var targetClient *Client
	for client := range r.Clients {
		if client.ID == targetID {
			targetClient = client
			break
		}
	}
	r.mu.Unlock()

	if targetClient == nil {
		return
	}

	threshold := 1
	if playerCount <= 3 {
		threshold = 1
	} else if playerCount == 4 {
		threshold = 2
	} else if playerCount >= 5 {
		threshold = 3
	} else if playerCount == 6 {
		threshold = 4
	} else if playerCount >= 7 {
		threshold = 5
	}

	r.broadcastSystemMessage(fmt.Sprintf("%s has voted to kick %s [%d/%d]", c.Nickname, targetClient.Nickname, votes, threshold))

	if votes >= threshold {
		kickedMsg, _ := json.Marshal(map[string]interface{}{"type": "kicked"})
		select {
		case targetClient.Send <- kickedMsg:
		default:
		}
		r.Leave <- targetClient
	}
}

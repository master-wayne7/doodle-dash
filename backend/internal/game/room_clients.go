package game

import (
	"encoding/json"
	"sort"
)

func (r *Room) addClient(client *Client) {
	r.mu.Lock()
	r.Clients[client] = true
	history := make([]map[string]interface{}, len(r.DrawHistory))
	copy(history, r.DrawHistory)

	r.sendGameStateToLocked(client)
	r.broadcastPlayerListLocked()
	r.mu.Unlock()

	for _, histMsg := range history {
		b, _ := json.Marshal(histMsg)
		client.Send <- b
	}

	r.checkStartGame()
}

func (r *Room) removeClient(client *Client) {
	r.mu.Lock()
	if _, ok := r.Clients[client]; ok {
		delete(r.Clients, client)
		close(client.Send)
	}
	numClients := len(r.Clients)
	isDrawer := client == r.Drawer
	state := r.State

	if numClients == 0 {
		r.mu.Unlock()
		r.Hub.DeleteRoom <- r.ID
		r.setTimeLeft(0)
		return
	}
	r.broadcastPlayerListLocked()
	r.mu.Unlock()

	if state == StateDrawing && isDrawer {
		r.endTurn()
	} else if numClients < 2 && state != StateLobby {
		r.changeState(StateLobby)
	}
}

func (r *Room) broadcastPlayerList() {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.broadcastPlayerListLocked()
}

func (r *Room) broadcastPlayerListLocked() {
	var clients []*Client
	for client := range r.Clients {
		clients = append(clients, client)
	}

	sort.Slice(clients, func(i, j int) bool {
		return clients[i].JoinedAt.Before(clients[j].JoinedAt)
	})

	var players []map[string]interface{}
	for _, client := range clients {
		players = append(players, map[string]interface{}{
			"id":          client.ID,
			"nickname":    client.Nickname,
			"score":       client.Score,
			"turn_score":  client.TurnScore,
			"isDrawer":    (r.Drawer != nil && client == r.Drawer),
			"guessedWord": client.GuessedWord,
			"voted":       client.Voted,
		})
	}

	b, _ := json.Marshal(map[string]interface{}{
		"type":    "players",
		"players": players,
	})
	r.broadcastMessageLocked(b)
}

func (r *Room) checkStartGame() {
	r.mu.Lock()
	shouldStart := r.State == StateLobby && len(r.Clients) >= 2
	if shouldStart {
		r.RoundNumber = 0
		for c := range r.Clients {
			c.Score = 0
		}
	}
	r.mu.Unlock()

	if shouldStart {
		r.changeState(StateStarting)
	}
}

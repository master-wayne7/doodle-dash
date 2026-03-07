package game

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"sync"
)

type GameState string

const (
	StateLobby    GameState = "lobby"
	StateStarting GameState = "starting"
	StateRound    GameState = "round"
	StateChoosing GameState = "choosing"
	StateDrawing  GameState = "drawing"
	StateTurnEnd  GameState = "turn_end"
	StateGameOver GameState = "game_over"
)

type Room struct {
	ID      string
	Hub     *Hub
	Clients map[*Client]bool
	Join    chan *Client
	Leave   chan *Client

	State       GameState
	RoundNumber int
	MaxRounds   int
	CurrentWord string
	WordChoices []string
	Drawer      *Client
	TurnQueue   []*Client
	DrawHistory []map[string]interface{}
	HintIndices []int

	TimeLeft    int
	tickerMutex sync.Mutex
	mu          sync.Mutex
}

func NewRoom(id string, hub *Hub) *Room {
	r := &Room{
		ID:        id,
		Hub:       hub,
		Clients:   make(map[*Client]bool),
		Join:      make(chan *Client),
		Leave:     make(chan *Client),
		State:     StateLobby,
		MaxRounds: 3,
	}
	if id != "test" {
		go r.runTimer()
	}
	return r
}

func (r *Room) Run() {
	for {
		select {
		case client := <-r.Join:
			r.addClient(client)
		case client := <-r.Leave:
			r.removeClient(client)
		}
	}
}

func (r *Room) changeState(newState GameState) {
	r.mu.Lock()
	r.State = newState

	switch newState {
	case StateLobby:
		r.setTimeLeft(0)
		r.broadcastSystemMessageLocked("Waiting for more players...")
	case StateStarting:
		r.setTimeLeft(5)
		r.broadcastSystemMessageLocked("Game is starting soon...")
		r.broadcastGameStateLocked()
	case StateRound:
		r.broadcastGameStateLocked()
		r.setTimeLeft(3)
	case StateChoosing:
		r.broadcastPlayerListLocked()
		r.WordChoices = GetRandomWords(3)
		r.CurrentWord = r.WordChoices[0]
		r.HintIndices = make([]int, 0)
		for i, ch := range r.CurrentWord {
			if string(ch) != " " {
				r.HintIndices = append(r.HintIndices, i)
			}
		}
		rand.Shuffle(len(r.HintIndices), func(i, j int) {
			r.HintIndices[i], r.HintIndices[j] = r.HintIndices[j], r.HintIndices[i]
		})
		choicesMsg, _ := json.Marshal(map[string]interface{}{
			"type": "word_choices", "words": r.WordChoices,
		})
		if r.Drawer != nil {
			r.Drawer.Send <- choicesMsg
			r.broadcastSystemMessageLocked(fmt.Sprintf("%s is choosing a word...", r.Drawer.Nickname))
		}
		r.broadcastGameStateLocked()
		r.setTimeLeft(10)
	case StateDrawing:
		r.setTimeLeft(60)
		for c := range r.Clients {
			c.TurnScore = 0
			c.Voted = false
		}
		r.broadcastGameStateLocked()
		r.broadcastPlayerListLocked()
		r.broadcastSystemMessageLocked(fmt.Sprintf("%s is drawing!", r.Drawer.Nickname))
	case StateTurnEnd:
		r.DrawHistory = make([]map[string]interface{}, 0)
		for c := range r.Clients {
			c.Score += c.TurnScore
		}
		r.broadcastMessageLocked([]byte(`{"type": "draw", "action": "clear"}`))
		r.broadcastSystemMessageLocked(fmt.Sprintf("Turn over! The word was: %s", r.CurrentWord))
		r.broadcastGameStateLocked()
		r.broadcastPlayerListLocked()
		r.setTimeLeft(5)
	case StateGameOver:
		r.broadcastSystemMessageLocked("Game Over!")
		r.broadcastGameStateLocked()
		r.setTimeLeft(10)
	}
	r.mu.Unlock()
}

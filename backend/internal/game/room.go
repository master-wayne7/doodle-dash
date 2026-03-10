package game

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"sync"
	"time"
)

// / GameState represents the current phase of the game room.
type GameState string

const (
	/// StateLobby indicates the room is waiting for players to join.
	StateLobby GameState = "lobby"
	/// StateStarting indicates the game is about to begin.
	StateStarting GameState = "starting"
	/// StateRound indicates the start of a new round, consisting of multiple turns.
	StateRound GameState = "round"
	/// StateChoosing indicates the current drawer is selecting a word to draw.
	StateChoosing GameState = "choosing"
	/// StateDrawing indicates the drawer is actively drawing and others are guessing.
	StateDrawing GameState = "drawing"
	/// StateTurnEnd indicates the turn has finished.
	StateTurnEnd GameState = "turn_end"
	/// StateGameOver indicates all rounds are complete and the final leaderboard is shown.
	StateGameOver GameState = "game_over"
)

// / Room represents a single game session/lobby containing multiple clients.
type Room struct {
	ID      string
	Hub     *Hub
	Clients map[*Client]bool
	Join    chan *Client
	Leave   chan *Client

	State          GameState
	RoundNumber    int
	MaxRounds      int
	CurrentWord    string
	WordChoices    []string
	Drawer         *Client
	TurnQueue      []*Client
	DrawHistory    []map[string]interface{}
	HintIndices    []int
	VoteKicks      map[string]map[string]bool // TargetID -> {VoterID: true}
	RoundStartedAt time.Time

	TimeLeft    int
	tickerMutex sync.Mutex
	mu          sync.Mutex
}

// / NewRoom initializes and returns a new default Room instance.
func NewRoom(id string, hub *Hub) *Room {
	r := &Room{
		ID:        id,
		Hub:       hub,
		Clients:   make(map[*Client]bool),
		Join:      make(chan *Client),
		Leave:     make(chan *Client),
		State:     StateLobby,
		MaxRounds: 3,
		VoteKicks: make(map[string]map[string]bool),
	}
	if id != "test" {
		go r.runTimer()
	}
	return r
}

// / Run starts the room's main event loop, listening for join and leave events.
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

// / changeState securely transitions the room into a new game state and triggers the required setup for that state.
func (r *Room) changeState(newState GameState) {
	r.mu.Lock()
	r.State = newState

	switch newState {
	case StateLobby:
		r.setTimeLeft(0)
		r.broadcastSystemMessageLocked("Waiting for more players...", "blue")
	case StateStarting:
		r.setTimeLeft(5)
		r.broadcastSystemMessageLocked("Game is starting soon...", "blue")
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
			r.broadcastSystemMessageLocked(fmt.Sprintf("%s is choosing a word...", r.Drawer.Nickname), "blue")
		}
		r.broadcastGameStateLocked()
		r.setTimeLeft(10)
	case StateDrawing:
		r.setTimeLeft(60)
		r.RoundStartedAt = time.Now()
		for c := range r.Clients {
			c.TurnScore = 0
			c.Voted = false
		}
		r.broadcastGameStateLocked()
		r.broadcastPlayerListLocked()
		r.broadcastSystemMessageLocked(fmt.Sprintf("%s is drawing!", r.Drawer.Nickname), "blue")
	case StateTurnEnd:
		r.calculateFinalScores()
		r.DrawHistory = make([]map[string]interface{}, 0)
		for c := range r.Clients {
			c.Score += c.TurnScore
		}
		r.VoteKicks = make(map[string]map[string]bool)
		r.broadcastMessageLocked([]byte(`{"type": "draw", "action": "clear"}`))
		r.broadcastSystemMessageLocked(fmt.Sprintf("Turn over! The word was: %s", r.CurrentWord), "green")
		r.broadcastGameStateLocked()
		r.broadcastPlayerListLocked()
		r.setTimeLeft(5)
	case StateGameOver:
		r.broadcastSystemMessageLocked("Game Over!", "yellow")
		r.broadcastGameStateLocked()
		r.setTimeLeft(10)
	}
	r.mu.Unlock()
}

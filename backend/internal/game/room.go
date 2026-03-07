package game

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"sync"
	"time"

	log "github.com/sirupsen/logrus"
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
	TurnQueue   []*Client // Who hasn't drawn this round
	DrawHistory []map[string]interface{}
	HintIndices []int

	TimeLeft    int
	tickerMutex sync.Mutex

	mu sync.Mutex
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
	go r.runTimer()
	return r
}

func (r *Room) runTimer() {
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()
	for {
		<-ticker.C
		r.tickerMutex.Lock()
		if r.TimeLeft > 0 {
			r.TimeLeft--
			tL := r.TimeLeft
			r.tickerMutex.Unlock()

			r.mu.Lock()
			for client := range r.Clients {
				isDrawer := (r.Drawer != nil && client == r.Drawer)
				b, _ := json.Marshal(map[string]interface{}{
					"type":      "timer",
					"time_left": tL,
					"hint":      r.getHintLocked(isDrawer),
				})
				select {
				case client.Send <- b:
				default:
					close(client.Send)
					delete(r.Clients, client)
				}
			}
			r.mu.Unlock()

			r.tickerMutex.Lock()
			if r.TimeLeft == 0 {
				go r.handleTimeout() // Run in goroutine to not block ticker
			}
			r.tickerMutex.Unlock()
		} else {
			r.tickerMutex.Unlock()
		}
	}
}

func (r *Room) setTimeLeft(t int) {
	r.tickerMutex.Lock()
	r.TimeLeft = t
	r.tickerMutex.Unlock()
}

func (r *Room) handleTimeout() {
	r.mu.Lock()
	state := r.State
	r.mu.Unlock()

	switch state {
	case StateStarting:
		r.startNextRound()
	case StateRound:
		r.startNextTurn()
	case StateChoosing:
		r.mu.Lock()
		words := r.WordChoices
		r.mu.Unlock()
		if len(words) > 0 {
			r.selectWord(words[0])
		}
	case StateDrawing:
		r.endTurn()
	case StateTurnEnd:
		r.startNextTurn()
	case StateGameOver:
		r.changeState(StateLobby)
	}
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

func (r *Room) addClient(client *Client) {
	r.mu.Lock()
	r.Clients[client] = true
	history := make([]map[string]interface{}, len(r.DrawHistory))
	copy(history, r.DrawHistory)
	r.mu.Unlock()

	// Send current game state to the joining client
	r.sendGameStateTo(client)

	r.broadcastPlayerList()

	// Send draw history
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
		log.WithFields(log.Fields{
			"room":     r.ID,
			"nickname": client.Nickname,
		}).Info("Player left room / disconnected")
	}
	r.mu.Unlock()

	if len(r.Clients) == 0 {
		r.Hub.DeleteRoom <- r.ID
		r.setTimeLeft(0)
		return
	}
	r.broadcastPlayerList()

	// If drawer left, end turn early
	if r.State == StateDrawing && client == r.Drawer {
		r.endTurn()
	} else if len(r.Clients) < 2 && r.State != StateLobby {
		r.changeState(StateLobby)
	}
}

func (r *Room) broadcastMessage(message []byte) {
	r.mu.Lock()
	for client := range r.Clients {
		select {
		case client.Send <- message:
		default:
			close(client.Send)
			delete(r.Clients, client)
		}
	}
	r.mu.Unlock()
}

// Check if we have enough players to start the game
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

func (r *Room) startNextRound() {
	r.RoundNumber++
	if r.RoundNumber > r.MaxRounds {
		r.changeState(StateGameOver)
		return
	}

	// Refill the turn queue with all clients
	r.mu.Lock()
	r.TurnQueue = make([]*Client, 0, len(r.Clients))
	for client := range r.Clients {
		r.TurnQueue = append(r.TurnQueue, client)
	}
	// Shuffle queue
	rand.Shuffle(len(r.TurnQueue), func(i, j int) {
		r.TurnQueue[i], r.TurnQueue[j] = r.TurnQueue[j], r.TurnQueue[i]
	})
	r.mu.Unlock()

	r.changeState(StateRound)
}

func (r *Room) startNextTurn() {
	r.mu.Lock()
	if len(r.TurnQueue) == 0 {
		r.mu.Unlock()
		r.startNextRound()
		return
	}

	// Pop next drawer
	nextDrawer := r.TurnQueue[0]
	r.TurnQueue = r.TurnQueue[1:]

	// Reset roles and turn scores
	for c := range r.Clients {
		c.IsDrawer = false
		c.GuessedWord = false
		c.TurnScore = 0
	}
	nextDrawer.IsDrawer = true
	r.Drawer = nextDrawer
	r.mu.Unlock()

	r.changeState(StateChoosing)
}

func (r *Room) changeState(newState GameState) {
	r.State = newState

	log.WithFields(log.Fields{
		"room":  r.ID,
		"state": newState,
	}).Info("Room state changed")

	switch newState {
	case StateLobby:
		r.setTimeLeft(0)
		r.broadcastSystemMessage("Waiting for more players...")
	case StateStarting:
		// 5 seconds start game
		r.setTimeLeft(5)
		r.broadcastSystemMessage("Game is starting soon...")
		r.broadcastGameState()
	case StateRound:
		r.broadcastGameState()
		r.setTimeLeft(3) // 3 seconds to show Round X title card
	case StateChoosing:
		r.broadcastPlayerList()
		r.WordChoices = GetRandomWords(3)

		// Create a local game loop copy of words so hint calculation doesn't error
		r.CurrentWord = r.WordChoices[0]

		// Pre-calculate random reveal order for hints
		r.HintIndices = make([]int, 0)
		for i, ch := range r.CurrentWord {
			if string(ch) != " " {
				r.HintIndices = append(r.HintIndices, i)
			}
		}
		rand.Shuffle(len(r.HintIndices), func(i, j int) {
			r.HintIndices[i], r.HintIndices[j] = r.HintIndices[j], r.HintIndices[i]
		})

		// Send choices ONLY to the drawer
		choicesMsg, _ := json.Marshal(map[string]interface{}{
			"type":  "word_choices",
			"words": r.WordChoices,
		})
		if r.Drawer != nil {
			r.Drawer.Send <- choicesMsg
			r.broadcastSystemMessage(fmt.Sprintf("%s is choosing a word...", r.Drawer.Nickname))
		}

		r.broadcastGameState()

		// 10 seconds to choose
		r.setTimeLeft(10)

	case StateDrawing:
		// 60 seconds to draw
		r.setTimeLeft(60)

		r.broadcastGameState()
		r.broadcastPlayerList()
		r.broadcastSystemMessage(fmt.Sprintf("%s is drawing!", r.Drawer.Nickname))

	case StateTurnEnd:
		r.mu.Lock()
		r.DrawHistory = make([]map[string]interface{}, 0)
		r.mu.Unlock()

		r.broadcastMessage([]byte(`{"type": "draw", "action": "clear"}`))
		r.broadcastSystemMessage(fmt.Sprintf("Turn over! The word was: %s", r.CurrentWord))
		r.broadcastGameState()
		r.broadcastPlayerList()

		// 5 seconds to show leaderboard
		r.setTimeLeft(5)

	case StateGameOver:
		r.broadcastSystemMessage("Game Over!")
		r.broadcastGameState()
		// Return to lobby after 10 seconds
		r.setTimeLeft(10)
	}
}

func (r *Room) selectWord(word string) {
	if r.State != StateChoosing {
		return
	}
	r.CurrentWord = word
	r.setTimeLeft(0)
	r.changeState(StateDrawing)
}

func (r *Room) endTurn() {
	if r.State != StateDrawing {
		return
	}
	r.changeState(StateTurnEnd)
}

func (r *Room) ProcessMessage(c *Client, msg map[string]interface{}) {
	msgType, ok := msg["type"].(string)
	if !ok {
		return
	}

	switch msgType {
	case "chat":
		content, ok := msg["content"].(string)
		if !ok {
			return
		}

		if r.State == StateDrawing && c != r.Drawer && !c.GuessedWord {
			if content == r.CurrentWord {
				// Correct guess
				c.GuessedWord = true

				timePoints := r.TimeLeft * 10
				if timePoints < 10 {
					timePoints = 10
				}
				bonus := len(r.Clients) * 5
				pointsEarned := timePoints + bonus

				c.Score += pointsEarned
				c.TurnScore += pointsEarned

				// Drawer gets points relative to guess points
				if r.Drawer != nil {
					numGuessers := len(r.Clients) - 1
					if numGuessers < 1 {
						numGuessers = 1
					}
					drawerPoints := pointsEarned / numGuessers
					r.Drawer.Score += drawerPoints
					r.Drawer.TurnScore += drawerPoints
				}

				r.broadcastSystemMessage(fmt.Sprintf("%s guessed the word!", c.Nickname))
				r.broadcastPlayerList()

				// Check if everyone has guessed
				allGuessed := true
				r.mu.Lock()
				for client := range r.Clients {
					if !client.IsDrawer && !client.GuessedWord {
						allGuessed = false
						break
					}
				}
				r.mu.Unlock()

				if allGuessed {
					r.endTurn()
				}
				return // Don't broadcast the actual word
			}
		}

		// Normal chat
		b, _ := json.Marshal(map[string]interface{}{
			"type":    "chat",
			"sender":  c.Nickname,
			"content": content,
		})
		r.broadcastMessage(b)

	case "draw":
		if r.State == StateDrawing && c == r.Drawer {
			r.mu.Lock()
			r.DrawHistory = append(r.DrawHistory, msg)
			r.mu.Unlock()

			b, _ := json.Marshal(msg)
			r.broadcastMessage(b)
		}

	case "choose_word":
		if r.State == StateChoosing && c == r.Drawer {
			word, ok := msg["word"].(string)
			if ok {
				// Check if word is in choices
				valid := false
				for _, w := range r.WordChoices {
					if w == word {
						valid = true
						break
					}
				}
				if valid {
					r.selectWord(word)
				}
			}
		}
	}
}

func (r *Room) broadcastGameState() {
	var drawerNickname string
	if r.Drawer != nil {
		drawerNickname = r.Drawer.Nickname
	}

	r.mu.Lock()
	defer r.mu.Unlock()

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
		})

		select {
		case client.Send <- b:
		default:
			close(client.Send)
			delete(r.Clients, client)
		}
	}
}

func (r *Room) broadcastPlayerList() {
	var players []map[string]interface{}
	r.mu.Lock()
	for client := range r.Clients {
		players = append(players, map[string]interface{}{
			"id":          client.ID,
			"nickname":    client.Nickname,
			"score":       client.Score,
			"turn_score":  client.TurnScore,
			"isDrawer":    client.IsDrawer,
			"guessedWord": client.GuessedWord,
		})
	}
	r.mu.Unlock()

	b, _ := json.Marshal(map[string]interface{}{
		"type":    "players",
		"players": players,
	})
	r.broadcastMessage(b)
}

func (r *Room) broadcastSystemMessage(msg string) {
	b, _ := json.Marshal(map[string]interface{}{
		"type":    "system",
		"content": msg,
	})
	r.broadcastMessage(b)
}

func (r *Room) sendGameStateTo(c *Client) {
	var drawerNickname string
	if r.Drawer != nil {
		drawerNickname = r.Drawer.Nickname
	}

	r.mu.Lock()
	defer r.mu.Unlock()
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
	})
	c.Send <- b
}

func (r *Room) getHintLocked(isDrawer bool) string {
	word := r.CurrentWord
	if r.State != StateDrawing || len(word) == 0 {
		return ""
	}

	if isDrawer {
		return word
	}

	r.tickerMutex.Lock()
	tl := r.TimeLeft
	r.tickerMutex.Unlock()

	// 60 total seconds. At 40s (1/3), 1 char. At 20s (2/3), 2 chars.
	timeElapsed := 60 - tl
	numRevealed := timeElapsed / 20

	// Cap at the maximum number of revealable characters
	if numRevealed > len(r.HintIndices) {
		numRevealed = len(r.HintIndices)
	}

	// Create a map/set of indices that should be visible
	revealedSet := make(map[int]bool)
	for i := 0; i < numRevealed; i++ {
		revealedSet[r.HintIndices[i]] = true
	}

	hint := ""
	for i, ch := range word {
		if string(ch) == " " {
			hint += "  "
		} else {
			if revealedSet[i] {
				hint += string(ch) + " "
			} else {
				hint += "_ "
			}
		}
	}
	// Trim trailing space
	if len(hint) > 0 {
		hint = hint[:len(hint)-1]
	}
	return hint
}

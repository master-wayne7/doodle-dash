package game

import "time"

func (r *Room) startNextRound() {
	r.RoundNumber++
	if r.RoundNumber > r.MaxRounds {
		r.changeState(StateGameOver)
		return
	}

	r.mu.Lock()
	r.TurnQueue = make([]*Client, 0, len(r.Clients))
	for client := range r.Clients {
		r.TurnQueue = append(r.TurnQueue, client)
	}
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

	nextDrawer := r.TurnQueue[0]
	r.TurnQueue = r.TurnQueue[1:]

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

func (r *Room) endTurn() {
	if r.State != StateDrawing {
		return
	}
	r.changeState(StateTurnEnd)
}

func (r *Room) selectWord(word string) {
	if r.State != StateChoosing {
		return
	}
	r.CurrentWord = word
	r.setTimeLeft(0)
	r.changeState(StateDrawing)
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

func (r *Room) runTimer() {
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()
	for {
		<-ticker.C
		r.mu.Lock()
		r.tickerMutex.Lock()
		if r.TimeLeft > 0 {
			r.TimeLeft--
			r.tickerMutex.Unlock()
			r.broadcastTimerLocked()
			r.tickerMutex.Lock()
			if r.TimeLeft == 0 {
				go r.handleTimeout()
			}
			r.tickerMutex.Unlock()
		} else {
			r.tickerMutex.Unlock()
		}
		r.mu.Unlock()
	}
}

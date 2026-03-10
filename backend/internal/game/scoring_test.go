package game

import (
	"testing"
	"time"
)

func TestCalculateFinalScores(t *testing.T) {
	now := time.Now()
	roundStart := now.Add(-60 * time.Second) // Round started 60s ago (at the limit)

	r := &Room{
		Clients:        make(map[*Client]bool),
		RoundStartedAt: roundStart,
	}

	// Drawer
	drawer := &Client{Nickname: "Drawer", IsDrawer: true}
	r.Drawer = drawer
	r.Clients[drawer] = true

	// G1: Guessed at 5s after start
	g1Time := roundStart.Add(5 * time.Second)
	g1 := &Client{Nickname: "G1", GuessedWord: true, GuessedAt: &g1Time}
	r.Clients[g1] = true

	// G2: Guessed at 15s after start
	g2Time := roundStart.Add(15 * time.Second)
	g2 := &Client{Nickname: "G2", GuessedWord: true, GuessedAt: &g2Time}
	r.Clients[g2] = true

	// G3: Guessed at 30s after start
	g3Time := roundStart.Add(30 * time.Second)
	g3 := &Client{Nickname: "G3", GuessedWord: true, GuessedAt: &g3Time}
	r.Clients[g3] = true

	// G4: Guessed at 50s after start
	g4Time := roundStart.Add(50 * time.Second)
	g4 := &Client{Nickname: "G4", GuessedWord: true, GuessedAt: &g4Time}
	r.Clients[g4] = true

	// G5: Didn't guess
	g5 := &Client{Nickname: "G5", GuessedWord: false}
	r.Clients[g5] = true

	r.calculateFinalScores()

	// Expected results based on the provided logic:
	// DrawTime = 60s
	// G1: timeRemaining = 55s. timeScore = (55/60)*350 = 320.8. orderScore = (1-0/4)*150 = 150. Total = 470.8 -> Round to 5: 470
	// G2: timeRemaining = 45s. timeScore = (45/60)*350 = 262.5. orderScore = (1-1/4)*150 = 112.5. Total = 375 -> Round to 5: 375
	// G3: timeRemaining = 30s. timeScore = (30/60)*350 = 175. orderScore = (1-2/4)*150 = 75. Total = 250 -> Round to 5: 250
	// G4: timeRemaining = 10s. timeScore = (10/60)*350 = 58.3. orderScore = (1-3/4)*150 = 37.5. Total = 95.8 -> Round to 5: 95
	// Drawer: 100 + 4*50 = 300

	if g1.TurnScore != 470 {
		t.Errorf("G1 expected 470, got %d", g1.TurnScore)
	}
	if g2.TurnScore != 375 {
		t.Errorf("G2 expected 375, got %d", g2.TurnScore)
	}
	if g3.TurnScore != 250 {
		t.Errorf("G3 expected 250, got %d", g3.TurnScore)
	}
	if g4.TurnScore != 95 {
		t.Errorf("G4 expected 95, got %d", g4.TurnScore)
	}
	if drawer.TurnScore != 300 {
		t.Errorf("Drawer expected 300, got %d", drawer.TurnScore)
	}

	// Verify all scores are multiples of 5
	for c := range r.Clients {
		if c.TurnScore%5 != 0 {
			t.Errorf("%s score %d is not a multiple of 5", c.Nickname, c.TurnScore)
		}
	}
}

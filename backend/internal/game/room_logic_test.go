package game

import (
	"fmt"
	"strings"
	"testing"
	"time"
)

func TestLevenshteinDistance(t *testing.T) {
	testCases := []struct {
		a, b     string
		expected int
	}{
		{"banana", "bandana", 1},
		{"banana", "banana", 0},
		{"banana", "apple", 5},
		{"cat", "car", 1},
		{"elephant", "elphant", 1},
		{"strawberry", "strawbery", 1},
		{"", "hello", 5},
		{"hello", "", 5},
		{"abc", "def", 3},
	}

	for _, tc := range testCases {
		t.Run(fmt.Sprintf("%s vs %s", tc.a, tc.b), func(t *testing.T) {
			result := levenshteinDistance(tc.a, tc.b)
			if result != tc.expected {
				t.Errorf("expected %d, got %d", tc.expected, result)
			}
		})
	}
}

func TestCloseThreshold(t *testing.T) {
	testCases := []struct {
		wordLen  int
		expected int
	}{
		{3, 1},
		{5, 1},
		{6, 2},
		{9, 2},
		{10, 3},
		{15, 3},
	}

	for _, tc := range testCases {
		t.Run(fmt.Sprintf("length %d", tc.wordLen), func(t *testing.T) {
			result := closeThreshold(tc.wordLen)
			if result != tc.expected {
				t.Errorf("expected %d, got %d", tc.expected, result)
			}
		})
	}
}

func TestHintGeneration(t *testing.T) {
	r := &Room{
		CurrentWord: "apple tree",
		State:       StateDrawing,
		TimeLeft:    60,
		HintIndices: []int{0, 1, 2, 3, 4, 6, 7, 8, 9},
	}

	// Dynamic building to avoid whitespace issues in test code
	hint := r.getHintLocked(false)
	expected := strings.Repeat("_ ", 5) + "  " + strings.TrimSpace(strings.Repeat("_ ", 4))

	if hint != expected {
		t.Errorf("expected [%s], got [%s]", expected, hint)
	}

	r.TimeLeft = 40
	hint = r.getHintLocked(false)
	expected = "a " + strings.Repeat("_ ", 4) + "  " + strings.TrimSpace(strings.Repeat("_ ", 4))
	if hint != expected {
		t.Errorf("expected [%s], got [%s]", expected, hint)
	}
}

func TestStateTransitions(t *testing.T) {
	r := NewRoom("test", nil)

	drain := func(c *Client) {
		go func() {
			for range c.Send {
			}
		}()
	}

	c1 := &Client{ID: "1", Nickname: "C1", Send: make(chan []byte, 100), JoinedAt: time.Now()}
	c2 := &Client{ID: "2", Nickname: "C2", Send: make(chan []byte, 100), JoinedAt: time.Now()}
	drain(c1)
	drain(c2)

	r.addClient(c1)
	if r.State != StateLobby {
		t.Errorf("expected Lobby, got %s", r.State)
	}

	r.addClient(c2)
	if r.State != StateStarting {
		t.Errorf("expected Starting, got %s", r.State)
	}

	r.handleTimeout()
	if r.State != StateRound {
		t.Errorf("expected Round, got %s", r.State)
	}
}

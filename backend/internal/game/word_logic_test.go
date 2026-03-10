package game

import (
	"testing"
)

func TestNormalizeWord(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"T-Rex", "trex"},
		{"t rex", "t rex"},
		{"TREX!!!", "trex"},
		{"Ice-Cream", "icecream"},
		{"Hello World 123", "hello world 123"},
	}

	for _, tt := range tests {
		result := normalizeWord(tt.input)
		if result != tt.expected {
			t.Errorf("normalizeWord(%q) = %q; want %q", tt.input, result, tt.expected)
		}
	}
}

func TestDashedWordHint(t *testing.T) {
	r := &Room{
		CurrentWord: "T-Rex",
		State:       StateDrawing,
		TimeLeft:    60, // No hints yet
	}

	// Only alphabets should be hidden
	// T-Rex -> _ - _ _ _
	expected := "_ - _ _ _"
	hint := r.getHintLocked(false)
	if hint != expected {
		t.Errorf("Expected hint %q, got %q", expected, hint)
	}

	// Another one with spaces and dashes
	r.CurrentWord = "Spider-Man 2"
	// S p i d e r - M a n   2
	// _ _ _ _ _ _ - _ _ _   2
	expected = "_ _ _ _ _ _ - _ _ _   2"
	hint = r.getHintLocked(false)
	if hint != expected {
		t.Errorf("Expected hint %q, got %q", expected, hint)
	}
}

func TestHintRevealSpecialChars(t *testing.T) {
	r := &Room{
		CurrentWord: "Yo-Yo",
		State:       StateDrawing,
		TimeLeft:    40, // 1st hint revealed
	}
	// Initial Reveal: only 1 char from alphabets
	// HintIndices should only contain Y, o, Y, o (indices 0, 1, 3, 4)
	r.HintIndices = []int{0, 1, 3, 4} // Manual set for deterministic test

	// Reveal index 0 (Y)
	// Y _ - _ _
	expected := "Y _ - _ _"
	hint := r.getHintLocked(false)
	if hint != expected {
		t.Errorf("Expected hint %q, got %q", expected, hint)
	}
}

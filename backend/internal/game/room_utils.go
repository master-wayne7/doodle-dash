package game

import (
	"strings"
)

// levenshteinDistance calculates the minimum number of single-character edits to change one word into the other.
func levenshteinDistance(a, b string) int {
	a = strings.ToLower(a)
	b = strings.ToLower(b)
	la, lb := len(a), len(b)
	if la == 0 {
		return lb
	}
	if lb == 0 {
		return la
	}
	matrix := make([][]int, la+1)
	for i := range matrix {
		matrix[i] = make([]int, lb+1)
	}
	for i := 0; i <= la; i++ {
		matrix[i][0] = i
	}
	for j := 0; j <= lb; j++ {
		matrix[0][j] = j
	}
	for i := 1; i <= la; i++ {
		for j := 1; j <= lb; j++ {
			cost := 1
			if a[i-1] == b[j-1] {
				cost = 0
			}
			matrix[i][j] = min3(
				matrix[i-1][j]+1,
				matrix[i][j-1]+1,
				matrix[i-1][j-1]+cost,
			)
		}
	}
	return matrix[la][lb]
}

// min3 returns the smallest of three integers.
func min3(a, b, c int) int {
	if a < b {
		if a < c {
			return a
		}
		return c
	}
	if b < c {
		return b
	}
	return c
}

// closeThreshold determines the maximum Levenshtein distance allowed for a guess to be considered "close" based on word length.
func closeThreshold(wordLen int) int {
	switch {
	case wordLen <= 5:
		return 1
	case wordLen <= 9:
		return 2
	default:
		return 3
	}
}

// getHintLocked returns the obfuscated word hint string for the current time. Drawers see the full word.
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

	// Reveal 1st hint at 20s (tl=40), 2nd hint at 40s (tl=20)
	numRevealed := 0
	if tl <= 40 {
		numRevealed = 1
	}
	if tl <= 20 {
		numRevealed = 2
	}

	if numRevealed > len(r.HintIndices) {
		numRevealed = len(r.HintIndices)
	}
	revealedSet := make(map[int]bool)
	for i := 0; i < numRevealed; i++ {
		revealedSet[r.HintIndices[i]] = true
	}
	hint := ""
	for i, ch := range word {
		if (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') {
			if revealedSet[i] {
				hint += string(ch) + " "
			} else {
				hint += "_ "
			}
		} else if string(ch) == " " {
			hint += "  "
		} else {
			// Reveal special characters (dash, apostrophe, etc.) by default
			hint += string(ch) + " "
		}
	}
	return strings.TrimSpace(hint)
}

// normalizeWord removes all symbols except alphanumeric characters and spaces.
func normalizeWord(s string) string {
	var b strings.Builder
	for _, r := range strings.ToLower(strings.TrimSpace(s)) {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == ' ' {
			b.WriteRune(r)
		}
	}
	// Return normalized string, trimming extra whitespace
	return b.String()
}

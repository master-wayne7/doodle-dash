package game

import (
	"strings"
)

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

	timeElapsed := 60 - tl
	numRevealed := timeElapsed / 20
	if numRevealed > len(r.HintIndices) {
		numRevealed = len(r.HintIndices)
	}
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
	return strings.TrimSpace(hint)
}

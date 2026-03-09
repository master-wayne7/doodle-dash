package game

import (
	"bufio"
	"math/rand"
	"os"
	"strings"
	"time"

	log "github.com/sirupsen/logrus"
)

// WordList contains the set of playable words for the game.
var WordList []string

func init() {
	// Attempt to load from words.txt
	file, err := os.Open("words.txt")
	if err != nil {
		log.WithError(err).Warn("Could not open words.txt. Falling back to default word list.")
		WordList = []string{
			"apple", "banana", "car", "dog", "elephant", "frog", "guitar", "house",
			"icecream", "jacket", "kangaroo", "lion", "monkey", "ninja", "ocean",
			"pizza", "queen", "robot", "snake", "tree", "umbrella", "volcano",
			"watermelon", "xylophone", "yacht", "zebra", "airplane", "bridge",
			"castle", "diamond", "eagle", "fire", "ghost", "helicopter", "island",
		}
		return
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		word := strings.TrimSpace(scanner.Text())
		if len(word) > 0 {
			WordList = append(WordList, word)
		}
	}

	if err := scanner.Err(); err != nil {
		log.WithError(err).Error("Error reading words.txt")
	}

	log.Infof("Successfully loaded %d words from words.txt", len(WordList))
}

// GetRandomWords returns a specified number of randomly selected words from the WordList.
func GetRandomWords(count int) []string {
	rand.Seed(time.Now().UnixNano())
	shuffled := make([]string, len(WordList))
	copy(shuffled, WordList)
	rand.Shuffle(len(shuffled), func(i, j int) {
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	})

	if count > len(shuffled) {
		count = len(shuffled)
	}
	return shuffled[:count]
}

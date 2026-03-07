package game

import (
	"math/rand"
	"time"
)

var WordList = []string{
	"apple", "banana", "car", "dog", "elephant", "frog", "guitar", "house",
	"icecream", "jacket", "kangaroo", "lion", "monkey", "ninja", "ocean",
	"pizza", "queen", "robot", "snake", "tree", "umbrella", "volcano",
	"watermelon", "xylophone", "yacht", "zebra", "airplane", "bridge",
	"castle", "diamond", "eagle", "fire", "ghost", "helicopter", "island",
}

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

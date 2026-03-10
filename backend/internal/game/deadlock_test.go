package game

import (
	"fmt"
	"sync"
	"testing"
	"time"
)

// TestRoomHubDeadlock stress tests the interaction between Hub and Rooms
// to ensure no circular deadlocks occur during rapid joining and room deletion.
func TestRoomHubDeadlock(t *testing.T) {
	hub := NewHub()
	go hub.Run()

	const numWorkers = 50
	const iterations = 100
	var wg sync.WaitGroup
	wg.Add(numWorkers)

	// Timeout for the entire test to catch deadlocks
	timeout := time.After(30 * time.Second)
	done := make(chan bool)

	go func() {
		for i := 0; i < numWorkers; i++ {
			go func(workerID int) {
				defer wg.Done()
				for j := 0; j < iterations; j++ {
					// 1. Create a client
					client := &Client{
						Hub:      hub,
						Send:     make(chan []byte, 100),
						Nickname: fmt.Sprintf("W%d-I%d", workerID, j),
					}
					// Drain the send channel in background
					go func() {
						for range client.Send {
						}
					}()
					hub.Register <- client

					// 2. Join a room (randomly pick between 5 room IDs)
					roomID := fmt.Sprintf("room-%d", j%5)
					hub.ProcessMessage(client, map[string]interface{}{
						"type":    "join_room",
						"room_id": roomID,
					})

					// Small sleep to allow room.Run or hub.Run to process
					time.Sleep(time.Millisecond)

					// 3. Simulate disconnection
					// In reality, ReadPump would call Leave OR Unregister.
					if client.Room != nil {
						client.Room.Leave <- client
					} else {
						hub.Unregister <- client
					}
				}
			}(i)
		}
		wg.Wait()
		done <- true
	}()

	select {
	case <-done:
		// Success
	case <-timeout:
		t.Fatal("Test timed out! Possible deadlock detected.")
	}
}

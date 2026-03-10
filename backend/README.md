# Doodle Dash - Backend ⚙️

The Doodle Dash backend is a high-performance, concurrent WebSocket server written in Go.

## 🛠️ Technology Stack

-   **Language**: [Go (Golang)](https://go.dev/)
-   **WebSocket Library**: [Gorilla WebSocket](https://github.com/gorilla/websocket)
-   **Logging**: [Logrus](https://github.com/sirupsen/logrus)

## 📂 Folder Structure

```text
backend/
├── internal/game/      # Core Domain Logic
│   ├── client.go       # Individual connection management & pumps
│   ├── room.go         # Room state machine and hub coordination
│   ├── room_chat.go    # Chat processing and scoring calculations
│   ├── room_clients.go # Join/Leave logic and player listing
│   ├── room_messaging.go # Broadcast and system messaging
│   └── room_state.go   # Game phases (choosing, drawing, turn end)
├── main.go             # Server initialization and routing
├── words.txt           # Dictionary for game words
└── go.mod              # Dependency management
```

## 🏗️ Architectural Decisions

-   **Concurrency Model**: Uses Go's lightweight goroutines and channels for handling hundreds of concurrent players. Each client has a dedicated `WritePump` and `ReadPump`.
-   **Room-Based Isolation**: Game sessions are isolated into `Room` objects, each with its own state and event loop, preventing one slow room from affecting others.
-   **Custom Scoring System**: Implements a dynamic scoring algorithm that evaluates speed and guess order:
    -   `Points = min(round((timeRemaining/60)*350 + (1-rank/total)*150), 500)`
-   **Backend-Driven UI**: UI elements like chat message colors and system notifications are driven by the backend to ensure consistency across all connected clients.
-   **Robust Error Handling**: Handles abrupt disconnections, timeouts, and malformed JSON payloads gracefully.

The backend includes several test suites covering different aspects of the game:

-   **Scoring Logic**: `scoring_test.go` - Verifies speed-based point calculations and rounding.
-   **Core Game Logic**: `room_logic_test.go` - Tests Levenshtein distance, hint generation, and basic room flows.
-   **Room Management**: `room_test.go` - Verifies room instantiation and client joining.
-   **Hub Operations**: `hub_test.go` - Tests the central message hub and client registration.

To run all tests:
```bash
go test -v ./internal/game/...
```

To run a specific test:
```bash
go test -v ./internal/game/scoring_test.go
```

## 🚀 Running locally

```bash
go run main.go
```
The server listens on `:8080`.

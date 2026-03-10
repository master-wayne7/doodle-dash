# Doodle Dash 🚀

Doodle Dash is a real-time, multi-player drawing and guessing game inspired by Skribbl.io. It features a high-performance Go backend and a vibrant, responsive Flutter frontend, communicating seamlessly via WebSockets.

## 🏗️ Architecture Overiew

Doodle Dash follows a classic Client-Server architecture with a focus on low-latency real-time updates:

-   **Backend (Go)**: A stateful WebSocket server that manages game rooms, handles concurrent drawing events, and processes player guesses. It uses a "Hub-Room-Client" model to scale horizontally across multiple concurrent game sessions.
-   **Frontend (Flutter)**: A cross-platform UI (Web, Mobile, Desktop) built with a feature-driven architecture. It uses Riverpod for state management, GoRouter for navigation, and an optimized path-based `CustomPainter` for the drawing board.
-   **Communication**: Bidirectional JSON-based messaging over WebSockets.
-   **Typography**: Clean and modern typography using the Nunito font family.

## 📂 Project Structure

```text
.
├── backend/               # Go (Golang) Backend
│   ├── internal/game/     # Core game logic (Hub, Room, Client, Scoring)
│   ├── main.go            # Entry point and WebSocket handler
│   └── words.txt          # Source of game words
├── frontend/              # Flutter Frontend
│   ├── lib/               # Source code
│   │   ├── core/          # Audio, WebSocket, and shared services
│   │   └── features/      # Feature-based modules (Lobby, Game)
│   ├── assets/            # Game assets (Gifs, Svg, Icons)
│   └── web/               # Web implementation details
└── .github/workflows/     # CI/CD (GitHub Actions)
```

## 🚀 Quick Start

### Prerequisites

-   [Go](https://go.dev/dl/) (1.24+)
-   [Flutter](https://docs.flutter.dev/get-started/install) (3.38+)

### Running the Backend

1.  Navigate to the backend directory:
    ```bash
    cd backend
    ```
2.  Run the server:
    ```bash
    go run main.go
    ```
    The server will start on `ws://localhost:8080/ws`.

### Running the Frontend

1.  Navigate to the frontend directory:
    ```bash
    cd frontend
    ```
2.  Install dependencies:
    ```bash
    flutter pub get
    ```
3.  Run the application:
    ```bash
    flutter run -d chrome  # For Web
    ```

## 🎨 Key Features

-   **Real-time Drawing**: Low-latency synchronization of brush strokes.
-   **Dynamic Scoring**: Points awarded based on speed and guess order.
-   **Social Integration**: Real-time chat, vote-to-kick system, and like/dislike reactions.
-   **Custom Avatars**: Personalized player representation.
-   **Responsive Design**: Optimized for different screen sizes and platforms.

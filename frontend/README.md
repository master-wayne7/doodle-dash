# Doodle Dash - Frontend 🎨

The Doodle Dash frontend is built with Flutter, providing a fast and consistent experience across Web, Mobile, and Desktop.

## 🛠️ Technology Stack

-   **Framework**: [Flutter](https://flutter.dev/)
-   **State Management**: [Riverpod](https://riverpod.dev/) (Functional approach)
-   **Routing**: [GoRouter](https://pub.dev/packages/go_router)
-   **Networking**: [WebSockets](https://pub.dev/packages/web_socket_channel)
-   **Audio**: [Audioplayers](https://pub.dev/packages/audioplayers)
-   **Typography**: Nunito 
-   **Styling**: Custom Theme with a modern aesthetic.

## 📂 Folder Structure

```text
lib/
├── core/
│   ├── audio/          # Preloading and playing game sound effects
│   └── websocket/      # Robust WebSocket service for real-time sync
├── features/
│   ├── shared/         # Reusable widgets (Avatars, buttons)
│   └── game/           # Core game experience
│       ├── models/     # Immutable data classes (Player, GameState)
│       ├── providers/  # Riverpod Notifiers for reactive state 
│       ├── screens/    # Main game screen routes
│       └── widgets/    # Specialized UI (DrawingBoard, ChatBox, PlayerList)
└── main.dart           # Application entry and initialization
```

## 🏗️ Architectural Decisions

-   **Feature-Driven Design**: Code is organized by domain (e.g., `features/game`), making it easy to scale and maintain.
-   **Unidirectional Data Flow**: State is managed in `providers`, flowing down to widgets. Events flow up to the provider, which communicates with the backend.
-   **Optimized Rendering**: The `DrawingBoard` uses an isolated `StreamSubscription` to the WebSocket to ensure brush strokes are rendered with minimal lag, bypassing the main state update loop where possible.
-   **SVG & GIF Support**: Leverages vector graphics for high-quality favicons and logos, and gifs for expressive feedback (thumbs up, pen animation).

## 🚀 Development

### Running with a specific Backend

By default, the app looks for the backend at `ws://localhost:8080/ws`. You can override this using `--dart-define`:

```bash
flutter run -d chrome --dart-define=BACKEND_URL=wss://your-backend.com/ws
```

### Building for Web

```bash
flutter build web --release --base-href /
```

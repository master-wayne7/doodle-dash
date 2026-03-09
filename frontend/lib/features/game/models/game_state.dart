/// Enum representing the various phases a game room can be in.
enum GameState { lobby, starting, round, choosing, drawing, turnEnd, gameOver }

/// Parses a string from the backend into the corresponding [GameState] enum.
GameState parseGameState(String state) {
  switch (state) {
    case 'starting':
      return GameState.starting;
    case 'round':
      return GameState.round;
    case 'choosing':
      return GameState.choosing;
    case 'drawing':
      return GameState.drawing;
    case 'turn_end':
      return GameState.turnEnd;
    case 'game_over':
      return GameState.gameOver;
    case 'lobby':
    default:
      return GameState.lobby;
  }
}

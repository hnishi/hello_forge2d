import 'dart:math' as math;

enum RallyPhase { ready, playing, gameOver }

class RallySession {
  static const int startingLives = 3;
  static const double initialBallSpeed = 38;
  static const double maximumBallSpeed = 52;

  RallyPhase phase = RallyPhase.ready;
  int score = 0;
  int rally = 0;
  int bestRally = 0;
  int smashes = 0;
  int targetsDestroyed = 0;
  int lives = startingLives;

  bool get isReady => phase == RallyPhase.ready;
  bool get isPlaying => phase == RallyPhase.playing;
  bool get isGameOver => phase == RallyPhase.gameOver;

  double get ballSpeed =>
      math.min(initialBallSpeed + (rally ~/ 5) * 2, maximumBallSpeed);

  void serve() {
    if (isReady) {
      phase = RallyPhase.playing;
    }
  }

  int registerReturn({bool smash = false}) {
    if (!isPlaying) {
      return 0;
    }

    rally++;
    bestRally = math.max(bestRally, rally);
    final points = rally * 10 + (smash ? 50 : 0);
    if (smash) {
      smashes++;
    }
    score += points;
    return points;
  }

  int registerTarget({required int chain}) {
    if (!isPlaying) {
      return 0;
    }
    targetsDestroyed++;
    final points = 100 * chain;
    score += points;
    return points;
  }

  int registerBumperHit() {
    if (!isPlaying) {
      return 0;
    }
    score += 25;
    return 25;
  }

  void miss() {
    if (!isPlaying) {
      return;
    }

    lives--;
    rally = 0;
    phase = lives > 0 ? RallyPhase.ready : RallyPhase.gameOver;
  }

  void restart() {
    phase = RallyPhase.ready;
    score = 0;
    rally = 0;
    smashes = 0;
    targetsDestroyed = 0;
    lives = startingLives;
  }
}

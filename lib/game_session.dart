class GameSession {
  static const int targetCores = 8;
  static const int startingLives = 3;
  static const double startingTime = 45.0;
  static const double comboDuration = 3.0;

  int score = 0;
  int cores = 0;
  int lives = startingLives;
  int combo = 0;
  double timeLeft = startingTime;
  double comboTimeLeft = 0;

  bool get won => cores >= targetCores;
  bool get lost => lives <= 0 || timeLeft <= 0;
  bool get isPlaying => !won && !lost;

  void update(double dt) {
    if (!isPlaying) {
      return;
    }

    timeLeft -= dt;
    if (timeLeft < 0) {
      timeLeft = 0;
    }

    comboTimeLeft -= dt;
    if (comboTimeLeft <= 0) {
      comboTimeLeft = 0;
      combo = 0;
    }
  }

  int collectCore() {
    if (!isPlaying) {
      return 0;
    }

    combo++;
    comboTimeLeft = comboDuration;
    cores++;
    final points = 100 * combo;
    score += points;
    timeLeft += 1.5;
    return points;
  }

  void takeHit() {
    if (!isPlaying) {
      return;
    }

    lives--;
    combo = 0;
    comboTimeLeft = 0;
    timeLeft -= 2;
    if (timeLeft < 0) {
      timeLeft = 0;
    }
  }
}

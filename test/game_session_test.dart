import 'package:flame_tutorial/game_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameSession', () {
    test('consecutive cores increase the combo score', () {
      final session = GameSession();

      expect(session.collectCore(), 100);
      expect(session.collectCore(), 200);
      expect(session.score, 300);
      expect(session.combo, 2);
    });

    test('combo expires after three seconds', () {
      final session = GameSession()..collectCore();

      session.update(GameSession.comboDuration);

      expect(session.combo, 0);
      expect(session.collectCore(), 100);
    });

    test('collecting the target number of cores wins', () {
      final session = GameSession();

      for (var i = 0; i < GameSession.targetCores; i++) {
        session.collectCore();
      }

      expect(session.won, isTrue);
      expect(session.isPlaying, isFalse);
    });

    test('three hits end the run', () {
      final session = GameSession();

      session.takeHit();
      session.takeHit();
      session.takeHit();

      expect(session.lost, isTrue);
      expect(session.lives, 0);
    });
  });
}

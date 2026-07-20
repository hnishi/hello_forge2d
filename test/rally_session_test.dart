import 'package:flame_tutorial/rally_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RallySession', () {
    test('starts ready and begins on serve', () {
      final session = RallySession();

      expect(session.isReady, isTrue);
      session.serve();

      expect(session.isPlaying, isTrue);
    });

    test('consecutive returns increase rally and score', () {
      final session = RallySession()..serve();

      expect(session.registerReturn(), 10);
      expect(session.registerReturn(), 20);
      expect(session.rally, 2);
      expect(session.score, 30);
      expect(session.bestRally, 2);
    });

    test('ball gets faster every five returns and has a cap', () {
      final session = RallySession()..serve();

      for (var i = 0; i < 5; i++) {
        session.registerReturn();
      }
      expect(session.ballSpeed, 40);

      for (var i = 0; i < 100; i++) {
        session.registerReturn();
      }
      expect(session.ballSpeed, RallySession.maximumBallSpeed);
    });

    test('a smash adds a fifty point bonus', () {
      final session = RallySession()..serve();

      expect(session.registerReturn(smash: true), 60);
      expect(session.score, 60);
      expect(session.smashes, 1);
    });

    test('targets award escalating chain bonuses', () {
      final session = RallySession()..serve();

      expect(session.registerTarget(chain: 1), 100);
      expect(session.registerTarget(chain: 3), 300);
      expect(session.targetsDestroyed, 2);
      expect(session.score, 400);
    });

    test('bumpers award twenty-five points', () {
      final session = RallySession()..serve();

      expect(session.registerBumperHit(), 25);
      expect(session.score, 25);
    });

    test('a miss resets rally but preserves the best', () {
      final session = RallySession()..serve();
      session.registerReturn();
      session.registerReturn();

      session.miss();

      expect(session.lives, 2);
      expect(session.rally, 0);
      expect(session.bestRally, 2);
      expect(session.isReady, isTrue);
    });

    test('third miss ends the game and restart keeps the best', () {
      final session = RallySession()..serve();
      session.registerReturn();
      session.miss();
      session.serve();
      session.miss();
      session.serve();
      session.miss();

      expect(session.isGameOver, isTrue);
      session.restart();

      expect(session.isReady, isTrue);
      expect(session.lives, RallySession.startingLives);
      expect(session.bestRally, 1);
    });
  });
}

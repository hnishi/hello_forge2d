import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flame_tutorial/physics_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PhysicsModels', () {
    test('kinetic energy includes translation and rotation', () {
      final energy = PhysicsModels.kineticEnergy(
        mass: 2,
        velocity: Vector2(3, 4),
        inertia: 4,
        angularVelocity: 2,
      );

      expect(energy, 33);
    });

    test('magnus force is perpendicular to velocity', () {
      final velocity = Vector2(4, 3);
      final force = PhysicsModels.magnusForce(
        velocity: velocity,
        angularVelocity: 5,
      );

      expect(force.dot(velocity), closeTo(0, 0.000001));
      expect(force.length, greaterThan(0));
    });

    test('inverse square impulse weakens with distance', () {
      final near = PhysicsModels.inverseSquareImpulse(
        strength: 120,
        distance: 2,
      );
      final far = PhysicsModels.inverseSquareImpulse(
        strength: 120,
        distance: 8,
      );

      expect(near, greaterThan(far));
    });

    test('magnetic strength is bounded at very short distances', () {
      final atCenter = PhysicsModels.magneticStrength(
        strength: 95,
        distance: 0,
      );
      final atMinimum = PhysicsModels.magneticStrength(
        strength: 95,
        distance: 1.5,
      );

      expect(atCenter, atMinimum);
    });

    test('swept paddle detects a ball crossed between frames', () {
      final hit = PhysicsModels.segmentAabbIntersectionFraction(
        start: Vector2(0, 0),
        end: Vector2(10, 0),
        center: Vector2(5, 0),
        halfExtents: Vector2(1, 1),
      );

      expect(hit, closeTo(0.4, 0.000001));
    });

    test('swept paddle ignores a path outside the ball bounds', () {
      final hit = PhysicsModels.segmentAabbIntersectionFraction(
        start: Vector2(0, 0),
        end: Vector2(10, 0),
        center: Vector2(5, 3),
        halfExtents: Vector2(1, 1),
      );

      expect(hit, isNull);
    });

    test('faster paddle movement adds more return speed', () {
      final slow = PhysicsModels.paddleSpeedBoost(20);
      final fast = PhysicsModels.paddleSpeedBoost(100);

      expect(fast, greaterThan(slow));
      expect(PhysicsModels.paddleSpeedBoost(1000), 14);
    });
  });
}

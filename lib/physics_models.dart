import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';

class PhysicsModels {
  const PhysicsModels._();

  static double kineticEnergy({
    required double mass,
    required Vector2 velocity,
    required double inertia,
    required double angularVelocity,
  }) {
    final translational = 0.5 * mass * velocity.length2;
    final rotational = 0.5 * inertia * angularVelocity * angularVelocity;
    return translational + rotational;
  }

  static Vector2 magnusForce({
    required Vector2 velocity,
    required double angularVelocity,
    double coefficient = 0.018,
  }) {
    if (velocity.length2 < 0.0001 || angularVelocity.abs() < 0.0001) {
      return Vector2.zero();
    }
    return Vector2(-velocity.y, velocity.x)
      ..scale(angularVelocity * coefficient);
  }

  static double inverseSquareImpulse({
    required double strength,
    required double distance,
    double softening = 1.5,
  }) {
    return strength / (distance * distance + softening);
  }

  static double magneticStrength({
    required double strength,
    required double distance,
    double minimumDistance = 1.5,
  }) {
    final safeDistance = math.max(distance, minimumDistance);
    return strength / (safeDistance * safeDistance);
  }

  static double paddleSpeedBoost(
    double paddleSpeed, {
    double coefficient = 0.11,
    double maximum = 14,
  }) {
    return (paddleSpeed.abs() * coefficient).clamp(0, maximum);
  }

  static double? segmentAabbIntersectionFraction({
    required Vector2 start,
    required Vector2 end,
    required Vector2 center,
    required Vector2 halfExtents,
  }) {
    final delta = end - start;
    var minimumTime = 0.0;
    var maximumTime = 1.0;

    for (var axis = 0; axis < 2; axis++) {
      final origin = axis == 0 ? start.x : start.y;
      final direction = axis == 0 ? delta.x : delta.y;
      final centerValue = axis == 0 ? center.x : center.y;
      final extent = axis == 0 ? halfExtents.x : halfExtents.y;
      final minimum = centerValue - extent;
      final maximum = centerValue + extent;

      if (direction.abs() < 0.000001) {
        if (origin < minimum || origin > maximum) {
          return null;
        }
        continue;
      }

      var entryTime = (minimum - origin) / direction;
      var exitTime = (maximum - origin) / direction;
      if (entryTime > exitTime) {
        final swap = entryTime;
        entryTime = exitTime;
        exitTime = swap;
      }
      minimumTime = math.max(minimumTime, entryTime);
      maximumTime = math.min(maximumTime, exitTime);
      if (minimumTime > maximumTime) {
        return null;
      }
    }

    return minimumTime;
  }
}

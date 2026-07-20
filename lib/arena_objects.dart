import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

class ExplosiveTarget extends BodyComponent {
  ExplosiveTarget(this.spawnPosition)
    : super(paint: Paint()..color = const Color(0xFFFF8A3D));

  static const double radius = 1.3;
  final Vector2 spawnPosition;
  bool detonated = false;

  @override
  Body createBody() {
    final fixtureDef = FixtureDef(
      CircleShape()..radius = radius,
      restitution: 0.9,
      friction: 0.1,
    );
    return world.createBody(BodyDef(userData: this, position: spawnPosition))
      ..createFixture(fixtureDef);
  }

  @override
  void renderCircle(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius * 1.18,
      Paint()..color = const Color(0x44FF3D00),
    );
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(
      center,
      radius * 0.58,
      Paint()..color = const Color(0xFFBF360C),
    );
    canvas.drawCircle(
      center + const Offset(-0.35, -0.38),
      radius * 0.2,
      Paint()..color = const Color(0xFFFFF3E0),
    );
  }
}

class ArenaBumper extends BodyComponent {
  ArenaBumper(this.spawnPosition)
    : super(paint: Paint()..color = const Color(0xFF17D7FF));

  static const double radius = 1.65;
  final Vector2 spawnPosition;

  @override
  Body createBody() {
    final fixtureDef = FixtureDef(
      CircleShape()..radius = radius,
      restitution: 1.15,
      friction: 0,
    );
    return world.createBody(BodyDef(userData: this, position: spawnPosition))
      ..createFixture(fixtureDef);
  }

  @override
  void renderCircle(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius * 1.25,
      Paint()..color = const Color(0x3317D7FF),
    );
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(
      center,
      radius * 0.62,
      Paint()..color = const Color(0xFF073B5C),
    );
    canvas.drawCircle(
      center,
      radius * 0.28,
      Paint()..color = const Color(0xFFFFFFFF),
    );
  }
}

class ExplosionDebris extends BodyComponent {
  ExplosionDebris({
    required this.spawnPosition,
    required this.initialVelocity,
    required this.size,
    required this.color,
  }) : super(paint: Paint()..color = color);

  final Vector2 spawnPosition;
  final Vector2 initialVelocity;
  final double size;
  final Color color;
  double _age = 0;

  @override
  Body createBody() {
    final fixtureDef = FixtureDef(
      PolygonShape()..setAsBoxXY(size, size * 0.65),
      density: 0.45,
      restitution: 0.65,
      friction: 0.35,
    );
    final bodyDef = BodyDef(
      position: spawnPosition,
      linearVelocity: initialVelocity,
      angularVelocity: initialVelocity.x * 0.8,
      type: BodyType.dynamic,
    );
    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= 3) {
      removeFromParent();
    }
  }
}

class ExplosionBurst extends PositionComponent {
  ExplosionBurst(Vector2 position)
    : super(position: position, anchor: Anchor.center, priority: 20);

  static const double duration = 0.48;
  double _age = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final progress = (_age / duration).clamp(0.0, 1.0);
    final eased = math.sin(progress * math.pi / 2);
    final alpha = ((1 - progress) * 210).round();
    canvas.drawCircle(
      Offset.zero,
      5.8 * eased,
      Paint()..color = Color.fromARGB(alpha ~/ 2, 255, 61, 0),
    );
    canvas.drawCircle(
      Offset.zero,
      3.4 * eased,
      Paint()..color = Color.fromARGB(alpha, 255, 179, 0),
    );
    canvas.drawCircle(
      Offset.zero,
      1.7 * eased,
      Paint()..color = Color.fromARGB(alpha, 255, 255, 255),
    );
  }
}

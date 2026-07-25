import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart' hide PointerMoveEvent;
import 'package:flutter/services.dart';

import 'arena_objects.dart';
import 'material_objects.dart';
import 'physics_models.dart';
import 'rally_session.dart';
import 'table_components.dart';

enum PaddleSwingPhase { idle, windup, drive, recover }

class _ShieldRayCastCallback extends RayCastCallback {
  _ShieldRayCastCallback(this.targetBody);

  final Body targetBody;
  bool isBlocked = false;

  @override
  double reportFixture(
    Fixture fixture,
    Vector2 point,
    Vector2 normal,
    double fraction,
  ) {
    if (fixture.body == targetBody) {
      return -1;
    }
    final object = fixture.body.userData;
    if (object is TableWall || object is MaterialObstacle) {
      isBlocked = true;
      return 0;
    }
    return -1;
  }
}

class Paddle extends BodyComponent {
  Paddle({
    required this.initialPosition,
    required this.minimumX,
    required this.maximumX,
    required this.minimumY,
    required this.maximumY,
  }) : super(renderBody: false);

  static const double width = 0.9;
  static const double height = 7;
  static const double keyboardSpeed = 28;

  final Vector2 initialPosition;
  final double minimumX;
  final double maximumX;
  final double minimumY;
  final double maximumY;
  final Paint _shadowPaint = Paint()..color = const Color(0x44000000);
  final Paint _paddlePaint = Paint()..color = const Color(0xFFFF5A5F);
  final Paint _highlightPaint = Paint()..color = const Color(0xFFFFB3B5);
  final Vector2 motionVelocity = Vector2.zero();
  PaddleSwingPhase swingPhase = PaddleSwingPhase.idle;

  bool get isSwinging => swingPhase != PaddleSwingPhase.idle;
  double get hitPower => switch (swingPhase) {
    PaddleSwingPhase.drive => 1,
    PaddleSwingPhase.windup => 0.25,
    PaddleSwingPhase.recover => 0.45,
    PaddleSwingPhase.idle => 0,
  };

  @override
  Body createBody() {
    final fixtureDef = FixtureDef(
      PolygonShape()..setAsBoxXY(width / 2, height / 2),
      restitution: 1,
      friction: 0,
    );
    final bodyDef = BodyDef(
      userData: this,
      position: initialPosition,
      allowSleep: false,
      type: BodyType.kinematic,
    );
    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  void move({
    required Vector2 direction,
    required double dt,
    Vector2? targetPosition,
  }) {
    var velocity = direction * keyboardSpeed;
    if (targetPosition != null) {
      final target = Vector2(
        targetPosition.x.clamp(minimumX, maximumX),
        targetPosition.y.clamp(minimumY, maximumY),
      );
      motionVelocity
        ..setFrom(target)
        ..sub(body.position)
        ..scale(1 / math.max(dt, 1 / 240));
      if (motionVelocity.length > 120) {
        motionVelocity.normalize();
        motionVelocity.scale(120);
      }
      body.setTransform(target, body.angle);
      body.linearVelocity = Vector2.zero();
      return;
    }

    if ((body.position.x <= minimumX && velocity.x < 0) ||
        (body.position.x >= maximumX && velocity.x > 0)) {
      velocity.x = 0;
    }
    if ((body.position.y <= minimumY && velocity.y < 0) ||
        (body.position.y >= maximumY && velocity.y > 0)) {
      velocity.y = 0;
    }
    // Use the setter so Forge2D wakes a sleeping kinematic body.
    motionVelocity.setFrom(velocity);
    body.linearVelocity = velocity;
  }

  void keepInsideTable() {
    final clampedX = body.position.x.clamp(minimumX, maximumX);
    final clampedY = body.position.y.clamp(minimumY, maximumY);
    if (clampedX != body.position.x || clampedY != body.position.y) {
      body.setTransform(Vector2(clampedX, clampedY), body.angle);
    }
  }

  void swing() {
    if (isSwinging) {
      return;
    }
    swingPhase = PaddleSwingPhase.windup;
    body.setAwake(true);
  }

  void updateSwing() {
    switch (swingPhase) {
      case PaddleSwingPhase.idle:
        body.angularVelocity = 0;
      case PaddleSwingPhase.windup:
        body.angularVelocity = -6;
        if (body.angle <= -0.28) {
          swingPhase = PaddleSwingPhase.drive;
        }
      case PaddleSwingPhase.drive:
        body.angularVelocity = 12;
        if (body.angle >= 0.5) {
          swingPhase = PaddleSwingPhase.recover;
        }
      case PaddleSwingPhase.recover:
        body.angularVelocity = -5;
        if (body.angle <= 0) {
          body.setTransform(body.position, 0);
          body.angularVelocity = 0;
          swingPhase = PaddleSwingPhase.idle;
        }
    }
  }

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: width,
      height: height,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.shift(const Offset(0, 0.18)),
        const Radius.circular(0.45),
      ),
      _shadowPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(0.45)),
      _paddlePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-width / 2 + 0.5, -0.28, width - 1, 0.16),
        const Radius.circular(0.08),
      ),
      _highlightPaint,
    );
  }
}

class RallyBall extends BodyComponent<WallRallyGame> with ContactCallbacks {
  RallyBall(this.initialPosition)
    : super(paint: Paint()..color = const Color(0xFFFFF4D6));

  static const double radius = 0.7;
  final Vector2 initialPosition;
  final Paint _shadowPaint = Paint()..color = const Color(0x55000000);
  final Paint _shinePaint = Paint()..color = const Color(0xFFFFFFFF);
  final Vector2 acceleration = Vector2.zero();
  final Vector2 _previousVelocity = Vector2.zero();
  bool _hasPreviousVelocity = false;

  double get speed => body.linearVelocity.length;
  double get kineticEnergy => PhysicsModels.kineticEnergy(
    mass: body.mass,
    velocity: body.linearVelocity,
    inertia: body.inertia,
    angularVelocity: body.angularVelocity,
  );

  @override
  Body createBody() {
    final fixtureDef = FixtureDef(
      CircleShape()..radius = radius,
      restitution: 0.92,
      friction: 0.58,
      density: 1,
    );
    final bodyDef = BodyDef(
      userData: this,
      position: initialPosition,
      type: BodyType.dynamic,
      bullet: true,
      fixedRotation: false,
      angularDamping: 0.035,
      linearDamping: 0.012,
      gravityScale: Vector2.zero(),
    );
    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void beginContact(Object other, Contact contact) {
    if (other is Paddle && body.linearVelocity.x < 0) {
      game.queuePaddleReturn();
    } else if (other is MissZone) {
      game.queueMiss();
    } else if (other is ExplosiveTarget) {
      game.queueExplosion(other);
    } else if (other is ArenaBumper) {
      game.queueBumperHit();
    } else if (other is MaterialObstacle && other.isJelly) {
      body.linearVelocity.scale(0.48);
      body.angularVelocity *= 0.42;
    }
  }

  @override
  void update(double dt) {
    if (dt > 0 && _hasPreviousVelocity) {
      acceleration
        ..setFrom(body.linearVelocity)
        ..sub(_previousVelocity)
        ..scale(1 / dt);
    }
    _previousVelocity.setFrom(body.linearVelocity);
    _hasPreviousVelocity = true;

    if ((body.gravityScale?.length2 ?? 0) > 0) {
      body.applyForce(
        PhysicsModels.magnusForce(
          velocity: body.linearVelocity,
          angularVelocity: body.angularVelocity,
        ),
      );
    }
    super.update(dt);
  }

  void holdAt(Vector2 position) {
    body.setTransform(position, 0);
    body.linearVelocity.setZero();
    body.angularVelocity = 0;
    body.gravityScale = Vector2.zero();
    acceleration.setZero();
    _hasPreviousVelocity = false;
  }

  void launch(Vector2 velocity, {double? angularVelocity}) {
    // Assign through the setter so a ball sleeping on the paddle wakes up.
    body.gravityScale = Vector2.all(1);
    body.linearVelocity = velocity;
    if (angularVelocity != null) {
      body.angularVelocity = angularVelocity;
    }
  }

  @override
  void renderCircle(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center + const Offset(0.16, 0.2),
      radius * 1.05,
      _shadowPaint,
    );
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(
      center + const Offset(-0.2, -0.22),
      radius * 0.24,
      _shinePaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.72),
      -math.pi * 0.75,
      math.pi * 1.5,
      false,
      Paint()
        ..color = const Color(0xFFEF5350)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.16,
    );

    canvas.save();
    canvas.rotate(-body.angle);
    _drawVector(canvas, body.linearVelocity * 0.12, const Color(0xFF38E8FF));
    _drawVector(canvas, acceleration * 0.018, const Color(0xFFFFD54F));
    canvas.restore();
  }

  void _drawVector(Canvas canvas, Vector2 rawVector, Color color) {
    final vector = rawVector.clone();
    if (vector.length < 0.15) {
      return;
    }
    if (vector.length > 7) {
      vector.normalize();
      vector.scale(7);
    }
    final end = Offset(vector.x, vector.y);
    final direction = vector.normalized();
    final perpendicular = Vector2(-direction.y, direction.x);
    final arrowBase = vector - direction * 0.65;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.16
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, end, paint);
    canvas.drawLine(
      end,
      Offset(
        arrowBase.x + perpendicular.x * 0.32,
        arrowBase.y + perpendicular.y * 0.32,
      ),
      paint,
    );
    canvas.drawLine(
      end,
      Offset(
        arrowBase.x - perpendicular.x * 0.32,
        arrowBase.y - perpendicular.y * 0.32,
      ),
      paint,
    );
  }
}

class WallRallyGame extends Forge2DGame
    with KeyboardEvents, TapCallbacks, DragCallbacks, PointerMoveCallbacks
    implements ArenaEventSink {
  WallRallyGame() : super(gravity: Vector2(0, 10), zoom: 10);

  static final TextPaint hudRenderer = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.bold,
    ),
  );
  static final TextPaint messageRenderer = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFF4D6),
      fontSize: 28,
      fontWeight: FontWeight.bold,
    ),
  );
  static final TextPaint helpRenderer = TextPaint(
    style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 15),
  );

  final math.Random _random = math.Random();
  late final Rect tableRect;
  late final Paddle paddle;
  late final RallyBall ball;
  late final TextComponent hudText;
  late final TextComponent messageText;
  late final TextComponent helpText;
  RallySession session = RallySession();
  final List<ExplosiveTarget> _targets = [];
  final List<MaterialObstacle> _materialObjects = [];

  final Vector2 _movementInput = Vector2.zero();
  Vector2? _pointerTarget;
  bool _paddleReturnQueued = false;
  bool _missQueued = false;
  double _queuedHitPower = 0;
  double _queuedAngularVelocity = 0;
  double? _queuedHitOffset;
  int _bumperHitsQueued = 0;
  int wave = 1;
  double _waveRespawnTimer = 0;

  @override
  Color backgroundColor() => const Color(0xFF071A24);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final visibleRect = camera.visibleWorldRect;
    final tableWidth = math.min(visibleRect.width - 4, 78).toDouble();
    final tableHeight = math.min(visibleRect.height - 4, 42).toDouble();
    tableRect = Rect.fromCenter(
      center: visibleRect.center,
      width: tableWidth,
      height: tableHeight,
    );
    await _createTable();
    await _createHud();

    final paddleX = tableRect.left + 3;
    paddle = Paddle(
      initialPosition: Vector2(paddleX, tableRect.center.dy),
      minimumX: tableRect.left + Paddle.width / 2 + 0.8,
      maximumX: tableRect.center.dx - Paddle.width / 2 - 0.8,
      minimumY: tableRect.top + Paddle.height / 2 + 0.8,
      maximumY: tableRect.bottom - Paddle.height / 2 - 0.8,
    );
    await world.add(paddle);

    ball = RallyBall(Vector2(paddleX + 2, tableRect.center.dy));
    await world.add(ball);
    await _createArenaObjects();
    _refreshHud();
  }

  Future<void> _createArenaObjects() async {
    final center = tableRect.center;
    final rightCenterX = center.dx + tableRect.width * 0.25;
    await world.addAll([
      ArenaBumper(
        Vector2(rightCenterX - tableRect.width * 0.12, center.dy - 9),
      ),
      ArenaBumper(
        Vector2(rightCenterX + tableRect.width * 0.12, center.dy + 9),
      ),
      ArenaBumper(Vector2(rightCenterX, center.dy)),
    ]);
    final positions = [
      Vector2(center.dx + 6, center.dy - 14),
      Vector2(center.dx + 18, center.dy - 14),
      Vector2(center.dx + 8, center.dy + 13),
      Vector2(center.dx + 20, center.dy + 13),
      Vector2(center.dx + 29, center.dy - 8),
      Vector2(center.dx + 29, center.dy + 8),
    ];
    for (var i = 0; i < ArenaMaterial.values.length; i++) {
      final obstacle = MaterialObstacle(
        material: ArenaMaterial.values[i],
        spawnPosition: positions[i],
        size: i == ArenaMaterial.ice.index ? 1.15 : 0.92,
      );
      _materialObjects.add(obstacle);
      await world.add(obstacle);
    }
    _spawnTargets();
  }

  void _spawnTargets() {
    final center = tableRect.center;
    final spread = tableRect.height * 0.12;
    for (var i = -2; i <= 2; i++) {
      final target = ExplosiveTarget(
        Vector2(
          tableRect.right - 8 - (i.isEven ? 0 : 2.2),
          center.dy + i * spread,
        ),
      );
      _targets.add(target);
      world.add(target);
    }
  }

  Future<void> _createTable() async {
    await world.add(TableSurface(tableRect));
    await world.addAll([
      TableWall(
        Vector2(tableRect.left, tableRect.top),
        Vector2(tableRect.right, tableRect.top),
      ),
      TableWall(
        Vector2(tableRect.right, tableRect.top),
        Vector2(tableRect.right, tableRect.bottom),
      ),
      TableWall(
        Vector2(tableRect.right, tableRect.bottom),
        Vector2(tableRect.left, tableRect.bottom),
      ),
      MissZone(
        Vector2(tableRect.left - 1, tableRect.bottom),
        Vector2(tableRect.left - 1, tableRect.top),
      ),
    ]);
  }

  Future<void> _createHud() async {
    hudText = TextComponent(
      textRenderer: hudRenderer,
      position: Vector2(14, 12),
    );
    messageText = TextComponent(
      textRenderer: messageRenderer,
      position: size / 2,
      anchor: Anchor.center,
    );
    helpText = TextComponent(
      textRenderer: helpRenderer,
      position: Vector2(size.x / 2, size.y - 18),
      anchor: Anchor.bottomCenter,
    );
    await camera.viewport.addAll([hudText, messageText, helpText]);
  }

  @override
  void update(double dt) {
    final previousPaddlePosition = paddle.body.position.clone();
    paddle.move(
      direction: _movementInput,
      dt: dt,
      targetPosition: _pointerTarget,
    );
    paddle.updateSwing();
    _queueSweptPaddleReturn(previousPaddlePosition, paddle.body.position);

    if (session.isReady || session.isGameOver) {
      ball.holdAt(paddle.body.position + Vector2(2, 0));
    }

    super.update(dt);
    paddle.keepInsideTable();
    _applyMagneticForces();

    if (_paddleReturnQueued) {
      _paddleReturnQueued = false;
      _returnBall();
    }
    if (_missQueued) {
      _missQueued = false;
      _handleMiss();
    }
    _processArenaEvents(dt);
    _refreshHud();
  }

  void queuePaddleReturn() {
    if (session.isPlaying) {
      _paddleReturnQueued = true;
      _queuedHitPower = math.max(_queuedHitPower, paddle.hitPower);
      _queuedAngularVelocity = paddle.body.angularVelocity;
    }
  }

  void _queueSweptPaddleReturn(Vector2 start, Vector2 end) {
    if (!session.isPlaying ||
        ball.body.linearVelocity.x >= 0 ||
        _paddleReturnQueued) {
      return;
    }
    final hitFraction = PhysicsModels.segmentAabbIntersectionFraction(
      start: start,
      end: end,
      center: ball.body.position,
      halfExtents: Vector2(
        Paddle.width / 2 + RallyBall.radius,
        Paddle.height / 2 + RallyBall.radius,
      ),
    );
    if (hitFraction == null) {
      return;
    }

    final impactPaddlePosition = start + (end - start) * hitFraction;
    final relativeHitY = (ball.body.position.y - impactPaddlePosition.y).clamp(
      -Paddle.height / 2,
      Paddle.height / 2,
    );
    _queuedHitOffset = relativeHitY / (Paddle.height / 2);
    ball.body.setTransform(
      Vector2(
        impactPaddlePosition.x + Paddle.width / 2 + RallyBall.radius + 0.08,
        impactPaddlePosition.y + relativeHitY,
      ),
      ball.body.angle,
    );
    ball.body.linearVelocity.setZero();
    _missQueued = false;
    queuePaddleReturn();
  }

  void queueMiss() {
    if (session.isPlaying) {
      _missQueued = true;
    }
  }

  @override
  void queueExplosion(ExplosiveTarget target, {int chain = 1}) {
    if (!session.isPlaying || target.detonated || target.isArmed) {
      return;
    }
    target.arm(duration: chain == 1 ? 0.42 : 0.14, chain: chain);
  }

  void queueBumperHit() {
    if (session.isPlaying) {
      _bumperHitsQueued++;
    }
  }

  void _processArenaEvents(double dt) {
    for (var i = 0; i < _bumperHitsQueued; i++) {
      session.registerBumperHit();
    }
    _bumperHitsQueued = 0;

    for (final target in List<ExplosiveTarget>.from(_targets)) {
      if (target.tickFuse(dt)) {
        _detonate(target, target.pendingChain);
      }
    }

    if (_targets.isEmpty && _waveRespawnTimer <= 0) {
      _waveRespawnTimer = 1.4;
    }
    if (_waveRespawnTimer > 0) {
      _waveRespawnTimer -= dt;
      if (_waveRespawnTimer <= 0) {
        wave++;
        for (final debris
            in world.children.whereType<ExplosionDebris>().toList()) {
          debris.removeFromParent();
        }
        _spawnTargets();
      }
    }
  }

  void _detonate(ExplosiveTarget target, int chain) {
    if (target.detonated) {
      return;
    }
    target.detonated = true;
    final position = target.body.position.clone();
    _targets.remove(target);
    target.removeFromParent();
    session.registerTarget(chain: chain);
    world.add(ExplosionBurst(position));

    _applyExplosionImpulse(ball.body, position, radius: 9);
    for (final debris in world.children.whereType<ExplosionDebris>()) {
      _applyExplosionImpulse(debris.body, position, radius: 9);
    }
    for (final obstacle in _materialObjects) {
      if (obstacle.body.bodyType == BodyType.dynamic) {
        _applyExplosionImpulse(obstacle.body, position, radius: 9);
      }
    }

    const debrisColors = [
      Color(0xFFFFD54F),
      Color(0xFFFF6D00),
      Color(0xFFEF5350),
    ];
    for (var i = 0; i < 10; i++) {
      final angle = i / 10 * math.pi * 2 + _random.nextDouble() * 0.25;
      final massDensity = 0.35 + _random.nextDouble() * 3.2;
      final massResponse = math.sqrt(0.8 / massDensity).clamp(0.5, 1.5);
      final speed = (8 + _random.nextDouble() * 9) * massResponse;
      world.add(
        ExplosionDebris(
          spawnPosition: position,
          initialVelocity: Vector2(math.cos(angle), math.sin(angle)) * speed,
          size: 0.18 + _random.nextDouble() * 0.22,
          color: debrisColors[i % debrisColors.length],
          massDensity: massDensity,
        ),
      );
    }

    for (final neighbor in List<ExplosiveTarget>.from(_targets)) {
      if ((neighbor.body.position - position).length < 6.2) {
        queueExplosion(neighbor, chain: chain + 1);
      }
    }
  }

  void _applyExplosionImpulse(
    Body body,
    Vector2 source, {
    required double radius,
  }) {
    final offset = body.position - source;
    final distance = offset.length;
    if (distance <= 0.1 || distance >= radius) {
      return;
    }
    final shielding = _isExplosionShielded(source, body.position, body)
        ? 0.18
        : 1.0;
    final magnitude = PhysicsModels.inverseSquareImpulse(
      strength: 120,
      distance: distance,
    );
    body.applyLinearImpulse(offset.normalized() * magnitude * shielding);
  }

  bool _isExplosionShielded(Vector2 source, Vector2 destination, Body target) {
    final callback = _ShieldRayCastCallback(target);
    world.raycast(callback, source, destination);
    return callback.isBlocked;
  }

  void _applyMagneticForces() {
    if (!session.isPlaying) {
      return;
    }
    for (final magnet in _materialObjects.where((item) => item.isMagnet)) {
      final offset = magnet.body.position - ball.body.position;
      final distance = offset.length;
      if (distance <= 0.4 || distance > 14) {
        continue;
      }
      final strength = PhysicsModels.magneticStrength(
        strength: 95,
        distance: distance,
      );
      ball.body.applyForce(offset.normalized() * strength);
    }
  }

  void _returnBall() {
    final isSmash = _queuedHitPower >= 0.8;
    session.registerReturn(smash: isSmash);
    final hitOffset =
        _queuedHitOffset ??
        ((ball.body.position.y - paddle.body.position.y) / (Paddle.height / 2))
            .clamp(-0.9, 0.9);
    final paddleInfluence = (paddle.motionVelocity.y / 55).clamp(-0.35, 0.35);
    final swingInfluence = (_queuedAngularVelocity / 18).clamp(-0.55, 0.55);
    final direction = Vector2(
      1,
      hitOffset + paddleInfluence + swingInfluence,
    ).normalized();
    final sideSpin = paddle.motionVelocity.y * 0.32;
    final strokeSpin = _queuedAngularVelocity * 1.25;
    final paddleSpeedBoost = PhysicsModels.paddleSpeedBoost(
      paddle.motionVelocity.length,
    );
    ball.launch(
      direction *
          (session.ballSpeed + _queuedHitPower * 3.5 + paddleSpeedBoost),
      angularVelocity: (sideSpin + strokeSpin).clamp(-32, 32),
    );
    _queuedHitPower = 0;
    _queuedAngularVelocity = 0;
    _queuedHitOffset = null;
  }

  void _handleMiss() {
    session.miss();
    ball.holdAt(paddle.body.position + Vector2(2, 0));
  }

  void _serve() {
    if (!session.isReady) {
      return;
    }
    session.serve();
    final vertical = _random.nextDouble() * 0.7 - 0.35;
    ball.launch(
      Vector2(1, vertical).normalized() * RallySession.initialBallSpeed,
      angularVelocity: vertical * 8,
    );
  }

  void _restart() {
    session.restart();
    _paddleReturnQueued = false;
    _missQueued = false;
    _queuedHitPower = 0;
    _queuedAngularVelocity = 0;
    _queuedHitOffset = null;
    _bumperHitsQueued = 0;
    _waveRespawnTimer = 0;
    wave = 1;
    for (final target in List<ExplosiveTarget>.from(_targets)) {
      target.removeFromParent();
    }
    _targets.clear();
    for (final debris in world.children.whereType<ExplosionDebris>().toList()) {
      debris.removeFromParent();
    }
    for (final burst in world.children.whereType<ExplosionBurst>().toList()) {
      burst.removeFromParent();
    }
    _spawnTargets();
    ball.holdAt(paddle.body.position + Vector2(2, 0));
  }

  void _refreshHud() {
    final velocity = ball.body.linearVelocity;
    final acceleration = ball.acceleration;
    hudText.text =
        'SCORE ${session.score}   RALLY ${session.rally}   '
        'BEST ${session.bestRally}   SMASH ${session.smashes}   '
        'LIFE ${session.lives}   GRAVITY ON\n'
        'WAVE $wave   TARGET ${_targets.length}   '
        'DESTROYED ${session.targetsDestroyed}\n'
        'SPEED ${ball.speed.toStringAsFixed(1)} m/s   '
        'ω ${ball.body.angularVelocity.toStringAsFixed(1)} rad/s   '
        'KE ${ball.kineticEnergy.toStringAsFixed(0)} J\n'
        'v (${velocity.x.toStringAsFixed(1)}, ${velocity.y.toStringAsFixed(1)})   '
        'a (${acceleration.x.toStringAsFixed(1)}, '
        '${acceleration.y.toStringAsFixed(1)}) m/s²';

    if (session.isGameOver) {
      messageText.text = 'GAME OVER\nTAP OR R TO RETRY';
      helpText.text = '';
    } else if (session.isReady) {
      messageText.text = 'WALL RALLY\nTAP OR ENTER TO SERVE';
      helpText.text =
          'PLAYER AREA: LEFT HALF   MOVE: WASD · ARROWS · MOUSE · DRAG   '
          'SWING: SPACE';
    } else {
      messageText.text = '';
      helpText.text = 'SPACE: SWING   Hit orange targets for chain explosions!';
    }
  }

  void _followPointer(Vector2 canvasPosition) {
    _pointerTarget = screenToWorld(canvasPosition);
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    _movementInput.x =
        (keysPressed.contains(LogicalKeyboardKey.keyD) ||
                keysPressed.contains(LogicalKeyboardKey.arrowRight)
            ? 1
            : 0) -
        (keysPressed.contains(LogicalKeyboardKey.keyA) ||
                keysPressed.contains(LogicalKeyboardKey.arrowLeft)
            ? 1
            : 0);
    _movementInput.y =
        (keysPressed.contains(LogicalKeyboardKey.keyS) ||
                keysPressed.contains(LogicalKeyboardKey.arrowDown)
            ? 1
            : 0) -
        (keysPressed.contains(LogicalKeyboardKey.keyW) ||
                keysPressed.contains(LogicalKeyboardKey.arrowUp)
            ? 1
            : 0);
    if (_movementInput.length2 > 0) {
      _pointerTarget = null;
    }

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        paddle.swing();
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        _serve();
      } else if (event.logicalKey == LogicalKeyboardKey.keyR &&
          session.isGameOver) {
        _restart();
      }
    }
    return super.onKeyEvent(event, keysPressed);
  }

  @override
  void onTapDown(TapDownEvent event) {
    _followPointer(event.canvasPosition);
    if (session.isGameOver) {
      _restart();
    } else {
      _serve();
    }
  }

  @override
  void onPointerMove(PointerMoveEvent event) {
    _followPointer(event.canvasPosition);
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _followPointer(event.canvasPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    _followPointer(event.canvasEndPosition);
  }
}

void main() {
  runApp(GameWidget(game: WallRallyGame()));
}

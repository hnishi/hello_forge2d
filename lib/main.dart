import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart' hide PointerMoveEvent;
import 'package:flutter/services.dart';

import 'arena_objects.dart';
import 'rally_session.dart';
import 'table_components.dart';

enum PaddleSwingPhase { idle, windup, drive, recover }

class Paddle extends BodyComponent {
  Paddle({
    required this.initialPosition,
    required this.minimumX,
    required this.maximumX,
  }) : super(renderBody: false);

  static const double width = 7;
  static const double height = 0.9;
  static const double keyboardSpeed = 28;

  final Vector2 initialPosition;
  final double minimumX;
  final double maximumX;
  final Paint _shadowPaint = Paint()..color = const Color(0x44000000);
  final Paint _paddlePaint = Paint()..color = const Color(0xFFFF5A5F);
  final Paint _highlightPaint = Paint()..color = const Color(0xFFFFB3B5);
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

  void move({required double direction, double? targetX}) {
    var velocityX = direction * keyboardSpeed;
    if (targetX != null) {
      velocityX = ((targetX - body.position.x) * 18).clamp(-45, 45);
    }

    if ((body.position.x <= minimumX && velocityX < 0) ||
        (body.position.x >= maximumX && velocityX > 0)) {
      velocityX = 0;
    }
    // Use the setter so Forge2D wakes a sleeping kinematic body.
    body.linearVelocity = Vector2(velocityX, 0);
  }

  void keepInsideTable() {
    final clampedX = body.position.x.clamp(minimumX, maximumX);
    if (clampedX != body.position.x) {
      body.setTransform(Vector2(clampedX, body.position.y), body.angle);
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

  @override
  Body createBody() {
    final fixtureDef = FixtureDef(
      CircleShape()..radius = radius,
      restitution: 1,
      friction: 0,
      density: 1,
    );
    final bodyDef = BodyDef(
      userData: this,
      position: initialPosition,
      type: BodyType.dynamic,
      bullet: true,
      fixedRotation: true,
      gravityScale: Vector2.zero(),
    );
    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void beginContact(Object other, Contact contact) {
    if (other is Paddle && body.linearVelocity.y > 0) {
      game.queuePaddleReturn();
    } else if (other is MissZone) {
      game.queueMiss();
    } else if (other is ExplosiveTarget) {
      game.queueExplosion(other);
    } else if (other is ArenaBumper) {
      game.queueBumperHit();
    }
  }

  void holdAt(Vector2 position) {
    body.setTransform(position, 0);
    body.linearVelocity.setZero();
    body.angularVelocity = 0;
    body.gravityScale = Vector2.zero();
  }

  void launch(Vector2 velocity) {
    // Assign through the setter so a ball sleeping on the paddle wakes up.
    body.gravityScale = Vector2.all(1);
    body.linearVelocity = velocity;
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
  }
}

class WallRallyGame extends Forge2DGame
    with KeyboardEvents, TapCallbacks, DragCallbacks, PointerMoveCallbacks {
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
  final Map<ExplosiveTarget, int> _explosionQueue = {};

  double _horizontalInput = 0;
  double? _pointerTargetX;
  bool _paddleReturnQueued = false;
  bool _missQueued = false;
  double _queuedHitPower = 0;
  double _queuedAngularVelocity = 0;
  int _bumperHitsQueued = 0;
  int wave = 1;
  double _waveRespawnTimer = 0;

  @override
  Color backgroundColor() => const Color(0xFF071A24);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final visibleRect = camera.visibleWorldRect;
    final tableWidth = math.min(visibleRect.width - 4, 46).toDouble();
    final tableHeight = math.min(visibleRect.height - 4, 62).toDouble();
    tableRect = Rect.fromCenter(
      center: visibleRect.center,
      width: tableWidth,
      height: tableHeight,
    );
    await _createTable();
    await _createHud();

    final paddleY = tableRect.bottom - 3;
    paddle = Paddle(
      initialPosition: Vector2(tableRect.center.dx, paddleY),
      minimumX: tableRect.left + Paddle.width / 2 + 0.8,
      maximumX: tableRect.right - Paddle.width / 2 - 0.8,
    );
    await world.add(paddle);

    ball = RallyBall(Vector2(tableRect.center.dx, paddleY - 2));
    await world.add(ball);
    await _createArenaObjects();
    _refreshHud();
  }

  Future<void> _createArenaObjects() async {
    final center = tableRect.center;
    await world.addAll([
      ArenaBumper(
        Vector2(tableRect.left + tableRect.width * 0.23, center.dy + 2),
      ),
      ArenaBumper(
        Vector2(tableRect.right - tableRect.width * 0.23, center.dy + 2),
      ),
      ArenaBumper(Vector2(center.dx, tableRect.top + tableRect.height * 0.3)),
    ]);
    _spawnTargets();
  }

  void _spawnTargets() {
    final center = tableRect.center;
    final spread = tableRect.width * 0.11;
    for (var i = -2; i <= 2; i++) {
      final target = ExplosiveTarget(
        Vector2(
          center.dx + i * spread,
          tableRect.top + 8 + (i.isEven ? 0 : 2.2),
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
        Vector2(tableRect.left, tableRect.bottom),
        Vector2(tableRect.left, tableRect.top),
      ),
      TableWall(
        Vector2(tableRect.left, tableRect.top),
        Vector2(tableRect.right, tableRect.top),
      ),
      TableWall(
        Vector2(tableRect.right, tableRect.top),
        Vector2(tableRect.right, tableRect.bottom),
      ),
      MissZone(
        Vector2(tableRect.left, tableRect.bottom + 1),
        Vector2(tableRect.right, tableRect.bottom + 1),
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
    paddle.move(direction: _horizontalInput, targetX: _pointerTargetX);
    paddle.updateSwing();

    if (session.isReady || session.isGameOver) {
      ball.holdAt(paddle.body.position + Vector2(0, -2));
    }

    super.update(dt);
    paddle.keepInsideTable();

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

  void queueMiss() {
    if (session.isPlaying) {
      _missQueued = true;
    }
  }

  void queueExplosion(ExplosiveTarget target, {int chain = 1}) {
    if (!session.isPlaying || target.detonated) {
      return;
    }
    final previousChain = _explosionQueue[target] ?? 0;
    _explosionQueue[target] = math.max(previousChain, chain);
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

    if (_explosionQueue.isNotEmpty) {
      final queued = Map<ExplosiveTarget, int>.from(_explosionQueue);
      _explosionQueue.clear();
      for (final entry in queued.entries) {
        _detonate(entry.key, entry.value);
      }
    }

    if (_targets.isEmpty && _explosionQueue.isEmpty && _waveRespawnTimer <= 0) {
      _waveRespawnTimer = 1.4;
    }
    if (_waveRespawnTimer > 0) {
      _waveRespawnTimer -= dt;
      if (_waveRespawnTimer <= 0) {
        wave++;
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

    final ballOffset = ball.body.position - position;
    if (ballOffset.length2 < 64 && ballOffset.length2 > 0.01) {
      final distance = math.max(ballOffset.length, 1).toDouble();
      ball.body.applyLinearImpulse(ballOffset.normalized() * (16 / distance));
    }

    const debrisColors = [
      Color(0xFFFFD54F),
      Color(0xFFFF6D00),
      Color(0xFFEF5350),
    ];
    for (var i = 0; i < 10; i++) {
      final angle = i / 10 * math.pi * 2 + _random.nextDouble() * 0.25;
      final speed = 8 + _random.nextDouble() * 9;
      world.add(
        ExplosionDebris(
          spawnPosition: position,
          initialVelocity: Vector2(math.cos(angle), math.sin(angle)) * speed,
          size: 0.18 + _random.nextDouble() * 0.22,
          color: debrisColors[i % debrisColors.length],
        ),
      );
    }

    for (final neighbor in List<ExplosiveTarget>.from(_targets)) {
      if ((neighbor.body.position - position).length < 6.2) {
        queueExplosion(neighbor, chain: chain + 1);
      }
    }
  }

  void _returnBall() {
    final isSmash = _queuedHitPower >= 0.8;
    session.registerReturn(smash: isSmash);
    final hitOffset =
        ((ball.body.position.x - paddle.body.position.x) / (Paddle.width / 2))
            .clamp(-0.9, 0.9);
    final paddleInfluence = (paddle.body.linearVelocity.x / 55).clamp(
      -0.35,
      0.35,
    );
    final swingInfluence = (_queuedAngularVelocity / 18).clamp(-0.55, 0.55);
    final direction = Vector2(
      hitOffset + paddleInfluence + swingInfluence,
      -1,
    ).normalized();
    ball.launch(direction * (session.ballSpeed + _queuedHitPower * 3.5));
    _queuedHitPower = 0;
    _queuedAngularVelocity = 0;
  }

  void _handleMiss() {
    session.miss();
    ball.holdAt(paddle.body.position + Vector2(0, -2));
  }

  void _serve() {
    if (!session.isReady) {
      return;
    }
    session.serve();
    final horizontal = _random.nextDouble() * 0.7 - 0.35;
    ball.launch(
      Vector2(horizontal, -1).normalized() * RallySession.initialBallSpeed,
    );
  }

  void _restart() {
    session.restart();
    _paddleReturnQueued = false;
    _missQueued = false;
    _queuedHitPower = 0;
    _queuedAngularVelocity = 0;
    _explosionQueue.clear();
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
    ball.holdAt(paddle.body.position + Vector2(0, -2));
  }

  void _refreshHud() {
    hudText.text =
        'SCORE ${session.score}   RALLY ${session.rally}   '
        'BEST ${session.bestRally}   SMASH ${session.smashes}   '
        'LIFE ${session.lives}   GRAVITY ON\n'
        'WAVE $wave   TARGET ${_targets.length}   '
        'DESTROYED ${session.targetsDestroyed}';

    if (session.isGameOver) {
      messageText.text = 'GAME OVER\nTAP OR R TO RETRY';
      helpText.text = '';
    } else if (session.isReady) {
      messageText.text = 'WALL RALLY\nTAP OR ENTER TO SERVE';
      helpText.text = 'MOVE: A / D · ARROWS · MOUSE · DRAG   SWING: SPACE';
    } else {
      messageText.text = '';
      helpText.text = 'SPACE: SWING   Hit orange targets for chain explosions!';
    }
  }

  void _followPointer(Vector2 canvasPosition) {
    _pointerTargetX = screenToWorld(canvasPosition).x;
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    _horizontalInput =
        (keysPressed.contains(LogicalKeyboardKey.keyD) ||
                keysPressed.contains(LogicalKeyboardKey.arrowRight)
            ? 1
            : 0) -
        (keysPressed.contains(LogicalKeyboardKey.keyA) ||
                keysPressed.contains(LogicalKeyboardKey.arrowLeft)
            ? 1
            : 0);
    if (_horizontalInput != 0) {
      _pointerTargetX = null;
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

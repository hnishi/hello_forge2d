import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'boundaries.dart';
import 'game_session.dart';

class Player extends BodyComponent<SpaceShooterGame> with ContactCallbacks {
  final Vector2 initialPosition;
  final Vector2 size = Vector2(2, 3);
  Vector2 facing = Vector2(1, 0);

  Player(this.initialPosition) : super(renderBody: false);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final sprite = await game.loadSprite('player-sprite.png');
    await add(
      SpriteComponent(sprite: sprite, size: size, anchor: Anchor.center),
    );
  }

  @override
  Body createBody() {
    final shape = PolygonShape()
      ..set([
        Vector2(-size.x / 2, -size.y / 2),
        Vector2(size.x / 2, -size.y / 2),
        Vector2(0, size.y / 2),
      ]);

    final fixtureDef = FixtureDef(
      shape,
      restitution: 0.25,
      density: 1,
      friction: 0.4,
    );
    final bodyDef = BodyDef(
      userData: this,
      position: initialPosition,
      linearDamping: 3.5,
      fixedRotation: true,
      type: BodyType.dynamic,
    );
    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void beginContact(Object other, Contact contact) {
    if (other is EnergyCore) {
      game.collect(other);
    } else if (other is BlobPart) {
      game.hitByBlob(other);
    }
  }

  void steer(Vector2 direction) {
    if (direction.length2 == 0) {
      return;
    }

    final normalized = direction.normalized();
    facing = normalized;
    body.applyForce(normalized * 55);

    const maxSpeed = 13.0;
    if (body.linearVelocity.length > maxSpeed) {
      body.linearVelocity.scale(maxSpeed / body.linearVelocity.length);
    }
  }

  void dash(Vector2 direction) {
    final dashDirection = direction.length2 == 0
        ? facing
        : direction.normalized();
    facing = dashDirection;
    body.applyLinearImpulse(dashDirection * 22);
  }

  void resetAt(Vector2 position) {
    body.setTransform(position, 0);
    body.linearVelocity.setZero();
    body.angularVelocity = 0;
    facing = Vector2(1, 0);
  }
}

class EnergyCore extends BodyComponent {
  final Vector2 spawnPosition;
  bool collected = false;

  EnergyCore(this.spawnPosition)
    : super(paint: Paint()..color = const Color(0xFFFFD54F));

  @override
  Body createBody() {
    final fixtureDef = FixtureDef(CircleShape()..radius = 0.8, isSensor: true);
    final bodyDef = BodyDef(userData: this, position: spawnPosition);
    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void renderCircle(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius * 1.45,
      Paint()..color = const Color(0x55FFD54F),
    );
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(
      center,
      radius * 0.35,
      Paint()..color = const Color(0xFFFFFFFF),
    );
  }
}

class BlobPart extends BodyComponent {
  static const int bodyCount = 20;

  final ConstantVolumeJointDef jointDef;
  final int bodyNumber;
  final Vector2 blobRadius;
  final Vector2 blobCenter;

  BlobPart(this.bodyNumber, this.jointDef, this.blobRadius, this.blobCenter)
    : super(paint: Paint()..color = const Color(0xFFE84A5F));

  @override
  Body createBody() {
    final angle = (bodyNumber / bodyCount) * math.pi * 2;
    final position = Vector2(
      blobCenter.x + blobRadius.x * math.sin(angle),
      blobCenter.y + blobRadius.y * math.cos(angle),
    );
    final bodyDef = BodyDef(
      userData: this,
      fixedRotation: true,
      linearDamping: 1.2,
      position: position,
      type: BodyType.dynamic,
    );
    final body = world.createBody(bodyDef);
    final fixtureDef = FixtureDef(
      CircleShape()..radius = 0.5,
      density: 1,
      restitution: 0.3,
      filter: Filter()..groupIndex = -2,
    );
    body.createFixture(fixtureDef);
    jointDef.addBody(body);
    return body;
  }

  void chase(Vector2 target) {
    final direction = target - body.position;
    if (direction.length2 > 0.1) {
      body.applyForce(direction.normalized() * 4 + Vector2(0, -7));
    }
  }
}

class SpaceShooterGame extends Forge2DGame with KeyboardEvents, TapCallbacks {
  SpaceShooterGame() : super(gravity: Vector2(0, 10));

  static final TextPaint hudRenderer = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.bold,
    ),
  );
  static final TextPaint messageRenderer = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFD54F),
      fontSize: 28,
      fontWeight: FontWeight.bold,
    ),
  );

  final math.Random _random = math.Random();
  final Vector2 _movement = Vector2.zero();
  final List<BlobPart> _blobParts = [];
  final List<EnergyCore> _collectedCores = [];

  late final Vector2 _worldCenter;
  late final Player player;
  late final TextComponent hudText;
  late final TextComponent messageText;
  GameSession session = GameSession();
  EnergyCore? _activeCore;
  double _dashCooldown = 0;
  double _damageCooldown = 0;

  @override
  Color backgroundColor() => const Color(0xFF101629);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _worldCenter = camera.visibleWorldRect.center.toVector2();
    await world.addAll(createBoundaries(this));

    hudText = TextComponent(
      textRenderer: hudRenderer,
      position: Vector2(12, 12),
      anchor: Anchor.topLeft,
    );
    messageText = TextComponent(
      textRenderer: messageRenderer,
      position: size / 2,
      anchor: Anchor.center,
    );
    await camera.viewport.addAll([hudText, messageText]);

    player = Player(_worldCenter);
    await world.add(player);
    await _createBlob();
    _spawnCore();
    _refreshHud();
  }

  Future<void> _createBlob() async {
    final jointDef = ConstantVolumeJointDef()
      ..frequencyHz = 12
      ..dampingRatio = 1
      ..collideConnected = false;
    final blobCenter = _worldCenter + Vector2(0, -18);
    for (var i = 0; i < BlobPart.bodyCount; i++) {
      final part = BlobPart(i, jointDef, Vector2.all(4.5), blobCenter);
      _blobParts.add(part);
      await world.add(part);
    }
    world.createJoint(ConstantVolumeJoint(world.physicsWorld, jointDef));
  }

  @override
  void update(double dt) {
    if (session.isPlaying) {
      session.update(dt);
      _dashCooldown = math.max(0.0, _dashCooldown - dt).toDouble();
      _damageCooldown = math.max(0.0, _damageCooldown - dt).toDouble();
      player.steer(_movement);
      for (final part in _blobParts) {
        part.chase(player.body.position);
      }
    }

    super.update(dt);
    _processCollectedCores();
    _refreshHud();
  }

  void collect(EnergyCore core) {
    if (!session.isPlaying || core.collected) {
      return;
    }
    core.collected = true;
    session.collectCore();
    _collectedCores.add(core);
  }

  void _processCollectedCores() {
    if (_collectedCores.isEmpty) {
      return;
    }
    for (final core in _collectedCores) {
      core.removeFromParent();
      if (identical(core, _activeCore)) {
        _activeCore = null;
      }
    }
    _collectedCores.clear();
    if (session.isPlaying) {
      _spawnCore();
    }
  }

  void hitByBlob(BlobPart blob) {
    if (!session.isPlaying || _damageCooldown > 0) {
      return;
    }
    session.takeHit();
    _damageCooldown = 1.5;
    player.dash(player.body.position - blob.body.position);
  }

  void _spawnCore() {
    if (_activeCore != null || !session.isPlaying) {
      return;
    }

    final rect = camera.visibleWorldRect.deflate(2);
    var position = _worldCenter.clone();
    for (var attempt = 0; attempt < 12; attempt++) {
      position = Vector2(
        rect.left + _random.nextDouble() * rect.width,
        rect.top + _random.nextDouble() * rect.height,
      );
      if ((position - player.body.position).length >= 5) {
        break;
      }
    }

    _activeCore = EnergyCore(position);
    world.add(_activeCore!);
  }

  void _dash(Vector2 direction) {
    if (!session.isPlaying || _dashCooldown > 0) {
      return;
    }
    player.dash(direction);
    _dashCooldown = 1;
  }

  void _restart() {
    _activeCore?.removeFromParent();
    _activeCore = null;
    _collectedCores.clear();
    session = GameSession();
    _dashCooldown = 0;
    _damageCooldown = 0;
    _movement.setZero();
    player.resetAt(_worldCenter);
    _spawnCore();
    _refreshHud();
  }

  void _refreshHud() {
    final comboLabel = session.combo > 1 ? '  COMBO x${session.combo}' : '';
    hudText.text =
        'SCORE ${session.score}   '
        'CORE ${session.cores}/${GameSession.targetCores}   '
        'LIFE ${session.lives}   '
        'TIME ${session.timeLeft.ceil()}$comboLabel\n'
        'MOVE: WASD / ARROWS   DASH: SPACE / TAP';

    if (session.won) {
      messageText.text = 'MISSION COMPLETE!\nR / TAP TO PLAY AGAIN';
    } else if (session.lost) {
      messageText.text = 'MISSION FAILED\nR / TAP TO RETRY';
    } else {
      messageText.text = '';
    }
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    _movement.setValues(
      (keysPressed.contains(LogicalKeyboardKey.keyD) ||
                  keysPressed.contains(LogicalKeyboardKey.arrowRight)
              ? 1
              : 0) -
          (keysPressed.contains(LogicalKeyboardKey.keyA) ||
                  keysPressed.contains(LogicalKeyboardKey.arrowLeft)
              ? 1
              : 0),
      (keysPressed.contains(LogicalKeyboardKey.keyS) ||
                  keysPressed.contains(LogicalKeyboardKey.arrowDown)
              ? 1
              : 0) -
          (keysPressed.contains(LogicalKeyboardKey.keyW) ||
                  keysPressed.contains(LogicalKeyboardKey.arrowUp)
              ? 1
              : 0),
    );

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        _dash(_movement);
      } else if (event.logicalKey == LogicalKeyboardKey.keyR &&
          !session.isPlaying) {
        _restart();
      }
    }
    return super.onKeyEvent(event, keysPressed);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!session.isPlaying) {
      _restart();
      return;
    }
    final target = screenToWorld(event.canvasPosition);
    _dash(target - player.body.position);
  }
}

void main() {
  runApp(GameWidget(game: SpaceShooterGame()));
}

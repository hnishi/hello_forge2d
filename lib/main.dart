import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flame_forge2d/position_body_component.dart';
import 'package:flame_forge2d/body_component.dart';
import 'package:flame_forge2d/forge2d_game.dart';
import 'package:forge2d/forge2d.dart';

import 'boundaries.dart';

class Player extends PositionBodyComponent {
  final Vector2 position;

  Player(
    this.position, {
    Vector2? size,
  }) : super(size: size ?? Vector2(2, 3));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final sprite = await gameRef.loadSprite('player-sprite.png');
    positionComponent = SpriteComponent(sprite: sprite, size: size);
  }

  @override
  Body createBody() {
    final shape = PolygonShape();

    final vertices = [
      Vector2(-size.x / 2, -size.y / 2),
      Vector2(size.x / 2, -size.y / 2),
      Vector2(0, size.y / 2),
    ];
    shape.set(vertices);

    final fixtureDef = FixtureDef(shape)
      ..userData = this // To be able to determine object in collision
      ..restitution = 0.4
      ..density = 1.0
      ..friction = 0.5;

    final bodyDef = BodyDef()
      ..position = position
      ..angle = (position.x + position.y) / 2 * math.pi
      ..type = BodyType.dynamic;
    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  void move(Vector2 delta) {
    position.add(delta);
  }
}

class BlobPart extends BodyComponent {
  final ConstantVolumeJointDef jointDef;
  final int bodyNumber;
  final Vector2 blobRadius;
  final Vector2 blobCenter;

  BlobPart(
    this.bodyNumber,
    this.jointDef,
    this.blobRadius,
    this.blobCenter,
  );

  @override
  Body createBody() {
    const nBodies = 20.0;
    const bodyRadius = 0.5;
    final angle = (bodyNumber / nBodies) * math.pi * 2;
    final x = blobCenter.x + blobRadius.x * math.sin(angle);
    final y = blobCenter.y + blobRadius.y * math.cos(angle);

    final bodyDef = BodyDef()
      ..fixedRotation = true
      ..position.setValues(x, y)
      ..type = BodyType.dynamic;
    final body = world.createBody(bodyDef);

    final shape = CircleShape()..radius = bodyRadius;
    final fixtureDef = FixtureDef(shape)
      ..density = 1.0
      ..filter.groupIndex = -2;
    body.createFixture(fixtureDef);
    jointDef.addBody(body);
    return body;
  }
}

class SpaceShooterGame extends Forge2DGame with KeyboardEvents {
  SpaceShooterGame() : super(gravity: Vector2(0, -10.0));

  static const int speed = 200;
  final Vector2 velocity = Vector2(0, 0);

  late Player player;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final worldCenter = screenToWorld(size * camera.zoom / 2);
    addAll(createBoundaries(this));

    final position = worldCenter;
    player = Player(position);
    add(player);

    final blobCenter = worldCenter + Vector2(0, 30);
    final blobRadius = Vector2.all(6.0);
    final jointDef = ConstantVolumeJointDef()
      ..frequencyHz = 20.0
      ..dampingRatio = 1.0
      ..collideConnected = false;
    await Future.wait(
      List.generate(
        20,
        (i) => add(BlobPart(i, jointDef, blobRadius, blobCenter)),
      ),
    );
    world.createJoint(jointDef);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final displacement = velocity * (speed * dt);
    player.move(displacement);
  }

  @override
  KeyEventResult onKeyEvent(
    RawKeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final isKeyDown = event is RawKeyDownEvent;

    if (event.logicalKey == LogicalKeyboardKey.keyA) {
      velocity.x = isKeyDown ? -1 : 0;
    } else if (event.logicalKey == LogicalKeyboardKey.keyD) {
      velocity.x = isKeyDown ? 1 : 0;
    } else if (event.logicalKey == LogicalKeyboardKey.keyW) {
      velocity.y = isKeyDown ? -1 : 0;
    } else if (event.logicalKey == LogicalKeyboardKey.keyS) {
      velocity.y = isKeyDown ? 1 : 0;
    }

    return super.onKeyEvent(event, keysPressed);
  }
}

void main() {
  runApp(GameWidget(game: SpaceShooterGame()));
}

import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class Player extends SpriteComponent with HasGameRef<SpaceShooterGame> {
  @override
  Future<void> onLoad() async {
    await super.onLoad();

    sprite = await gameRef.loadSprite('player-sprite.png');

    position = gameRef.size / 2;
    width = 100;
    height = 150;
    anchor = Anchor.center;
  }

  void move(Vector2 delta) {
    position.add(delta);
  }
}

class SpaceShooterGame extends FlameGame with KeyboardEvents {
  static const int speed = 200;
  final Vector2 velocity = Vector2(0, 0);

  late Player player;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    player = Player();

    add(player);
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

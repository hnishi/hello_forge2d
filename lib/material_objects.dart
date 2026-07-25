import 'dart:math' as math;
import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';

enum ArenaMaterial { rubber, iron, ice, wood, jelly, magnet }

extension ArenaMaterialProperties on ArenaMaterial {
  String get label => switch (this) {
    ArenaMaterial.rubber => 'RUBBER',
    ArenaMaterial.iron => 'IRON',
    ArenaMaterial.ice => 'ICE',
    ArenaMaterial.wood => 'WOOD',
    ArenaMaterial.jelly => 'JELLY',
    ArenaMaterial.magnet => 'MAGNET',
  };

  Color get color => switch (this) {
    ArenaMaterial.rubber => const Color(0xFFFF496C),
    ArenaMaterial.iron => const Color(0xFF78909C),
    ArenaMaterial.ice => const Color(0xFFB3F5FF),
    ArenaMaterial.wood => const Color(0xFFC58B4E),
    ArenaMaterial.jelly => const Color(0xFFB967FF),
    ArenaMaterial.magnet => const Color(0xFFFF4D4D),
  };

  double get restitution => switch (this) {
    ArenaMaterial.rubber => 1.12,
    ArenaMaterial.iron => 0.18,
    ArenaMaterial.ice => 0.72,
    ArenaMaterial.wood => 0.55,
    ArenaMaterial.jelly => 0.08,
    ArenaMaterial.magnet => 0.45,
  };

  double get friction => switch (this) {
    ArenaMaterial.rubber => 0.92,
    ArenaMaterial.iron => 0.48,
    ArenaMaterial.ice => 0.015,
    ArenaMaterial.wood => 0.46,
    ArenaMaterial.jelly => 0.8,
    ArenaMaterial.magnet => 0.3,
  };

  double get density => switch (this) {
    ArenaMaterial.rubber => 0.9,
    ArenaMaterial.iron => 7.8,
    ArenaMaterial.ice => 0.85,
    ArenaMaterial.wood => 0.65,
    ArenaMaterial.jelly => 0.4,
    ArenaMaterial.magnet => 4.5,
  };
}

class MaterialObstacle extends BodyComponent {
  MaterialObstacle({
    required this.material,
    required this.spawnPosition,
    this.size = 2.2,
  }) : super(renderBody: false);

  final ArenaMaterial material;
  final Vector2 spawnPosition;
  final double size;
  double _age = 0;

  bool get isMagnet => material == ArenaMaterial.magnet;
  bool get isJelly => material == ArenaMaterial.jelly;

  @override
  Body createBody() {
    final shape = material == ArenaMaterial.ice
        ? (PolygonShape()..setAsBoxXY(size * 1.35, size * 0.42))
        : (PolygonShape()..setAsBoxXY(size, size));
    final fixtureDef = FixtureDef(
      shape,
      density: material.density,
      restitution: material.restitution,
      friction: material.friction,
    );
    final isMovable =
        material == ArenaMaterial.iron || material == ArenaMaterial.wood;
    final bodyDef = BodyDef(
      userData: this,
      position: spawnPosition,
      type: isMovable ? BodyType.dynamic : BodyType.static,
      angularDamping: material == ArenaMaterial.iron ? 1.8 : 0.55,
      linearDamping: material == ArenaMaterial.iron ? 0.9 : 0.25,
    );
    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
  }

  @override
  void render(Canvas canvas) {
    final halfWidth = material == ArenaMaterial.ice ? size * 1.35 : size;
    final halfHeight = material == ArenaMaterial.ice ? size * 0.42 : size;
    final rect = Rect.fromLTRB(-halfWidth, -halfHeight, halfWidth, halfHeight);
    final paint = Paint()..color = material.color;

    if (material == ArenaMaterial.jelly) {
      final pulse = 1 + math.sin(_age * 7) * 0.05;
      canvas.save();
      canvas.scale(1 / pulse, pulse);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(size * 0.6)),
        paint,
      );
      canvas.restore();
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(size * 0.18)),
        paint,
      );
    }

    if (material == ArenaMaterial.magnet) {
      canvas.drawArc(
        rect.deflate(size * 0.35),
        -math.pi * 0.15,
        math.pi * 1.3,
        false,
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size * 0.25,
      );
    } else {
      canvas.drawLine(
        Offset(-halfWidth * 0.65, -halfHeight * 0.35),
        Offset(halfWidth * 0.65, halfHeight * 0.35),
        Paint()
          ..color = const Color(0x55FFFFFF)
          ..strokeWidth = 0.16,
      );
    }
  }
}

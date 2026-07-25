import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

class TableSurface extends PositionComponent {
  TableSurface(Rect tableRect)
    : super(
        position: Vector2(tableRect.left, tableRect.top),
        size: Vector2(tableRect.width, tableRect.height),
        priority: -10,
      );

  final Paint _surfacePaint = Paint()..color = const Color(0xFF164D5A);
  final Paint _opponentAreaPaint = Paint()..color = const Color(0xFF103745);
  final Paint _playerAreaPaint = Paint()..color = const Color(0x2217D7FF);
  final Paint _innerPaint = Paint()
    ..color = const Color(0xFF0B4F47)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.18;
  final Paint _linePaint = Paint()
    ..color = const Color(0x99FFFFFF)
    ..strokeWidth = 0.12;
  final Paint _goalPaint = Paint()..color = const Color(0x33FF5A5F);

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(0.7)),
      _surfacePaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.x / 2, 0, size.x / 2, size.y),
      _opponentAreaPaint,
    );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x / 2, size.y), _playerAreaPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(0.5), const Radius.circular(0.4)),
      _innerPaint,
    );
    canvas.drawLine(
      Offset(size.x / 2, 0.5),
      Offset(size.x / 2, size.y - 0.5),
      _linePaint,
    );
    canvas.drawLine(
      Offset(0.5, size.y / 2),
      Offset(size.x - 0.5, size.y / 2),
      _linePaint,
    );
    for (var i = 1; i < 4; i++) {
      final x = size.x * i / 4;
      canvas.drawLine(
        Offset(x, 0.5),
        Offset(x, size.y - 0.5),
        Paint()
          ..color = const Color(0x33FFFFFF)
          ..strokeWidth = 0.08,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(0.5, 0.5, size.x / 2 - 0.5, size.y - 1),
      _goalPaint,
    );
  }
}

class TableWall extends BodyComponent {
  TableWall(this.start, this.end)
    : super(paint: Paint()..color = const Color(0xFFFFFFFF));

  final Vector2 start;
  final Vector2 end;

  @override
  Body createBody() {
    final fixtureDef = FixtureDef(
      EdgeShape()..set(start, end),
      restitution: 0.86,
      friction: 0.62,
    );
    return world.createBody(BodyDef(userData: this))..createFixture(fixtureDef);
  }
}

class MissZone extends BodyComponent {
  MissZone(this.start, this.end) : super(renderBody: false);

  final Vector2 start;
  final Vector2 end;

  @override
  Body createBody() {
    final fixtureDef = FixtureDef(EdgeShape()..set(start, end), isSensor: true);
    return world.createBody(BodyDef(userData: this))..createFixture(fixtureDef);
  }
}

import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 创建花朵图标
  final iconSize = 1024.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size(iconSize, iconSize);
  
  // 绘制背景（绿色渐变）
  final backgroundPaint = Paint()
    ..shader = ui.Gradient.radial(
      Offset(iconSize / 2, iconSize / 2),
      iconSize / 2,
      [
        const Color(0xFF4CAF50),
        const Color(0xFF2E7D32),
      ],
    );
  canvas.drawRect(Rect.fromLTWH(0, 0, iconSize, iconSize), backgroundPaint);
  
  // 绘制花朵
  final center = Offset(iconSize / 2, iconSize / 2);
  final flowerRadius = iconSize * 0.35;
  
  // 绘制花瓣（5个花瓣）
  final petalPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;
  
  final petalCount = 5;
  for (int i = 0; i < petalCount; i++) {
    final angle = (i * 2 * math.pi) / petalCount - math.pi / 2;
    final petalCenter = Offset(
      center.dx + flowerRadius * 0.6 * math.cos(angle),
      center.dy + flowerRadius * 0.6 * math.sin(angle),
    );
    
    // 绘制椭圆形花瓣
    canvas.save();
    canvas.translate(petalCenter.dx, petalCenter.dy);
    canvas.rotate(angle);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: flowerRadius * 0.8,
        height: flowerRadius * 1.2,
      ),
      petalPaint,
    );
    canvas.restore();
  }
  
  // 绘制花心（黄色圆形）
  final centerPaint = Paint()
    ..shader = ui.Gradient.radial(
      center,
      flowerRadius * 0.3,
      [
        const Color(0xFFFFEB3B),
        const Color(0xFFFFC107),
      ],
    );
  canvas.drawCircle(center, flowerRadius * 0.3, centerPaint);
  
  // 绘制花心细节（小点）
  final dotPaint = Paint()
    ..color = const Color(0xFFFF9800)
    ..style = PaintingStyle.fill;
  for (int i = 0; i < 8; i++) {
    final dotAngle = (i * 2 * math.pi) / 8;
    final dotOffset = Offset(
      center.dx + flowerRadius * 0.15 * math.cos(dotAngle),
      center.dy + flowerRadius * 0.15 * math.sin(dotAngle),
    );
    canvas.drawCircle(dotOffset, flowerRadius * 0.05, dotPaint);
  }
  
  // 绘制叶子
  final leafPaint = Paint()
    ..color = const Color(0xFF66BB6A)
    ..style = PaintingStyle.fill;
  
  // 左侧叶子
  canvas.save();
  canvas.translate(iconSize * 0.15, iconSize * 0.75);
  canvas.rotate(-0.5);
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset.zero,
      width: flowerRadius * 0.6,
      height: flowerRadius * 0.9,
    ),
    leafPaint,
  );
  canvas.restore();
  
  // 右侧叶子
  canvas.save();
  canvas.translate(iconSize * 0.85, iconSize * 0.75);
  canvas.rotate(0.5);
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset.zero,
      width: flowerRadius * 0.6,
      height: flowerRadius * 0.9,
    ),
    leafPaint,
  );
  canvas.restore();
  
  // 转换为图片
  final picture = recorder.endRecording();
  final image = await picture.toImage(iconSize.toInt(), iconSize.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final pngBytes = byteData!.buffer.asUint8List();
  
  // 保存文件
  final file = File('assets/icon.png');
  await file.create(recursive: true);
  await file.writeAsBytes(pngBytes);
  
  print('图标已生成: ${file.path}');
}

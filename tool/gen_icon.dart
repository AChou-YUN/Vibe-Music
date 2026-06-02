import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() {
  final sizes = [256, 128, 64, 48, 32, 16];
  final images = <img.Image>[];
  for (final sz in sizes) {
    images.add(drawIcon(sz));
  }
  final icoBytes = encodeIco(images);
  final outPath = 'windows/runner/resources/app_icon.ico';
  File(outPath).writeAsBytesSync(icoBytes);
  print('Wrote ' + outPath + ' (' + icoBytes.length.toString() + ' bytes)');
}

img.Image drawIcon(int size) {
  final im = img.Image(width: size, height: size, numChannels: 4);
  final s = size.toDouble();
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      im.setPixelRgba(x, y, 0x0D, 0x0D, 0x0D, 255);
    }
  }
  final radius = s * 0.22;
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final dx2 = max(0.0, max(radius - x.toDouble(), x.toDouble() - (s - 1 - radius)));
      final dy2 = max(0.0, max(radius - y.toDouble(), y.toDouble() - (s - 1 - radius)));
      if (dx2 * dx2 + dy2 * dy2 > radius * radius) {
        im.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }
  }
  final vCenterX = s * 0.50;
  final vTopY = s * 0.14;
  final vBottomY = s * 0.54;
  final vLeftX = s * 0.18;
  final vRightX = s * 0.82;
  final vThickness = s * 0.07;
  final vColor = img.ColorRgb8(0xFF, 0x7A, 0x40);
  if (size >= 64) {
    final glowColor = img.ColorRgb8(0xFF, 0x6B, 0x00);
    final glowAlpha = size >= 128 ? 40 : 25;
    drawThickLine(im, vLeftX, vTopY, vCenterX, vBottomY, vThickness * 1.8, glowColor, alpha: glowAlpha);
    drawThickLine(im, vCenterX, vBottomY, vRightX, vTopY, vThickness * 1.8, glowColor, alpha: glowAlpha);
  }
  drawThickLine(im, vLeftX, vTopY, vCenterX, vBottomY, vThickness, vColor);
  drawThickLine(im, vCenterX, vBottomY, vRightX, vTopY, vThickness, vColor);
  final barWidth = s * 0.045;
  final barGap = s * 0.088;
  final barsY = s * 0.88;
  final barHeightFrac = [0.045, 0.070, 0.100, 0.130, 0.100, 0.070, 0.045];
  final barOpacities = [0.40, 0.55, 0.75, 1.0, 0.75, 0.55, 0.40];
  final totalBarsW = 7 * barWidth + 6 * (barGap - barWidth);
  final barsStartX = vCenterX - totalBarsW / 2;
  for (int i = 0; i < 7; i++) {
    final bx = barsStartX + i * barGap;
    final bh = s * barHeightFrac[i];
    final by = barsY - bh;
    final opacity = barOpacities[i];
    for (int py = by.round(); py < barsY.round(); py++) {
      final t2 = bh > 0 ? (barsY - py) / bh : 0.0;
      final rv = lerpV(0xFF, 0xFF, t2);
      final gv = lerpV(0x6B, 0xB0, t2);
      final bv = lerpV(0x35, 0x7A, t2);
      final a = (opacity * 255).round();
      for (int px = bx.round(); px < (bx + barWidth).round() && px < size; px++) {
        if (px >= 0 && py >= 0 && py < size) {
          final bg = im.getPixel(px, py);
          final blendA = a / 255.0;
          final outR = (bg.r * (1 - blendA) + rv * blendA).round();
          final outG = (bg.g * (1 - blendA) + gv * blendA).round();
          final outB = (bg.b * (1 - blendA) + bv * blendA).round();
          im.setPixelRgba(px, py, outR, outG, outB, 255);
        }
      }
    }
  }
  return im;
}

int lerpV(int a, int b, double t) => (a + (b - a) * t).round().clamp(0, 255);

void drawThickLine(img.Image im, double x0, double y0, double x1, double y1,
    double thickness, img.Color color, {int alpha = 255}) {
  final dx = x1 - x0;
  final dy = y1 - y0;
  final len = sqrt(dx * dx + dy * dy);
  if (len == 0) return;
  final halfW = thickness / 2;
  final minX = max(0, (min(x0, x1) - thickness).round());
  final maxX = min(im.width - 1, (max(x0, x1) + thickness).round());
  final minY = max(0, (min(y0, y1) - thickness).round());
  final maxY = min(im.height - 1, (max(y0, y1) + thickness).round());
  for (int py = minY; py <= maxY; py++) {
    for (int px = minX; px <= maxX; px++) {
      final t = ((px - x0) * dx + (py - y0) * dy) / (len * len);
      final tc = t.clamp(0.0, 1.0);
      final closestX = x0 + tc * dx;
      final closestY = y0 + tc * dy;
      final dist = sqrt((px - closestX) * (px - closestX) + (py - closestY) * (py - closestY));
      if (dist <= halfW) {
        final edgeFade = max(0.0, 1.0 - (dist - halfW + 1.5).abs() / 1.5);
        final a = (alpha * edgeFade).round().clamp(0, 255);
        if (a > 0) {
          final bg = im.getPixel(px, py);
          final blend = a / 255.0;
          final outR = (bg.r * (1 - blend) + color.r * blend).round();
          final outG = (bg.g * (1 - blend) + color.g * blend).round();
          final outB = (bg.b * (1 - blend) + color.b * blend).round();
          im.setPixelRgba(px, py, outR, outG, outB, 255);
        }
      }
    }
  }
}

List<int> encodeIco(List<img.Image> images) {
  final pngData = <List<int>>[];
  for (final im in images) {
    pngData.add(img.encodePng(im));
  }
  final entryCount = images.length;
  final headerSize = 6 + entryCount * 16;
  final bytes = <int>[];
  bytes.addAll([0, 0]);
  bytes.addAll([1, 0]);
  bytes.addAll([entryCount & 0xFF, (entryCount >> 8) & 0xFF]);
  int offset = headerSize;
  for (int i = 0; i < entryCount; i++) {
    final sz = images[i].width;
    bytes.add(sz < 256 ? sz : 0);
    bytes.add(sz < 256 ? sz : 0);
    bytes.add(0);
    bytes.add(0);
    bytes.addAll([1, 0]);
    bytes.addAll([32, 0]);
    final dataSize = pngData[i].length;
    bytes.addAll([dataSize & 0xFF, (dataSize >> 8) & 0xFF, (dataSize >> 16) & 0xFF, (dataSize >> 24) & 0xFF]);
    bytes.addAll([offset & 0xFF, (offset >> 8) & 0xFF, (offset >> 16) & 0xFF, (offset >> 24) & 0xFF]);
    offset += dataSize;
  }
  for (final d in pngData) {
    bytes.addAll(d);
  }
  return bytes;
}


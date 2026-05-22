import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/icon/app_icon.png');
  if (!file.existsSync()) {
    print("Icon file not found!");
    return;
  }

  final bytes = file.readAsBytesSync();
  var decoded = img.decodeImage(bytes);
  
  if (decoded == null) {
    print("Could not decode image.");
    return;
  }

  // The AI generated image often places the black square on a white canvas.
  // We want to find the exact boundaries of that black square.
  // We'll scan from the middle outwards to find where the dark background ends.

  int midY = decoded.height ~/ 2;
  int midX = decoded.width ~/ 2;

  // Find left edge
  int left = 0;
  for (int x = 0; x < midX; x++) {
    final p = decoded.getPixel(x, midY);
    // If it's very dark, it's our icon background
    if (p.r < 50 && p.g < 50 && p.b < 50) {
      left = x;
      break;
    }
  }

  // Find right edge
  int right = decoded.width - 1;
  for (int x = decoded.width - 1; x > midX; x--) {
    final p = decoded.getPixel(x, midY);
    if (p.r < 50 && p.g < 50 && p.b < 50) {
      right = x;
      break;
    }
  }

  // Find top edge
  int top = 0;
  for (int y = 0; y < midY; y++) {
    final p = decoded.getPixel(midX, y);
    if (p.r < 50 && p.g < 50 && p.b < 50) {
      top = y;
      break;
    }
  }

  // Find bottom edge
  int bottom = decoded.height - 1;
  for (int y = decoded.height - 1; y > midY; y--) {
    final p = decoded.getPixel(midX, y);
    if (p.r < 50 && p.g < 50 && p.b < 50) {
      bottom = y;
      break;
    }
  }

  int cropWidth = right - left + 1;
  int cropHeight = bottom - top + 1;

  print("Found black square at: (\$left, \$top) with size \${cropWidth}x\${cropHeight}");

  // Only crop if we actually found a reasonable square
  if (cropWidth > 100 && cropHeight > 100) {
    // Add a tiny bit of inward padding (5 pixels) to guarantee no white edges remain
    int padding = 5;
    left += padding;
    top += padding;
    cropWidth -= padding * 2;
    cropHeight -= padding * 2;

    var cropped = img.copyCrop(decoded, x: left, y: top, width: cropWidth, height: cropHeight);
    
    // Ensure it's perfectly square for iOS (take the min dimension)
    int size = cropWidth < cropHeight ? cropWidth : cropHeight;
    cropped = img.copyCrop(cropped, x: 0, y: 0, width: size, height: size);

    var resized = img.copyResize(cropped, width: 1024, height: 1024, interpolation: img.Interpolation.cubic);

    file.writeAsBytesSync(img.encodePng(resized));
    print("Successfully aggressive-cropped and saved the icon!");
  } else {
    print("Could not detect the black square.");
  }
}

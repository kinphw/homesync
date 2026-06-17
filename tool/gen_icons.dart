// 우리집일정표 앱 아이콘/스플래시 이미지를 코드로 생성한다.
// 실행: dart run tool/gen_icons.dart
//
// 산출물:
//   assets/icon/icon.png            (파란 배경 + 흰 달력) - iOS / 레거시 안드로이드
//   assets/icon/icon_foreground.png (투명 배경 + 흰 달력) - 안드로이드 적응형 전경
//   assets/icon/splash_logo.png     (스플래시용 = 전경과 동일)
import 'dart:io';
import 'package:image/image.dart' as img;

const int s = 1024;

final blue = img.ColorRgb8(0x15, 0x65, 0xC0);
final white = img.ColorRgb8(0xFF, 0xFF, 0xFF);
final clear = img.ColorRgba8(0, 0, 0, 0);

// 달력 안에 찍는 회원 구분 색 점들(앱의 색 팔레트와 동일 계열).
final dotColors = <img.Color>[
  img.ColorRgb8(0x15, 0x65, 0xC0),
  img.ColorRgb8(0xD3, 0x2F, 0x2F),
  img.ColorRgb8(0x2E, 0x7D, 0x32),
  img.ColorRgb8(0xF9, 0xA8, 0x25),
  img.ColorRgb8(0x6A, 0x1B, 0x9A),
  img.ColorRgb8(0x00, 0x83, 0x8F),
];

/// 캔버스 중앙에 흰색 달력을 그린다. [scale]은 달력 폭 비율(0~1).
void drawCalendar(img.Image im, double scale) {
  final bw = (s * scale).round();
  final bh = (bw * 0.92).round();
  final x1 = (s - bw) ~/ 2;
  final y1 = (s - bh) ~/ 2 + (s * 0.03).round();
  final x2 = x1 + bw;
  final y2 = y1 + bh;
  final r = (bw * 0.11).round();

  // 상단 바인더 고리 2개 (흰색, 본체 위로 살짝 튀어나오게)
  final ringR = (bw * 0.05).round();
  final ringY = y1 - (bh * 0.04).round();
  img.fillCircle(im,
      x: x1 + (bw * 0.30).round(), y: ringY, radius: ringR, color: white);
  img.fillCircle(im,
      x: x1 + (bw * 0.70).round(), y: ringY, radius: ringR, color: white);

  // 본체(흰 라운드 사각형)
  img.fillRect(im, x1: x1, y1: y1, x2: x2, y2: y2, color: white, radius: r);

  // 헤더(파란 띠) — 위쪽 모서리는 둥글게, 아래쪽은 각지게
  final headerH = (bh * 0.24).round();
  img.fillRect(im,
      x1: x1, y1: y1, x2: x2, y2: y1 + headerH, color: blue, radius: r);
  img.fillRect(im,
      x1: x1, y1: y1 + headerH - r, x2: x2, y2: y1 + headerH, color: blue);

  // 본체 내부 날짜 점 그리드 (3 x 2)
  const cols = 3, rows = 2;
  final gLeft = x1 + (bw * 0.20).round();
  final gRight = x2 - (bw * 0.20).round();
  final gTop = y1 + headerH + (bh * 0.16).round();
  final gBottom = y2 - (bh * 0.16).round();
  final dotR = (bw * 0.058).round();
  for (var rr = 0; rr < rows; rr++) {
    for (var c = 0; c < cols; c++) {
      final gx = gLeft + ((gRight - gLeft) * c / (cols - 1)).round();
      final gy = gTop + ((gBottom - gTop) * rr / (rows - 1)).round();
      img.fillCircle(im,
          x: gx, y: gy, radius: dotR, color: dotColors[(rr * cols + c) % dotColors.length]);
    }
  }
}

void main() {
  Directory('assets/icon').createSync(recursive: true);

  // 1) 풀 아이콘 (파란 배경)
  final icon = img.Image(width: s, height: s, numChannels: 4);
  img.fill(icon, color: blue);
  drawCalendar(icon, 0.60);
  File('assets/icon/icon.png').writeAsBytesSync(img.encodePng(icon));

  // 2) 적응형 전경 (투명 배경, 안전영역 고려해 더 작게)
  final fg = img.Image(width: s, height: s, numChannels: 4);
  img.fill(fg, color: clear);
  drawCalendar(fg, 0.46);
  File('assets/icon/icon_foreground.png').writeAsBytesSync(img.encodePng(fg));

  // 3) 스플래시 로고 = 전경과 동일(흰 달력, 투명 배경)
  File('assets/icon/splash_logo.png').writeAsBytesSync(img.encodePng(fg));

  stdout.writeln('생성 완료: assets/icon/{icon,icon_foreground,splash_logo}.png');
}

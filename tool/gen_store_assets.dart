// Play Console 업로드용 그래픽 자산 생성.
// 실행: dart run tool/gen_store_assets.dart
//
// 산출물:
//   store/play_icon_512.png   (512x512 고해상도 앱 아이콘 — Play '앱 아이콘')
//   store/feature_graphic.png (1024x500 피처 그래픽)
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  Directory('store').createSync(recursive: true);

  final blue = img.ColorRgb8(0x15, 0x65, 0xC0);

  // 1) 512 앱 아이콘 = 기존 1024 아이콘을 축소
  final icon1024 = img.decodePng(File('assets/icon/icon.png').readAsBytesSync())!;
  final icon512 = img.copyResize(icon1024,
      width: 512, height: 512, interpolation: img.Interpolation.average);
  File('store/play_icon_512.png').writeAsBytesSync(img.encodePng(icon512));

  // 2) 피처 그래픽 1024x500 (파란 배경 + 흰 달력 + 색점 장식)
  final fg = img.Image(width: 1024, height: 500, numChannels: 4);
  img.fill(fg, color: blue);

  // 흰 달력(전경, 투명 배경)을 가운데에 배치
  final cal = img.decodePng(
      File('assets/icon/icon_foreground.png').readAsBytesSync())!;
  const calSize = 480;
  final calSized = img.copyResize(cal, width: calSize, height: calSize);
  img.compositeImage(fg, calSized,
      dstX: (1024 - calSize) ~/ 2, dstY: (500 - calSize) ~/ 2);

  // 양옆에 회원 색 점들을 대칭으로 장식
  final dots = <img.Color>[
    img.ColorRgb8(0xD3, 0x2F, 0x2F),
    img.ColorRgb8(0x2E, 0x7D, 0x32),
    img.ColorRgb8(0xF9, 0xA8, 0x25),
  ];
  for (var i = 0; i < dots.length; i++) {
    final y = 130 + i * 120;
    img.fillCircle(fg, x: 120, y: y, radius: 22, color: dots[i]);
    img.fillCircle(fg, x: 904, y: y, radius: 22, color: dots[dots.length - 1 - i]);
  }

  File('store/feature_graphic.png').writeAsBytesSync(img.encodePng(fg));

  stdout.writeln('생성 완료: store/play_icon_512.png, store/feature_graphic.png');
}

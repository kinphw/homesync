import 'package:flutter/material.dart';

/// 회원가입 시 각자 고를 수 있는 구분 색상 팔레트.
/// 캘린더에서 회원별 일정을 색으로 구분하는 데 사용한다.
class MemberColors {
  const MemberColors._();

  /// 선택 가능한 색상 목록(ARGB int).
  static const List<int> palette = <int>[
    0xFF1565C0, // 파랑
    0xFFD32F2F, // 빨강
    0xFF2E7D32, // 초록
    0xFFF9A825, // 노랑/주황
    0xFF6A1B9A, // 보라
    0xFF00838F, // 청록
    0xFFEF6C00, // 주황
    0xFFAD1457, // 자홍
    0xFF4E342E, // 갈색
    0xFF455A64, // 회청색
  ];

  static Color toColor(int value) => Color(value);

  /// 인덱스로 색을 안전하게 가져온다(범위를 벗어나면 순환).
  static int byIndex(int index) => palette[index % palette.length];
}

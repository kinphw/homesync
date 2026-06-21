import 'package:cloud_firestore/cloud_firestore.dart';

/// 일정의 시간대. 정밀 시:분 대신 큰 구간으로만 구분한다.
enum EventPeriod {
  allDay('종일', 0),
  morning('오전', 1),
  afternoon('오후', 2),
  evening('저녁', 3);

  const EventPeriod(this.label, this.order);

  /// 화면에 표시할 한글 라벨.
  final String label;

  /// 같은 날 안에서 정렬할 때 쓰는 순서.
  final int order;

  static EventPeriod fromName(String? name) {
    return EventPeriod.values.firstWhere(
      (p) => p.name == name,
      orElse: () => EventPeriod.allDay,
    );
  }
}

/// 일정 1건. Firestore `groups/{groupId}/events/{eventId}` 문서와 매핑된다.
class CalendarEvent {
  final String id;
  final String title;

  /// 일정 날짜(자정 기준). 기간 일정이면 시작일.
  final DateTime date;

  /// 기간 일정의 종료일(자정 기준). null이거나 [date]와 같으면 하루 일정.
  final DateTime? endDate;

  /// 시간대(종일/오전/오후/저녁). 정확한 시각은 제목에 자유롭게 적는다.
  final EventPeriod period;

  /// 매주 반복 여부. true면 [date]의 요일에 매주 표시된다(앵커=date).
  final bool repeatWeekly;

  /// 작성자 정보(필터·색상 표시에 사용).
  final String ownerUid;
  final String ownerName;

  /// 표시 색상(보통 작성자 색상). ARGB int.
  final int colorValue;

  final String memo;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CalendarEvent({
    required this.id,
    required this.title,
    required this.date,
    this.endDate,
    required this.period,
    this.repeatWeekly = false,
    required this.ownerUid,
    required this.ownerName,
    required this.colorValue,
    this.memo = '',
    this.createdAt,
    this.updatedAt,
  });

  /// 같은 날짜끼리 묶기 위한 키 (시/분 제거).
  static DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// "종일" / "오전" / "오후" / "저녁".
  String get periodLabel => period.label;

  /// 여러 날에 걸친 기간 일정인지.
  bool get isRange =>
      endDate != null && dayOnly(endDate!).isAfter(dayOnly(date));

  /// 앵커 날짜의 한글 요일 (월~일).
  String get weekdayKorean {
    const names = ['월', '화', '수', '목', '금', '토', '일'];
    return names[date.weekday - 1];
  }

  /// copyWith에서 endDate를 '바꾸지 않음'과 'null로 지움'을 구분하기 위한 표식.
  static const Object _unset = Object();

  CalendarEvent copyWith({
    String? title,
    DateTime? date,
    Object? endDate = _unset,
    EventPeriod? period,
    bool? repeatWeekly,
    int? colorValue,
    String? memo,
  }) {
    return CalendarEvent(
      id: id,
      title: title ?? this.title,
      date: date ?? this.date,
      endDate:
          identical(endDate, _unset) ? this.endDate : endDate as DateTime?,
      period: period ?? this.period,
      repeatWeekly: repeatWeekly ?? this.repeatWeekly,
      ownerUid: ownerUid,
      ownerName: ownerName,
      colorValue: colorValue ?? this.colorValue,
      memo: memo ?? this.memo,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'date': Timestamp.fromDate(dayOnly(date)),
      'endDate':
          endDate != null ? Timestamp.fromDate(dayOnly(endDate!)) : null,
      'period': period.name,
      'repeatWeekly': repeatWeekly,
      'ownerUid': ownerUid,
      'ownerName': ownerName,
      'colorValue': colorValue,
      'memo': memo,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory CalendarEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return CalendarEvent(
      id: doc.id,
      title: (data['title'] ?? '') as String,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      period: EventPeriod.fromName(data['period'] as String?),
      repeatWeekly: (data['repeatWeekly'] ?? false) as bool,
      ownerUid: (data['ownerUid'] ?? '') as String,
      ownerName: (data['ownerName'] ?? '') as String,
      colorValue: (data['colorValue'] ?? 0xFF1565C0) as int,
      memo: (data['memo'] ?? '') as String,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

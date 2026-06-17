// 모델 단위 테스트. (위젯/통합 테스트는 Firebase 초기화가 필요하므로 별도 구성)
import 'package:flutter_test/flutter_test.dart';
import 'package:homesync/models/calendar_event.dart';

void main() {
  group('EventPeriod', () {
    test('이름으로 시간대를 복원한다', () {
      expect(EventPeriod.fromName('morning'), EventPeriod.morning);
      expect(EventPeriod.fromName('evening'), EventPeriod.evening);
    });

    test('알 수 없는 값은 종일로 처리', () {
      expect(EventPeriod.fromName('xxx'), EventPeriod.allDay);
      expect(EventPeriod.fromName(null), EventPeriod.allDay);
    });

    test('정렬 순서: 종일 < 오전 < 오후 < 저녁', () {
      expect(EventPeriod.allDay.order, lessThan(EventPeriod.morning.order));
      expect(EventPeriod.morning.order, lessThan(EventPeriod.afternoon.order));
      expect(EventPeriod.afternoon.order, lessThan(EventPeriod.evening.order));
    });

    test('한글 라벨', () {
      expect(EventPeriod.morning.label, '오전');
      expect(EventPeriod.allDay.label, '종일');
    });
  });

  test('dayOnly 는 시/분을 버린다', () {
    final only = CalendarEvent.dayOnly(DateTime(2026, 6, 13, 15, 42));
    expect(only, DateTime(2026, 6, 13));
  });
}

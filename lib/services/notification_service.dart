import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/calendar_event.dart';

/// 등록한 일정에 대한 로컬 알림(리마인더) 예약을 담당.
///
/// - 당일 아침 8시: 그날 일정 요약 1건.
/// - 1시간 전: 시간대 대표시각(오후 14시→13시, 저녁 19시→18시) 기준.
///   (오전·종일은 아침 8시 요약으로 갈음)
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'event_reminders';
  static const _channelName = '일정 알림';

  /// 시간대 → "1시간 전" 알림의 대표 시각(시). 없으면 null(아침 요약으로 갈음).
  static int? _repHour(EventPeriod p) {
    switch (p) {
      case EventPeriod.afternoon:
        return 14;
      case EventPeriod.evening:
        return 19;
      case EventPeriod.morning:
      case EventPeriod.allDay:
        return null;
    }
  }

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );
    _ready = true;
  }

  /// 알림 권한 요청(안드로이드 13+ 알림 권한, 정확 알람 / iOS 권한).
  Future<void> requestPermissions() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: '등록한 일정 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  /// 전체 재예약: 기존 예약을 모두 취소하고, 앞으로 30일 일정에 대해 다시 예약.
  Future<void> rescheduleAll(
    List<CalendarEvent> events, {
    required bool enabled,
  }) async {
    await init();
    await _plugin.cancelAll();
    if (!enabled) return;

    final now = tz.TZDateTime.now(tz.local);
    final today = DateTime(now.year, now.month, now.day);
    final horizon = today.add(const Duration(days: 30));

    // 단발/반복을 다가오는 날짜로 펼쳐 날짜별로 묶는다.
    final byDay = <DateTime, List<CalendarEvent>>{};
    void addOcc(DateTime day, CalendarEvent e) {
      final d = DateTime(day.year, day.month, day.day);
      if (d.isBefore(today) || d.isAfter(horizon)) return;
      byDay.putIfAbsent(d, () => []).add(e);
    }

    for (final e in events) {
      if (e.repeatWeekly) {
        final anchor = DateTime(e.date.year, e.date.month, e.date.day);
        for (var d = today; !d.isAfter(horizon);
            d = d.add(const Duration(days: 1))) {
          if (d.weekday == e.date.weekday && !d.isBefore(anchor)) addOcc(d, e);
        }
      } else {
        addOcc(e.date, e);
      }
    }

    final pending = <_Pending>[];
    byDay.forEach((day, dayEvents) {
      // 당일 아침 8시 요약
      final at8 = tz.TZDateTime(tz.local, day.year, day.month, day.day, 8, 0);
      if (at8.isAfter(now)) {
        final titles = dayEvents.map((e) => e.title).toList();
        final body = titles.length <= 3
            ? titles.join(', ')
            : '${titles.take(3).join(', ')} 외 ${titles.length - 3}건';
        pending.add(_Pending(at8, '오늘 일정 ${dayEvents.length}건', body));
      }
      // 시간대 대표시각 1시간 전 (오후/저녁)
      for (final e in dayEvents) {
        final rep = _repHour(e.period);
        if (rep == null) continue;
        final when =
            tz.TZDateTime(tz.local, day.year, day.month, day.day, rep - 1, 0);
        if (when.isAfter(now)) {
          pending.add(
              _Pending(when, e.title, '${e.periodLabel} · ${e.ownerName} · 곧 시작'));
        }
      }
    });

    // iOS는 예약 알림이 최대 64개 → 가까운 시각 우선으로 상한.
    pending.sort((a, b) => a.when.compareTo(b.when));
    var id = 1;
    for (final p in pending.take(60)) {
      await _plugin.zonedSchedule(
        id: id++,
        title: p.title,
        body: p.body,
        scheduledDate: p.when,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }
}

class _Pending {
  final tz.TZDateTime when;
  final String title;
  final String body;
  _Pending(this.when, this.title, this.body);
}

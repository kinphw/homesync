import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../data/holidays.dart';
import '../../models/calendar_event.dart';
import '../../providers.dart';
import '../../widgets/member_filter_bar.dart';
import '../event/event_detail_screen.dart';
import '../event/event_edit_screen.dart';
import '../settings/settings_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  /// false = 점 보기(아래 목록), true = 달력 칸에 내용 직접 표시. 기본은 내용 보기.
  bool _showContent = true;

  /// 표시 범위. 기본은 월(가독성). 2주 모드는 토글로 전환.
  CalendarFormat _format = CalendarFormat.month;

  /// 2주 모드의 시작일 = 이번 주 일요일. (오늘 주가 항상 1주차가 되도록 + 과거 차단)
  DateTime get _twoWeekFirstDay {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day);
    return base.subtract(Duration(days: base.weekday % 7)); // 일요일 시작
  }

  /// 하루치 일정 = 그 날의 단발 일정 + 매주 반복 일정(요일/앵커 조건 충족분).
  List<CalendarEvent> _eventsForDay(
    DateTime day,
    Map<DateTime, List<CalendarEvent>> oneTimeByDay,
    List<CalendarEvent> repeating,
  ) {
    final d = CalendarEvent.dayOnly(day);
    final list = <CalendarEvent>[...(oneTimeByDay[d] ?? const [])];
    for (final e in repeating) {
      if (e.date.weekday == day.weekday &&
          !d.isBefore(CalendarEvent.dayOnly(e.date))) {
        list.add(e);
      }
    }
    list.sort((a, b) => a.period.order.compareTo(b.period.order));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(currentGroupProvider).value;
    final eventsAsync = ref.watch(groupEventsProvider);
    final hidden = ref.watch(hiddenMembersProvider);

    // 회원 필터를 적용하면서 단발/반복으로 분리.
    final allEvents = eventsAsync.value ?? const <CalendarEvent>[];
    final oneTimeByDay = <DateTime, List<CalendarEvent>>{};
    final repeating = <CalendarEvent>[];
    for (final e in allEvents) {
      if (hidden.contains(e.ownerUid)) continue;
      if (e.repeatWeekly) {
        repeating.add(e);
      } else {
        oneTimeByDay
            .putIfAbsent(CalendarEvent.dayOnly(e.date), () => [])
            .add(e);
      }
    }

    List<CalendarEvent> eventsForDay(DateTime day) =>
        _eventsForDay(day, oneTimeByDay, repeating);

    final selectedDayEvents = eventsForDay(_selectedDay);

    // 2주 모드는 행이 2줄뿐이라 칸을 크게 → 한 칸에 더 많은 일정 표시.
    final isTwoWeeks = _format == CalendarFormat.twoWeeks;
    final double rowHeight = _showContent
        ? (isTwoWeeks ? 140 : 82)
        : (isTwoWeeks ? 60 : 52);
    final int maxItems = isTwoWeeks ? 6 : 3;

    return Scaffold(
      appBar: AppBar(
        title: Text(group?.name ?? '우리집일정표'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '설정',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                _segToggle(
                  '2주', isTwoWeeks,
                  () => setState(() {
                    _format = CalendarFormat.twoWeeks;
                    _focusedDay = DateTime.now(); // 오늘 주가 1주차가 되도록
                  }),
                  '1달', !isTwoWeeks,
                  () => setState(() => _format = CalendarFormat.month),
                ),
                const SizedBox(width: 10),
                _segToggle(
                  '내용', _showContent,
                  () => setState(() => _showContent = true),
                  '점', !_showContent,
                  () => setState(() => _showContent = false),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const MemberFilterBar(),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            child: TableCalendar<CalendarEvent>(
              locale: 'ko_KR',
              firstDay:
                  isTwoWeeks ? _twoWeekFirstDay : DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2035, 12, 31),
              focusedDay: _focusedDay,
              rowHeight: rowHeight,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              holidayPredicate: (day) => Holidays.isHoliday(day),
              eventLoader: eventsForDay,
              startingDayOfWeek: StartingDayOfWeek.sunday,
              calendarFormat: _format,
              onFormatChanged: (f) => setState(() => _format = f),
              availableGestures: AvailableGestures.horizontalSwipe,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              calendarStyle: const CalendarStyle(
                outsideDaysVisible: false,
                todayDecoration: BoxDecoration(
                  color: Color(0x331565C0),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(color: Color(0xFF1565C0)),
                selectedDecoration: BoxDecoration(
                  color: Color(0xFF1565C0),
                  shape: BoxShape.circle,
                ),
                holidayTextStyle: TextStyle(color: Color(0xFFD32F2F)),
                holidayDecoration: BoxDecoration(),
                markersMaxCount: 4,
              ),
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                });
              },
              onPageChanged: (focused) {
                _focusedDay = focused;
                ref.read(focusedMonthProvider.notifier).setMonth(focused);
              },
              calendarBuilders: _showContent
                  ? _contentBuilders(eventsForDay, maxItems)
                  : _dotBuilders(),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _DayEventList(
              date: _selectedDay,
              events: selectedDayEvents,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EventEditScreen(initialDate: _selectedDay),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('일정 추가'),
      ),
    );
  }

  /// 두 칸짜리 글자 토글(예: [2주|1달], [내용|점]). 선택된 칸이 파랗게 채워진다.
  Widget _segToggle(
    String l1,
    bool a1,
    VoidCallback t1,
    String l2,
    bool a2,
    VoidCallback t2,
  ) {
    Widget seg(String label, bool active, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1565C0) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : Colors.black54,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [seg(l1, a1, t1), seg(l2, a2, t2)],
      ),
    );
  }

  // ---------- 점 보기 ----------
  CalendarBuilders<CalendarEvent> _dotBuilders() {
    return CalendarBuilders<CalendarEvent>(
      markerBuilder: (context, day, events) {
        if (events.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in events.take(4))
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: Color(e.colorValue),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ---------- 내용 보기 (셀 안에 제목 표시) ----------
  CalendarBuilders<CalendarEvent> _contentBuilders(
      List<CalendarEvent> Function(DateTime) loader, int maxItems) {
    return CalendarBuilders<CalendarEvent>(
      // 기본 점 마커는 끈다(셀에 직접 그리므로).
      markerBuilder: (_, _, _) => const SizedBox.shrink(),
      defaultBuilder: (ctx, day, _) => _contentCell(day, loader(day), maxItems),
      outsideBuilder: (ctx, day, _) =>
          _contentCell(day, loader(day), maxItems, isOutside: true),
      todayBuilder: (ctx, day, _) => _contentCell(day, loader(day), maxItems,
          isToday: true, isSelected: isSameDay(_selectedDay, day)),
      selectedBuilder: (ctx, day, _) => _contentCell(day, loader(day), maxItems,
          isSelected: true, isToday: isSameDay(day, DateTime.now())),
    );
  }

  Widget _contentCell(
    DateTime day,
    List<CalendarEvent> events,
    int maxItems, {
    bool isToday = false,
    bool isSelected = false,
    bool isOutside = false,
  }) {
    final bool isHoliday = Holidays.isHoliday(day);
    final Color dayColor = isOutside
        ? Colors.black26
        : (isHoliday || day.weekday == DateTime.sunday)
            ? Colors.red.shade400
            : day.weekday == DateTime.saturday
                ? Colors.blue.shade400
                : Colors.black87;

    // 셀을 가득 채우되, table_calendar가 빌더 결과를 Semantics로 감싸므로
    // Positioned(Stack 직속 필요)가 아닌 SizedBox.expand 를 사용한다.
    return SizedBox.expand(
      child: Container(
        margin: const EdgeInsets.all(1.5),
        padding: const EdgeInsets.fromLTRB(2, 2, 2, 2),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0x141565C0) : null,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isSelected ? const Color(0xFF1565C0) : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: ClipRect(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: isToday
                    ? const BoxDecoration(
                        color: Color(0xFF1565C0), shape: BoxShape.circle)
                    : null,
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isToday ? Colors.white : dayColor,
                  ),
                ),
              ),
              const SizedBox(height: 1),
              for (final e in events.take(maxItems))
                Container(
                  margin: const EdgeInsets.only(top: 1.5),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: Color(e.colorValue).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    e.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      color: Color(e.colorValue),
                    ),
                  ),
                ),
              if (events.length > maxItems)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text('+${events.length - maxItems}',
                      style:
                          const TextStyle(fontSize: 8.5, color: Colors.black45)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayEventList extends StatelessWidget {
  const _DayEventList({required this.date, required this.events});

  final DateTime date;
  final List<CalendarEvent> events;

  @override
  Widget build(BuildContext context) {
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          Text(
            '${date.month}월 ${date.day}일 (${_weekday(date)})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (Holidays.nameFor(date) != null) ...[
            const SizedBox(width: 8),
            Text(Holidays.nameFor(date)!,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFD32F2F))),
          ],
          const SizedBox(width: 8),
          if (events.isNotEmpty)
            Text('${events.length}건',
                style: const TextStyle(color: Colors.black45)),
        ],
      ),
    );

    if (events.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const Expanded(
            child: Center(
              child: Text('등록된 일정이 없습니다.',
                  style: TextStyle(color: Colors.black38)),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
            itemCount: events.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _EventTile(event: events[i]),
          ),
        ),
      ],
    );
  }

  static String _weekday(DateTime d) {
    const names = ['월', '화', '수', '목', '금', '토', '일'];
    return names[d.weekday - 1];
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});
  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 6,
          height: 44,
          decoration: BoxDecoration(
            color: Color(event.colorValue),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(event.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            if (event.repeatWeekly) ...[
              const SizedBox(width: 6),
              const Icon(Icons.repeat, size: 14, color: Colors.black38),
            ],
          ],
        ),
        subtitle: Text('${event.periodLabel} · ${event.ownerName}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
        ),
      ),
    );
  }
}

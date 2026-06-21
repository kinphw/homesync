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

  /// 표시 범위. 기본은 월(가독성). 2주 모드는 토글로 전환.
  CalendarFormat _format = CalendarFormat.month;

  /// 일정 목록 시트 제어용. 달 높이(주 수)나 2주·월 전환으로 캘린더 높이가 바뀌면
  /// 시트를 캘린더 바로 아래 위치로 부드럽게 이동시킨다.
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  double? _lastRestFrac;

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  /// 2주 모드의 firstDay. table_calendar는 2주 페이지를 firstDay+14*n 으로 나누므로,
  /// '이번 주 일요일'에서 짝수 주(10년)만큼 앞으로 당기면 오늘 주가 항상 1주차(맨 윗줄)에
  /// 오면서도 과거로 이동할 수 있다. (이전엔 이번 주 일요일을 firstDay로 둬서 과거가 막혔음)
  DateTime get _twoWeekFirstDay {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day);
    final sunday = base.subtract(Duration(days: base.weekday % 7)); // 이번 주 일요일
    return sunday.subtract(const Duration(days: 7 * 520)); // 10년 전(짝수 주)
  }

  /// 해당 월이 달력에서 차지하는 주(행) 수. (일요일 시작 기준, 4~6)
  int _rowsInMonth(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final leading = first.weekday % 7; // 일요일=0 … 토요일=6
    final days = DateTime(month.year, month.month + 1, 0).day; // 그 달 일수
    return ((leading + days) / 7).ceil();
  }

  /// 하루치 일정 = 그 날의 단발 일정 + 매주 반복 일정(요일/앵커 조건 충족분).
  List<CalendarEvent> _eventsForDay(
    DateTime day,
    Map<DateTime, List<CalendarEvent>> oneTimeByDay,
    List<CalendarEvent> repeating,
    List<CalendarEvent> ranged,
  ) {
    final d = CalendarEvent.dayOnly(day);
    final list = <CalendarEvent>[...(oneTimeByDay[d] ?? const [])];
    for (final e in repeating) {
      if (e.date.weekday == day.weekday &&
          !d.isBefore(CalendarEvent.dayOnly(e.date))) {
        list.add(e);
      }
    }
    // 기간 일정: 시작일~종료일 사이의 모든 날에 표시.
    for (final e in ranged) {
      final start = CalendarEvent.dayOnly(e.date);
      final end = CalendarEvent.dayOnly(e.endDate!);
      if (!d.isBefore(start) && !d.isAfter(end)) list.add(e);
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
    final ranged = <CalendarEvent>[];
    for (final e in allEvents) {
      if (hidden.contains(e.ownerUid)) continue;
      if (e.repeatWeekly) {
        repeating.add(e);
      } else if (e.isRange) {
        ranged.add(e);
      } else {
        oneTimeByDay
            .putIfAbsent(CalendarEvent.dayOnly(e.date), () => [])
            .add(e);
      }
    }

    List<CalendarEvent> eventsForDay(DateTime day) =>
        _eventsForDay(day, oneTimeByDay, repeating, ranged);

    final selectedDayEvents = eventsForDay(_selectedDay);

    // 2주 모드는 행이 2줄뿐이라 칸을 크게 → 한 칸에 더 많은 일정 표시.
    final isTwoWeeks = _format == CalendarFormat.twoWeeks;
    final double rowHeight = isTwoWeeks ? 140 : 68;
    final int maxItems = isTwoWeeks ? 6 : 2;

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
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const MemberFilterBar(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 캘린더가 차지하는 대략 높이(헤더+요일행+행들+여백)를 계산해,
                // 일정 목록 시트가 처음엔 캘린더 바로 아래에 놓이게 한다.
                // 달마다 실제 주 수에 맞춰 높이를 잡아 빈 줄이 안 생기게 한다.
                final rows = isTwoWeeks ? 2 : _rowsInMonth(_focusedDay);
                // 헤더+요일행+행들+여백. 시트가 캘린더 마지막 줄(선택된 날의 파란 박스
                // 하단)을 가리지 않도록 약간 넉넉히 잡는다.
                final calHeight = 58 + 18 + rows * rowHeight + 18;
                final avail = constraints.maxHeight;
                // 6주짜리 달에선 캘린더가 길어 남는 공간이 작다. 최소치를 낮게 둬서
                // 시트가 캘린더(6주차 포함) 아래에 놓이게 한다(필요하면 위로 드래그).
                final restFrac =
                    ((avail - calHeight) / avail).clamp(0.10, 0.85).toDouble();
                // 캘린더 높이(주 수/2주·월)가 바뀌면 시트를 캘린더 바로 아래로 이동.
                if (_lastRestFrac != restFrac) {
                  _lastRestFrac = restFrac;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_sheetController.isAttached) {
                      _sheetController.animateTo(
                        restFrac,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                }
                return Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        child: TableCalendar<CalendarEvent>(
                          locale: 'ko_KR',
                          firstDay: isTwoWeeks
                              ? _twoWeekFirstDay
                              : DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2035, 12, 31),
                          focusedDay: _focusedDay,
                          rowHeight: rowHeight,
                          selectedDayPredicate: (day) =>
                              isSameDay(_selectedDay, day),
                          holidayPredicate: (day) => Holidays.isHoliday(day),
                          eventLoader: eventsForDay,
                          startingDayOfWeek: StartingDayOfWeek.sunday,
                          calendarFormat: _format,
                          onFormatChanged: (f) =>
                              setState(() => _format = f),
                          availableGestures:
                              AvailableGestures.horizontalSwipe,
                          headerStyle: const HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                            titleTextStyle: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          calendarStyle: const CalendarStyle(
                            outsideDaysVisible: false,
                            todayDecoration: BoxDecoration(
                              color: Color(0x331565C0),
                              shape: BoxShape.circle,
                            ),
                            todayTextStyle:
                                TextStyle(color: Color(0xFF1565C0)),
                            selectedDecoration: BoxDecoration(
                              color: Color(0xFF1565C0),
                              shape: BoxShape.circle,
                            ),
                            holidayTextStyle:
                                TextStyle(color: Color(0xFFD32F2F)),
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
                            // setState로 다시 그려야 새 달의 주 수에 맞춰 시트가 이동한다.
                            setState(() => _focusedDay = focused);
                            ref
                                .read(focusedMonthProvider.notifier)
                                .setMonth(focused);
                          },
                          calendarBuilders:
                              _contentBuilders(eventsForDay, maxItems),
                        ),
                      ),
                    ),
                    // 일정 목록: 위로 드래그하면 크게 펼쳐진다.
                    // 주 수(달 높이)가 바뀌면 시트를 다시 만들어 캘린더 아래에 맞춘다.
                    DraggableScrollableSheet(
                      controller: _sheetController,
                      initialChildSize: restFrac,
                      minChildSize: 0.12,
                      maxChildSize: 0.92,
                      builder: (context, scrollController) => _DayEventList(
                        date: _selectedDay,
                        events: selectedDayEvents,
                        scrollController: scrollController,
                      ),
                    ),
                  ],
                );
              },
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

  // ---------- 달력 칸 내용 그리기 ----------
  CalendarBuilders<CalendarEvent> _contentBuilders(
      List<CalendarEvent> Function(DateTime) loader, int maxItems) {
    return CalendarBuilders<CalendarEvent>(
      // 기본 점 마커는 끈다(셀에 직접 그리므로).
      markerBuilder: (_, _, _) => const SizedBox.shrink(),
      defaultBuilder: (ctx, day, _) => _contentCell(day, loader(day), maxItems),
      // 공휴일도 동일한 셀로 그려 숫자 위치를 다른 날과 맞춘다(기본 셀은 숫자가
      // 가운데라 어긋났음). 색상은 _contentCell이 공휴일을 빨갛게 처리한다.
      holidayBuilder: (ctx, day, _) => _contentCell(day, loader(day), maxItems),
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

    // 기간 일정(띠)과 단일 일정(글자)을 분리. 띠는 시작일 기준 정렬로
    // 날짜가 바뀌어도 같은 줄에 쌓이도록 안정화한다.
    final bars = events.where((e) => e.isRange).toList()
      ..sort((a, b) {
        final c = a.date.compareTo(b.date);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    final points = events.where((e) => !e.isRange).toList();
    final shownBars = bars.take(maxItems).toList();
    final pointBudget = maxItems - shownBars.length;
    final shownPoints = pointBudget > 0
        ? points.take(pointBudget).toList()
        : const <CalendarEvent>[];
    final hidden =
        (bars.length - shownBars.length) + (points.length - shownPoints.length);

    // 가로 여백을 0으로 둬서 기간 일정 띠가 인접 칸과 붙어 이어지게 한다.
    return SizedBox.expand(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1.5),
        color: isSelected ? const Color(0x141565C0) : null,
        child: ClipRect(
          // 세로는 칸 안으로 자르되 가로로는 살짝 넘치도록 허용(띠 이음새 덮기용).
          clipper: const _CellBleedClipper(),
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
              // 기간 일정: 칸 너비를 꽉 채운 띠(이어져 보임).
              for (final e in shownBars) _rangeBar(e, day),
              // 단일 일정: 제목 칩.
              for (final e in shownPoints)
                Container(
                  margin: const EdgeInsets.fromLTRB(3, 1.5, 3, 0),
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
              if (hidden > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(3, 1, 0, 0),
                  child: Text('+$hidden',
                      style: const TextStyle(
                          fontSize: 8.5, color: Colors.black45)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 기간 일정 한 줄(띠). 칸 너비를 꽉 채우고, 시작/끝·주 경계에서만 모서리를
  /// 둥글려 인접 칸과 이어져 보이게 한다. 제목은 시작일 또는 매 주의 첫 칸에만.
  Widget _rangeBar(CalendarEvent e, DateTime day) {
    final isStart = isSameDay(day, e.date);
    final isEnd = isSameDay(day, e.endDate);
    final isWeekStart = day.weekday == DateTime.sunday;
    final isWeekEnd = day.weekday == DateTime.saturday;
    final left =
        (isStart || isWeekStart) ? const Radius.circular(4) : Radius.zero;
    final right = (isEnd || isWeekEnd) ? const Radius.circular(4) : Radius.zero;
    final showLabel = isStart || isWeekStart;
    final color = Color(e.colorValue);
    final bar = Container(
      height: 14,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        // 불투명(solid)으로 둬야 겹친 부분이 두 겹으로 진해지지 않는다.
        color: color,
        borderRadius: BorderRadius.horizontal(left: left, right: right),
      ),
      child: showLabel
          ? Text(
              e.title,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: const TextStyle(
                fontSize: 9.5,
                height: 1.1,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            )
          : const SizedBox.shrink(),
    );
    // 끝 칸(또는 토요일)이 아니면 오른쪽으로 살짝 늘려 다음 칸과 겹쳐 이음새를 덮는다.
    final bleed = !(isEnd || isWeekEnd);
    return Padding(
      padding: const EdgeInsets.only(top: 1.5),
      child: bleed
          ? Transform.scale(
              scaleX: 1.05,
              alignment: Alignment.centerLeft,
              child: bar,
            )
          : bar,
    );
  }
}

class _DayEventList extends StatelessWidget {
  const _DayEventList({
    required this.date,
    required this.events,
    this.scrollController,
  });

  final DateTime date;
  final List<CalendarEvent> events;

  /// DraggableScrollableSheet가 넘겨주는 컨트롤러. 시트 전체를 끌어 펼칠 수 있게 한다.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final handle = Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.fromLTRB(0, 8, 0, 6),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: 8,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          handle,
          header,
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text('등록된 일정이 없습니다.',
                    style: TextStyle(color: Colors.black38)),
              ),
            )
          else
            for (final e in events)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: _EventTile(event: e),
              ),
        ],
      ),
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
            if (event.isRange) ...[
              const SizedBox(width: 6),
              const Icon(Icons.date_range, size: 14, color: Colors.black38),
            ],
          ],
        ),
        subtitle: Text(event.isRange
            ? '${event.date.month}/${event.date.day}~'
                '${event.endDate!.month}/${event.endDate!.day} · ${event.ownerName}'
            : '${event.periodLabel} · ${event.ownerName}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
        ),
      ),
    );
  }
}

/// 셀 내용을 세로로는 칸 안으로 자르되, 가로로는 약간(±3px) 넘치도록 허용한다.
/// 기간 일정 띠가 인접 칸과 겹쳐 이음새(미세한 흰 선)가 보이지 않게 하는 용도.
class _CellBleedClipper extends CustomClipper<Rect> {
  const _CellBleedClipper();

  @override
  Rect getClip(Size size) => Rect.fromLTRB(-3, 0, size.width + 3, size.height);

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}

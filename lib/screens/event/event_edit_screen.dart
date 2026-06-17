import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/calendar_event.dart';
import '../../providers.dart';

/// 일정 추가/수정 화면. existing 이 있으면 수정 모드.
class EventEditScreen extends ConsumerStatefulWidget {
  const EventEditScreen({super.key, this.initialDate, this.existing});

  final DateTime? initialDate;
  final CalendarEvent? existing;

  @override
  ConsumerState<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends ConsumerState<EventEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _memo;
  late DateTime _date;
  late EventPeriod _period;
  late bool _repeatWeekly;
  bool _loading = false;

  bool get _isEdit => widget.existing != null;

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _memo = TextEditingController(text: e?.memo ?? '');
    _date = e?.date ?? widget.initialDate ?? DateTime.now();
    _period = e?.period ?? EventPeriod.allDay;
    _repeatWeekly = e?.repeatWeekly ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
      locale: const Locale('ko', 'KR'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider).value;
    final group = ref.read(currentGroupProvider).value;
    if (user == null || group == null) return;

    setState(() => _loading = true);
    try {
      final service = ref.read(firestoreServiceProvider);
      if (_isEdit) {
        final updated = widget.existing!.copyWith(
          title: _title.text.trim(),
          date: _date,
          period: _period,
          repeatWeekly: _repeatWeekly,
          memo: _memo.text.trim(),
        );
        await service.updateEvent(group.id, updated);
      } else {
        final event = CalendarEvent(
          id: '',
          title: _title.text.trim(),
          date: _date,
          period: _period,
          repeatWeekly: _repeatWeekly,
          ownerUid: user.uid,
          ownerName: user.name,
          colorValue: user.colorValue,
          memo: _memo.text.trim(),
        );
        await service.addEvent(group.id, event);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('저장에 실패했습니다.')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? '일정 수정' : '일정 추가')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: '제목',
                    hintText: '예: 치과 3시, 가족 모임',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '제목을 입력하세요' : null,
                ),
                const SizedBox(height: 20),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.event),
                    title: const Text('날짜'),
                    trailing: Text(
                      '${_date.year}.${_date.month}.${_date.day}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('시간대',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                SegmentedButton<EventPeriod>(
                  segments: const [
                    ButtonSegment(
                        value: EventPeriod.allDay, label: Text('종일')),
                    ButtonSegment(
                        value: EventPeriod.morning, label: Text('오전')),
                    ButtonSegment(
                        value: EventPeriod.afternoon, label: Text('오후')),
                    ButtonSegment(
                        value: EventPeriod.evening, label: Text('저녁')),
                  ],
                  selected: {_period},
                  onSelectionChanged: (s) => setState(() => _period = s.first),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(
                    '정확한 시각이 필요하면 제목에 적어주세요 (예: "치과 3시")',
                    style: TextStyle(color: Colors.black45, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: SwitchListTile(
                    secondary: const Icon(Icons.repeat),
                    title: const Text('매주 반복'),
                    subtitle: Text('매주 ${_weekdays[_date.weekday - 1]}요일에 표시돼요'),
                    value: _repeatWeekly,
                    onChanged: (v) => setState(() => _repeatWeekly = v),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _memo,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '메모 (선택)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isEdit ? '수정 완료' : '저장'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

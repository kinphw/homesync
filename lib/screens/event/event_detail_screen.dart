import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/calendar_event.dart';
import '../../providers.dart';
import 'event_edit_screen.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.event});
  final CalendarEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).value;
    final isOwner = me != null && me.uid == event.ownerUid;
    final group = ref.watch(currentGroupProvider).value;

    Future<void> delete() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('일정 삭제'),
          content: const Text('이 일정을 삭제할까요?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('삭제', style: TextStyle(color: Colors.red))),
          ],
        ),
      );
      if (ok == true && group != null) {
        await ref.read(firestoreServiceProvider).deleteEvent(group.id, event.id);
        if (context.mounted) Navigator.of(context).pop();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('일정 상세'),
        actions: [
          if (isOwner) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: '수정',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => EventEditScreen(existing: event)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '삭제',
              onPressed: delete,
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Color(event.colorValue),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  event.title,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (event.isRange) ...[
            _InfoRow(
              icon: Icons.date_range,
              label: '기간',
              value:
                  '${event.date.year}년 ${event.date.month}월 ${event.date.day}일\n'
                  '~ ${event.endDate!.year}년 ${event.endDate!.month}월 ${event.endDate!.day}일',
            ),
          ] else ...[
            _InfoRow(
              icon: Icons.event,
              label: event.repeatWeekly ? '시작일' : '날짜',
              value:
                  '${event.date.year}년 ${event.date.month}월 ${event.date.day}일',
            ),
            if (event.repeatWeekly)
              _InfoRow(
                icon: Icons.repeat,
                label: '반복',
                value: '매주 ${event.weekdayKorean}요일',
              ),
            _InfoRow(
              icon: Icons.access_time,
              label: '시간대',
              value: event.periodLabel,
            ),
          ],
          _InfoRow(
            icon: Icons.person_outline,
            label: '등록자',
            value: event.ownerName,
          ),
          if (event.memo.trim().isNotEmpty)
            _InfoRow(icon: Icons.notes, label: '메모', value: event.memo),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.black45),
          const SizedBox(width: 12),
          SizedBox(
            width: 56,
            child: Text(label, style: const TextStyle(color: Colors.black45)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

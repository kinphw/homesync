import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// 캘린더 상단의 회원 필터 바. (아웃룩 공유/개인 일정처럼 개별 on/off 토글)
///
/// - 각 회원 칩: 누르면 그 회원 일정이 보였다/안 보였다 토글.
/// - "전체" 칩: 전원 켜기/끄기 토글.
class MemberFilterBar extends ConsumerWidget {
  const MemberFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(groupMembersProvider).value ?? const [];
    final hidden = ref.watch(hiddenMembersProvider);

    // 현재 회원들 기준으로 한 명이라도 숨겨져 있는지.
    final anyHidden = members.any((m) => hidden.contains(m.uid));
    final allVisible = !anyHidden;

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _FilterChip(
            label: '전체',
            color: const Color(0xFF607D8B),
            on: allVisible,
            onTap: () {
              final notifier = ref.read(hiddenMembersProvider.notifier);
              if (allVisible) {
                notifier.hideAll(members.map((m) => m.uid));
              } else {
                notifier.showAll();
              }
            },
          ),
          const SizedBox(width: 8),
          for (final m in members) ...[
            _FilterChip(
              label: m.name,
              color: Color(m.colorValue),
              on: !hidden.contains(m.uid),
              onTap: () =>
                  ref.read(hiddenMembersProvider.notifier).toggle(m.uid),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.color,
    required this.on,
    required this.onTap,
  });

  final String label;
  final Color color;

  /// true = 표시(켜짐), false = 숨김(꺼짐).
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: on ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: on ? color : const Color(0xFFCFD8DC),
            width: 1.4,
          ),
        ),
        child: Row(
          children: [
            Icon(
              on ? Icons.check : Icons.remove,
              size: 15,
              color: on ? Colors.white : Colors.black26,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: on ? Colors.white : Colors.black38,
                fontWeight: FontWeight.w600,
                decoration: on ? null : TextDecoration.lineThrough,
                decorationColor: Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

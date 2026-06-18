import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/app_user.dart';
import '../models/family_group.dart';
import '../providers.dart';
import 'admin_providers.dart';
import 'admin_service.dart';

/// 운영자 관제 대시보드. 회원·그룹 현황과 요약 수치를 보여준다.
class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);
    final usersAsync = ref.watch(allUsersProvider);
    final groupsAsync = ref.watch(allGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('우리집일정표 관제'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(adminStatsProvider),
          ),
          IconButton(
            tooltip: '로그아웃',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── 요약 카드 ────────────────────────────
              stats.when(
                loading: () => const _StatRow(loading: true),
                error: (e, _) =>
                    _ErrorCard(message: '집계를 불러오지 못했습니다.\n$e'),
                data: (s) => _StatRow(stats: s),
              ),
              const SizedBox(height: 24),

              // ── 그룹 현황 ────────────────────────────
              _SectionHeader(
                icon: Icons.home_outlined,
                title: '그룹 현황',
                count: groupsAsync.value?.length,
              ),
              groupsAsync.when(
                loading: () => const _LoadingTile(),
                error: (e, _) =>
                    _ErrorCard(message: '그룹을 불러오지 못했습니다.\n$e'),
                data: (groups) {
                  if (groups.isEmpty) {
                    return const _EmptyTile('아직 그룹이 없습니다.');
                  }
                  final usersById = {
                    for (final u in (usersAsync.value ?? const <AppUser>[]))
                      u.uid: u,
                  };
                  return Column(
                    children: [
                      for (final g in groups)
                        _GroupCard(group: g, usersById: usersById),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // ── 회원 현황 ────────────────────────────
              _SectionHeader(
                icon: Icons.people_outline,
                title: '회원 현황',
                count: usersAsync.value?.length,
              ),
              usersAsync.when(
                loading: () => const _LoadingTile(),
                error: (e, _) =>
                    _ErrorCard(message: '회원을 불러오지 못했습니다.\n$e'),
                data: (users) {
                  if (users.isEmpty) {
                    return const _EmptyTile('아직 회원이 없습니다.');
                  }
                  return Column(
                    children: [for (final u in users) _UserTile(user: u)],
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────── 요약 카드 ────────────────────────────

class _StatRow extends StatelessWidget {
  const _StatRow({this.stats, this.loading = false});
  final AdminStats? stats;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: '회원',
            value: stats?.userCount,
            icon: Icons.person_outline,
            isLoading: loading,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: '그룹',
            value: stats?.groupCount,
            icon: Icons.home_outlined,
            isLoading: loading,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: '일정',
            value: stats?.eventCount,
            icon: Icons.event_outlined,
            isLoading: loading,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.isLoading = false,
  });
  final String label;
  final int? value;
  final IconData icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final Widget number;
    if (isLoading) {
      number = const SizedBox(
        height: 28,
        width: 28,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (value == null) {
      // 집계 실패(권한 거부 등) → 회색 대시
      number = const Text('—',
          style: TextStyle(
              fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black26));
    } else {
      number = Text('$value',
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF1565C0)),
            const SizedBox(height: 8),
            number,
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────── 그룹 카드 ────────────────────────────

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.usersById});
  final FamilyGroup group;
  final Map<String, AppUser> usersById;

  @override
  Widget build(BuildContext context) {
    final owner = usersById[group.ownerUid];
    final memberNames = group.memberUids
        .map((uid) => usersById[uid]?.name ?? '(탈퇴/미상 $uid)')
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    group.name.isEmpty ? '(이름 없음)' : group.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                _CountBadge('${group.memberUids.length}명'),
              ],
            ),
            const SizedBox(height: 6),
            _Kv('방장', owner?.name ?? group.ownerUid),
            _Kv('초대코드', group.inviteCode),
            _Kv('구성원', memberNames.isEmpty ? '-' : memberNames.join(', ')),
            if (group.createdAt != null) _Kv('생성', _fmt(group.createdAt!)),
            _Kv('그룹 ID', group.id),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────── 회원 타일 ────────────────────────────

class _UserTile extends ConsumerWidget {
  const _UserTile({required this.user});
  final AppUser user;

  /// 다이얼로그·토스트에 쓸 회원 표시 이름.
  String get _label => user.name.isEmpty ? user.loginId : user.name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMe = ref.watch(authStateProvider).value?.uid == user.uid;

    final sub = StringBuffer(user.loginId);
    if (!user.isEmailAccount) sub.write(' · 아이디가입');
    if (user.createdAt != null) sub.write(' · 가입 ${_fmt(user.createdAt!)}');

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: user.banned ? Colors.grey : Color(user.colorValue),
          child: Text(
            user.name.isNotEmpty ? user.name.characters.first : '?',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Row(
          children: [
            Flexible(child: Text(user.name.isEmpty ? '(이름 없음)' : user.name)),
            if (user.banned) ...[
              const SizedBox(width: 6),
              const _StatusBadge('차단됨',
                  bg: Color(0xFFFFEBEE), fg: Color(0xFFC62828)),
            ],
            if (user.groupId == null) ...[
              const SizedBox(width: 6),
              const _StatusBadge('그룹없음',
                  bg: Color(0xFFEEEEEE), fg: Colors.black54),
            ],
          ],
        ),
        subtitle: Text(sub.toString()),
        trailing: isMe
            ? const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Text('나', style: TextStyle(color: Colors.black38)),
              )
            : PopupMenuButton<String>(
                tooltip: '회원 관리',
                onSelected: (v) => _onAction(context, ref, v),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'ban',
                    child: Text(user.banned ? '로그인 차단 해제' : '로그인 차단'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child:
                        Text('회원 삭제', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _onAction(
      BuildContext context, WidgetRef ref, String action) async {
    final service = ref.read(adminServiceProvider);

    if (action == 'ban') {
      final ban = !user.banned;
      final ok = await _confirm(
        context,
        title: ban ? '로그인 차단' : '차단 해제',
        body: ban
            ? '"$_label" 회원의 로그인을 차단합니다.\n일반 앱에서 로그인하면 차단 안내 후 내보내집니다. 진행할까요?'
            : '"$_label" 회원의 차단을 해제합니다.\n다시 로그인할 수 있게 됩니다. 진행할까요?',
        confirmText: ban ? '차단' : '해제',
        danger: ban,
      );
      if (ok != true) return;
      try {
        await service.setUserBanned(user.uid, ban);
        if (context.mounted) {
          _toast(context, ban ? '차단했습니다.' : '차단을 해제했습니다.');
        }
      } catch (_) {
        if (context.mounted) _toast(context, '처리에 실패했습니다.');
      }
    } else if (action == 'delete') {
      final ok = await _confirm(
        context,
        title: '회원 삭제',
        body: '"$_label" 회원의 가입내역을 삭제하고 소속 그룹에서 제거합니다.\n'
            '되돌릴 수 없어요. 삭제할까요?\n\n'
            '(로그인 계정 자체는 서버가 없어 완전 삭제되지 않습니다.)',
        confirmText: '삭제',
        danger: true,
      );
      if (ok != true) return;
      try {
        await service.deleteUserAccount(user.uid, user.groupId);
        if (context.mounted) _toast(context, '삭제했습니다.');
      } catch (_) {
        if (context.mounted) _toast(context, '처리에 실패했습니다.');
      }
    }
  }
}

// ──────────────────────────── 공통 위젯/유틸 ────────────────────────────

/// 회원 상태(차단됨·그룹없음)를 나타내는 작은 색 배지.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.text, {required this.bg, required this.fg});
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

/// 위험 작업 확인 다이얼로그. 확인 시 true.
Future<bool?> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmText,
  bool danger = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmText,
              style: TextStyle(color: danger ? Colors.red : null)),
        ),
      ],
    ),
  );
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}

/// 그룹 카드의 인원수 같은 작은 숫자 배지. (Chip 의 라벨 잘림을 피하려고 직접 만든다)
class _CountBadge extends StatelessWidget {
  const _CountBadge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1565C0),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title, this.count});
  final IconData icon;
  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.black54),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          if (count != null) ...[
            const SizedBox(width: 6),
            Text('($count)', style: const TextStyle(color: Colors.black54)),
          ],
        ],
      ),
    );
  }
}

class _Kv extends StatelessWidget {
  const _Kv(this.k, this.v);
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(k,
                style: const TextStyle(color: Colors.black54, fontSize: 13)),
          ),
          Expanded(
            child: SelectableText(v, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _LoadingTile extends StatelessWidget {
  const _LoadingTile();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
}

class _EmptyTile extends StatelessWidget {
  const _EmptyTile(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text, style: const TextStyle(color: Colors.black54)),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(message, style: TextStyle(color: Colors.red.shade700)),
        ),
      );
}

String _fmt(DateTime d) => DateFormat('yyyy.MM.dd HH:mm', 'ko_KR').format(d);

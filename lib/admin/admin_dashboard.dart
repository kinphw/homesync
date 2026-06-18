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
            value: loading ? null : stats?.userCount,
            icon: Icons.person_outline,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: '그룹',
            value: loading ? null : stats?.groupCount,
            icon: Icons.home_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: '일정',
            value: loading ? null : stats?.eventCount,
            icon: Icons.event_outlined,
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
  });
  final String label;
  final int? value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF1565C0)),
            const SizedBox(height: 8),
            value == null
                ? const SizedBox(
                    height: 28,
                    width: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('$value',
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold)),
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
                Chip(
                  label: Text('${group.memberUids.length}명'),
                  visualDensity: VisualDensity.compact,
                ),
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

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final sub = StringBuffer(user.loginId);
    if (!user.isEmailAccount) sub.write(' · 아이디가입');
    if (user.createdAt != null) sub.write(' · 가입 ${_fmt(user.createdAt!)}');

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(user.colorValue),
          child: Text(
            user.name.isNotEmpty ? user.name.characters.first : '?',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(user.name.isEmpty ? '(이름 없음)' : user.name),
        subtitle: Text(sub.toString()),
        trailing: user.groupId == null
            ? const Chip(
                label: Text('그룹없음', style: TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
              )
            : null,
      ),
    );
  }
}

// ──────────────────────────── 공통 위젯/유틸 ────────────────────────────

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

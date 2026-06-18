import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import 'profile_edit_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).value;
    final group = ref.watch(currentGroupProvider).value;
    final members = ref.watch(groupMembersProvider).value ?? const [];
    final isOwner = me != null && group != null && group.ownerUid == me.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          // 내 프로필
          const _SectionTitle('내 정보'),
          ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  me != null ? Color(me.colorValue) : Colors.grey,
              child: Text(
                me != null && me.name.isNotEmpty ? me.name.characters.first : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(me?.name ?? '-'),
            subtitle: Text(me != null
                ? '${me.loginId}${me.isEmailAccount ? '' : '  ·  비밀번호 찾기 불가(아이디 가입)'}'
                : ''),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
            ),
          ),
          const Divider(),

          // 알림
          const _SectionTitle('알림'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('일정 알림 받기'),
            subtitle: const Text('당일 아침 8시 요약 · 시간대 1시간 전'),
            value: ref.watch(notificationsEnabledProvider),
            onChanged: (v) =>
                ref.read(notificationsEnabledProvider.notifier).setEnabled(v),
          ),
          const Divider(),

          // 그룹 정보 + 초대 코드
          const _SectionTitle('가족 그룹'),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('그룹 이름'),
            trailing: Text(group?.name ?? '-',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(Icons.vpn_key_outlined),
            title: const Text('초대 코드'),
            subtitle: const Text('가족에게 알려주면 같은 그룹에 참여할 수 있어요'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SelectableText(
                  group?.inviteCode ?? '-',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: '복사',
                  onPressed: group == null
                      ? null
                      : () {
                          Clipboard.setData(
                              ClipboardData(text: group.inviteCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('초대 코드를 복사했어요')),
                          );
                        },
                ),
              ],
            ),
          ),
          const Divider(),

          // 구성원 목록
          _SectionTitle('구성원 (${members.length}명)'),
          for (final m in members)
            ListTile(
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: Color(m.colorValue),
                child: Text(
                  m.name.isNotEmpty ? m.name.characters.first : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              title: Text(m.name),
              subtitle: Text(m.loginId),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (m.uid == group?.ownerUid)
                    const Chip(
                      label: Text('방장', style: TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (isOwner && m.uid != me.uid)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20),
                      onSelected: (v) async {
                        final service = ref.read(firestoreServiceProvider);
                        final action = v == 'transfer' ? '방장 위임' : '내보내기';
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (dctx) => AlertDialog(
                            title: Text(action),
                            content: Text(v == 'transfer'
                                ? '${m.name} 님에게 방장을 넘길까요?'
                                : '${m.name} 님을 그룹에서 내보낼까요?'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(dctx, false),
                                  child: const Text('취소')),
                              TextButton(
                                  onPressed: () => Navigator.pop(dctx, true),
                                  child: Text(action,
                                      style:
                                          const TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (ok != true) return;
                        if (v == 'transfer') {
                          await service.transferOwnership(
                              groupId: group.id, newOwnerUid: m.uid);
                        } else {
                          await service.kickMember(
                              groupId: group.id, uid: m.uid);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'transfer', child: Text('방장 위임')),
                        PopupMenuItem(
                            value: 'kick',
                            child: Text('내보내기',
                                style: TextStyle(color: Colors.red))),
                      ],
                    ),
                ],
              ),
            ),
          const Divider(),

          // 그룹 나가기 / 삭제
          if (me != null && group != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: () async {
                  final title = isOwner ? '그룹 삭제' : '그룹 나가기';
                  final body = isOwner
                      ? '그룹과 모든 일정이 삭제됩니다. 되돌릴 수 없어요. 삭제할까요?'
                      : '이 그룹에서 나갑니다. 다시 들어오려면 초대 코드가 필요해요. 나갈까요?';
                  final ok = await showDialog<bool>(
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
                            child: Text(title,
                                style: const TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  final service = ref.read(firestoreServiceProvider);
                  try {
                    if (isOwner) {
                      await service.deleteGroup(
                          groupId: group.id, ownerUid: me.uid);
                    } else {
                      await service.leaveGroup(groupId: group.id, uid: me.uid);
                    }
                    if (context.mounted) Navigator.of(context).pop();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('처리에 실패했습니다.')));
                    }
                  }
                },
                icon: Icon(isOwner ? Icons.delete_forever : Icons.exit_to_app),
                label: Text(isOwner ? '그룹 삭제 (방장)' : '그룹 나가기'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade700),
                ),
              ),
            ),
          ],
          const Divider(height: 32),

          // 로그아웃
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authServiceProvider).signOut();
                if (context.mounted) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.logout),
              label: const Text('로그아웃'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: const TextStyle(
            fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 13),
      ),
    );
  }
}

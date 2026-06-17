import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).value;
    final group = ref.watch(currentGroupProvider).value;
    final members = ref.watch(groupMembersProvider).value ?? const [];

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
              trailing: m.uid == group?.ownerUid
                  ? const Chip(
                      label: Text('방장', style: TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    )
                  : null,
            ),
          const Divider(),

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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';

/// 로그인했지만 아직 그룹이 없을 때 보여주는 화면.
/// 새 가족 그룹을 만들거나, 초대 코드로 기존 그룹에 참여한다.
class GroupSetupScreen extends ConsumerWidget {
  const GroupSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('가족 그룹 설정'),
          actions: [
            IconButton(
              tooltip: '로그아웃',
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(authServiceProvider).signOut(),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '그룹 만들기'),
              Tab(text: '그룹 참여하기'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _CreateGroupTab(ownerUid: user?.uid),
            _JoinGroupTab(uid: user?.uid),
          ],
        ),
      ),
    );
  }
}

class _CreateGroupTab extends ConsumerStatefulWidget {
  const _CreateGroupTab({required this.ownerUid});
  final String? ownerUid;

  @override
  ConsumerState<_CreateGroupTab> createState() => _CreateGroupTabState();
}

class _CreateGroupTabState extends ConsumerState<_CreateGroupTab> {
  final _name = TextEditingController(text: '우리집');
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final uid = widget.ownerUid;
    if (uid == null || _name.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await ref.read(firestoreServiceProvider).createGroup(
            name: _name.text,
            ownerUid: uid,
          );
      // 그룹 생성 후 user.groupId가 갱신되면 AuthGate가 캘린더로 전환.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('그룹 생성에 실패했습니다.')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const Text('새 가족 그룹을 만들어 보세요.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('만든 뒤 생성되는 초대 코드를 가족에게 알려주면 함께 사용할 수 있어요.',
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 24),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: '그룹 이름',
              hintText: '예: 우리집, 박씨네',
              prefixIcon: Icon(Icons.home_outlined),
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _loading ? null : _create,
            child: _loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('그룹 만들기'),
          ),
        ],
      ),
    );
  }
}

class _JoinGroupTab extends ConsumerStatefulWidget {
  const _JoinGroupTab({required this.uid});
  final String? uid;

  @override
  ConsumerState<_JoinGroupTab> createState() => _JoinGroupTabState();
}

class _JoinGroupTabState extends ConsumerState<_JoinGroupTab> {
  final _code = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final uid = widget.uid;
    final code = _code.text.trim().toUpperCase();
    if (uid == null || code.isEmpty) return;
    setState(() => _loading = true);
    try {
      final service = ref.read(firestoreServiceProvider);
      final group = await service.findGroupByInviteCode(code);
      if (group == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('해당 초대 코드의 그룹을 찾을 수 없습니다.')));
        }
        return;
      }
      await service.joinGroup(groupId: group.id, uid: uid);
      // 참여 후 AuthGate가 캘린더로 전환.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('그룹 참여에 실패했습니다.')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const Text('가족에게 받은 초대 코드를 입력하세요.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: '초대 코드 (6자리)',
              hintText: '예: AB3C9D',
              prefixIcon: Icon(Icons.vpn_key_outlined),
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _loading ? null : _join,
            child: _loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('참여하기'),
          ),
        ],
      ),
    );
  }
}

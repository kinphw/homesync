import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../theme/member_colors.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _name = TextEditingController();
  int _colorValue = MemberColors.palette.first;
  bool _loading = false;
  bool _initialized = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _save() async {
    final me = ref.read(currentUserProvider).value;
    if (me == null) return;
    if (_name.text.trim().isEmpty) {
      _snack('이름을 입력하세요');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(firestoreServiceProvider).updateProfile(
            uid: me.uid,
            name: _name.text,
            colorValue: _colorValue,
            groupId: me.groupId,
          );
      _snack('저장했어요');
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _snack('저장에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changePassword() async {
    final cur = TextEditingController();
    final next = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('비밀번호 변경'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: cur,
              obscureText: true,
              decoration: const InputDecoration(labelText: '현재 비밀번호'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: next,
              obscureText: true,
              decoration: const InputDecoration(labelText: '새 비밀번호 (6자 이상)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('변경')),
        ],
      ),
    );
    if (ok == true) {
      if (next.text.length < 6) {
        _snack('새 비밀번호는 6자 이상이어야 합니다.');
      } else {
        try {
          await ref.read(authServiceProvider).changePassword(
                currentPassword: cur.text,
                newPassword: next.text,
              );
          _snack('비밀번호를 변경했어요.');
        } on FirebaseAuthException catch (e) {
          _snack(
            (e.code == 'wrong-password' || e.code == 'invalid-credential')
                ? '현재 비밀번호가 올바르지 않습니다.'
                : '변경에 실패했습니다. (${e.code})',
          );
        } catch (_) {
          _snack('변경에 실패했습니다.');
        }
      }
    }
    cur.dispose();
    next.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;
    if (!_initialized && me != null) {
      _name.text = me.name;
      _colorValue = me.colorValue;
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('프로필 편집')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: '이름',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 24),
            const Text('내 색상',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final c in MemberColors.palette)
                  GestureDetector(
                    onTap: () => setState(() => _colorValue = c),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _colorValue == c
                              ? Colors.black
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: _colorValue == c
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 20)
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('저장'),
            ),
            const Divider(height: 48),
            OutlinedButton.icon(
              onPressed: _changePassword,
              icon: const Icon(Icons.lock_outline),
              label: const Text('비밀번호 변경'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

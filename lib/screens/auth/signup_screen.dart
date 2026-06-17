import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../services/auth_service.dart';
import '../../theme/member_colors.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _account = TextEditingController();
  final _password = TextEditingController();
  int _colorValue = MemberColors.palette.first;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _account.addListener(() => setState(() {})); // 실시간 안내 갱신
  }

  @override
  void dispose() {
    _name.dispose();
    _account.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validateAccount(String? v) {
    final a = (v ?? '').trim();
    if (a.isEmpty) return '이메일 또는 아이디를 입력하세요';
    if (AuthService.looksLikeEmail(a)) {
      final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(a);
      return ok ? null : '이메일 형식이 올바르지 않습니다';
    }
    if (a.length < 3) return '아이디는 3자 이상이어야 합니다';
    if (!RegExp(r'^[a-z0-9._-]+$').hasMatch(a.toLowerCase())) {
      return '아이디는 영문/숫자/._- 만 사용할 수 있어요';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).signUp(
            name: _name.text,
            account: _account.text,
            password: _password.text,
            colorValue: _colorValue,
          );
      if (mounted) Navigator.of(context).pop(); // AuthGate가 이후 화면 처리
    } on FirebaseAuthException catch (e) {
      _showError(_messageFor(e));
    } catch (e) {
      _showError('회원가입 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return '이미 사용 중인 이메일/아이디입니다.';
      case 'invalid-email':
        return '이메일 형식이 올바르지 않습니다.';
      case 'weak-password':
        return '비밀번호는 6자 이상이어야 합니다.';
      default:
        return '회원가입에 실패했습니다. (${e.code})';
    }
  }

  /// 입력값에 따른 실시간 안내(색상 포함).
  Widget _accountHint() {
    final a = _account.text.trim();
    if (a.isEmpty) {
      return const _HintText(
        icon: Icons.info_outline,
        color: Colors.black45,
        text: '이메일로 가입하면 비밀번호 찾기가 가능해요. (권장)',
      );
    }
    if (AuthService.looksLikeEmail(a)) {
      return const _HintText(
        icon: Icons.check_circle_outline,
        color: Color(0xFF2E7D32),
        text: '이메일로 가입 — 비밀번호를 잊어도 메일로 찾을 수 있어요.',
      );
    }
    return const _HintText(
      icon: Icons.warning_amber_rounded,
      color: Color(0xFFEF6C00),
      text: '아이디로 가입 — 비밀번호 찾기가 안 돼요. 이메일이 있다면 이메일을 권장해요.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: '이름',
                    hintText: '예: 박형원',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '이름을 입력하세요' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _account,
                  autocorrect: false,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: '이메일 또는 아이디',
                    hintText: '예: hyungwon@gmail.com 또는 minjun',
                    prefixIcon: Icon(Icons.account_circle_outlined),
                  ),
                  validator: _validateAccount,
                ),
                const SizedBox(height: 8),
                _accountHint(),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '비밀번호 (6자 이상)',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? '비밀번호는 6자 이상이어야 합니다'
                      : null,
                ),
                const SizedBox(height: 24),
                const Text('내 색상 (캘린더에서 나를 구분하는 색)',
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
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('가입하기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HintText extends StatelessWidget {
  const _HintText({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 12, color: color, height: 1.3)),
        ),
      ],
    );
  }
}

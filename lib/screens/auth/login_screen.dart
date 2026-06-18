import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers.dart';
import '../../services/auth_service.dart';
import 'signup_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _account = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _rememberId = true;

  @override
  void initState() {
    super.initState();
    _loadSavedId();
  }

  Future<void> _loadSavedId() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('remember_id') ?? true;
    final saved = prefs.getString('last_login_id') ?? '';
    if (!mounted) return;
    setState(() {
      _rememberId = remember;
      if (remember && saved.isNotEmpty) _account.text = saved;
    });
  }

  Future<void> _saveId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_id', _rememberId);
    if (_rememberId) {
      await prefs.setString('last_login_id', _account.text.trim());
    } else {
      await prefs.remove('last_login_id');
    }
  }

  @override
  void dispose() {
    _account.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _saveId();
      await ref.read(authServiceProvider).signIn(
            account: _account.text,
            password: _password.text,
          );
    } on FirebaseAuthException catch (e) {
      _showError(_messageFor(e));
    } catch (e) {
      _showError('로그인 중 오류가 발생했습니다.');
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
      case 'user-disabled':
        return '비활성화된 계정입니다.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return '아이디(이메일) 또는 비밀번호가 올바르지 않습니다.';
      default:
        return '로그인에 실패했습니다. (${e.code})';
    }
  }

  Future<void> _showResetDialog() async {
    final emailCtrl = TextEditingController(
      text: AuthService.looksLikeEmail(_account.text) ? _account.text.trim() : '',
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('비밀번호 찾기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '가입할 때 사용한 이메일을 입력하면 재설정 링크를 보내드려요.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 6),
            const Text(
              '※ 아이디로만 가입한 경우(이메일 없음)에는 복구가 불가능합니다.',
              style: TextStyle(fontSize: 12, color: Color(0xFFEF6C00)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: '이메일',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (!AuthService.looksLikeEmail(email)) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('올바른 이메일을 입력하세요.')));
                return;
              }
              Navigator.pop(ctx);
              try {
                await ref.read(authServiceProvider).sendPasswordReset(email);
              } catch (_) {/* 존재하지 않는 메일도 동일 메시지로 처리 */}
              _showError('재설정 메일을 보냈어요. 메일함을 확인하세요.');
            },
            child: const Text('메일 보내기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  const Icon(Icons.calendar_month,
                      size: 64, color: Color(0xFF1565C0)),
                  const SizedBox(height: 16),
                  const Text(
                    '우리집일정표',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '가족과 일정을 함께 나눠요',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _account,
                    autocorrect: false,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: '이메일 또는 아이디',
                      prefixIcon: Icon(Icons.account_circle_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? '이메일 또는 아이디를 입력하세요'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '비밀번호',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? '비밀번호를 입력하세요' : null,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () =>
                            setState(() => _rememberId = !_rememberId),
                        borderRadius: BorderRadius.circular(6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _rememberId,
                              visualDensity: VisualDensity.compact,
                              onChanged: (v) =>
                                  setState(() => _rememberId = v ?? true),
                            ),
                            const Text('아이디 저장'),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _loading ? null : _showResetDialog,
                        child: const Text('비밀번호를 잊으셨나요?'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('로그인'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const SignupScreen()),
                            ),
                    child: const Text('처음이신가요? 회원가입'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

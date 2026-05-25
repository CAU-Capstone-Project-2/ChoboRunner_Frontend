import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../viewmodel/auth_viewmodel.dart';
import 'widgets/auth_form_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authViewModelProvider.notifier).signIn(
          username: _usernameCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
    if (!mounted) return;
    if (ok) {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      // 키보드가 올라와도 화면 사이즈는 고정. 입력 필드가 가려질 수 있는 경우는
      // 카드 내부 스크롤로 따로 처리.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            ref.read(authViewModelProvider.notifier).clearError();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.authStart);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.heroBanner,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 입력 영역은 스크롤 가능 (키보드가 가려도 스크롤로 노출).
                  // 하단 회원가입 링크는 카드 바닥에 항상 고정.
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(
                            child: Text(
                              'Log In',
                              style: TextStyle(
                                color: AppColors.primaryActionText,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          AuthFormField(
                            controller: _usernameCtrl,
                            label: '아이디',
                            hint: 'example_id',
                            textInputAction: TextInputAction.next,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return '아이디를 입력하세요';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          AuthFormField(
                            controller: _passwordCtrl,
                            label: '비밀번호',
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            validator: (v) {
                              if (v == null || v.isEmpty) return '비밀번호를 입력하세요';
                              return null;
                            },
                          ),
                          if (auth.error != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              auth.error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.statusError,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 32),
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primaryAction,
                                foregroundColor: AppColors.primaryActionText,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                              ),
                              onPressed: auth.isBusy ? null : _submit,
                              child: auth.isBusy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primaryActionText,
                                      ),
                                    )
                                  : const Text(
                                      '로그인',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: GestureDetector(
                      onTap: auth.isBusy
                          ? null
                          : () {
                              ref.read(authViewModelProvider.notifier).clearError();
                              context.push(AppRoutes.signup);
                            },
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: AppColors.primaryActionText.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                          children: const [
                            TextSpan(text: "계정이 없으신가요? "),
                            TextSpan(
                              text: '회원가입',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryActionText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../shell/shell.dart';

// Demo accounts share one password, set as DEMO_PASSWORD on the server and passed in at build time.
const _demoPassword = String.fromEnvironment('DEMO_PASSWORD', defaultValue: 'sathi2026');
const _demo = [('officer.e', 'role.ward_officer', 'Ward E', Icons.badge_outlined), ('auditor', 'role.auditor', null, Icons.fact_check_outlined), ('citizen', 'role.citizen', null, Icons.person_outline)];

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginState();
}

class _LoginState extends ConsumerState<LoginScreen> {
  final _user = TextEditingController(), _pass = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit([String? username, String? password]) async {
    if (_busy) return;
    final t = ref.read(stringsProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).signIn(username ?? _user.text.trim(), password ?? _pass.text);
    } catch (e) {
      final err = asApiError(e);
      if (mounted) setState(() => _error = err.code == 'network' ? t('err.network') : t('err.not_signed_in'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final c = SathiColors.of(context);
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Gap.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Icon(Icons.account_balance_outlined, color: c.primary, size: 32),
                const SizedBox(width: Gap.sm),
                Expanded(child: Text('${t('app.name')} · ${t('app.module')}', style: tt.headlineMedium!.copyWith(color: c.primary))),
                const LangToggle(),
                const ThemeToggle(),
              ]),
              const SizedBox(height: Gap.sm),
              const Align(alignment: Alignment.centerLeft, child: SyntheticTag()),
              const SizedBox(height: Gap.xl),
              SectionCard(
                title: t('login.title'),
                child: AutofillGroup(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    TextField(controller: _user, decoration: InputDecoration(labelText: t('login.username')), autofillHints: const [AutofillHints.username], textInputAction: TextInputAction.next),
                    const SizedBox(height: Gap.md),
                    TextField(controller: _pass, decoration: InputDecoration(labelText: t('login.password')), obscureText: true, autofillHints: const [AutofillHints.password], onSubmitted: (_) => _submit()),
                    if (_error != null) ...[
                      const SizedBox(height: Gap.sm),
                      Row(children: [Icon(Icons.error_outline, size: 18, color: c.error), const SizedBox(width: Gap.xs), Expanded(child: Text(_error!, style: TextStyle(color: c.error)))]),
                    ],
                    const SizedBox(height: Gap.lg),
                    FilledButton(onPressed: _busy ? null : _submit, child: Text(t('action.signIn'))),
                  ]),
                ),
              ),
              const SizedBox(height: Gap.lg),
              SectionCard(
                title: t('login.demo'),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(t('login.demoHint'), style: tt.bodySmall),
                  const SizedBox(height: Gap.sm),
                  for (final (username, roleKey, ward, icon) in _demo)
                    Padding(
                      padding: const EdgeInsets.only(top: Gap.sm),
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _submit(username, _demoPassword),
                        icon: Icon(icon, size: 18),
                        label: Align(alignment: Alignment.centerLeft, child: Text(ward == null ? t(roleKey) : '${t(roleKey)} · $ward')),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: Gap.lg),
              Text(t('app.disclaimer'), style: tt.bodySmall, textAlign: TextAlign.center),
            ]),
          ),
        ),
      ),
    );
  }
}

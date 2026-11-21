import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../shell/shell.dart';

// Demo accounts share one password, set as DEMO_PASSWORD on the server and passed in at build time.
const _demoPassword = String.fromEnvironment('DEMO_PASSWORD', defaultValue: 'sathi2026');
// (username, role key, ward, sub-line key, initials; null initials shows a person icon)
const _demo = [
  ('officer.e', 'role.ward_officer', 'E', 'login.officerSub', 'RK'),
  ('auditor', 'role.auditor', null, 'login.auditorSub', 'AD'),
  ('citizen', 'role.citizen', null, 'login.citizenSub', null),
];

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginState();
}

class _LoginState extends ConsumerState<LoginScreen> {
  final _user = TextEditingController(), _pass = TextEditingController();
  bool _busy = false, _showPass = false;
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

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: Tok.body.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500)),
  );

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final form = SizedBox(
      width: 400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(t('login.title'), style: Tok.figure.copyWith(height: 34 / 28)),
          const SizedBox(height: 6),
          Text(t('login.sub'), style: Tok.nav.copyWith(color: Tok.text2)),
          const SizedBox(height: 22),
          AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _label(t('login.username')),
                TextField(
                  controller: _user,
                  style: Tok.emph.copyWith(fontWeight: FontWeight.w400),
                  decoration: InputDecoration(
                    hintText: t('login.userHint'),
                    prefixIcon: const Icon(Icons.person_outline, size: 16),
                    prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 44),
                  ),
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                _label(t('login.password')),
                TextField(
                  controller: _pass,
                  style: Tok.emph.copyWith(fontWeight: FontWeight.w400),
                  obscureText: !_showPass,
                  decoration: InputDecoration(
                    hintText: t('login.passHint'),
                    prefixIcon: const Icon(Icons.lock_outline, size: 16),
                    prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 44),
                    suffixIcon: IconButton(
                      tooltip: t(_showPass ? 'login.hidePass' : 'login.showPass'),
                      icon: Icon(_showPass ? Icons.visibility_off_outlined : Ico.eye, size: 16, color: Tok.text3),
                      onPressed: () => setState(() => _showPass = !_showPass),
                    ),
                  ),
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(Tok.inputH), textStyle: Tok.emph.copyWith(fontWeight: FontWeight.w600)),
            onPressed: _busy ? null : _submit,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Text(t('action.signIn')), const SizedBox(width: 8), const Icon(Ico.arrowRight, size: 15)],
            ),
          ),
          Semantics(
            liveRegion: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 26),
              child: _error == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 16, color: Tok.red),
                          const SizedBox(width: 6),
                          Expanded(child: Text(_error!, style: Tok.body.copyWith(color: Tok.red))),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Expanded(child: Divider(color: Tok.line)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Caps(t('login.demo'))),
              const Expanded(child: Divider(color: Tok.line)),
            ],
          ),
          const SizedBox(height: 14),
          for (final (i, (username, roleKey, ward, subKey, initials)) in _demo.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            _DemoCard(
              title: ward == null ? t(roleKey) : '${t(roleKey)} · ${t('ward.label', {'code': ward})}',
              sub: t(subKey),
              initials: initials,
              onTap: _busy ? null : () => _submit(username, _demoPassword),
            ),
          ],
          const SizedBox(height: 18),
          Text(t('app.disclaimer'), style: Tok.sub.copyWith(color: Tok.text3), textAlign: TextAlign.center),
        ],
      ),
    );

    final signIn = Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        color: Tok.panel,
        borderRadius: BorderRadius.circular(Tok.rPanel),
        border: Border.all(color: Tok.line),
        boxShadow: Tok.shadowPanel,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const SyntheticTag(),
              const SizedBox(width: 8),
              const LangToggle(),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Tok.panel,
                  borderRadius: BorderRadius.circular(Tok.rControl),
                  border: Border.all(color: Tok.line),
                  boxShadow: Tok.shadowControl,
                ),
                child: const ThemeToggle(),
              ),
            ],
          ),
          Expanded(
            child: Center(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(vertical: 16), child: form)),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Tok.ground,
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Tok.shell,
            borderRadius: BorderRadius.circular(Tok.rShell),
            border: Border.all(color: Colors.white),
            boxShadow: Tok.shadowShell,
          ),
          child: LayoutBuilder(
            builder: (context, box) => box.maxWidth < 900
                ? Padding(padding: const EdgeInsets.all(12), child: signIn)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Expanded(flex: 55, child: _Pitch()),
                      Expanded(
                        flex: 45,
                        child: Padding(padding: const EdgeInsets.fromLTRB(0, 12, 12, 12), child: signIn),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Left half: name, headline and the three questions the app answers.
class _Pitch extends ConsumerWidget {
  const _Pitch();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    Widget question(IconData icon, String q, String tag, bool first) => Container(
      height: 50,
      decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: Tok.line))),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Tok.panel,
              borderRadius: BorderRadius.circular(Tok.rControl),
              border: Border.all(color: Tok.line),
              boxShadow: Tok.shadowControl,
            ),
            child: Icon(icon, size: 16, color: Tok.tealDark),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(q, style: Tok.cardTitle.copyWith(fontWeight: FontWeight.w500))),
          Caps(tag),
        ],
      ),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(36, 28, 40, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: Tok.teal, borderRadius: BorderRadius.circular(9.7)),
                child: const CustomPaint(painter: _RoadMarkPainter()),
              ),
              const SizedBox(width: 12),
              Text(t('app.name'), style: Tok.section.copyWith(fontSize: 21, height: 1.2)),
              const SizedBox(width: 9),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(const Strings('mr')('app.name'), style: Tok.cardTitle.copyWith(fontWeight: FontWeight.w400, color: Tok.text2)),
              ),
              const SizedBox(width: 9),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(t('app.module'), style: Tok.body.copyWith(color: Tok.text3)),
              ),
            ],
          ),
          const SizedBox(height: 54),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Text(
              t('login.headline'),
              style: Tok.figure.copyWith(fontSize: 34, height: 40 / 34, letterSpacing: -0.85),
            ),
          ),
          const SizedBox(height: 12),
          Text(t('login.lede'), style: Tok.emph.copyWith(fontWeight: FontWeight.w400, color: Tok.text2, height: 21 / 14)),
          const SizedBox(height: 26),
          SizedBox(
            width: 440,
            child: Column(
              children: [
                question(Ico.budget, t('login.q1'), t('login.q1Tag'), true),
                question(Ico.retry, t('login.q2'), t('login.q2Tag'), false),
                question(Ico.filter, t('login.q3'), t('login.q3Tag'), false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({required this.title, required this.sub, required this.initials, required this.onTap});
  final String title, sub;
  final String? initials;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    radius: Tok.rCard,
    semanticLabel: '$title. $sub',
    builder: (_, hover) => Container(
      height: 60,
      padding: const EdgeInsets.fromLTRB(11, 0, 12, 0),
      decoration: BoxDecoration(
        color: hover ? Tok.lineSoft : Tok.inset,
        borderRadius: BorderRadius.circular(Tok.rCard),
        border: Border.all(color: Tok.lineInset),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: initials == null ? Tok.panel : Tok.tealTint,
              borderRadius: BorderRadius.circular(Tok.rControl),
              border: Border.all(color: initials == null ? Tok.line : Tok.tealLine),
            ),
            child: initials == null
                ? const Icon(Icons.person_outline, size: 17, color: Tok.text2)
                : Text(initials!, style: Tok.body.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600, color: Tok.tealDark)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Tok.emph.copyWith(fontWeight: FontWeight.w600, height: 19 / 14)),
                const SizedBox(height: 1),
                Text(sub, style: Tok.sub.copyWith(fontSize: 12.5)),
              ],
            ),
          ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Tok.panel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Tok.line),
            ),
            child: const Icon(Ico.chevronRight, size: 14, color: Tok.text2),
          ),
        ],
      ),
    ),
  );
}

/// The shell's road mark, drawn at any size: two road edges and a centre line, not a civic emblem.
class _RoadMarkPainter extends CustomPainter {
  const _RoadMarkPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 26);
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(8, 20), const Offset(11.5, 6), p);
    canvas.drawLine(const Offset(18, 20), const Offset(14.5, 6), p);
    p
      ..strokeWidth = 1.7
      ..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawLine(const Offset(13, 18.5), const Offset(13, 15.5), p);
    canvas.drawLine(const Offset(13, 12), const Offset(13, 9.5), p);
  }

  @override
  bool shouldRepaint(_RoadMarkPainter oldDelegate) => false;
}

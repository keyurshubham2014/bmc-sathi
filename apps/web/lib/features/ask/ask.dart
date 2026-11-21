import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

void _openAsk(BuildContext context, Strings t, String scopeType, String scopeId) =>
    showDetail(context, title: t('ask.p.title.$scopeType'), child: _AskPanel(scopeType, scopeId));

/// Opens the Ask panel for one ward or contractor.
class AskButton extends ConsumerWidget {
  const AskButton(this.scopeType, this.scopeId, {super.key});
  final String scopeType, scopeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    return AppButton.outlined(t('ask.button'), icon: Ico.ask, onPressed: () => _openAsk(context, t, scopeType, scopeId));
  }
}

/// Work order and complaint ids in a text, in order, without repeats.
Set<String> _ids(String text) => {for (final m in RegExp(r'\b(?:WO|BMC)\d\d-N?\d+\b').allMatches(text)) m[0]!};

const _bodyInk = Color(0xFF2E3338);

class _AskPanel extends ConsumerStatefulWidget {
  const _AskPanel(this.scopeType, this.scopeId);
  final String scopeType, scopeId;
  @override
  ConsumerState<_AskPanel> createState() => _AskState();
}

class _AskState extends ConsumerState<_AskPanel> {
  final _box = TextEditingController();
  bool _busy = false;
  String? _question, _answer;
  Object? _error;

  @override
  void dispose() {
    _box.dispose();
    super.dispose();
  }

  Future<void> _ask([String? preset]) async {
    final q = (preset ?? _box.text).trim();
    if (q.length < 3 || _busy) return;
    setState(() {
      _busy = true;
      _question = q;
      _error = _answer = null;
    });
    _box.clear();
    try {
      final res = await ref.read(dioProvider).post('/ask',
          data: {'question': q, 'scope_type': widget.scopeType, 'scope_id': widget.scopeId, 'lang': ref.read(langProvider)});
      if (mounted) setState(() => _answer = '${res.data['answer']}');
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goTrail(String id) {
    final router = GoRouter.of(context);
    closeDetail(context);
    router.go('/trail/${id.startsWith('WO') ? 'work-order' : 'complaint'}/$id');
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final ward = widget.scopeType == 'ward';
    final scope = ward ? t('ward.label', {'code': widget.scopeId}) : widget.scopeId;
    final presets = ward
        ? [for (var n = 1; n <= 3; n++) t('ask.p.q.ward$n')]
        : [for (var n = 1; n <= 2; n++) t('ask.q.contractor$n')];
    final ids = _answer == null ? const <String>{} : _ids(_answer!);
    final nSources = ids.length + 1;

    Widget sourceChip(IconData icon, String label, VoidCallback? onTap) => Pressable(
          onTap: onTap,
          radius: 8,
          child: Container(
            height: 28,
            padding: const EdgeInsets.fromLTRB(8, 0, 10, 0),
            decoration: BoxDecoration(color: const Color(0xFFF2F8F7), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFCFE5E1))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 13, color: Tok.teal),
              const SizedBox(width: 6),
              Text(label,
                  style: Tok.body.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Tok.tealDark,
                      decoration: onTap == null ? null : TextDecoration.underline,
                      decorationColor: const Color(0xFF9CCBC4))),
            ]),
          ),
        );

    final list = ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 18), children: [
      Text.rich(TextSpan(style: Tok.body.copyWith(color: Tok.text2), children: [
        TextSpan(text: scope),
        const TextSpan(text: ' · ', style: TextStyle(color: Tok.sep)),
        TextSpan(text: t('ask.p.only')),
      ])),
      const SizedBox(height: 14),
      Caps(t('ask.p.try')),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final p in presets)
          Pressable(
            onTap: _busy ? null : () => _ask(p),
            radius: Tok.rPill,
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: Tok.panel, borderRadius: BorderRadius.circular(Tok.rPill), border: Border.all(color: Tok.line), boxShadow: Tok.shadowControl),
              child: Text(p, style: Tok.body.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500)),
            ),
          ),
      ]),
      if (_question != null) ...[
        const SizedBox(height: 18),
        const Divider(height: 1, color: Tok.line),
        const SizedBox(height: 16),
        Align(alignment: Alignment.centerRight, child: Caps(t('ask.p.yourQ'))),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Tok.inset,
              border: Border.all(color: Tok.lineInset),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12), topRight: Radius.circular(12), bottomLeft: Radius.circular(12), bottomRight: Radius.circular(4)),
            ),
            child: Text(_question!, style: Tok.emph),
          ),
        ),
        const SizedBox(height: 14),
      ],
      if (_busy) const LoadingSkeleton(lines: 3),
      if (_error != null) ErrorState(_error!, onRetry: () => _ask(_question)),
      if (_answer != null) ...[
        InsetCard(
          radius: 14,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: 30,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(children: [
                  const Icon(Ico.summary, size: 16, color: Tok.teal),
                  const SizedBox(width: 8),
                  Text(t('ask.p.answer'), style: Tok.emph.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(nSources == 1 ? t('ask.p.oneSource') : t('ask.p.nSources', {'n': nSources}), style: Tok.sub),
                ]),
              ),
            ),
            const SizedBox(height: 2),
            SubCard(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SelectableText(_answer!, style: Tok.emph.copyWith(fontWeight: FontWeight.w400, height: 22 / 14, color: _bodyInk)),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Tok.line),
                const SizedBox(height: 11),
                Caps(t('ask.p.sources')),
                const SizedBox(height: 8),
                // The scope's figures are always the source; record ids named in the answer link to their trail.
                Wrap(spacing: 6, runSpacing: 6, children: [
                  sourceChip(ward ? Ico.home : Ico.contractor, t('ask.p.figures', {'scope': scope}), null),
                  for (final id in ids) sourceChip(Ico.trail, id, () => _goTrail(id)),
                ]),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Ico.info, size: 14, color: Tok.text3)),
          const SizedBox(width: 8),
          Expanded(child: Text(t('ask.p.note'), style: Tok.sub.copyWith(fontSize: 12.5, height: 18 / 12.5))),
        ]),
      ],
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: Tok.inset, borderRadius: BorderRadius.circular(12), border: Border.all(color: Tok.lineInset)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(
              header: true, child: Text(t('ask.p.wontTitle'), style: Tok.body.copyWith(fontWeight: FontWeight.w600, height: 18 / 13))),
          const SizedBox(height: 7),
          for (var n = 1; n <= 3; n++)
            Padding(
              padding: EdgeInsets.only(top: n == 1 ? 0 : 4),
              child: Row(children: [
                const Icon(Icons.block, size: 13, color: Tok.text3),
                const SizedBox(width: 8),
                Expanded(child: Text(t('ask.p.wont$n'), style: Tok.body.copyWith(height: 20 / 13, color: _bodyInk))),
              ]),
            ),
        ]),
      ),
    ]);

    final form = Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Tok.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        ValueListenableBuilder(
          valueListenable: _box,
          builder: (_, v, _) => Row(children: [
            Text(t('ask.p.new'), style: Tok.body.copyWith(fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(t('ask.p.count', {'n': v.text.length}), style: Tok.sub),
          ]),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _box,
          maxLength: 500,
          minLines: 2,
          maxLines: 2,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.send,
          style: Tok.body.copyWith(height: 20 / 13),
          decoration: InputDecoration(
            hintText: t('ask.p.hint'),
            counterText: '',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(Tok.rControl), borderSide: const BorderSide(color: Tok.treeLine)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Tok.rControl), borderSide: const BorderSide(color: Tok.treeLine)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Tok.rControl), borderSide: const BorderSide(color: Tok.teal, width: 2)),
          ),
          onSubmitted: (_) => _ask(),
        ),
        const SizedBox(height: 10),
        Row(children: [
          AppButton.primary(t('ask.p.send'), icon: Ico.arrowRight, onPressed: _busy ? null : _ask),
          const SizedBox(width: 12),
          Expanded(child: Text(t('ask.p.replace'), style: Tok.sub)),
        ]),
      ]),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 2),
      Expanded(child: list),
      form,
    ]);
  }
}

final summaryProvider = FutureProvider.family<Map<String, dynamic>?, (String, String, String)>((ref, k) async {
  final data = await apiGet(ref, '/ask/summary', {'type': k.$1, 'id': k.$2, 'lang': k.$3});
  return data['summary'] as Map<String, dynamic>?;
});

/// "Summary (written from these figures)" panel with an Ask button. Shows nothing while loading or if the
/// summary cannot be fetched; says so when none has been written yet.
class SummaryCard extends ConsumerWidget {
  const SummaryCard(this.scopeType, this.scopeId, {super.key});
  final String scopeType, scopeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final async = ref.watch(summaryProvider((scopeType, scopeId, ref.watch(langProvider))));
    if (!async.hasValue) return const SizedBox.shrink();
    final summary = async.value;
    return Panel(
      padding: const EdgeInsets.fromLTRB(18, 12, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 38),
          child: Row(children: [
            const Icon(Ico.summary, size: 16, color: Tok.teal),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(TextSpan(children: [
                TextSpan(text: t('ask.summary.title'), style: Tok.cardTitle),
                TextSpan(text: ' ${t('ask.summary.sub')}', style: Tok.body.copyWith(color: Tok.text2, fontSize: 15)),
              ])),
            ),
            const SizedBox(width: 8),
            Pressable(
              onTap: () => _openAsk(context, t, scopeType, scopeId),
              radius: 9,
              child: Container(
                height: 30,
                padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
                decoration: BoxDecoration(color: Tok.tealTint, borderRadius: BorderRadius.circular(9), border: Border.all(color: Tok.teal)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Ico.ask, size: 14, color: Tok.tealDark),
                  const SizedBox(width: 6),
                  Text(t('ask.title'), style: Tok.body.copyWith(color: Tok.tealDark, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        if (summary == null)
          Text(t('ask.summary.none'), style: Tok.body.copyWith(color: Tok.text2))
        else ...[
          Text('${summary['body']}', style: Tok.nav.copyWith(height: 21 / 13.5, color: _bodyInk)),
          if (summary['stale'] == true) ...[
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: Pill(t('summary.stale'), tone: Tone.info, icon: Icons.history)),
          ],
        ],
      ]),
    );
  }
}

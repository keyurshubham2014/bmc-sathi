import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/format.dart' as fmt;
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../overview/city_screen.dart';
import '../overview/ward_screen.dart';
import 'flag_queue.dart';

final flagDetailProvider = FutureProvider.family<Map<String, dynamic>, (String, String)>((ref, a) => apiGet(ref, '/flags/${a.$1}/${a.$2}'));

/// Flag detail as its own page, used below the wide breakpoint and for direct links.
class FlagDetailPage extends ConsumerWidget {
  const FlagDetailPage(this.type, this.id, {super.key});
  final String type, id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.canPop() ? context.pop() : context.go('/flags'),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: Text(ref.watch(stringsProvider)('flags.title')),
          ),
        ),
        Expanded(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: FlagDetail(type, id)))),
      ]);
}

class FlagDetail extends ConsumerWidget {
  const FlagDetail(this.type, this.id, {super.key});
  final String type, id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final tt = Theme.of(context).textTheme;
    final key = (type, id);
    return AsyncView(
      value: ref.watch(flagDetailProvider(key)),
      onRetry: () => ref.invalidate(flagDetailProvider(key)),
      lines: 8,
      builder: (data) {
        final f = Map<String, dynamic>.from(data['flag']);
        final w = Map<String, dynamic>.from(data['work_order']);
        final watch = f['tier'] == 'watch';
        return ListView(padding: const EdgeInsets.all(Gap.lg), children: [
          Wrap(spacing: Gap.sm, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('${f['work_order_id']}', style: tt.titleLarge),
            Pill(t('flags.tab.${watch ? 'watch' : type}'), tone: Tone.flag, icon: Icons.flag_outlined),
          ]),
          Text('${t('ward.label', {'code': w['ward_code']})} · ${w['road_name']} · ${w['contractor_name']}', style: tt.bodyMedium),
          const SizedBox(height: Gap.md),
          Text(flagReason(t, f), style: tt.bodyLarge),
          const SizedBox(height: Gap.xs),
          Text('${t('flags.atStake')}: ${fmt.money(f['amount_at_stake'])}', style: tt.labelLarge),
          const SizedBox(height: Gap.lg),
          Text(t('flags.evidence'), style: tt.titleMedium),
          const SizedBox(height: Gap.sm),
          switch (type) {
            'duplicate' => _DuplicateEvidence(Map<String, dynamic>.from(data['earlier_work_order']), w, f),
            'dlp' => _DlpEvidence(w),
            _ => _OverbilledEvidence(w),
          },
          const SizedBox(height: Gap.lg),
          if (watch) Text(t('flags.watchNote'), style: tt.bodySmall) else _DecisionForm(f, wardCode: '${w['ward_code']}'),
        ]);
      },
    );
  }
}

/// Label and value rows inside a bordered box.
class _Facts extends StatelessWidget {
  const _Facts(this.rows);
  final List<(String, String, bool)> rows; // label, value, emphasised

  @override
  Widget build(BuildContext context) {
    final c = SathiColors.of(context);
    final tt = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(kRadius)),
      child: Column(children: [
        for (final (i, (label, value, strong)) in rows.indexed)
          Container(
            decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: c.border))),
            padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 2, child: Text(label, style: tt.bodySmall)),
              Expanded(flex: 3, child: Text(value, style: strong ? tt.titleMedium : tt.bodyMedium, textAlign: TextAlign.end)),
            ]),
          ),
      ]),
    );
  }
}

class _OverbilledEvidence extends ConsumerWidget {
  const _OverbilledEvidence(this.w);
  final Map<String, dynamic> w;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final c = SathiColors.of(context);
    final r = (w['cost_ratio'] as num).toDouble();
    final perSqm = w['unit'] == 'per sqm';
    // Position on a 0 to 3.2 scale; the band marks where usual jobs fall.
    double x(double v) => (v / 3.2).clamp(0, 1);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Facts([
        (t('flags.ev.method'), '${w['repair_method']}', false),
        if (perSqm) (t('flags.ev.area'), t('wo.area', {'area': w['area_sqm']}), false),
        (t('flags.ev.rate'), '${fmt.money(w['standard_rate_inr'])} ${w['unit']}', false),
        (t('flags.ev.expected'), fmt.money(w['expected_cost']), false),
        (t('flags.ev.billed'), fmt.money(w['cost_inr']), true),
        (t('flags.ev.ratio'), t('wo.timesRate', {'ratio': fmt.ratio(r)}), true),
      ]),
      const SizedBox(height: Gap.md),
      LayoutBuilder(builder: (_, box) {
        final wd = box.maxWidth;
        return SizedBox(
          height: 28,
          child: Stack(children: [
            Positioned(left: 0, right: 0, top: 10, child: Container(height: 8, decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(4)))),
            Positioned(left: wd * x(0.77), width: wd * (x(1.3) - x(0.77)), top: 10, child: Container(height: 8, color: c.accent)),
            Positioned(left: (wd * x(r) - 2).clamp(0, wd - 4), top: 2, child: Container(width: 4, height: 24, color: c.flag)),
          ]),
        );
      }),
      Text(t('flags.ev.normal'), style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

class _DuplicateEvidence extends ConsumerWidget {
  const _DuplicateEvidence(this.earlier, this.current, this.flag);
  final Map<String, dynamic> earlier, current, flag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final c = SathiColors.of(context);
    final tt = Theme.of(context).textTheme;
    String linked(Map<String, dynamic> w) => w['has_complaint'] == true ? t('flags.ev.linked') : t('wo.noComplaint');
    // (label, earlier value, this value, do they match)
    final rows = <(String, String, String, bool)>[
      (t('flags.ev.road'), '${earlier['road_name']}', '${current['road_name']}', true),
      (t('flags.ev.workType'), '${earlier['work_type']}', '${current['work_type']}', true),
      (t('flags.ev.contractor'), '${earlier['contractor_name']}', '${current['contractor_name']}', true),
      (t('flags.ev.area'), t('wo.area', {'area': earlier['area_sqm']}), t('wo.area', {'area': current['area_sqm']}), true),
      (t('flags.ev.assigned'), fmt.date(earlier['assigned_at']), fmt.date(current['assigned_at']), false),
      (t('flags.ev.cost'), fmt.money(earlier['cost_inr']), fmt.money(current['cost_inr']), false),
      (t('flags.ev.complaints'), linked(earlier), linked(current), false),
    ];
    Widget cell(String s, {TextStyle? style, int flex = 3}) => Expanded(flex: flex, child: Padding(padding: const EdgeInsets.all(Gap.sm), child: Text(s, style: style ?? tt.bodyMedium)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(kRadius)),
        child: Column(children: [
          Container(
            color: c.surfaceAlt,
            child: Row(children: [
              cell('', flex: 2),
              cell('${t('flags.ev.earlier')}\n${earlier['work_order_id']}', style: tt.labelLarge),
              cell('${t('flags.ev.this')}\n${current['work_order_id']}', style: tt.labelLarge),
            ]),
          ),
          for (final (label, a, b, same) in rows)
            Container(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.sm),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(label, style: tt.bodySmall),
                      if (same) Pill(t('flags.ev.same'), tone: Tone.flag, icon: Icons.drag_handle),
                    ]),
                  ),
                ),
                cell(a),
                cell(b, style: b == t('wo.noComplaint') ? tt.bodyMedium!.copyWith(color: c.flag, fontWeight: FontWeight.w600) : null),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: Gap.sm),
      Pill(t('flags.ev.daysApart', {'days': fmt.ratio(flag['evidence']['days_apart'])}), tone: Tone.flag, icon: Icons.date_range_outlined),
    ]);
  }
}

class _DlpEvidence extends ConsumerWidget {
  const _DlpEvidence(this.w);
  final Map<String, dynamic> w;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final c = SathiColors.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Facts([
        (t('flags.ev.road'), '${w['road_name']} (${w['road_id']})', false),
        (t('flags.ev.resurfaced'), fmt.date(w['last_resurfaced']), false),
        (t('wo.dlp'), 'Y', true),
        (t('flags.ev.method'), '${w['repair_method']}', false),
        (t('flags.ev.billed'), fmt.money(w['cost_inr']), true),
      ]),
      const SizedBox(height: Gap.md),
      Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(color: c.infoTint, borderRadius: BorderRadius.circular(kRadius)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline, size: 18, color: c.info),
          const SizedBox(width: Gap.sm),
          Expanded(child: Text(t('flags.ev.dlpLiable'), style: TextStyle(color: c.textPrimary))),
        ]),
      ),
    ]);
  }
}

class _DecisionForm extends ConsumerStatefulWidget {
  const _DecisionForm(this.flag, {required this.wardCode});
  final Map<String, dynamic> flag;
  final String wardCode;
  @override
  ConsumerState<_DecisionForm> createState() => _DecisionState();
}

class _DecisionState extends ConsumerState<_DecisionForm> {
  late String? _decision = widget.flag['decision'] == 'open' ? null : widget.flag['decision'] as String;
  late final _note = TextEditingController(text: widget.flag['note'] as String? ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save(Strings t) async {
    final f = widget.flag;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(dioProvider).put('/flags/${f['flag_type']}/${f['work_order_id']}/decision', data: {'decision': _decision, 'note': _note.text});
      // Every figure that counts open flags must refresh.
      ref.invalidate(flagsProvider);
      ref.invalidate(flagSummaryProvider);
      ref.invalidate(flagDetailProvider((f['flag_type'] as String, f['work_order_id'] as String)));
      ref.invalidate(wardDetailProvider(widget.wardCode));
      ref.invalidate(wardsProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('decision.saved'))));
    } catch (e) {
      final err = asApiError(e);
      if (mounted) setState(() => _error = err.code == 'network' ? t('err.network') : err.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final c = SathiColors.of(context);
    final tt = Theme.of(context).textTheme;
    final f = widget.flag;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Text(t('decision.title'), style: tt.titleMedium), const SizedBox(width: Gap.sm), DecisionChip('${f['decision']}')]),
      if (f['decided_at'] != null) Text(t('decision.by', {'name': f['decided_by_name'] ?? '', 'when': fmt.dateTime(f['decided_at'], local: true)}), style: tt.bodySmall),
      const SizedBox(height: Gap.sm),
      Wrap(spacing: Gap.sm, runSpacing: Gap.sm, children: [
        for (final d in ['confirmed', 'needs_explanation', 'not_an_issue'])
          ChoiceChip(label: Text(t('decision.$d')), selected: _decision == d, onSelected: _busy ? null : (_) => setState(() => _decision = d)),
      ]),
      const SizedBox(height: Gap.md),
      TextField(controller: _note, maxLength: 500, maxLines: 3, minLines: 2, decoration: InputDecoration(labelText: t('decision.note'))),
      if (_error != null) Padding(padding: const EdgeInsets.only(bottom: Gap.sm), child: Text(_error!, style: TextStyle(color: c.error))),
      FilledButton(onPressed: _busy || _decision == null ? null : () => _save(t), child: Text(t('action.save'))),
    ]);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/format.dart' as fmt;
import '../../core/theme.dart';
import '../../core/widgets.dart';

// Reads the client instead of watching it: saving a record refreshes every other figure in the app,
// and the form (with its result) must survive that.
final intakeOptionsProvider = FutureProvider<Map<String, dynamic>>(
    (ref) async => Map<String, dynamic>.from((await ref.read(dioProvider).get('/intake/options')).data));

/// A ward officer types in a new work order or complaint; the live rules judge it at once.
class IntakeScreen extends ConsumerStatefulWidget {
  const IntakeScreen({super.key});
  @override
  ConsumerState<IntakeScreen> createState() => _IntakeState();
}

class _IntakeState extends ConsumerState<IntakeScreen> {
  String _tab = 'wo';

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final tt = Theme.of(context).textTheme;
    return AsyncView(
      value: ref.watch(intakeOptionsProvider),
      onRetry: () => ref.invalidate(intakeOptionsProvider),
      lines: 8,
      builder: (o) => PageBody(children: [
        Text(t('intake.title'), style: tt.titleLarge),
        Text(t('intake.note'), style: tt.bodyMedium!.copyWith(color: SathiColors.of(context).textSecondary)),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [for (final k in ['wo', 'complaint']) ButtonSegment(value: k, label: Text(t('intake.tab.$k')))],
          selected: {_tab},
          onSelectionChanged: (s) => setState(() => _tab = s.first),
        ),
        if (_tab == 'wo') _WorkOrderForm(o) else _ComplaintForm(o),
      ]),
    );
  }
}

Widget _pick(String label, String? value, Map<String, String> items, ValueChanged<String?> onChanged) => DropdownButtonFormField<String>(
      key: ValueKey('$label-$value-${items.length}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))],
      onChanged: onChanged,
    );

/// Runs a save, reporting failures in the form.
mixin _Submit<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool busy = false;
  String? error;
  Map<String, dynamic>? result;

  Future<void> submit(String path, Map<String, dynamic> body) async {
    final t = ref.read(stringsProvider);
    setState(() {
      busy = true;
      error = null;
      result = null;
    });
    try {
      final res = await ref.read(dioProvider).post(path, data: body);
      // Every figure in the app may have moved.
      ref.invalidate(dioProvider);
      if (mounted) setState(() => result = Map<String, dynamic>.from(res.data));
    } catch (e) {
      final err = asApiError(e);
      if (mounted) setState(() => error = err.code == 'network' ? t('err.network') : err.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget errorLine(BuildContext context) => error == null ? const SizedBox.shrink() : Text(error!, style: TextStyle(color: SathiColors.of(context).error));
}

class _WorkOrderForm extends ConsumerStatefulWidget {
  const _WorkOrderForm(this.o);
  final Map<String, dynamic> o;
  @override
  ConsumerState<_WorkOrderForm> createState() => _WorkOrderFormState();
}

class _WorkOrderFormState extends ConsumerState<_WorkOrderForm> with _Submit {
  String? _road, _type, _method, _contractor;
  final _area = TextEditingController(), _cost = TextEditingController();

  @override
  void dispose() {
    _area.dispose();
    _cost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final tt = Theme.of(context).textTheme;
    final methods = List<Map<String, dynamic>>.from(widget.o['methods']);
    final area = double.tryParse(_area.text), cost = int.tryParse(_cost.text);
    final m = methods.where((x) => x['work_type'] == _type && x['repair_method'] == _method).firstOrNull;
    final expected = m == null ? null : (m['unit'] == 'per sqm' ? (area == null ? null : (m['standard_rate_inr'] as num) * area) : m['standard_rate_inr'] as num);
    final ready = _road != null && m != null && _contractor != null && area != null && area > 0 && cost != null && cost > 0;
    final wo = result?['work_order'];
    final flags = List<Map<String, dynamic>>.from(result?['flags'] ?? const []);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _pick(t('intake.road'), _road, {for (final r in widget.o['roads']) '${r['road_id']}': '${r['road_name']} · ${r['segment_no']}'}, (v) => setState(() => _road = v)),
          const SizedBox(height: Gap.md),
          _pick(t('intake.workType'), _type, {for (final x in methods) '${x['work_type']}': '${x['work_type']}'}, (v) => setState(() {
                _type = v;
                _method = null;
              })),
          const SizedBox(height: Gap.md),
          _pick(t('intake.method'), _method, {for (final x in methods.where((x) => x['work_type'] == _type)) '${x['repair_method']}': '${x['repair_method']}'}, (v) => setState(() => _method = v)),
          const SizedBox(height: Gap.md),
          _pick(t('intake.contractor'), _contractor, {for (final x in widget.o['contractors']) '${x['contractor_id']}': '${x['contractor_name']}'}, (v) => setState(() => _contractor = v)),
          const SizedBox(height: Gap.md),
          Row(children: [
            Expanded(child: TextField(controller: _area, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t('intake.area')), onChanged: (_) => setState(() {}))),
            const SizedBox(width: Gap.md),
            Expanded(child: TextField(controller: _cost, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: t('intake.cost')), onChanged: (_) => setState(() {}))),
          ]),
          const SizedBox(height: Gap.sm),
          if (expected != null) Text(t('intake.rate', {'amount': fmt.money(expected)}), style: tt.bodySmall),
          const SizedBox(height: Gap.md),
          Wrap(spacing: Gap.md, runSpacing: Gap.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
            FilledButton(
              onPressed: busy || !ready
                  ? null
                  : () => submit('/intake/work-orders', {'road_id': _road, 'work_type': _type, 'repair_method': _method, 'contractor_id': _contractor, 'area_sqm': area, 'cost_inr': cost}),
              child: Text(t('intake.submit')),
            ),
            if (!ready) Text(t('intake.required'), style: tt.bodySmall),
            errorLine(context),
          ]),
        ]),
      ),
      if (wo != null) ...[
        const SizedBox(height: Gap.lg),
        SectionCard(
          title: t('intake.saved', {'id': wo['work_order_id']}),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: Gap.sm, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(fmt.money(wo['cost_inr']), style: tt.titleMedium),
              Text(t('wo.expected', {'amount': fmt.money(wo['expected_cost'])}), style: tt.bodySmall),
              Pill(t('wo.timesRate', {'ratio': fmt.ratio(wo['cost_ratio'])}), tone: flags.isEmpty ? Tone.neutral : Tone.flag),
            ]),
            const SizedBox(height: Gap.md),
            if (flags.isEmpty)
              Pill(t('intake.noFlags'), tone: Tone.success, icon: Icons.check)
            else ...[
              Text(t('intake.flagged'), style: tt.labelLarge),
              const SizedBox(height: Gap.xs),
              Wrap(spacing: Gap.sm, runSpacing: Gap.xs, children: [
                for (final f in flags)
                  InkWell(
                    onTap: f['tier'] == 'flag' ? () => context.go('/flags/${f['flag_type']}/${wo['work_order_id']}') : null,
                    child: Pill('${t('flags.tab.${f['tier'] == 'watch' ? 'watch' : f['flag_type']}')} · ${fmt.money(f['amount_at_stake'])}', tone: Tone.flag, icon: Icons.flag_outlined),
                  ),
              ]),
            ],
            const SizedBox(height: Gap.md),
            TextButton.icon(
              icon: const Icon(Icons.undo, size: 18),
              label: Text(t('intake.undo')),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await ref.read(dioProvider).delete('/intake/work-orders/${wo['work_order_id']}');
                ref.invalidate(dioProvider);
                if (mounted) setState(() => result = null);
                messenger.showSnackBar(SnackBar(content: Text(t('intake.removed'))));
              },
            ),
          ]),
        ),
      ],
    ]);
  }
}

class _ComplaintForm extends ConsumerStatefulWidget {
  const _ComplaintForm(this.o);
  final Map<String, dynamic> o;
  @override
  ConsumerState<_ComplaintForm> createState() => _ComplaintFormState();
}

class _ComplaintFormState extends ConsumerState<_ComplaintForm> with _Submit {
  String? _category;
  final _locality = TextEditingController(), _text = TextEditingController();

  @override
  void dispose() {
    _locality.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final tt = Theme.of(context).textTheme;
    final ready = _category != null && _text.text.trim().length >= 5;
    final r = result;
    final road = r?['road'] == null ? null : '${r!['road']['road_name']} · ${r['road']['segment_no']}';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _pick(t('intake.category'), _category, {for (final x in widget.o['categories']) '$x': '$x'}, (v) => setState(() => _category = v)),
          const SizedBox(height: Gap.md),
          TextField(controller: _locality, maxLength: 120, decoration: InputDecoration(labelText: t('intake.locality'))),
          TextField(controller: _text, maxLength: 1000, minLines: 2, maxLines: 5, decoration: InputDecoration(labelText: t('intake.description')), onChanged: (_) => setState(() {})),
          const SizedBox(height: Gap.sm),
          Wrap(spacing: Gap.md, runSpacing: Gap.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
            FilledButton(
              onPressed: busy || !ready
                  ? null
                  : () => submit('/intake/complaints', {'description': _text.text.trim(), 'category_reported': _category, if (_locality.text.trim().isNotEmpty) 'locality_text': _locality.text.trim()}),
              child: Text(t('intake.submit')),
            ),
            if (!ready) Text(t('intake.required'), style: tt.bodySmall),
            errorLine(context),
          ]),
        ]),
      ),
      if (r != null) ...[
        const SizedBox(height: Gap.lg),
        SectionCard(
          title: t('intake.saved', {'id': r['complaint']['complaint_id']}),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(road == null ? t('intake.noRoad') : t(r['joined_existing'] == true ? 'intake.joined' : 'intake.newIssue', {'road': road}), style: tt.bodyMedium),
            if (r['plan'] != null) Text(t('intake.rank', {'rank': r['plan']['rank'], 'score': (r['plan']['risk_score'] as num).round()}), style: tt.bodyMedium),
            TextButton.icon(onPressed: () => context.go('/trail/issue/${r['issue']['issue_id']}'), icon: const Icon(Icons.timeline_outlined, size: 18), label: Text(t('intake.openTrail'))),
          ]),
        ),
      ],
    ]);
  }
}

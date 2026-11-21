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

/// Route /flags/:type/:id: the queue with this flag open in the right panel. [type] is the URL slug.
class FlagDetailPage extends StatelessWidget {
  const FlagDetailPage(this.type, this.id, {super.key});
  final String type, id;

  @override
  Widget build(BuildContext context) => FlagQueueScreen(slug: type, id: id);
}

/// The flag's detail panel: amount at stake, evidence on the same screen, decision form in the footer.
/// [type] is the API flag type; [watch] says which tab it was opened from until the flag has loaded.
class FlagDetail extends ConsumerWidget {
  const FlagDetail(this.type, this.id, {super.key, required this.watch, required this.onClose});
  final String type, id;
  final bool watch;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final key = (type, id);
    final async = ref.watch(flagDetailProvider(key));
    final data = async.value;
    final f = data == null ? null : Map<String, dynamic>.from(data['flag']);
    final w = data == null ? null : Map<String, dynamic>.from(data['work_order']);
    final isWatch = f == null ? watch : f['tier'] == 'watch';
    return DetailPanel(
      eyebrow: t(isWatch ? 'flags.panel.watch' : 'flags.panel.flag'),
      eyebrowIcon: isWatch ? Ico.eye : Ico.flag,
      eyebrowColor: isWatch ? Tok.text3 : Tok.amberIcon,
      title: t(isWatch ? 'flags.panel.watchTitle' : 'flags.tab.$type'),
      subtitle: w == null ? id : '$id · ${w['road_name']}',
      onClose: onClose,
      footer: f == null
          ? null
          : isWatch
              ? const _WatchNote()
              : _DecisionForm(f, wardCode: '${w!['ward_code']}', onCancel: onClose),
      child: AsyncView(
        value: async,
        onRetry: () => ref.invalidate(flagDetailProvider(key)),
        lines: 8,
        builder: (data) => _Body(type, data, watch: isWatch),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body(this.type, this.data, {required this.watch});
  final String type;
  final Map<String, dynamic> data;
  final bool watch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final f = Map<String, dynamic>.from(data['flag']);
    final w = Map<String, dynamic>.from(data['work_order']);
    final sub = Tok.sub.copyWith(fontSize: 12.5, height: 17 / 12.5);
    final reason = _Note(Text.rich(TextSpan(children: [
      TextSpan(text: '${t('flags.ev.reason')} ', style: const TextStyle(color: Tok.ink, fontWeight: FontWeight.w500)),
      TextSpan(text: flagReason(t, f)),
    ])));
    final links = [(t('flags.link.trail'), '/trail/work-order/${w['work_order_id']}'), (t('flags.link.contractor'), '/contractors/${w['contractor_id']}')];

    final evidence = switch (type) {
      'duplicate' => _duplicate(t, Map<String, dynamic>.from(data['earlier_work_order']), w, f),
      'dlp' => [
          _Facts([
            (t('flags.ev.road'), Text('${w['road_name']} (${w['road_type']}, ${w['surface']})')),
            (t('flags.ev.resurfaced'), Text(fmt.date(w['last_resurfaced']))),
            (
              t('flags.ev.dlpStatus'),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t('flags.ev.underDlp')),
                const SizedBox(height: 6),
                StatusPill(t('flags.ev.dlpPill'), dot: Tok.amberIcon),
              ]),
            ),
            (t('flags.ev.workOrder'), contractorText('${w['work_order_id']} · ${w['work_type']} · ${w['contractor_name']}')),
            (t('flags.ev.billedCost'), Text(fmt.rupees(w['cost_inr']))),
            (
              t('flags.ev.expectedRate'),
              Text('${fmt.rupees(w['standard_rate_inr'])} ${w['unit']} · ${t('wo.timesRate', {'ratio': fmt.ratio(w['cost_ratio'])})}'),
            ),
          ]),
          const SizedBox(height: 12),
          _WhiteCard(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(top: 1), child: Icon(Ico.info, size: 14, color: Tok.text3)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Caps(t('flags.ev.liable')),
                  const SizedBox(height: 2),
                  Text(t('flags.ev.dlpLiable'), style: Tok.body),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          reason,
          const SizedBox(height: 6),
          _Links(links),
        ],
      _ => [
          _Facts([
            (t('flags.ev.method'), Text('${w['repair_method']} (${w['unit']})')),
            (t('flags.ev.area'), Text(w['unit'] == 'per sqm' ? t('wo.area', {'area': w['area_sqm']}) : t('flags.ev.notPerJob'))),
            (t('flags.ev.rateCard'), Text('${fmt.rupees(w['standard_rate_inr'])} ${w['unit']}')),
            (t('flags.ev.expected'), Text(fmt.rupees(w['expected_cost']))),
            (t('flags.ev.billedCost'), Text(fmt.rupees(w['cost_inr']))),
            (
              t('flags.ev.ratioLabel'),
              Text(t('wo.timesRate', {'ratio': fmt.ratio(w['cost_ratio'])}), style: const TextStyle(color: Tok.amberText, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 12),
          _WhiteCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('flags.ev.range'), style: Tok.body.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              RangeStrip(ratio: (w['cost_ratio'] as num).toDouble()),
            ]),
          ),
          const SizedBox(height: 12),
          reason,
          const SizedBox(height: 6),
          _Links(links),
        ],
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InsetCard(
        radius: 14,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Caps(t('flags.atStake')),
          const SizedBox(height: 4),
          Text(fmt.money(f['amount_at_stake']), style: Tok.figure),
          if (type != 'duplicate') Text(t(type == 'dlp' ? 'flags.stake.dlp' : 'flags.stake.overbilled'), style: sub),
          const SizedBox(height: 12),
          Row(children: [
            Text(t('flags.currentDecision'), style: sub),
            const SizedBox(width: 8),
            DecisionChip(watch ? 'watch' : '${f['decision']}'),
          ]),
          const SizedBox(height: 5),
          Text(
            watch
                ? t('flags.evidenceOnly')
                : f['decided_at'] == null
                    ? t('flags.noDecision')
                    : t('flags.decidedBy', {'name': f['decided_by_name'] ?? '', 'when': fmt.dateTime(f['decided_at'], local: true)}),
            style: sub,
          ),
        ]),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Caps(t('flags.evidence')),
        const Spacer(),
        Text(t('flags.evSub.${type == 'duplicate' || type == 'dlp' ? type : 'overbilled'}'), style: Tok.sub),
      ]),
      const SizedBox(height: 6),
      ...evidence,
    ]);
  }

  /// Earlier job against the flagged one, field by field.
  List<Widget> _duplicate(Strings t, Map<String, dynamic> e, Map<String, dynamic> c, Map<String, dynamic> f) {
    Widget wo(Map<String, dynamic> w) => Text('${w['work_order_id']}', style: const TextStyle(color: Tok.tealDark, fontWeight: FontWeight.w600));
    Widget day(Map<String, dynamic> w, Color dot) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: dot, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.2))),
          const SizedBox(width: 6),
          Text(fmt.date(w['assigned_at'])),
        ]);
    String ids(Map<String, dynamic> w) => (w['linked_complaint_ids'] as String? ?? '').replaceAll('|', ', ');
    Widget complaints(Map<String, dynamic> w, {required bool flagged}) {
      if (ids(w).isNotEmpty) return Text(ids(w));
      if (!flagged) return Text(t('flags.ev.none'));
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Ico.flag, size: 13, color: Tok.amberIcon)),
        const SizedBox(width: 5),
        Flexible(child: Text(t('wo.noComplaint'), style: const TextStyle(color: Tok.amberText, fontWeight: FontWeight.w500))),
      ]);
    }

    EvidenceRow same(String label, String field, Widget Function(Map<String, dynamic>) show) =>
        EvidenceRow(label, left: show(e), right: show(c), matches: '${e[field]}' == '${c[field]}');
    const bold = TextStyle(fontWeight: FontWeight.w600);
    final re = (e['cost_ratio'] as num).toDouble(), rc = (c['cost_ratio'] as num).toDouble();
    bool inRange(double r) => r >= 0.77 && r <= 1.3;

    return [
      EvidencePair(
        leftTitle: t('flags.ev.earlier'),
        rightTitle: t('flags.ev.second'),
        rightNote: t('flags.ev.flagged'),
        rows: [
          EvidenceRow(t('flags.ev.workOrder'), left: wo(e), right: wo(c), matches: false),
          same(t('flags.ev.road'), 'road_id', (w) => Text('${w['road_name']} (${w['road_id']})')),
          same(t('flags.ev.workType'), 'work_type', (w) => Text('${w['work_type']}')),
          same(t('flags.ev.method'), 'repair_method', (w) => Text('${w['repair_method']}')),
          same(t('flags.ev.contractor'), 'contractor_id', (w) => contractorText('${w['contractor_name']}')),
          same(t('flags.ev.area'), 'area_sqm', (w) => Text(t('wo.area', {'area': w['area_sqm']}))),
          EvidenceRow(
            t('flags.ev.assigned'),
            left: day(e, Tok.teal),
            right: day(c, Tok.amberIcon),
            tag: t('flags.ev.within', {'days': fmt.ratio(f['evidence']['days_apart'])}),
            tagIcon: Ico.calendar,
          ),
          EvidenceRow(
            t('flags.ev.linkedComplaints'),
            left: complaints(e, flagged: false),
            right: complaints(c, flagged: true),
            matches: ids(e) == ids(c),
          ),
          same(t('flags.ev.cost'), 'cost_inr', (w) => Text(fmt.rupees(w['cost_inr']), style: bold)),
        ],
      ),
      if (inRange(re) && inRange(rc)) ...[
        const SizedBox(height: 12),
        _Note(Text(t('flags.ev.bothInRange', {'a': fmt.ratio(re), 'b': fmt.ratio(rc)}))),
      ],
      const SizedBox(height: 6),
      _Links([
        (t('flags.link.trailFor', {'id': c['work_order_id']}), '/trail/work-order/${c['work_order_id']}'),
        (t('flags.link.trailFor', {'id': e['work_order_id']}), '/trail/work-order/${e['work_order_id']}'),
        (t('flags.link.contractor'), '/contractors/${c['contractor_id']}'),
      ]),
    ];
  }
}

/// Label and value rows on a grey card.
class _Facts extends StatelessWidget {
  const _Facts(this.rows);
  final List<(String, Widget)> rows;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: Tok.inset, borderRadius: BorderRadius.circular(Tok.rCard), border: Border.all(color: Tok.lineInset)),
        child: Column(children: [
          for (final (i, (label, value)) in rows.indexed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: i == 0 ? null : const BoxDecoration(border: Border(top: BorderSide(color: Tok.line))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 128, child: Text(label, style: Tok.body.copyWith(color: Tok.text2))),
                Expanded(child: DefaultTextStyle.merge(style: Tok.body.copyWith(fontWeight: FontWeight.w500), child: value)),
              ]),
            ),
        ]),
      );
}

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(color: Tok.panel, borderRadius: BorderRadius.circular(Tok.rCard), border: Border.all(color: Tok.line)),
        child: child,
      );
}

/// Grey info line with an (i) icon.
class _Note extends StatelessWidget {
  const _Note(this.child);
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Ico.info, size: 14, color: Tok.text3)),
          const SizedBox(width: 8),
          Expanded(child: DefaultTextStyle.merge(style: Tok.sub.copyWith(fontSize: 12.5, height: 18 / 12.5), child: child)),
        ]),
      );
}

/// Underlined teal text links to other screens.
class _Links extends StatelessWidget {
  const _Links(this.links);
  final List<(String, String)> links;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 18, children: [
        for (final (label, path) in links)
          Pressable(
            onTap: () => context.go(path),
            radius: 4,
            semanticLabel: label,
            child: SizedBox(
              height: 28,
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: Tok.sub.copyWith(
                    fontSize: 12.5,
                    color: Tok.tealDark,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    decorationColor: const Color(0xFF9CCBC4),
                  ),
                ),
              ),
            ),
          ),
      ]);
}

class _WatchNote extends ConsumerWidget {
  const _WatchNote();
  @override
  Widget build(BuildContext context, WidgetRef ref) => _WhiteCard(
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: Tok.inset, borderRadius: BorderRadius.circular(10), border: Border.all(color: Tok.lineInset)),
            child: const Icon(Ico.eye, size: 15, color: Tok.text2),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(ref.watch(stringsProvider)('flags.watchNote'), style: Tok.body)),
        ]),
      );
}

class _DecisionForm extends ConsumerStatefulWidget {
  const _DecisionForm(this.flag, {required this.wardCode, required this.onCancel});
  final Map<String, dynamic> flag;
  final String wardCode;
  final VoidCallback onCancel;
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
    final name = ref.watch(sessionProvider)?.name ?? '';
    final field = OutlineInputBorder(borderRadius: BorderRadius.circular(Tok.rControl), borderSide: const BorderSide(color: Tok.treeLine));
    const choices = ['confirmed', 'needs_explanation', 'not_an_issue'];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Caps(t('flags.form.title')),
      const SizedBox(height: 8),
      Row(children: [
        for (final (i, d) in choices.indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          // Widths fit the English labels in a 440 px panel, incl. the alert icon on a chosen "Confirmed".
          Expanded(
            flex: d == 'needs_explanation' ? 12 : 9,
            child: _Choice(t('decision.$d'), red: d == 'confirmed', selected: _decision == d, onTap: _busy ? null : () => setState(() => _decision = d)),
          ),
        ],
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Text(t('flags.form.note'), style: Tok.body.copyWith(fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(t('flags.form.count', {'n': _note.text.length}), style: Tok.sub),
      ]),
      const SizedBox(height: 6),
      Semantics(
        label: t('flags.form.note'),
        child: TextField(
          controller: _note,
          maxLength: 500,
          minLines: 2,
          maxLines: 3,
          enabled: !_busy,
          onChanged: (_) => setState(() {}),
          style: Tok.body.copyWith(height: 20 / 13),
          decoration: InputDecoration(
            counterText: '',
            hintText: t('flags.form.hint'),
            hintStyle: Tok.body.copyWith(color: Tok.text3),
            isDense: true,
            filled: true,
            fillColor: Tok.panel,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: field,
            enabledBorder: field,
            focusedBorder: field.copyWith(borderSide: const BorderSide(color: Tok.teal, width: 2)),
          ),
        ),
      ),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: Tok.body.copyWith(color: Tok.red))),
      const SizedBox(height: 12),
      Row(children: [
        AppButton.primary(t('flags.form.save'), icon: Ico.check, onPressed: _busy || _decision == null ? null : () => _save(t)),
        const SizedBox(width: 8),
        AppButton.quiet(t('flags.form.cancel'), trailingIcon: null, onPressed: _busy ? null : widget.onCancel),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _decision == null ? t('flags.form.choose') : t('flags.form.savedAs', {'name': name}),
            style: Tok.sub,
            textAlign: TextAlign.end,
          ),
        ),
      ]),
    ]);
  }
}

/// Radio-style decision option. Confirmed turns red when chosen (red = confirmed problem), with an alert icon.
class _Choice extends StatelessWidget {
  const _Choice(this.label, {required this.red, required this.selected, required this.onTap});
  final String label;
  final bool red, selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final redOn = red && selected;
    final accent = redOn ? Tok.red : Tok.teal;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: Pressable(
        onTap: onTap,
        selected: selected,
        semanticLabel: label,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? (redOn ? Tok.redTint : Tok.tealTint) : Tok.panel,
            borderRadius: BorderRadius.circular(Tok.rControl),
            border: Border.all(color: selected ? accent : Tok.treeLine, width: selected ? 1.5 : 1),
            boxShadow: selected ? null : Tok.shadowControl,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: selected ? accent : const Color(0xFF8B9096), width: selected ? 4.5 : 1.5),
              ),
            ),
            const SizedBox(width: 7),
            if (redOn) ...[const Icon(Ico.alert, size: 13, color: Tok.red), const SizedBox(width: 5)],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Tok.body.copyWith(
                  color: redOn ? Tok.red : (selected ? Tok.tealDark : Tok.ink),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

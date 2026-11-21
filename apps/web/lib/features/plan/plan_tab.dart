import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/format.dart' as fmt;
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

final planProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, code) => apiGet(ref, '${wardPath(code)}/plan'));

const _parts = ['severity', 'access', 'safety', 'traffic', 'flood', 'demand'];

/// Cards shown before "Show all".
const _top = 4;

/// The reasons an item ranks where it does, taken from the facts behind its score.
List<String> planReasons(Strings t, Map<String, dynamic> i) => [
      if ((i['hospital_entry_count'] as num) > 0) t('plan.reason.hospital') else if ((i['school_count'] as num) > 0) t('plan.reason.school'),
      if ((i['accidents'] as num) > 0) t('plan.reason.accidents', {'n': i['accidents']}),
      if (i['near_hotspot_id'] != null) t('plan.reason.hotspot'),
      if (i['bus_route'] == true) t('plan.reason.bus'),
      if (i['road_type'] == 'Highway' || i['road_type'] == 'Arterial') t('plan.reason.roadType', {'type': i['road_type']}),
      if ((i['days_open'] as num) >= 14) t('plan.reason.days', {'n': (i['days_open'] as num).round()}),
    ];

/// Open issues ranked by risk, with a method, a cost and the line where the budget runs out.
/// Rendered inside the ward screen, which owns the top bar.
class PlanTab extends ConsumerStatefulWidget {
  const PlanTab(this.code, {super.key});
  final String code;
  @override
  ConsumerState<PlanTab> createState() => _PlanTabState();
}

class _PlanTabState extends ConsumerState<PlanTab> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final code = widget.code;
    return AsyncView(
      value: ref.watch(planProvider(code)),
      onRetry: () => ref.invalidate(planProvider(code)),
      lines: 8,
      builder: (data) {
        final ward = Map<String, dynamic>.from(data['ward']);
        final weights = Map<String, dynamic>.from(data['weights']);
        final items = List<Map<String, dynamic>>.from(data['items']);
        final budget = ward['budget'] as num, spend = ward['spend'] as num, remaining = ward['remaining'] as num;
        final over = remaining <= 0;
        final fit = items.where((i) => i['within_budget'] == true).toList();
        final shown = _all ? items : items.take(_top).toList();
        // Index of the first item the budget cannot cover; the line sits just before it.
        final lineAt = over ? -1 : items.indexWhere((i) => i['within_budget'] != true);
        final fitCost = fit.isEmpty ? 0 : fit.last['cumulative_cost'] as num;
        final rem = remaining - fitCost;

        final head = Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionHeader(t('plan.head.title'), sub: t(over ? 'plan.head.subOver' : 'plan.head.sub', {'code': code}), large: true),
            const SizedBox(height: Tok.s4),
            StatRow(children: [
              StatBlock(icon: Ico.budget, label: t('plan.stat.budget'), value: fmt.money(budget), sub: t('plan.stat.budgetSub', {'code': code})),
              StatBlock(icon: Ico.receipt, label: t('plan.stat.spent'), value: fmt.money(spend), sub: t('plan.stat.spentSub', {'pct': fmt.pct(budget == 0 ? null : spend / budget)})),
              over
                  ? StatBlock(
                      icon: Ico.alert,
                      tone: StatTone.red,
                      label: t('plan.stat.overBy'),
                      value: fmt.money(-remaining),
                      subLead: t('plan.stat.overLead'),
                      sub: t('plan.stat.overSub', {'amount': fmt.money(-remaining), 'budget': fmt.money(budget)}),
                    )
                  : StatBlock(
                      icon: Icons.check_circle_outline,
                      label: t('plan.stat.left'),
                      value: fmt.money(remaining),
                      subLead: t('plan.status.within'),
                      sub: t('plan.stat.leftSub', {'pct': fmt.pct(budget == 0 ? null : remaining / budget)}),
                    ),
              StatBlock(
                icon: Ico.info,
                label: t('plan.stat.open'),
                value: '${items.length}',
                sub: over ? t('plan.stat.openSubOver', {'n': fit.length}) : t('plan.stat.openSub', {'n': fit.length, 'amount': fmt.money(remaining)}),
              ),
            ]),
            const SizedBox(height: Tok.s4),
            const Divider(height: 1, color: Tok.line),
            const SizedBox(height: Tok.s3),
            BudgetBar(budget: budget, spent: spend),
          ]),
        );

        if (items.isEmpty) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [head, const SizedBox(height: Tok.gapPanels), Panel(child: EmptyState(t('plan.empty')))]);

        final rest = items.length - shown.length;
        final ranked = Panel(
          title: t('plan.ranked'),
          sub: t('plan.rankedSub'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (over)
              BudgetLine(t('plan.lineOver'), sub: t('plan.lineOverSub', {'amount': fmt.money(-remaining)}), below: t('plan.lineBelowOver')),
            for (final (n, i) in shown.indexed) ...[
              if (n == lineAt)
                BudgetLine(
                  t('plan.line'),
                  sub: fit.isEmpty
                      ? t('plan.lineSub0', {'left': fmt.money(remaining), 'cost': fmt.money(i['estimated_cost'])})
                      : t('plan.lineSub', {'left': fmt.money(remaining), 'rem': fmt.money(rem), 'n': fit.last['rank'], 'next': i['rank'], 'cost': fmt.money(i['estimated_cost'])}),
                  above: t('plan.lineAbove', {'amount': fmt.money(remaining)}),
                  below: t('plan.lineBelow'),
                )
              else if (n > 0)
                const SizedBox(height: Tok.gapCards),
              _PlanCard(
                i,
                weights: weights,
                status: i['within_budget'] == true
                    ? Pill(t('plan.status.within'), tone: Tone.success, icon: Ico.check)
                    : over || n == lineAt
                        ? Pill(t('plan.status.needs', {'amount': fmt.money(over ? i['estimated_cost'] : (i['cumulative_cost'] as num) - remaining)}), tone: Tone.flag, icon: Ico.alert)
                        : Pill(t('plan.status.below'), icon: Ico.arrowDown),
              ),
            ],
            const SizedBox(height: Tok.s3),
            Row(children: [
              Icon(over ? Ico.alert : Icons.check_circle_outline, size: 15, color: over ? Tok.red : Tok.teal),
              const SizedBox(width: Tok.s2),
              Expanded(
                child: Text.rich(TextSpan(style: Tok.body.copyWith(color: Tok.text2), children: [
                  TextSpan(text: t('plan.footer.fit', {'n': fit.length}), style: const TextStyle(color: Tok.ink, fontWeight: FontWeight.w600)),
                  if (over) ...[
                    TextSpan(text: ' · ${t('plan.footer.overNeed', {'n': shown.length, 'amount': fmt.money(shown.last['cumulative_cost'])})}'),
                    if (rest > 0) TextSpan(text: ' · ${t('plan.footer.more', {'n': rest})}'),
                  ] else ...[
                    TextSpan(text: ' · ${t('plan.footer.total', {'amount': fmt.money(fitCost)})}', style: const TextStyle(color: Tok.ink, fontWeight: FontWeight.w600)),
                    if (items.length > fit.length) TextSpan(text: ' · ${t('plan.footer.below', {'n': items.length - fit.length})}'),
                  ],
                ])),
              ),
              if (items.length > _top)
                AppButton.quiet(
                  _all ? t('plan.showFewer', {'n': _top}) : t('plan.showAll', {'n': items.length}),
                  trailingIcon: _all ? Ico.chevronUp : Ico.arrowRight,
                  onPressed: () => setState(() => _all = !_all),
                ),
            ]),
          ]),
        );

        final side = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _HowPanel(weights),
          const SizedBox(height: Tok.gapPanels),
          over ? _AddPanel(shown: shown, over: -remaining) : _CoversPanel(items: items, fit: fit, remaining: remaining),
        ]);

        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          head,
          if (over) ...[const SizedBox(height: Tok.gapPanels), _OverBanner(over: -remaining, funded: fit.length, total: items.length)],
          const SizedBox(height: Tok.gapPanels),
          LayoutBuilder(
            builder: (_, box) => box.maxWidth >= 1000
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: ranked),
                    const SizedBox(width: Tok.gapPanels),
                    SizedBox(width: 384, child: side),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [ranked, const SizedBox(height: Tok.gapPanels), side]),
          ),
        ]);
      },
    );
  }
}

/// Red banner for an overspent ward: red is for overspend only.
class _OverBanner extends ConsumerWidget {
  const _OverBanner({required this.over, required this.funded, required this.total});
  final num over;
  final int funded, total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final phone = isPhone(context);
    final pill = Pill(t('plan.banner.pill', {'n': funded, 'total': total}), tone: Tone.error, icon: Ico.alert);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
      decoration: BoxDecoration(color: Tok.redTint, borderRadius: BorderRadius.circular(Tok.rPanel), border: Border.all(color: Tok.redLine)),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: Tok.panel, borderRadius: BorderRadius.circular(Tok.rControl), border: Border.all(color: Tok.redLine)),
          child: const Icon(Ico.alert, size: 18, color: Tok.red),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('plan.banner.title'), style: Tok.section),
            Text.rich(TextSpan(style: Tok.body, children: [
              TextSpan(text: t('plan.banner.lead', {'amount': fmt.money(over)}), style: const TextStyle(color: Tok.red, fontWeight: FontWeight.w600)),
              TextSpan(text: ' ${t('plan.banner.rest')}'),
            ])),
            if (phone) ...[const SizedBox(height: 8), pill],
          ]),
        ),
        if (!phone) ...[const SizedBox(width: Tok.s3), pill],
      ]),
    );
  }
}

class _PlanCard extends ConsumerStatefulWidget {
  const _PlanCard(this.i, {required this.weights, required this.status});
  final Map<String, dynamic> i, weights;
  final Widget status;
  @override
  ConsumerState<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends ConsumerState<_PlanCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final i = widget.i;
    final fits = i['within_budget'] == true;
    final risk = i['risk_score'] as num;
    final reasons = planReasons(t, i);
    final strong = Tok.body.copyWith(fontWeight: FontWeight.w600);
    Widget kv(String k, InlineSpan v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 106, child: Text(k, style: Tok.body.copyWith(color: Tok.text2))),
            Expanded(child: Text.rich(TextSpan(style: Tok.body, children: [v]))),
          ]),
        );

    final phone = isPhone(context);
    final partsButton = AppButton.outlined(
      _open ? t('plan.hideParts') : t('plan.scoreParts'),
      trailingIcon: _open ? Ico.chevronUp : Ico.chevronDown,
      onPressed: () => setState(() => _open = !_open),
    );
    // Phone: the risk score and the parts button move under the text instead of beside it.
    final riskBox = SizedBox(
      width: 136,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(t('plan.riskLabel'), style: Tok.body.copyWith(color: Tok.text2)),
          const Spacer(),
          Text.rich(TextSpan(children: [
            TextSpan(text: '${risk.round()}', style: Tok.section),
            TextSpan(text: ' ${t('plan.of', {'max': 100})}', style: Tok.body.copyWith(color: Tok.text2)),
          ])),
        ]),
        const SizedBox(height: 6),
        ProgressBar(risk / 100),
      ]),
    );
    final body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Tok.panel, borderRadius: BorderRadius.circular(Tok.rControl), border: Border.all(color: Tok.line)),
            child: Text('${i['rank']}', style: Tok.figure.copyWith(fontSize: 22)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: Tok.s2, runSpacing: Tok.s1, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text('${i['road_name'] ?? '–'}', style: Tok.cardTitle),
                widget.status,
              ]),
              const SizedBox(height: 2),
              Text(
                [
                  i['category'],
                  t('plan.complaints', {'n': i['complaint_count']}),
                  if (i['segment_no'] != null) t('plan.segment', {'n': i['segment_no']}),
                ].join(' · '),
                style: Tok.sub,
              ),
              if (reasons.isNotEmpty) ...[
                const SizedBox(height: Tok.s2),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final r in reasons) Pill(r, tone: r == t('plan.reason.hospital') ? Tone.success : Tone.info),
                ]),
              ],
              if (phone) ...[const SizedBox(height: Tok.s2), riskBox],
            ]),
          ),
          if (!phone) ...[const SizedBox(width: Tok.s4), riskBox],
        ]),
      ),
      SubCard(
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              kv(
                t('plan.rec'),
                TextSpan(children: [
                  TextSpan(text: '${i['recommended_method']}', style: strong),
                  TextSpan(text: ' · ${t('plan.est', {'amount': ''})}', style: const TextStyle(color: Tok.text2)),
                  TextSpan(text: fmt.money(i['estimated_cost']), style: strong),
                ]),
              ),
              if (i['alt_method'] != null)
                kv(
                  t('plan.altLabel'),
                  TextSpan(
                    text: t('plan.altLine', {'method': i['alt_method'], 'amount': fmt.money(i['alt_cost']), 'pct': fmt.pct(i['alt_reopen_rate'])}),
                    style: const TextStyle(color: Tok.text2),
                  ),
                ),
              if (phone) ...[const SizedBox(height: 8), Align(alignment: Alignment.centerLeft, child: partsButton)],
            ]),
          ),
          if (!phone) ...[const SizedBox(width: Tok.s3), partsButton],
        ]),
      ),
      if (_open) ...[
        const SizedBox(height: 6),
        SubCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (i['alt_method'] != null) ...[
              Text(t(i['high_risk'] == true ? 'plan.why.durable' : 'plan.why.cheap'), style: Tok.sub),
              const SizedBox(height: Tok.s2),
            ],
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(children: [for (final p in _parts.take(3)) _PartRow(p, i, widget.weights)])),
              const SizedBox(width: Tok.s6),
              Expanded(child: Column(children: [for (final p in _parts.skip(3)) _PartRow(p, i, widget.weights)])),
            ]),
            const Divider(height: 17, color: Tok.lineSoft),
            Row(children: [
              Expanded(
                child: Text.rich(TextSpan(style: Tok.body.copyWith(color: Tok.text2), children: [
                  TextSpan(text: t('plan.sum', {'score': fmt.ratio(risk)}), style: strong.copyWith(color: Tok.ink)),
                  TextSpan(text: '  = ${[for (final p in _parts) fmt.ratio(i['pts_$p'] as num)].join(' + ')} · ${t('plan.sumNote')}'),
                ])),
              ),
              AppButton.quiet(t('plan.openTrail'), icon: Ico.trail, onPressed: () => context.go('/trail/issue/${i['issue_id']}')),
            ]),
          ]),
        ),
      ],
    ]);

    // Items the budget covers sit on solid grey cards; items below the line get a dashed edge.
    return fits
        ? InsetCard(child: body)
        : DashedBorder(
            radius: Tok.rCard,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Tok.inset, borderRadius: BorderRadius.circular(Tok.rCard)),
              child: body,
            ),
          );
  }
}

/// One score part: the bar's track length is the most the part can add, the fill is what this item got.
class _PartRow extends ConsumerWidget {
  const _PartRow(this.part, this.i, this.weights);
  final String part;
  final Map<String, dynamic> i, weights;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final pts = i['pts_$part'] as num, max = weights['w_$part'] as num;
    final top = weights.values.fold<num>(1, (a, b) => b as num > a ? b : a);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: 116, child: Text(t('plan.part.$part'), style: Tok.body)),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(widthFactor: (max / top).clamp(0, 1).toDouble(), child: ProgressBar(max == 0 ? 0 : pts / max)),
          ),
        ),
        SizedBox(
          width: 64,
          child: Text.rich(
            textAlign: TextAlign.right,
            TextSpan(style: Tok.body.copyWith(color: Tok.text2), children: [
              TextSpan(text: fmt.ratio(pts), style: const TextStyle(color: Tok.ink, fontWeight: FontWeight.w600)),
              TextSpan(text: ' ${t('plan.of', {'max': fmt.ratio(max)})}'),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// The weights behind the risk score, from the rule settings.
class _HowPanel extends ConsumerWidget {
  const _HowPanel(this.weights);
  final Map<String, dynamic> weights;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    num w(String p) => weights['w_$p'] as num? ?? 0;
    final top = _parts.map(w).fold<num>(1, (a, b) => b > a ? b : a);
    final total = _parts.map(w).fold<num>(0, (a, b) => a + b);
    return Panel(
      title: t('plan.how.title'),
      trailing: Caps(t('plan.how.points')),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final p in _parts)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Tok.lineSoft))),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t('plan.part.$p'), style: Tok.body.copyWith(fontWeight: FontWeight.w500)),
                  Text(t('plan.part.$p.sub'), style: Tok.sub),
                ]),
              ),
              SizedBox(width: 130, child: ProgressBar(w(p) / top)),
              SizedBox(width: 34, child: Text(fmt.ratio(w(p)), textAlign: TextAlign.right, style: Tok.emph)),
            ]),
          ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Tok.line))),
          child: Row(children: [
            Text(t('plan.how.total'), style: Tok.body.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text.rich(TextSpan(style: Tok.body.copyWith(color: Tok.text2), children: [
              TextSpan(text: '${t('plan.how.outOf')} '),
              TextSpan(text: fmt.ratio(total), style: const TextStyle(color: Tok.ink, fontWeight: FontWeight.w600)),
            ])),
          ]),
        ),
        InsetCard(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Ico.filter, size: 14, color: Tok.text3),
            const SizedBox(width: Tok.s2),
            Expanded(child: Text(t('plan.how.note'), style: Tok.sub)),
          ]),
        ),
      ]),
    );
  }
}

/// A small numbered row in the side panels.
class _ListRow extends StatelessWidget {
  const _ListRow({this.rank, required this.label, required this.value, this.running, this.valueColor = Tok.ink, this.strong = false});
  final Object? rank;
  final String label, value;
  final String? running;
  final Color valueColor;
  final bool strong;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
        decoration: BoxDecoration(color: Tok.inset, borderRadius: BorderRadius.circular(8), border: Border.all(color: Tok.lineInset)),
        child: Row(children: [
          if (rank != null) ...[
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Tok.panel, borderRadius: BorderRadius.circular(5), border: Border.all(color: Tok.line)),
              child: Text('$rank', style: Tok.sub.copyWith(fontSize: 11, color: Tok.ink)),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text(label, style: Tok.body.copyWith(fontWeight: strong ? FontWeight.w600 : null), overflow: TextOverflow.ellipsis)),
          Text(value, style: Tok.body.copyWith(color: valueColor, fontWeight: FontWeight.w600)),
          if (running != null) SizedBox(width: 72, child: Text(running!, textAlign: TextAlign.right, style: Tok.body.copyWith(color: Tok.text2))),
        ]),
      );
}

/// Within budget: what the money left pays for, in rank order, up to the budget line.
class _CoversPanel extends ConsumerWidget {
  const _CoversPanel({required this.items, required this.fit, required this.remaining});
  final List<Map<String, dynamic>> items, fit;
  final num remaining;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final fitCost = fit.isEmpty ? 0 : fit.last['cumulative_cost'] as num;
    final rem = remaining - fitCost;
    final next = fit.length < items.length ? items[fit.length] : null;
    return Panel(
      title: t('plan.covers.title', {'amount': fmt.money(remaining)}),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 10,
          child: Row(children: [
            for (final f in fit)
              Expanded(
                flex: (f['estimated_cost'] as num).round() + 1, // +1 keeps flex above zero
                child: Container(
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(color: Tok.teal, borderRadius: BorderRadius.circular(Tok.rPill)),
                ),
              ),
            if (rem > 0)
              Expanded(flex: rem.round() + 1, child: ClipRRect(borderRadius: BorderRadius.circular(Tok.rPill), child: const Hatch.rest())),
          ]),
        ),
        const SizedBox(height: 6),
        Row(children: [
          if (fit.isNotEmpty) Text(t('plan.covers.items', {'n': fit.length, 'amount': fmt.money(fitCost)}), style: Tok.sub),
          const Spacer(),
          Text(t('plan.covers.remains', {'amount': fmt.money(rem)}), style: Tok.sub.copyWith(color: Tok.tealDark, fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(height: Tok.s3),
        for (final f in fit) _ListRow(rank: f['rank'], label: '${f['road_name'] ?? '–'}', value: '– ${fmt.money(f['estimated_cost'])}'),
        _ListRow(label: fit.isEmpty ? t('plan.covers.left') : t('plan.covers.after', {'n': fit.last['rank']}), value: fmt.money(rem), valueColor: Tok.tealDark),
        if (next != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              const Expanded(child: Divider(color: Tok.dash)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: Tok.s2), child: Caps(t('plan.covers.line'))),
              const Expanded(child: Divider(color: Tok.dash)),
            ]),
          ),
          _ListRow(rank: next['rank'], label: '${next['road_name'] ?? '–'}', value: t('plan.covers.needs', {'amount': fmt.money(next['estimated_cost'])})),
          Row(children: [
            const Icon(Ico.alert, size: 14, color: Tok.amberIcon),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                t('plan.covers.short', {'amount': fmt.money((next['estimated_cost'] as num) - rem), 'rem': fmt.money(rem)}),
                style: Tok.sub.copyWith(color: Tok.amberText, fontWeight: FontWeight.w500),
              ),
            ),
          ]),
          const SizedBox(height: Tok.s3),
          Text(t('plan.covers.note'), style: Tok.sub),
        ] else ...[
          const SizedBox(height: 6),
          Text(t('plan.covers.allFit'), style: Tok.sub),
        ],
      ]),
    );
  }
}

/// Overspent: what extra money the top items would need, with a running total.
class _AddPanel extends ConsumerWidget {
  const _AddPanel({required this.shown, required this.over});
  final List<Map<String, dynamic>> shown;
  final num over;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    return Panel(
      title: t('plan.add.title'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(color: Tok.redTint, borderRadius: BorderRadius.circular(Tok.rControl), border: Border.all(color: Tok.redLine)),
          child: Row(children: [
            const Icon(Ico.alert, size: 14, color: Tok.red),
            const SizedBox(width: 8),
            Expanded(child: Text(t('plan.add.over', {'amount': fmt.money(over)}), style: Tok.body.copyWith(color: Tok.red, fontWeight: FontWeight.w600))),
          ]),
        ),
        const SizedBox(height: Tok.s3),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
          child: Row(children: [
            Expanded(child: Caps(t('plan.add.item'))),
            Caps(t('plan.add.needs')),
            SizedBox(width: 72, child: Align(alignment: Alignment.centerRight, child: Caps(t('plan.add.running')))),
          ]),
        ),
        for (final i in shown)
          _ListRow(rank: i['rank'], label: '${i['road_name'] ?? '–'}', value: fmt.money(i['estimated_cost']), running: fmt.money(i['cumulative_cost'])),
        _ListRow(label: t('plan.add.total', {'n': shown.length}), value: fmt.money(shown.last['cumulative_cost']), strong: true),
      ]),
    );
  }
}

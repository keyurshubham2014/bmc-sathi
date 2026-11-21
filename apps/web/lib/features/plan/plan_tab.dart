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
class PlanTab extends ConsumerWidget {
  const PlanTab(this.code, {super.key});
  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final c = SathiColors.of(context);
    final tt = Theme.of(context).textTheme;
    return AsyncView(
      value: ref.watch(planProvider(code)),
      onRetry: () => ref.invalidate(planProvider(code)),
      lines: 8,
      builder: (data) {
        final ward = Map<String, dynamic>.from(data['ward']);
        final weights = Map<String, dynamic>.from(data['weights']);
        final items = List<Map<String, dynamic>>.from(data['items']);
        final remaining = ward['remaining'] as num;
        final over = remaining <= 0;
        final fit = items.where((i) => i['within_budget'] == true).toList();
        final header = Container(
          padding: const EdgeInsets.all(Gap.lg),
          decoration: BoxDecoration(color: over ? c.errorTint : c.surface, borderRadius: BorderRadius.circular(kRadius), border: Border.all(color: over ? c.error : c.border)),
          child: Row(children: [
            Icon(over ? Icons.warning_amber_outlined : Icons.account_balance_wallet_outlined, color: over ? c.error : c.primary),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Text(
                over ? t('plan.over', {'amount': fmt.money(-remaining)}) : t('plan.left', {'amount': fmt.money(remaining), 'budget': fmt.money(ward['budget'])}),
                style: tt.titleMedium!.copyWith(color: over ? c.error : c.textPrimary),
              ),
            ),
          ]),
        );
        if (items.isEmpty) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, const SizedBox(height: Gap.lg), SectionCard(child: EmptyState(t('plan.empty')))]);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          header,
          const SizedBox(height: Gap.lg),
          for (final (n, i) in items.indexed) ...[
            // The line sits just before the first item the budget cannot cover.
            if (!over && i['within_budget'] != true && (n == 0 || items[n - 1]['within_budget'] == true)) _BudgetLine(t('plan.line')),
            _PlanCard(i, weights: weights, remaining: remaining, showShortfall: !over),
            const SizedBox(height: Gap.sm),
          ],
          const SizedBox(height: Gap.sm),
          Text(
            t('plan.footer', {'n': fit.length, 'total': items.length, 'amount': fmt.money(fit.isEmpty ? 0 : fit.last['cumulative_cost'])}),
            style: tt.labelLarge,
          ),
        ]);
      },
    );
  }
}

class _BudgetLine extends StatelessWidget {
  const _BudgetLine(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = SathiColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      child: Row(children: [
        Expanded(child: Container(height: 2, color: c.textPrimary)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.md),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.content_cut, size: 16, color: c.textPrimary),
            const SizedBox(width: Gap.xs),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
          ]),
        ),
        Expanded(child: Container(height: 2, color: c.textPrimary)),
      ]),
    );
  }
}

class _PlanCard extends ConsumerStatefulWidget {
  const _PlanCard(this.i, {required this.weights, required this.remaining, required this.showShortfall});
  final Map<String, dynamic> i, weights;
  final num remaining;
  final bool showShortfall;
  @override
  ConsumerState<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends ConsumerState<_PlanCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final c = SathiColors.of(context);
    final tt = Theme.of(context).textTheme;
    final i = widget.i;
    final fits = i['within_budget'] == true;
    final reasons = planReasons(t, i);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.primaryContainer, borderRadius: BorderRadius.circular(kRadius)),
                child: Text('${i['rank']}', style: tt.titleMedium!.copyWith(color: c.primary)),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${i['road_name'] ?? '–'}${i['segment_no'] == null ? '' : ' · ${i['segment_no']}'}  ·  ${i['category']}', style: tt.titleMedium),
                  Text('${t('plan.complaints', {'n': i['complaint_count']})} · ${t('plan.severity', {'n': i['severity']})}', style: tt.bodySmall),
                ]),
              ),
              const SizedBox(width: Gap.md),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(t('plan.risk', {'score': (i['risk_score'] as num).round()}), style: tt.titleMedium),
                Icon(_open ? Icons.expand_less : Icons.expand_more, size: 18, color: c.textSecondary),
              ]),
            ]),
            if (reasons.isNotEmpty) ...[
              const SizedBox(height: Gap.sm),
              Wrap(spacing: Gap.sm, runSpacing: Gap.xs, children: [for (final r in reasons) Pill(r, tone: Tone.info)]),
            ],
            const SizedBox(height: Gap.md),
            Wrap(spacing: Gap.md, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('${t('plan.method')}: ${i['recommended_method']}', style: tt.labelLarge),
              Text(t('plan.est', {'amount': fmt.money(i['estimated_cost'])}), style: tt.labelLarge),
              Text(t('plan.reopens', {'pct': fmt.pct(i['recommended_reopen_rate'])}), style: tt.bodySmall),
              if (widget.showShortfall && !fits) Pill(t('plan.needs', {'amount': fmt.money((i['cumulative_cost'] as num) - widget.remaining)}), tone: Tone.flag),
            ]),
            if (i['alt_method'] != null)
              Padding(
                padding: const EdgeInsets.only(top: Gap.xs),
                child: Text(t('plan.alt', {'method': i['alt_method'], 'amount': fmt.money(i['alt_cost']), 'pct': fmt.pct(i['alt_reopen_rate'])}), style: tt.bodySmall),
              ),
            if (_open) ...[
              const Divider(height: Gap.xl),
              if (i['alt_method'] != null) Padding(padding: const EdgeInsets.only(bottom: Gap.md), child: Text(t(i['high_risk'] == true ? 'plan.why.durable' : 'plan.why.cheap'), style: tt.bodyMedium)),
              Text(t('plan.breakdown'), style: tt.labelLarge),
              const SizedBox(height: Gap.sm),
              for (final p in _parts) _PartBar(label: t('plan.part.$p'), pts: i['pts_$p'] as num, max: widget.weights['w_$p'] as num),
              Row(children: [
                Expanded(child: Text(t('plan.cumulative', {'amount': fmt.money(i['cumulative_cost'])}), style: tt.bodySmall)),
                TextButton.icon(onPressed: () => context.go('/trail/issue/${i['issue_id']}'), icon: const Icon(Icons.timeline_outlined, size: 18), label: Text(t('plan.trail'))),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}

class _PartBar extends ConsumerWidget {
  const _PartBar({required this.label, required this.pts, required this.max});
  final String label;
  final num pts, max;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SathiColors.of(context);
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Row(children: [
        SizedBox(width: 190, child: Text(label, style: tt.bodySmall)),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: max == 0 ? 0 : (pts / max).clamp(0, 1).toDouble(), minHeight: 8, backgroundColor: c.surfaceAlt, color: c.accent))),
        SizedBox(width: 84, child: Text(ref.watch(stringsProvider)('plan.points', {'pts': fmt.ratio(pts), 'max': fmt.ratio(max)}), style: tt.bodySmall, textAlign: TextAlign.end)),
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/format.dart' as fmt;
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../ask/ask.dart';

final contractorsProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) async => List<Map<String, dynamic>>.from((await apiGet(ref, '/contractors'))['items']));
final contractorProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) => apiGet(ref, '/contractors/$id'));
final wardScorecardProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, code) => apiGet(ref, '${wardPath(code)}/scorecard'));

/// Contractors in name order. No rank numbers and no sorting by performance.
class ContractorListScreen extends ConsumerWidget {
  const ContractorListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final tt = Theme.of(context).textTheme;
    return AsyncView(
      value: ref.watch(contractorsProvider),
      onRetry: () => ref.invalidate(contractorsProvider),
      lines: 8,
      builder: (items) => PageBody(children: [
        Text(t('contractors.title'), style: tt.titleLarge),
        Text(t('contractors.note'), style: tt.bodyMedium!.copyWith(color: SathiColors.of(context).textSecondary)),
        LayoutBuilder(builder: (_, box) {
          final cols = box.maxWidth >= 1000 ? 2 : 1;
          final w = (box.maxWidth - Gap.lg * (cols - 1)) / cols;
          return Wrap(spacing: Gap.lg, runSpacing: Gap.lg, children: [
            for (final c in items)
              SizedBox(
                width: w,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.go('/contractors/${c['contractor_id']}'),
                    child: Padding(
                      padding: const EdgeInsets.all(Gap.lg),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${c['contractor_name']}', style: tt.titleMedium),
                            Text(t('sc.summary', {'n': fmt.count(c['jobs']), 'amount': fmt.money(c['spend']), 'wards': c['wards']}), style: tt.bodySmall),
                          ]),
                        ),
                        Icon(Icons.chevron_right, color: SathiColors.of(context).textSecondary),
                      ]),
                    ),
                  ),
                ),
              ),
          ]);
        }),
      ]),
    );
  }
}

class ContractorScreen extends ConsumerWidget {
  const ContractorScreen(this.id, {super.key});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final tt = Theme.of(context).textTheme;
    return AsyncView(
      value: ref.watch(contractorProvider(id)),
      onRetry: () => ref.invalidate(contractorProvider(id)),
      lines: 8,
      builder: (data) {
        final s = Map<String, dynamic>.from(data['scorecard']);
        return PageBody(children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(onPressed: () => context.go('/contractors'), icon: const Icon(Icons.arrow_back, size: 18), label: Text(t('contractors.title'))),
          ),
          Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: Gap.lg, runSpacing: Gap.sm, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('${data['contractor']['contractor_name']}', style: tt.titleLarge),
              Text(t('sc.summary', {'n': fmt.count(s['jobs']), 'amount': fmt.money(s['spend']), 'wards': s['wards']}), style: tt.bodyMedium),
            ]),
            AskButton('contractor', id),
          ]),
          ScorecardView(s, workOrdersUrl: '/contractors/$id/work-orders'),
        ]);
      },
    );
  }
}

/// Three measures against similar jobs. No overall grade.
class ScorecardView extends ConsumerWidget {
  const ScorecardView(this.s, {super.key, required this.workOrdersUrl});
  final Map<String, dynamic> s;
  final String workOrdersUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final c = SathiColors.of(context);
    final tt = Theme.of(context).textTheme;
    final m = Map<String, dynamic>.from(s['measures']);
    void open(String title, String filter) => showDetail(context, title: title, child: WorkOrderList('$workOrdersUrl?filter=$filter'));
    final cost = Map<String, dynamic>.from(m['cost']);
    final cards = [
      _RateCard(title: t('sc.speed'), icon: Icons.schedule_outlined, m: Map<String, dynamic>.from(m['speed']), obsKey: 'sc.speed.obs', link: t('sc.seeLate'), onOpen: () => open(t('sc.seeLate'), 'sla_missed')),
      _RateCard(title: t('sc.durability'), icon: Icons.verified_outlined, m: Map<String, dynamic>.from(m['durability']), obsKey: 'sc.durability.obs', link: t('sc.seeReopened'), onOpen: () => open(t('sc.seeReopened'), 'reopened')),
      _MeasureCard(
        title: t('sc.cost'),
        icon: Icons.currency_rupee,
        band: '${cost['band']}',
        headline: t('sc.cost.obs', {'ratio': fmt.ratio(cost['observed'])}),
        body: Text(t('sc.cost.flagged', {'n': cost['flagged']}), style: tt.bodyMedium),
        link: t('sc.seeOver'),
        onOpen: (cost['flagged'] as num) > 0 ? () => open(t('sc.seeOver'), 'overbilled') : null,
      ),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(builder: (_, box) {
        final cols = box.maxWidth >= 1000 ? 3 : 1;
        final w = (box.maxWidth - Gap.lg * (cols - 1)) / cols;
        return Wrap(spacing: Gap.lg, runSpacing: Gap.lg, children: [for (final card in cards) SizedBox(width: w, child: card)]);
      }),
      const SizedBox(height: Gap.lg),
      Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(color: c.infoTint, borderRadius: BorderRadius.circular(kRadius)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.cloud_outlined, size: 18, color: c.info),
          const SizedBox(width: Gap.sm),
          Expanded(child: Text(t('sc.context', {'rain': s['heavy_rain_jobs'], 'low': s['low_lying_jobs'], 'n': s['jobs']}), style: TextStyle(color: c.textPrimary))),
        ]),
      ),
      const SizedBox(height: Gap.lg),
      Card(
        child: ExpansionTile(
          title: Text(t('sc.how'), style: tt.titleMedium),
          shape: const Border(),
          childrenPadding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
          expandedAlignment: Alignment.centerLeft,
          children: [Text(t('sc.how.body'), style: tt.bodyMedium)],
        ),
      ),
    ]);
  }
}

/// Band label. Amber, never red: a gap from similar jobs is a prompt to look, not a verdict.
class BandChip extends ConsumerWidget {
  const BandChip(this.band, {super.key});
  final String band;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (tone, icon) = switch (band) {
      'well_above' || 'above' => (Tone.success, Icons.arrow_upward),
      'well_below' || 'below' => (Tone.flag, Icons.arrow_downward),
      'review' => (Tone.flag, Icons.search),
      'too_few' => (Tone.neutral, Icons.more_horiz),
      _ => (Tone.neutral, Icons.drag_handle),
    };
    return Pill(ref.watch(stringsProvider)('band.$band'), tone: tone, icon: icon);
  }
}

class _MeasureCard extends StatelessWidget {
  const _MeasureCard({required this.title, required this.icon, required this.band, required this.headline, required this.body, required this.link, this.onOpen});
  final String title, band, headline, link;
  final IconData icon;
  final Widget body;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final c = SathiColors.of(context);
    final tt = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, size: 18, color: c.textSecondary), const SizedBox(width: Gap.sm), Text(title, style: tt.labelLarge!.copyWith(color: c.textSecondary))]),
          const SizedBox(height: Gap.sm),
          Text(headline, style: tt.titleLarge),
          const SizedBox(height: Gap.sm),
          BandChip(band),
          const SizedBox(height: Gap.md),
          body,
          if (onOpen != null) ...[
            const SizedBox(height: Gap.sm),
            TextButton.icon(onPressed: onOpen, icon: const Icon(Icons.list_alt_outlined, size: 18), label: Text(link), style: TextButton.styleFrom(padding: EdgeInsets.zero)),
          ],
        ]),
      ),
    );
  }
}

/// A rate measure (speed or durability) with this record beside what similar jobs achieved.
class _RateCard extends ConsumerWidget {
  const _RateCard({required this.title, required this.icon, required this.m, required this.obsKey, required this.link, required this.onOpen});
  final String title, obsKey, link;
  final IconData icon;
  final Map<String, dynamic> m;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final c = SathiColors.of(context);
    final tt = Theme.of(context).textTheme;
    final few = m['band'] == 'too_few';
    Widget bar(String label, num? v, Color color) => Padding(
          padding: const EdgeInsets.only(bottom: Gap.sm),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(label, style: tt.bodySmall)), Text(fmt.pct(v), style: tt.labelLarge)]),
            const SizedBox(height: 2),
            ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: (v ?? 0).toDouble().clamp(0, 1), minHeight: 8, backgroundColor: c.surfaceAlt, color: color)),
          ]),
        );
    return _MeasureCard(
      title: title,
      icon: icon,
      band: '${m['band']}',
      headline: t(obsKey, {'pct': fmt.pct(m['observed'])}),
      link: link,
      onOpen: onOpen,
      // With too few jobs a comparison would mislead, so it is left out.
      body: few ? const SizedBox.shrink() : Column(children: [bar(t('sc.this'), m['observed'], c.primary), bar(t('sc.similar'), m['expected'], c.borderStrong)]),
    );
  }
}

/// The Scorecard tab on a ward page.
class WardScorecardTab extends ConsumerWidget {
  const WardScorecardTab(this.code, {super.key});
  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncView(
        value: ref.watch(wardScorecardProvider(code)),
        onRetry: () => ref.invalidate(wardScorecardProvider(code)),
        builder: (data) => ScorecardView(Map<String, dynamic>.from(data['scorecard']), workOrdersUrl: '${wardPath(code)}/work-orders'),
      );
}

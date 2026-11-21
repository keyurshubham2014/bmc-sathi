import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/format.dart' as fmt;
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../ask/ask.dart';
import '../contractors/scorecard.dart';
import '../plan/plan_tab.dart';
import 'city_screen.dart';

final wardDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, code) => apiGet(ref, wardPath(code)));

final breakdownProvider = FutureProvider.family<List<Map<String, dynamic>>, (String, String)>((ref, a) async =>
    List<Map<String, dynamic>>.from((await apiGet(ref, '${wardPath(a.$1)}/breakdown', {'dimension': a.$2}))['items']));

class WardScreen extends ConsumerWidget {
  const WardScreen(this.code, {super.key, this.tab = 'money'});
  final String code, tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final tt = Theme.of(context).textTheme;
    final session = ref.watch(sessionProvider)!;
    return AsyncView(
      value: ref.watch(wardDetailProvider(code)),
      onRetry: () => ref.invalidate(wardDetailProvider(code)),
      lines: 8,
      builder: (data) {
        final w = Map<String, dynamic>.from(data['ward']);
        return PageBody(children: [
          Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: Gap.lg, runSpacing: Gap.sm, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(t('ward.label', {'code': code}), style: tt.titleLarge),
              Text('${w['ward_name']} · ${w['zone']}', style: tt.bodyMedium!.copyWith(color: SathiColors.of(context).textSecondary)),
            ]),
            // A ward officer is tied to one ward; everyone else can move between wards.
            Wrap(spacing: Gap.md, runSpacing: Gap.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
              AskButton('ward', code),
              if (!session.isOfficer) _WardPicker(code),
            ]),
          ]),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [for (final k in ['money', 'plan', 'scorecard']) ButtonSegment(value: k, label: Text(t('ward.tab.$k')))],
            selected: {tab},
            onSelectionChanged: (s) => context.go('/ward/${wardSlug(code)}?tab=${s.first}'),
          ),
          if (tab == 'money') ..._money(context, ref, w, session) else if (tab == 'plan') PlanTab(code) else WardScorecardTab(code),
        ]);
      },
    );
  }

  List<Widget> _money(BuildContext context, WidgetRef ref, Map<String, dynamic> w, Session session) {
    final t = ref.watch(stringsProvider);
    final base = '${wardPath(code)}/work-orders';
    void open(String title, String query) => showDetail(context, title: title, child: WorkOrderList('$base?$query'));
    return [
      _BudgetCard(w, onTap: () => open(t('ward.allJobs', {'n': w['jobs']}), 'filter=all')),
      LayoutBuilder(builder: (_, box) {
        final cols = box.maxWidth >= 840 ? 3 : 1;
        final width = (box.maxWidth - Gap.lg * (cols - 1)) / cols;
        return Wrap(spacing: Gap.lg, runSpacing: Gap.lg, children: [
          SizedBox(width: width, child: StatTile(label: t('ward.tile.reopened'), value: fmt.money(w['reopened_spend']), sub: t('ward.jobs', {'n': w['reopened_jobs']}), onTap: () => open(t('ward.tile.reopened'), 'filter=reopened'))),
          SizedBox(width: width, child: StatTile(label: t('ward.tile.dlp'), value: fmt.money(w['dlp_spend']), sub: t('ward.jobs', {'n': w['dlp_jobs']}), onTap: () => open(t('ward.tile.dlp'), 'filter=dlp'))),
          // Citizens see the amount in open flags, not the queue behind it.
          SizedBox(width: width, child: StatTile(label: t('ward.tile.flags'), value: fmt.money(w['open_flag_amount']), sub: t('ward.flagsN', {'n': w['open_flags']}), tone: Tone.flag, onTap: session.canSeeFlags ? () => context.go('/flags?ward=${Uri.encodeComponent(code)}') : null)),
        ]);
      }),
      _Breakdown(code, onOpen: open),
    ];
  }
}

class _WardPicker extends ConsumerWidget {
  const _WardPicker(this.code);
  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wards = ref.watch(wardsProvider).value ?? const [];
    final codes = [for (final w in wards) w['ward_code'] as String]..sort();
    if (codes.isEmpty) return const SizedBox.shrink();
    return DropdownMenu<String>(
      initialSelection: code,
      label: Text(ref.watch(stringsProvider)('ward.choose')),
      width: 160,
      dropdownMenuEntries: [for (final c in codes) DropdownMenuEntry(value: c, label: c)],
      onSelected: (c) => c == null ? null : context.goWard(c),
    );
  }
}

class _BudgetCard extends ConsumerWidget {
  const _BudgetCard(this.w, {required this.onTap});
  final Map<String, dynamic> w;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final c = SathiColors.of(context);
    final tt = Theme.of(context).textTheme;
    final share = (w['spend_share'] as num).toDouble();
    final over = share > 1;
    Widget fig(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(label, style: tt.labelMedium), Text(value, style: tt.headlineMedium)]);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: Gap.xxl, runSpacing: Gap.md, children: [fig(t('ward.budget'), fmt.money(w['budget'])), fig(t('ward.spent'), fmt.money(w['spend']))]),
            const SizedBox(height: Gap.md),
            // The bar fills to 100% of budget. Past that it turns red and the words say by how much.
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: share.clamp(0, 1), minHeight: 12, backgroundColor: c.surfaceAlt, color: over ? c.error : c.accent),
            ),
            const SizedBox(height: Gap.sm),
            Row(children: [
              if (over) ...[Icon(Icons.warning_amber_outlined, size: 18, color: c.error), const SizedBox(width: Gap.xs)],
              Expanded(
                child: Text(
                  over ? t('ward.overBy', {'amount': fmt.money(-(w['remaining'] as num)), 'pct': fmt.pct(share)}) : t('ward.leftOf', {'amount': fmt.money(w['remaining']), 'pct': fmt.pct(share)}),
                  style: tt.labelLarge!.copyWith(color: over ? c.error : c.textPrimary),
                ),
              ),
              Text(t('ward.allJobs', {'n': w['jobs']}), style: tt.bodySmall),
              Icon(Icons.chevron_right, size: 18, color: c.textSecondary),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Breakdown extends ConsumerStatefulWidget {
  const _Breakdown(this.code, {required this.onOpen});
  final String code;
  final void Function(String title, String query) onOpen;
  @override
  ConsumerState<_Breakdown> createState() => _BreakdownState();
}

class _BreakdownState extends ConsumerState<_Breakdown> {
  String _dim = 'contractor';

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final key = (widget.code, _dim);
    const param = {'contractor': 'contractor_id', 'method': 'method', 'week': 'week'};
    return SectionCard(
      title: t('ward.spendBy'),
      trailing: SegmentedButton<String>(
        showSelectedIcon: false,
        segments: [for (final d in param.keys) ButtonSegment(value: d, label: Text(t('ward.dim.$d')))],
        selected: {_dim},
        onSelectionChanged: (s) => setState(() => _dim = s.first),
      ),
      child: AsyncView(
        value: ref.watch(breakdownProvider(key)),
        onRetry: () => ref.invalidate(breakdownProvider(key)),
        builder: (items) => items.isEmpty
            ? EmptyState(t('wo.empty'))
            : BarList([
                for (final i in items)
                  BarItem(
                    label: '${i['label']}',
                    value: i['spend'],
                    sub: t('ward.jobs', {'n': i['jobs']}),
                    onTap: () => widget.onOpen('${i['label']}', '${param[_dim]}=${Uri.encodeQueryComponent('${i['key']}')}'),
                  ),
              ]),
      ),
    );
  }
}

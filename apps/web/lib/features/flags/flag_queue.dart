import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/format.dart' as fmt;
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'flag_detail.dart';

/// The four tabs: (key, flag type, tier).
const flagTabs = [('overbilled', 'overbilled', 'flag'), ('duplicate', 'duplicate', 'flag'), ('dlp', 'dlp', 'flag'), ('watch', 'overbilled', 'watch')];

typedef FlagQuery = ({String type, String tier, String? decision, String? ward});

final flagsProvider = FutureProvider.family<Map<String, dynamic>, FlagQuery>((ref, q) =>
    apiGet(ref, '/flags', {'type': q.type, 'tier': q.tier, 'decision': q.decision, 'ward_code': q.ward, 'limit': 200}));

final flagSummaryProvider = FutureProvider.family<List<Map<String, dynamic>>, String?>((ref, ward) async =>
    List<Map<String, dynamic>>.from((await apiGet(ref, '/flags/summary', {'ward_code': ward}))['items']));

/// One plain sentence saying what the data shows, built from the evidence so it reads the same every time.
String flagReason(Strings t, Map<String, dynamic> f) {
  final e = Map<String, dynamic>.from(f['evidence']);
  if (f['tier'] == 'watch') return t('flags.reason.watch', {'ratio': fmt.ratio(e['ratio'])});
  return switch (f['flag_type']) {
    'overbilled' => t('flags.reason.overbilled', {'ratio': fmt.ratio(e['ratio']), 'method': e['method']}),
    'duplicate' => t('flags.reason.duplicate', {'earlier': e['earlier_work_order_id'], 'days': fmt.ratio(e['days_apart'])}),
    _ => t('flags.reason.dlp'),
  };
}

class FlagQueueScreen extends ConsumerStatefulWidget {
  const FlagQueueScreen({super.key});
  @override
  ConsumerState<FlagQueueScreen> createState() => _QueueState();
}

class _QueueState extends ConsumerState<FlagQueueScreen> {
  int _tab = 0;
  String _decision = 'open'; // open | decided | all
  (String, String)? _selected;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final tt = Theme.of(context).textTheme;
    final session = ref.watch(sessionProvider)!;
    // An officer is always limited to their ward by the server; an auditor may arrive filtered from a ward page.
    final ward = session.isOfficer ? session.wardCode : GoRouterState.of(context).uri.queryParameters['ward'];
    final (_, type, tier) = flagTabs[_tab];
    final query = (type: type, tier: tier, decision: _decision == 'open' ? 'open' : null, ward: ward);
    final wide = MediaQuery.sizeOf(context).width >= 1200;
    final summary = ref.watch(flagSummaryProvider(ward)).value ?? const [];

    num agg(String type, String tier, String field, {bool? open}) => summary
        .where((s) => s['flag_type'] == type && s['tier'] == tier && (open == null || (s['decision'] == 'open') == open))
        .fold<num>(0, (a, s) => a + (s[field] as num));

    final list = AsyncView(
      value: ref.watch(flagsProvider(query)),
      onRetry: () => ref.invalidate(flagsProvider(query)),
      lines: 8,
      builder: (data) {
        var items = List<Map<String, dynamic>>.from(data['items']);
        if (_decision == 'decided') items = items.where((f) => f['decision'] != 'open').toList();
        if (items.isEmpty) return EmptyState(t('flags.empty'));
        return Column(children: [
          for (final f in items)
            _FlagRow(f, selected: _selected == (f['flag_type'], f['work_order_id']) && wide, onTap: () {
              if (wide) {
                setState(() => _selected = (f['flag_type'] as String, f['work_order_id'] as String));
              } else {
                context.push('/flags/${f['flag_type']}/${f['work_order_id']}');
              }
            }),
        ]);
      },
    );

    final queue = PageBody(children: [
      Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: Gap.lg, runSpacing: Gap.sm, children: [
        Text(ward == null ? t('flags.title') : '${t('flags.title')} · ${t('ward.label', {'code': ward})}', style: tt.titleLarge),
        Text(
          t('flags.strip', {
            'open': fmt.count(agg(type, tier, 'count', open: true)),
            'amount': fmt.money(agg(type, tier, 'amount', open: true)),
            'decided': fmt.count(agg(type, tier, 'count', open: false)),
          }),
          style: tt.labelLarge,
        ),
      ]),
      Wrap(spacing: Gap.sm, runSpacing: Gap.sm, children: [
        for (final (i, (key, ty, ti)) in flagTabs.indexed)
          ChoiceChip(
            label: Text('${t('flags.tab.$key')} · ${fmt.count(agg(ty, ti, 'count'))}'),
            selected: _tab == i,
            onSelected: (_) => setState(() {
              _tab = i;
              _selected = null;
            }),
          ),
      ]),
      if (tier == 'flag')
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [for (final k in ['open', 'decided', 'all']) ButtonSegment(value: k, label: Text(t('flags.filter.$k')))],
            selected: {_decision},
            onSelectionChanged: (s) => setState(() => _decision = s.first),
          ),
        ),
      SectionCard(padding: const EdgeInsets.symmetric(vertical: Gap.sm), child: list),
    ]);

    if (!wide) return queue;
    final c = SathiColors.of(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: queue),
      Container(
        width: 460,
        decoration: BoxDecoration(color: c.surface, border: Border(left: BorderSide(color: c.border))),
        child: _selected == null ? EmptyState(t('flags.select'), icon: Icons.touch_app_outlined) : FlagDetail(_selected!.$1, _selected!.$2, key: ValueKey(_selected)),
      ),
    ]);
  }
}

class _FlagRow extends ConsumerWidget {
  const _FlagRow(this.f, {required this.selected, required this.onTap});
  final Map<String, dynamic> f;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final c = SathiColors.of(context);
    final tt = Theme.of(context).textTheme;
    return Material(
      color: selected ? c.primaryContainer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: Gap.sm, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text('${f['work_order_id']}', style: tt.labelLarge),
                  Text('${t('ward.label', {'code': f['ward_code']})} · ${f['road_name']}', style: tt.bodyMedium),
                ]),
                Text('${f['contractor_name']}', style: tt.bodySmall),
                const SizedBox(height: Gap.xs),
                Text(flagReason(t, f), style: tt.bodyMedium),
              ]),
            ),
            const SizedBox(width: Gap.md),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fmt.money(f['amount_at_stake']), style: tt.titleMedium),
              Text(t('flags.atStake'), style: tt.bodySmall),
              const SizedBox(height: Gap.xs),
              if (f['tier'] == 'flag') DecisionChip('${f['decision']}'),
            ]),
          ]),
        ),
      ),
    );
  }
}

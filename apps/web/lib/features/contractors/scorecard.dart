import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/format.dart' as fmt;
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../ask/ask.dart';

final contractorsProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) async => List<Map<String, dynamic>>.from((await apiGet(ref, '/contractors'))['items']));
final contractorProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) => apiGet(ref, '/contractors/$id'));
final wardScorecardProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, code) => apiGet(ref, '${wardPath(code)}/scorecard'));

/// Fewest jobs before a band is shown (server setting `band_min_jobs`).
const _minJobs = 30;

/// 26 px page heading used in the hero panels.
final _hero = Tok.section.copyWith(fontSize: 26, height: 32 / 26, letterSpacing: -0.4);

/// Splits "Name (synthetic)" so the tag can be drawn grey; the stored value is shown in full either way.
Widget _name(String name, TextStyle style) {
  const tag = ' (synthetic)';
  final has = name.endsWith(tag);
  return Text.rich(TextSpan(children: [
    TextSpan(text: has ? name.substring(0, name.length - tag.length) : name, style: style),
    if (has) TextSpan(text: tag, style: style.copyWith(color: Tok.text2, fontWeight: FontWeight.w400)),
  ]));
}

/// Contractors in name order (the API sorts by name). No rank numbers and no sorting by performance.
class ContractorListScreen extends ConsumerWidget {
  const ContractorListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    return SetTopBar(
      title: t('contractors.title'),
      child: AsyncView(
        value: ref.watch(contractorsProvider),
        onRetry: () => ref.invalidate(contractorsProvider),
        lines: 8,
        builder: (items) {
          final jobs = items.fold<num>(0, (a, c) => a + (c['jobs'] as num? ?? 0));
          final spend = items.fold<num>(0, (a, c) => a + (c['spend'] as num? ?? 0));
          void open(int i) => context.go('/contractors/${items[i]['contractor_id']}');
          return PageBody(children: [
            Panel(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(t('contractors.title'), style: _hero),
                const SizedBox(height: 6),
                Text(t('contractors.lead', {'n': items.length}), style: Tok.body.copyWith(color: Tok.text2)),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Tok.line),
                const SizedBox(height: 14),
                StatRow(children: [
                  StatBlock(icon: Ico.contractor, label: t('contractors.title'), value: '${items.length}', sub: t('contractors.allShown')),
                  StatBlock(icon: Ico.receipt, label: t('scorecard.jobs'), value: fmt.count(jobs), sub: t('scorecard.jobsSub')),
                  StatBlock(icon: Ico.budget, label: t('scorecard.spend'), value: fmt.money(spend), sub: t('scorecard.spendSub')),
                  _TextStat(icon: Ico.sort, label: t('contractors.order'), body: t('contractors.orderBody')),
                ]),
              ]),
            ),
            Panel(
              title: t('contractors.all'),
              sub: t('contractors.allSub'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Ico.sort, size: 14, color: Tok.text3),
                const SizedBox(width: 5),
                Text(t('contractors.az'), style: Tok.body.copyWith(color: Tok.text2)),
              ]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                WorksTable(
                  columns: [
                    WorksColumn(t('contractors.col.name'), flex: 3, sorted: false),
                    WorksColumn(t('scorecard.jobs'), numeric: true),
                    WorksColumn(t('scorecard.spend'), numeric: true),
                    WorksColumn(t('scorecard.wards'), numeric: true),
                    const WorksColumn('', width: 170),
                  ],
                  rows: [
                    for (final c in items)
                      [
                        _name('${c['contractor_name']}', Tok.body.copyWith(fontWeight: FontWeight.w500)),
                        Text(fmt.count(c['jobs'] as num? ?? 0)),
                        Text(fmt.money(c['spend'])),
                        Text('${c['wards']}'),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(t('contractors.open'), style: Tok.body.copyWith(color: Tok.tealDark, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 6),
                          const Icon(Ico.arrowRight, size: 13, color: Tok.tealDark),
                        ]),
                      ],
                  ],
                  onRowTap: open,
                ),
                const SizedBox(height: 12),
                _Note(t('contractors.totals', {'n': fmt.count(jobs), 'amount': fmt.money(spend)})),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}

class ContractorScreen extends ConsumerWidget {
  const ContractorScreen(this.id, {super.key});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final data = ref.watch(contractorProvider(id));
    final name = '${data.value?['contractor']?['contractor_name'] ?? ''}';
    return SetTopBar(
      onBack: () => context.go('/contractors'),
      crumbs: [Crumb(t('contractors.title'), onTap: () => context.go('/contractors')), Crumb(name)],
      action: AskButton('contractor', id),
      child: AsyncView(
        value: data,
        onRetry: () => ref.invalidate(contractorProvider(id)),
        lines: 8,
        builder: (data) {
          final s = Map<String, dynamic>.from(data['scorecard']);
          return PageBody(children: [
            Panel(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Tok.inset, borderRadius: BorderRadius.circular(Tok.rCard), border: Border.all(color: Tok.lineInset)),
                    child: Text(name.isEmpty ? '' : name[0], style: Tok.section.copyWith(fontSize: 22, color: Tok.text2)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _name(name, _hero),
                      const SizedBox(height: 4),
                      Text(t('scorecard.lead'), style: Tok.body.copyWith(color: Tok.text2)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Tok.line),
                const SizedBox(height: 14),
                StatRow(children: [
                  StatBlock(icon: Ico.receipt, label: t('scorecard.jobs'), value: fmt.count(s['jobs'] as num? ?? 0), sub: t('scorecard.jobsSub')),
                  StatBlock(icon: Ico.budget, label: t('scorecard.spend'), value: fmt.money(s['spend']), sub: t('scorecard.spendSub')),
                  StatBlock(icon: Ico.map, label: t('scorecard.wards'), value: '${s['wards']}', sub: t('scorecard.wardsSub')),
                  const _Basis(),
                ]),
              ]),
            ),
            ScorecardView(s, workOrdersUrl: '/contractors/$id/work-orders'),
            _SummaryAndHow(scopeType: 'contractor', scopeId: id),
          ]);
        },
      ),
    );
  }
}

/// The "Three measures" panel: speed, durability and cost, each against similar jobs or the rate card.
/// No overall grade, and a gap below similar jobs is never red.
class ScorecardView extends ConsumerWidget {
  const ScorecardView(this.s, {super.key, required this.workOrdersUrl, this.ward = false});
  final Map<String, dynamic> s;
  final String workOrdersUrl;
  final bool ward;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final m = Map<String, dynamic>.from(s['measures']);
    final few = _anyFew(s);
    void open(String title, String filter) => showDetail(context, title: title, child: WorkOrderList('$workOrdersUrl?filter=$filter'));
    final subject = t(ward ? 'scorecard.thisWard' : 'scorecard.thisContractor');
    final ctx = t('scorecard.ctx', {'rain': s['heavy_rain_jobs'], 'low': s['low_lying_jobs']});
    final cost = Map<String, dynamic>.from(m['cost']);
    final flagged = (cost['flagged'] as num?) ?? 0;
    final all = Map<String, dynamic>.from(m['speed']);
    final fair = m['speed_fair'] == null ? null : Map<String, dynamic>.from(m['speed_fair']);
    final wait = m['assign_wait'] == null ? null : Map<String, dynamic>.from(m['assign_wait']);
    final late = s['late'] == null ? null : Map<String, dynamic>.from(s['late']);
    final redo = s['redo'] == null ? null : Map<String, dynamic>.from(s['redo']);
    final targets = List<Map<String, dynamic>>.from(s['unreachable_targets'] ?? const []);
    String hours(num? h) => h == null ? '–' : t('scorecard.hours', {'n': h.round()});
    Widget tap(String label, String filter, Widget child) => Pressable(onTap: () => open(label, filter), semanticLabel: label, child: child);
    const go = Padding(padding: EdgeInsets.only(left: 6), child: Icon(Ico.chevronRight, size: 14, color: Tok.text3));
    final allN = (all['n'] as num?) ?? 0, allObs = all['observed'] as num?;
    final cards = [
      _RateCard(
        measure: 'speed',
        // The band rests on jobs that were assigned with enough time left; the all-jobs figure sits below.
        m: fair ?? all,
        subject: subject,
        ctx: ctx,
        unit: t('scorecard.onTime'),
        extra: fair == null ? null : t('scorecard.fairSub'),
        countLabel: t('scorecard.count.onTime'),
        countIcon: Ico.calendar,
        link: t('sc.seeLate'),
        onOpen: () => open(t('sc.seeLate'), 'sla_missed'),
        more: [
          if (fair != null)
            _countBox(
              Ico.receipt,
              t('scorecard.allJobs'),
              allObs == null ? '–' : t('scorecard.pctXofY', {'pct': fmt.pct(allObs), 'x': fmt.count((allObs * allN).round()), 'y': fmt.count(allN)}),
            ),
          // For a contractor the wait is context only: plain text, no band, no colour.
          if (wait != null && !ward) ...[
            _countBox(Ico.calendar, t('scorecard.waited'), hours(wait['observed'] as num?)),
            Text(t('scorecard.waitedSimilar', {'n': hours(wait['expected'] as num?)}), style: Tok.sub),
          ],
          if (late != null) ...[
            Text(t('scorecard.lateBy'), style: Tok.body.copyWith(fontWeight: FontWeight.w600)),
            for (final k in const ['expired_before_assignment', 'too_little_time_left', 'had_time'])
              tap(t('scorecard.late.$k'), k, _countBox(Ico.calendar, t('scorecard.late.$k'), fmt.count((late[k] as num?) ?? 0), trailing: go)),
          ],
        ],
      ),
      _RateCard(
        measure: 'durability',
        m: Map<String, dynamic>.from(m['durability']),
        subject: subject,
        ctx: ctx,
        unit: t('scorecard.reopened'),
        extra: t('scorecard.within30'),
        countLabel: t('scorecard.count.reopened'),
        countIcon: Ico.reopened,
        link: t('sc.seeReopened'),
        onOpen: () => open(t('sc.seeReopened'), 'reopened'),
        more: [
          if (redo != null && ((redo['reopened_jobs'] as num?) ?? 0) > 0) ...[
            tap(t('scorecard.redoSpend'), 'reopened', _countBox(Ico.rupee, t('scorecard.redoSpend'), fmt.money(redo['reopened_spend'] as num?), trailing: go)),
            tap(
              t('scorecard.followed'),
              'followed_up',
              _countBox(
                Ico.reopened,
                t('scorecard.followed'),
                t('scorecard.followedValue', {'n': fmt.count((redo['followed_up_jobs'] as num?) ?? 0), 'amount': fmt.money(redo['followup_spend'] as num?)}),
                trailing: go,
              ),
            ),
            if (((redo['followup_by_other'] as num?) ?? 0) > 0) Text(t('scorecard.followedOther', {'n': fmt.count(redo['followup_by_other'] as num)}), style: Tok.sub),
          ],
        ],
      ),
      _CostCard(
        m: cost,
        ctx: ctx,
        onOpen: flagged > 0
            ? () => open(t('sc.seeOver'), 'overbilled')
            : () => open(t('scorecard.seeN', {'n': fmt.count(cost['n'] as num? ?? 0)}), 'all'),
      ),
      if (ward && wait != null) _WaitCard(m: wait, subject: subject, hours: hours),
    ];
    final measures = Panel(
      title: t(cards.length > 3 ? 'scorecard.measures4' : 'scorecard.measures'),
      sub: t(few ? 'scorecard.measuresSubFew' : 'scorecard.measuresSub'),
      trailing: _Legend(subject: subject, similar: few ? t('scorecard.legendSimilarFew', {'min': _minJobs}) : t('scorecard.legendSimilar')),
      child: LayoutBuilder(builder: (_, box) {
        // Four cards go two by two until the panel is wide enough for one row.
        final perRow = box.maxWidth < 900 ? 1 : (cards.length > 3 && box.maxWidth < 1250 ? 2 : cards.length);
        return Column(children: [
          for (var r = 0; r < cards.length; r += perRow) ...[
            if (r > 0) const SizedBox(height: Tok.gapCards),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = r; i < r + perRow; i++) ...[
                if (i > r) const SizedBox(width: Tok.gapCards),
                Expanded(child: i < cards.length ? cards[i] : const SizedBox()),
              ],
            ]),
          ],
        ]);
      }),
    );
    if (targets.isEmpty) return measures;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      measures,
      const SizedBox(height: Tok.gapPanels),
      Panel(
        title: t('scorecard.targets.title'),
        sub: t('scorecard.targets.sub'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, x) in targets.indexed) ...[
            if (i > 0) _rule(),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 2, child: Text('${x['work_type']}', style: Tok.body.copyWith(fontWeight: FontWeight.w600))),
              Expanded(
                flex: 3,
                child: Text(
                  t('scorecard.targets.row', {'sla': x['sla_hours'], 'typical': (x['typical_hours'] as num).round(), 'n': x['jobs']}),
                  style: Tok.body.copyWith(color: Tok.text2),
                ),
              ),
            ]),
          ],
        ]),
      ),
    ]);
  }
}

/// Ward only: average hours from first complaint to assignment, against similar jobs. Hours, not fault.
class _WaitCard extends ConsumerWidget {
  const _WaitCard({required this.m, required this.subject, required this.hours});
  final Map<String, dynamic> m;
  final String subject;
  final String Function(num?) hours;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final band = '${m['band']}';
    final few = band == 'too_few';
    final obs = m['observed'] as num?, exp = m['expected'] as num?;
    final n = (m['n'] as num?) ?? 0;
    final diff = (obs == null || exp == null) ? null : (obs - exp).round();
    final top = [obs ?? 0, exp ?? 0, 1].reduce((a, b) => a > b ? a : b);
    return _MeasureShell(
      band: band,
      why: switch (band) {
        'too_few' => t('scorecard.why.too_few'),
        'similar' => t('scorecard.why.similar'),
        'well_above' || 'above' => t('scorecard.why.assign_wait.up'),
        _ => t('scorecard.why.assign_wait.down'),
      },
      title: t('sc.assignWait'),
      figure: obs == null ? '–' : '${obs.round()}',
      unit: t('scorecard.assignUnit'),
      sub: t('scorecard.assignSub'),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _cmpHeader(
          t('scorecard.cmpSimilar'),
          few || diff == null
              ? t('scorecard.notYet')
              : diff == 0
                  ? t('scorecard.same')
                  : t(diff < 0 ? 'scorecard.hoursShorter' : 'scorecard.hoursLonger', {'n': diff.abs()}),
        ),
        const SizedBox(height: 8),
        CompareBars(bars: [
          CompareBar(subject, (obs ?? 0) / top, hours(obs)),
          if (!few) CompareBar(t('sc.similar'), (exp ?? 0) / top, hours(exp), hatched: true),
        ]),
        if (few) _notYetRow(t('sc.similar'), t('scorecard.startsAt', {'min': _minJobs})),
        _rule(),
        _countBox(Ico.receipt, t('scorecard.count.waited'), fmt.count(n)),
      ]),
    );
  }
}

bool _anyFew(Map<String, dynamic> s) {
  final m = Map<String, dynamic>.from(s['measures']);
  return m['speed']?['band'] == 'too_few' || m['durability']?['band'] == 'too_few';
}

/// The Scorecard tab on a ward page. The ward screen owns the top bar.
class WardScorecardTab extends ConsumerWidget {
  const WardScorecardTab(this.code, {super.key});
  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    return AsyncView(
      value: ref.watch(wardScorecardProvider(code)),
      onRetry: () => ref.invalidate(wardScorecardProvider(code)),
      builder: (data) {
        final s = Map<String, dynamic>.from(data['scorecard']);
        final jobs = (s['jobs'] as num?) ?? 0;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Panel(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(t('scorecard.ward.title'), style: _hero),
              const SizedBox(height: 6),
              Text(t('scorecard.ward.lead', {'ward': t('ward.label', {'code': code})}), style: Tok.body.copyWith(color: Tok.text2)),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Tok.line),
              const SizedBox(height: 14),
              StatRow(children: [
                StatBlock(icon: Ico.receipt, label: t('scorecard.jobs'), value: fmt.count(jobs), sub: t('scorecard.ward.jobsSub')),
                StatBlock(icon: Ico.budget, label: t('scorecard.spent'), value: fmt.money(s['spend']), sub: t('scorecard.ward.spentSub', {'n': fmt.count(jobs)})),
                const _Basis(),
              ]),
              if (_anyFew(s)) ...[
                const SizedBox(height: 14),
                InsetCard(
                  padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                  child: Row(children: [
                    const Icon(Ico.info, size: 16, color: Tok.text3),
                    const SizedBox(width: 10),
                    Expanded(child: Text(t('scorecard.ward.few', {'min': _minJobs}), style: Tok.body.copyWith(fontWeight: FontWeight.w500))),
                    Text(t('scorecard.ward.soFar', {'n': fmt.count(jobs), 'min': _minJobs}), style: Tok.sub),
                  ]),
                ),
              ],
            ]),
          ),
          const SizedBox(height: Tok.gapPanels),
          ScorecardView(s, workOrdersUrl: '${wardPath(code)}/work-orders', ward: true),
          const SizedBox(height: Tok.gapPanels),
          _SummaryAndHow(scopeType: 'ward', scopeId: code),
        ]);
      },
    );
  }
}

// ---------------------------------------------------------------------------------------------------
// Private pieces
// ---------------------------------------------------------------------------------------------------

/// A stat column that holds a sentence instead of a figure.
class _TextStat extends StatelessWidget {
  const _TextStat({required this.icon, required this.label, required this.body, this.link});
  final IconData icon;
  final String label, body;
  final Widget? link;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Icon(icon, size: 14, color: Tok.text3),
          const SizedBox(width: 7),
          Flexible(child: Text(label, style: Tok.body.copyWith(color: Tok.text2))),
        ]),
        const SizedBox(height: 12),
        Text(body, style: Tok.body),
        if (link != null) ...[const SizedBox(height: 4), link!],
      ]);
}

/// "Basis of comparison" column with a link that opens the full explanation.
class _Basis extends ConsumerWidget {
  const _Basis();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    return _TextStat(
      icon: Icons.layers_outlined,
      label: t('scorecard.basis'),
      body: t('scorecard.basisBody'),
      link: Transform.translate(
        offset: const Offset(-10, 0),
        child: AppButton.quiet(
          t('scorecard.basisLink'),
          onPressed: () => showDetail(context, title: t('sc.how'), child: ListView(padding: const EdgeInsets.all(18), children: [_HowList(ward: false, t: t)])),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.subject, required this.similar});
  final String subject, similar;
  @override
  Widget build(BuildContext context) => Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: Tok.panel, borderRadius: BorderRadius.circular(Tok.rControl), border: Border.all(color: Tok.line)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 22, height: 8, decoration: BoxDecoration(color: Tok.teal, borderRadius: BorderRadius.circular(Tok.rPill))),
          const SizedBox(width: 7),
          Text(subject, style: Tok.body.copyWith(color: Tok.text2)),
          const SizedBox(width: 16),
          SizedBox(
            width: 22,
            height: 8,
            child: Container(
              foregroundDecoration: BoxDecoration(borderRadius: BorderRadius.circular(Tok.rPill), border: Border.all(color: Tok.strongLine)),
              child: ClipRRect(borderRadius: BorderRadius.circular(Tok.rPill), child: const Hatch.similar()),
            ),
          ),
          const SizedBox(width: 7),
          Text(similar, style: Tok.body.copyWith(color: Tok.text2)),
        ]),
      );
}

/// Grey card shell shared by the three measures: band chip, why line, title, big figure, then a white sub-card.
class _MeasureShell extends StatelessWidget {
  const _MeasureShell({required this.band, required this.why, required this.title, required this.figure, required this.unit, required this.sub, required this.body});
  final String band, why, title, figure, unit, sub;
  final Widget body;
  @override
  Widget build(BuildContext context) => InsetCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              BandChip(band),
              const SizedBox(height: 6),
              Text(why, style: Tok.sub),
              const SizedBox(height: 18),
              Text(title, style: Tok.cardTitle),
              const SizedBox(height: 2),
              Text.rich(TextSpan(children: [
                TextSpan(text: figure, style: Tok.figure),
                TextSpan(text: ' $unit', style: Tok.emph.copyWith(fontSize: 15)),
              ])),
              const SizedBox(height: 4),
              Text(sub, style: Tok.sub.copyWith(fontSize: 13)),
            ]),
          ),
          SubCard(child: body),
        ]),
      );
}

/// Sub-card header row: "Compared with similar jobs" and the gap at the right.
Widget _cmpHeader(String title, String right) => Row(children: [
      Expanded(child: Text(title, style: Tok.body.copyWith(fontWeight: FontWeight.w600))),
      Text(right, style: Tok.sub.copyWith(fontSize: 12.5)),
    ]);

Widget _rule() => const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: Tok.lineSoft));

Widget _ctxLine(String ctx) => Row(children: [
      const Icon(Icons.cloud_outlined, size: 13, color: Tok.text3),
      const SizedBox(width: 7),
      Expanded(child: Text(ctx, style: Tok.sub)),
    ]);

/// A rounded count row ("Jobs finished on time  118 of 303"). Amber only for jobs carrying unreviewed flags.
Widget _countBox(IconData icon, String label, String value, {Widget? trailing, bool amber = false}) => Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: amber ? Tok.amberFill : Tok.inset,
        borderRadius: BorderRadius.circular(Tok.rControl),
        border: Border.all(color: amber ? Tok.amberLine : Tok.lineInset),
      ),
      child: Row(children: [
        Icon(icon, size: 14, color: amber ? Tok.amberIcon : Tok.text3),
        const SizedBox(width: 9),
        Expanded(child: Text(label, style: Tok.body.copyWith(color: amber ? Tok.amberText : Tok.ink, fontWeight: amber ? FontWeight.w500 : null))),
        if (value.isNotEmpty) Text(value, style: Tok.body.copyWith(fontWeight: FontWeight.w600)),
        ?trailing,
      ]),
    );

/// "Similar jobs" row while there are too few jobs: a dashed note where the hatched bar would be.
Widget _notYetRow(String label, String note) => SizedBox(
      height: 30,
      child: Row(children: [
        SizedBox(width: 104, child: Text(label, style: Tok.body.copyWith(color: Tok.text2))),
        const SizedBox(width: 10),
        Expanded(
          child: DashedBorder(
            child: Container(height: 24, alignment: Alignment.center, child: Text(note, style: Tok.sub, overflow: TextOverflow.ellipsis)),
          ),
        ),
      ]),
    );

Widget _soFar(Strings t, num n) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Icon(Ico.receipt, size: 13, color: Tok.text3),
        const SizedBox(width: 7),
        Expanded(child: Text(t('scorecard.countedSoFar'), style: Tok.sub)),
        Text(t('scorecard.nOfMin', {'n': fmt.count(n), 'min': _minJobs}), style: Tok.sub.copyWith(color: Tok.ink, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 6),
      ProgressBar(n / _minJobs),
    ]);

Widget _link(String label, VoidCallback? onTap) => Transform.translate(
      offset: const Offset(-10, 0),
      child: Align(alignment: Alignment.centerLeft, child: AppButton.quiet(label, onPressed: onTap)),
    );

/// Speed or durability: this record beside what similar jobs achieved.
class _RateCard extends ConsumerWidget {
  const _RateCard({
    required this.measure,
    required this.m,
    required this.subject,
    required this.ctx,
    required this.unit,
    required this.countLabel,
    required this.countIcon,
    required this.link,
    required this.onOpen,
    this.extra,
    this.more = const [],
  });

  /// Extra rows under the count box, before the link.
  final List<Widget> more;
  final String measure, subject, ctx, unit, countLabel, link;
  final String? extra;
  final IconData countIcon;
  final Map<String, dynamic> m;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final band = '${m['band']}';
    final few = band == 'too_few';
    final obs = m['observed'] as num?, exp = m['expected'] as num?;
    final n = (m['n'] as num?) ?? 0;
    final hits = obs == null ? null : (obs * n).round();
    final why = switch (band) {
      'too_few' => t('scorecard.why.too_few'),
      'similar' => t('scorecard.why.similar'),
      'well_above' || 'above' => t('scorecard.why.$measure.up'),
      _ => t('scorecard.why.$measure.down'),
    };
    final pts = (obs == null || exp == null) ? null : ((obs - exp) * 100).round();
    final gap = few || pts == null
        ? t('scorecard.notYet')
        : pts == 0
            ? t('scorecard.same')
            : t(pts < 0 ? 'scorecard.ptsLower' : 'scorecard.ptsHigher', {'n': pts.abs()});
    final ofJobs = t('scorecard.ofJobs', {'n': fmt.count(n)});
    return _MeasureShell(
      band: band,
      why: why,
      title: t('sc.$measure'),
      figure: fmt.pct(obs),
      unit: unit,
      sub: extra == null ? ofJobs : '$extra · $ofJobs',
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _cmpHeader(t('scorecard.cmpSimilar'), gap),
        const SizedBox(height: 8),
        CompareBars(bars: [
          CompareBar(subject, (obs ?? 0).toDouble(), fmt.pct(obs)),
          if (!few) CompareBar(t('sc.similar'), (exp ?? 0).toDouble(), fmt.pct(exp), hatched: true),
        ]),
        if (few) _notYetRow(t('sc.similar'), t('scorecard.startsAt', {'min': _minJobs})),
        _rule(),
        if (few) _soFar(t, n) else _ctxLine(ctx),
        const SizedBox(height: 10),
        _countBox(countIcon, countLabel, hits == null ? '–' : t('scorecard.xOfY', {'x': fmt.count(hits), 'y': fmt.count(n)})),
        for (final w in more) ...[const SizedBox(height: 6), w],
        _rule(),
        _link(link, onOpen),
      ]),
    );
  }
}

/// Cost: the typical job's ratio to the rate card, and how many jobs are above 1.5 times.
class _CostCard extends ConsumerWidget {
  const _CostCard({required this.m, required this.ctx, required this.onOpen});
  final Map<String, dynamic> m;
  final String ctx;
  final VoidCallback onOpen;

  // The bars run from 0 to 1.5x, the flag line.
  static const _scale = 1.5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final band = '${m['band']}';
    final r = m['observed'] as num?;
    final n = (m['n'] as num?) ?? 0;
    final flagged = (m['flagged'] as num?) ?? 0;
    final diff = r == null ? null : (r - 1);
    final gap = diff == null
        ? '–'
        : diff.abs() < 0.005
            ? t('scorecard.same')
            : t(diff > 0 ? 'scorecard.xAbove' : 'scorecard.xBelow', {'x': fmt.ratio(diff.abs())});
    return _MeasureShell(
      band: band,
      why: t('scorecard.why.cost.$band'),
      title: t('sc.cost'),
      figure: '${fmt.ratio(r)}x',
      unit: t('scorecard.rateCardUnit'),
      sub: t('scorecard.median'),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _cmpHeader(t('scorecard.cmpRate'), gap),
        const SizedBox(height: 8),
        CompareBars(bars: [
          CompareBar(t('scorecard.medianJob'), ((r ?? 0) / _scale).toDouble(), '${fmt.ratio(r)}x'),
          CompareBar(t('scorecard.rateCard'), 1 / _scale, '1.00x', hatched: true),
        ]),
        _rule(),
        _ctxLine(ctx),
        const SizedBox(height: 10),
        flagged > 0
            ? _countBox(Ico.flag, t('scorecard.aboveN', {'n': fmt.count(flagged)}), '', amber: true, trailing: const BandChip('review'))
            : _countBox(Icons.list_alt_outlined, t('scorecard.count.behind'), fmt.count(n)),
        _rule(),
        _link(t('scorecard.seeN', {'n': fmt.count(flagged > 0 ? flagged : n)}), onOpen),
      ]),
    );
  }
}

/// Bulleted "How this is compared" notes.
class _HowList extends StatelessWidget {
  const _HowList({required this.ward, required this.t});
  final bool ward;
  final Strings t;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final (icon, key) in [
          (Icons.layers_outlined, 'scorecard.how1'),
          (Icons.join_inner_outlined, ward ? 'scorecard.how2.ward' : 'scorecard.how2.contractor'),
          (Icons.straighten, 'scorecard.how3'),
        ]) ...[
          InsetCard(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
            radius: Tok.rControl,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 13, color: Tok.text3)),
              const SizedBox(width: 10),
              Expanded(child: Text(t(key), style: Tok.body.copyWith(color: Tok.text2))),
            ]),
          ),
          const SizedBox(height: 6),
        ],
      ]);
}

/// Summary (from the Ask feature) beside the "How this is compared" notes.
class _SummaryAndHow extends ConsumerWidget {
  const _SummaryAndHow({required this.scopeType, required this.scopeId});
  final String scopeType, scopeId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final how = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Caps(t('sc.how')),
      const SizedBox(height: 10),
      _HowList(ward: scopeType == 'ward', t: t),
    ]);
    return LayoutBuilder(builder: (_, box) {
      final summary = SummaryCard(scopeType, scopeId);
      if (box.maxWidth < 900) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [summary, const SizedBox(height: Tok.gapPanels), Panel(child: how)]);
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 3, child: summary),
        const SizedBox(width: Tok.gapPanels),
        Expanded(flex: 2, child: Panel(child: how)),
      ]);
    });
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Row(children: [
        const Icon(Ico.info, size: 13, color: Tok.text3),
        const SizedBox(width: 7),
        Expanded(child: Text(text, style: Tok.sub)),
      ]);
}

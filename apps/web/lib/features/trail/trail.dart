import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/format.dart' as fmt;
import '../../core/theme.dart';
import '../../core/widgets.dart';

final searchProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, q) => apiGet(ref, '/trail/search', {'q': q}));

/// Keyed by the API path, e.g. `/trail/issue/12` or `/trail/work-order/WO25-00004`.
final trailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, path) => apiGet(ref, path));

// =====================================================================================================
// Search (15-trail-search.html)
// =====================================================================================================

/// The query lives in the URL (`/trail?q=...`), so the shell's sidebar search and this box share it.
class TrailSearchScreen extends ConsumerStatefulWidget {
  const TrailSearchScreen({super.key});
  @override
  ConsumerState<TrailSearchScreen> createState() => _SearchState();
}

class _SearchState extends ConsumerState<TrailSearchScreen> {
  final _box = TextEditingController();
  String? _urlQ;
  String _tab = 'all';

  @override
  void dispose() {
    _box.dispose();
    super.dispose();
  }

  void _go(String v) => context.go(v.trim().isEmpty ? '/trail' : '/trail?q=${Uri.encodeQueryComponent(v.trim())}');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final urlQ = GoRouterState.of(context).uri.queryParameters['q'] ?? '';
    if (urlQ != _urlQ) {
      _urlQ = urlQ;
      _box.text = urlQ;
      _tab = 'all';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final q = (_urlQ ?? '').trim();
    final result = q.length < 3 ? null : ref.watch(searchProvider(q));
    final data = result?.value;
    List<Map<String, dynamic>> list(String k) => data == null ? const [] : List<Map<String, dynamic>>.from(data[k]);
    final complaints = list('complaints'), jobs = list('work_orders'), issues = list('issues');
    final total = complaints.length + jobs.length + issues.length;

    final searchPanel = Panel(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('trail.find'), style: Tok.section.copyWith(fontSize: 17)),
          const SizedBox(height: Tok.s4),
          TextField(
            controller: _box,
            autofocus: true,
            style: Tok.emph.copyWith(fontSize: 15),
            textInputAction: TextInputAction.search,
            onSubmitted: _go,
            decoration: InputDecoration(
              hintText: t('trail.search'),
              prefixIcon: const Icon(Ico.search, size: 18, color: Tok.ink),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (data != null) Text(t('trail.matches', {'n': total}), style: Tok.sub),
                  if (q.isNotEmpty) ...[
                    const SizedBox(width: Tok.s2),
                    AppIconButton(Ico.close, tooltip: t('trail.clear'), onPressed: () => _go('')),
                  ],
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
          const SizedBox(height: Tok.s2),
          Text(t('trail.hint'), style: Tok.sub),
          if (data != null && total > 0) ...[
            const SizedBox(height: Tok.s4),
            SegmentedTabs<String>(
              value: _tab,
              onChanged: (v) => setState(() => _tab = v),
              items: [
                TabItem('all', t('trail.tab.all'), count: total),
                if (complaints.isNotEmpty) TabItem('complaints', t('trail.group.complaints'), count: complaints.length),
                if (jobs.isNotEmpty) TabItem('work_orders', t('trail.group.workOrders'), count: jobs.length),
                if (issues.isNotEmpty) TabItem('issues', t('trail.group.issues'), count: issues.length),
              ],
            ),
          ],
        ],
      ),
    );

    Widget results;
    if (result == null) {
      results = Panel(child: EmptyState(t('trail.hint'), icon: Ico.trail));
    } else {
      results = AsyncView(
        value: result,
        onRetry: () => ref.invalidate(searchProvider(q)),
        builder: (_) {
          if (total == 0) return Panel(child: EmptyState(t('trail.none', {'q': q}), icon: Ico.search));
          bool show(String k) => _tab == 'all' || _tab == k;
          return Panel(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (complaints.isNotEmpty && show('complaints'))
                  _Group(t('trail.group.complaints'), [
                    for (final c in complaints)
                      _ResultRow(
                        icon: Icons.chat_bubble_outline,
                        title: '${c['id']}',
                        line: '${c['locality_text'] ?? '–'} · ${fmt.date(c['received_at'])}',
                        trailing: [Pill('${c['status']}', tone: Tone.info, icon: Ico.open)],
                        to: '/trail/complaint/${c['id']}',
                      ),
                  ]),
                if (jobs.isNotEmpty && show('work_orders'))
                  _Group(t('trail.group.workOrders'), [
                    for (final w in jobs)
                      _ResultRow(
                        icon: Icons.assignment_outlined,
                        title: '${w['id']}',
                        titleSub: '${w['road_name']} · ${w['work_type']}',
                        line: '${w['contractor_name']}',
                        to: '/trail/work-order/${w['id']}',
                      ),
                  ]),
                if (issues.isNotEmpty && show('issues'))
                  _Group(t('trail.group.issues'), [
                    for (final i in issues)
                      _ResultRow(
                        icon: Icons.add_road,
                        title: '${i['category']}',
                        titleSub: '${i['road_name'] ?? '–'}',
                        line:
                            '${t('ward.label', {'code': i['ward_code']})} · ${t('plan.complaints', {'n': i['complaint_count']})} · ${fmt.date(i['last_reported_at'])}',
                        trailing: [_StateChip('${i['state']}')],
                        to: '/trail/issue/${i['id']}',
                      ),
                  ]),
                const SizedBox(height: Tok.s2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    children: [
                      Text(t('trail.matches', {'n': total}), style: Tok.sub.copyWith(color: Tok.ink, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Text(t('trail.groupedNote'), style: Tok.sub),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return SetTopBar(
      title: t('nav.trail'),
      child: SingleChildScrollView(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [searchPanel, const SizedBox(height: Tok.gapPanels), results])),
            const SizedBox(width: Tok.gapPanels),
            const SizedBox(width: 374, child: _Explainer()),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group(this.title, this.rows);
  final String title;
  final List<Widget> rows;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Tok.s3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Row(
            children: [
              Caps(title),
              const SizedBox(width: 8),
              Text('${rows.length}', style: Tok.caps.copyWith(color: Tok.ink, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              const Expanded(child: Divider(color: Tok.line)),
            ],
          ),
        ),
        for (final (i, r) in rows.indexed) ...[if (i > 0) const SizedBox(height: 6), r],
      ],
    ),
  );
}

Widget _iconTile(IconData icon, {Color bg = Tok.panel, Color fg = Tok.text2, Color border = Tok.line}) => Container(
  width: 32,
  height: 32,
  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9), border: Border.all(color: border)),
  child: Icon(icon, size: 16, color: fg),
);

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.icon, required this.title, this.titleSub, required this.line, this.trailing = const [], required this.to});
  final IconData icon;
  final String title, line, to;
  final String? titleSub;
  final List<Widget> trailing;
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: () => context.go(to),
    radius: Tok.rCard,
    semanticLabel: title,
    builder: (_, hover) => Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: hover ? Tok.lineSoft : Tok.inset,
        borderRadius: BorderRadius.circular(Tok.rCard),
        border: Border.all(color: Tok.lineInset),
      ),
      child: Row(
        children: [
          _iconTile(icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: title, style: Tok.emph.copyWith(fontWeight: FontWeight.w600)),
                      if (titleSub != null) TextSpan(text: '  $titleSub', style: Tok.body.copyWith(color: Tok.text2)),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(line, style: Tok.body.copyWith(color: Tok.text2)),
              ],
            ),
          ),
          for (final w in trailing) ...[const SizedBox(width: Tok.s2), w],
          const SizedBox(width: Tok.s3),
          const Icon(Ico.chevronRight, size: 18, color: Tok.text3),
        ],
      ),
    ),
  );
}

/// Right column of the search page: what each of the five stages holds.
class _Explainer extends ConsumerWidget {
  const _Explainer();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    const stages = [
      ('complaints', Icons.chat_bubble_outline),
      ('issue', Icons.call_merge),
      ('workOrder', Icons.assignment_outlined),
      ('road', Icons.add_road),
      ('outcome', Icons.verified_user_outlined),
    ];
    return Panel(
      title: t('trail.explain.title'),
      trailing: Text(t('trail.explain.stages'), style: Tok.sub),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('trail.explain.lead'), style: Tok.body.copyWith(color: Tok.text2)),
          const SizedBox(height: Tok.s4),
          for (final (i, (k, icon)) in stages.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _iconTile(icon, bg: Tok.tealTint, fg: Tok.teal, border: Tok.tealLine),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: '0${i + 1}  ', style: Tok.sub.copyWith(color: Tok.text3)),
                              TextSpan(text: t('trail.stage.$k'), style: Tok.emph.copyWith(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Text(t('trail.explain.$k'), style: Tok.body.copyWith(color: Tok.text2)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          InsetCard(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Ico.open, size: 13, color: Tok.text3)),
                const SizedBox(width: 8),
                Expanded(child: Text(t('trail.explain.empty'), style: Tok.body.copyWith(color: Tok.text2))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StateChip extends ConsumerWidget {
  const _StateChip(this.state);
  final String state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (tone, icon) = switch (state) {
      'fixed' => (Tone.success, Ico.check),
      'fixed_reopened' => (Tone.neutral, Ico.reopened),
      'open' => (Tone.info, Ico.open),
      _ => (Tone.neutral, Icons.block),
    };
    return Pill(ref.watch(stringsProvider)('trail.state.$state'), tone: tone, icon: icon);
  }
}

// =====================================================================================================
// One trail (16-19-trail-*.html)
// =====================================================================================================

String _x(Object? r) => r == null ? '–' : '${(r as num).toStringAsFixed(2)}x';

/// "5 d 19 h · 139 h" between two timestamps, or null.
(String, int)? _taken(Object? from, Object? to) {
  final a = DateTime.tryParse('${from ?? ''}'), b = DateTime.tryParse('${to ?? ''}');
  if (a == null || b == null) return null;
  final m = b.difference(a).inMinutes, h = m ~/ 60;
  final s = h >= 24 ? '${h ~/ 24} d ${h % 24} h · $h h' : (h > 0 ? '$h h ${m % 60} min' : '${m % 60} min');
  return (s, h);
}

bool _isOpenFlag(Map f) => f['tier'] == 'flag' && const [null, 'open', 'needs_explanation'].contains(f['decision']);

/// One item end to end: complaints, issue, work order, road, outcome.
class TrailScreen extends ConsumerWidget {
  const TrailScreen(this.apiPath, {super.key});
  final String apiPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final canSeeFlags = ref.watch(sessionProvider)!.canSeeFlags;
    final seg = Uri.parse(apiPath).pathSegments; // trail, kind, id
    final kind = seg.length > 1 ? seg[1] : '', pathId = seg.isNotEmpty ? seg.last : '';
    final value = ref.watch(trailProvider(apiPath));
    final d = value.value;
    final firstComplaint = d == null || (d['complaints'] as List).isEmpty ? null : '${d['highlight'] ?? (d['complaints'] as List).first['complaint_id']}';
    final crumbId = kind == 'issue' ? (firstComplaint ?? pathId) : pathId;

    return SetTopBar(
      crumbs: [Crumb(t('nav.trail'), onTap: () => context.go('/trail')), Crumb(crumbId)],
      onBack: () => context.go('/trail'),
      child: AsyncView(
        value: value,
        onRetry: () => ref.invalidate(trailProvider(apiPath)),
        lines: 10,
        builder: (d) => _TrailBody(d: d, kind: kind, pathId: pathId, firstComplaint: firstComplaint, canSeeFlags: canSeeFlags),
      ),
    );
  }
}

class _TrailBody extends ConsumerWidget {
  const _TrailBody({required this.d, required this.kind, required this.pathId, required this.firstComplaint, required this.canSeeFlags});
  final Map<String, dynamic> d;
  final String kind, pathId;
  final String? firstComplaint;
  final bool canSeeFlags;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    Map<String, dynamic>? m(String k) => d[k] == null ? null : Map<String, dynamic>.from(d[k]);
    final issue = m('issue'), w = m('work_order'), road = m('road'), plan = m('plan');
    final complaints = List<Map<String, dynamic>>.from(d['complaints']);
    final flags = List<Map<String, dynamic>>.from(d['flags']);
    final posts = List<Map<String, dynamic>>.from(d['social_posts']);
    final openFlags = flags.where(_isOpenFlag).toList();
    final reopened = w?['reopened_within_30d'] as bool?;
    final slaMet = w?['sla_met'] as bool?;
    final taken = w == null ? null : _taken(w['assigned_at'], w['completed_at']);
    final ward = '${issue?['ward_code'] ?? w?['ward_code'] ?? ''}';
    final upvotes = complaints.fold<int>(0, (s, c) => s + ((c['upvotes'] as num?)?.toInt() ?? 0));
    String flagCount(int n) => t(n == 1 ? 'trail.openFlag1' : 'trail.openFlagN', {'n': n});

    // Languages as "2 English, 1 Marathi".
    final langs = <String, int>{};
    for (final c in complaints) {
      langs.update('${c['language'] ?? '–'}', (v) => v + 1, ifAbsent: () => 1);
    }
    final langLine = langs.length == 1 ? langs.keys.first : langs.entries.map((e) => '${e.value} ${e.key}').join(', ');

    // ---- Header + stepper
    final isWo = kind == 'work-order';
    final heading = isWo
        ? t('trail.heading.workOrder', {'id': pathId})
        : (firstComplaint == null ? t('trail.heading.issueN', {'id': pathId}) : t('trail.heading.issue', {'id': firstComplaint}));
    final roadLine = road == null ? null : '${road['road_name']}${isWo && road['segment_no'] != null ? ', ${t('trail.segment', {'n': road['segment_no']})}' : ''}';
    final outcomeTitle = w == null
        ? t('trail.state.${issue?['state'] ?? 'open'}')
        : reopened == null
        ? t('trail.pending')
        : t(reopened ? 'wo.reopened' : 'wo.held');
    final slaWord = slaMet == null ? null : t(slaMet ? 'trail.slaMet' : 'trail.slaMissed');

    final header = Panel(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Caps(t(isWo ? 'trail.eyebrow.workOrder' : 'trail.eyebrow.issue')),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(heading, style: Tok.section.copyWith(fontSize: 20, height: 26 / 20)),
              if (w == null) Pill(t('trail.neverFixedShort'), tone: Tone.info, icon: Ico.open),
              if (reopened == true) Pill(t('trail.reopened30'), icon: Ico.reopened),
              if (reopened == false) Pill(t('wo.held'), tone: Tone.success, icon: Ico.check),
              if (openFlags.isNotEmpty) FlagPill(flagCount(openFlags.length)) else if (slaMet == false) Pill(slaWord!, icon: Icons.schedule),
            ],
          ),
          const SizedBox(height: 4),
          Text([t('ward.label', {'code': ward}), ?roadLine].join(' · '), style: Tok.body.copyWith(color: Tok.text2)),
          const SizedBox(height: Tok.s4),
          const Divider(color: Tok.line),
          const SizedBox(height: Tok.s4),
          TrailStepper(
            steps: [
              complaints.isEmpty
                  ? TrailStep(t('trail.stage.complaints'), t('wo.noComplaint'), sub: t('trail.noneOnRecord'), node: TrailNode.missing)
                  : TrailStep(
                      t('trail.stage.complaints'),
                      complaints.length == 1 ? t('trail.complaint1') : t('plan.complaints', {'n': complaints.length}),
                      sub: upvotes > 0 ? t('trail.upvotesN', {'n': upvotes}) : langLine,
                    ),
              issue == null
                  ? TrailStep(t('trail.stage.issue'), t('trail.noIssue'), sub: t('trail.noIssueSub'), node: TrailNode.missing)
                  : TrailStep(
                      t('trail.stage.issue'),
                      '${issue['category']}',
                      sub: '${t('trail.sevEst', {'n': issue['severity']})}${issue['state'] == 'open' ? ' · ${t('trail.state.open').toLowerCase()}' : ''}',
                    ),
              w == null
                  ? TrailStep(
                      t('trail.stage.workOrder'),
                      t('trail.neverFixedShort'),
                      sub: plan == null ? null : t('trail.planRankShort', {'rank': plan['rank'], 'ward': ward}),
                      node: TrailNode.missing,
                    )
                  : TrailStep(t('trail.stage.workOrder'), fmt.rupees(w['cost_inr']), sub: t('trail.ratioExpected', {'x': _x(w['cost_ratio'])})),
              road == null
                  ? TrailStep(t('trail.stage.road'), t('trail.noRoad'), sub: t('trail.source.none'), node: TrailNode.missing)
                  : TrailStep(
                      t('trail.stage.road'),
                      '${road['road_name']}',
                      sub: [
                        '${road['road_type']}',
                        '${road['surface']}',
                        if (road['under_dlp'] == true) t('trail.underDlp').toLowerCase(),
                      ].join(' · '),
                    ),
              w == null
                  ? TrailStep(t('trail.stage.outcome'), outcomeTitle, sub: t('trail.noWorkOrderYet'), node: TrailNode.missing)
                  : TrailStep(
                      t('trail.stage.outcome'),
                      outcomeTitle,
                      sub: [?slaWord, openFlags.isEmpty ? t('trail.noFlags') : flagCount(openFlags.length)].join(' · '),
                      node: openFlags.isEmpty ? TrailNode.recorded : TrailNode.flagged,
                    ),
            ],
          ),
        ],
      ),
    );

    // ---- Stage cards
    Widget fields(List<(String, String)> items, {int perRow = 4}) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var r = 0; r < items.length; r += perRow) ...[
          if (r > 0) const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = r; i < r + perRow; i++)
                Expanded(child: i < items.length ? _Field(items[i].$1, items[i].$2) : const SizedBox()),
            ],
          ),
        ],
      ],
    );

    final complaintsStage = complaints.isEmpty
        ? _Stage.missing(eyebrow: t('trail.stage.complaints'), title: t('wo.noComplaint'))
        : _Stage(
            title: t('trail.stage.complaints'),
            sub: [t('trail.linked', {'n': complaints.length}), langLine, if (upvotes > 0) t('trail.upvotesN', {'n': upvotes})].join(' · '),
            children: [for (final k in complaints) _ComplaintCard(k, highlighted: k['complaint_id'] == d['highlight'])],
          );

    final issueStage = issue == null
        ? _Stage.missing(eyebrow: t('trail.stage.issue'), title: t('trail.noIssue'), body: t('trail.noIssueBody'))
        : _Stage(
            title: t('trail.stage.issue'),
            sub: t('trail.groupedFrom', {'n': issue['complaint_count']}),
            trailing: issue['state'] == 'open' ? Pill(t('trail.statusOpen'), tone: Tone.info) : null,
            children: [
              SubCard(
                child: fields([
                  (t('trail.f.category'), '${issue['category']}'),
                  (t('trail.f.severity'), t('trail.sevVal', {'n': issue['severity']})),
                  (t('trail.f.complaints'), '${issue['complaint_count']}'),
                  (t('trail.f.status'), t('trail.state.${issue['state']}')),
                ]),
              ),
              if (posts.isNotEmpty)
                SubCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('trail.socialN', {'n': posts.length}), style: Tok.sub.copyWith(color: Tok.ink, fontWeight: FontWeight.w500)),
                      for (final p in posts.take(5)) ...[
                        const SizedBox(height: 8),
                        Text('${p['source']} · ${fmt.dateTime(p['posted_at'])}', style: Tok.sub),
                        Text('${p['text']}', style: Tok.body),
                        if (p['text_en'] != null && p['text_en'] != p['text']) Text('${p['text_en']}', style: Tok.body.copyWith(color: Tok.text2)),
                      ],
                    ],
                  ),
                ),
            ],
          );

    final Widget woStage;
    if (w == null) {
      woStage = _Stage.missing(
        eyebrow: t('trail.stage.workOrder'),
        title: t('trail.neverFixedShort'),
        body: [
          t('trail.neverFixedBody', {'date': fmt.date(issue?['first_reported_at'])}),
          if (plan != null) t('trail.daysOpen', {'n': (plan['days_open'] as num).round()}),
        ].join(' '),
        footer: plan == null
            ? null
            : Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Tok.panel, borderRadius: BorderRadius.circular(6), border: Border.all(color: Tok.line)),
                    child: Text('${plan['rank']}', style: Tok.sub.copyWith(color: Tok.ink, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t('trail.planRankLine', {'rank': plan['rank'], 'ward': ward}), style: Tok.body)),
                  AppButton.quiet(t('trail.openPlan'), onPressed: () => context.go('/ward/${wardSlug(ward)}?tab=plan')),
                ],
              ),
      );
    } else {
      final cost = (w['cost_inr'] as num).toDouble(), exp = (w['expected_cost'] as num?)?.toDouble() ?? 0;
      final above = cost > exp;
      final diff = (cost - exp).abs();
      woStage = _Stage(
        titleWidget: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: t('trail.stage.workOrder'), style: Tok.cardTitle),
              TextSpan(text: '   ${w['work_order_id']}', style: Tok.cardTitle.copyWith(color: Tok.tealDark)),
              TextSpan(text: '   ${w['contractor_name']}', style: Tok.body.copyWith(color: Tok.text2)),
            ],
          ),
        ),
        children: [
          SubCard(
            child: fields([
              (t('trail.f.method'), '${w['repair_method']}'),
              (t('trail.f.area'), t('wo.area', {'area': w['area_sqm']})),
              (t('trail.f.timeTaken'), taken?.$1 ?? '–'),
              (t('trail.f.assigned'), fmt.dateTime(w['assigned_at'])),
              if (w['work_started_at'] != null) (t('trail.f.started'), fmt.dateTime(w['work_started_at'])),
              (t('trail.f.completed'), fmt.dateTime(w['completed_at'])),
            ], perRow: 3),
          ),
          SubCard(
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(t('trail.costAgainst'), style: Tok.sub),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(fmt.rupees(cost), style: Tok.figure.copyWith(fontSize: 22)),
                            const SizedBox(width: 8),
                            Text(t('trail.againstExpected', {'amount': fmt.rupees(exp)}), style: Tok.body.copyWith(color: Tok.text2)),
                            const Spacer(),
                            Text(_x(w['cost_ratio']), style: Tok.emph.copyWith(fontWeight: FontWeight.w600, fontSize: 15)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(Tok.rPill),
                          child: SizedBox(
                            height: 8,
                            child: Row(
                              children: [
                                Expanded(flex: (above ? exp : cost).round().clamp(1, 1 << 31), child: const ColoredBox(color: Tok.teal)),
                                const SizedBox(width: 2),
                                if (diff > 0)
                                  Expanded(
                                    flex: diff.round().clamp(1, 1 << 31),
                                    child: above ? const Hatch(stripe: Tok.strongLine, background: Tok.panel, width: 2, gap: 2.5) : const Hatch.rest(),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                above
                                    ? t('trail.legendAbove', {'amount': fmt.rupees(exp)})
                                    : t('trail.legendBelow', {'amount': fmt.rupees(cost), 'exp': fmt.rupees(exp)}),
                                style: Tok.sub.copyWith(fontSize: 11.5),
                              ),
                            ),
                            Text(
                              t(above ? 'trail.aboveExpected' : 'trail.belowExpected', {'amount': fmt.rupees(diff)}),
                              style: Tok.sub.copyWith(fontSize: 11.5, color: Tok.ink, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 32, color: Tok.line),
                  SizedBox(
                    width: 180,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t('trail.slaLabel'), style: Tok.sub),
                        const SizedBox(height: 6),
                        if (slaMet != null) _slaPill(t(slaMet ? 'trail.slaMet' : 'trail.slaMissed'), slaMet),
                        if (taken != null && w['sla_hours'] != null) ...[
                          const SizedBox(height: 6),
                          Text(t('trail.took', {'h': taken.$2, 'limit': w['sla_hours']}), style: Tok.sub),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if ('${w['engineer_remark'] ?? ''}'.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 2),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${t('trail.remark')}   ', style: Tok.sub),
                    TextSpan(text: '“${w['engineer_remark']}”', style: Tok.body.copyWith(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    final roadStage = road == null
        ? _Stage.missing(eyebrow: t('trail.stage.road'), title: t('trail.noRoad'))
        : _Stage(
            title: t('trail.stage.road'),
            trailing: Wrap(
              spacing: 6,
              children: [
                road['under_dlp'] == true ? StatusPill(t('trail.underDlp'), dot: Tok.amberIcon) : StatusPill(t('trail.noDlp')),
                if (road['bus_route'] == true) StatusPill(t('plan.reason.bus'), dot: StatusPill.routeDot),
              ],
            ),
            trailingInline: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                child: Text('${road['road_name']}', style: Tok.section),
              ),
              SubCard(
                child: fields([
                  (t('trail.f.class'), '${road['road_type']}'),
                  (t('trail.f.segment'), '${road['segment_no']} (${road['road_id']})'),
                  (t('trail.f.surface'), '${road['surface']}'),
                  (t('trail.f.resurfaced'), fmt.date(road['last_resurfaced'])),
                  (t('trail.f.dlp'), t(road['under_dlp'] == true ? 'trail.yes' : 'trail.no')),
                  (t('trail.f.bus'), t(road['bus_route'] == true ? 'trail.yes' : 'trail.no')),
                ], perRow: 6),
              ),
            ],
          );

    final outcomeStage = w == null
        ? _Stage.missing(eyebrow: t('trail.stage.outcome'), title: t('trail.outcomeOpen'), body: t('trail.outcomeOpenSub'))
        : _Stage(
            title: t('trail.stage.outcome'),
            trailing: openFlags.isEmpty ? null : FlagPill(flagCount(openFlags.length)),
            trailingInline: true,
            children: [
              SubCard(
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t('trail.reopenResult'), style: Tok.sub),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 10,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (reopened == true) Pill(t('trail.reopened30'), tone: Tone.info, icon: Ico.reopened),
                                if (reopened == false) Pill(t('wo.held'), tone: Tone.success, icon: Ico.check),
                                Text(
                                  reopened == null ? t('trail.outcome.pending') : t(reopened ? 'trail.outcome.reopened' : 'trail.notReopened'),
                                  style: Tok.body.copyWith(color: Tok.text2),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 32, color: Tok.line),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t('trail.slaResult'), style: Tok.sub),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 10,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (slaMet != null) _slaPill(t(slaMet ? 'trail.slaMet' : 'trail.slaMissed'), slaMet),
                                if (taken != null && w['sla_hours'] != null)
                                  Text(t('trail.takenLimit', {'h': taken.$2, 'limit': w['sla_hours']}), style: Tok.body.copyWith(color: Tok.text2)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(10, 6, 10, 2), child: Caps(t('trail.flagsOnWo'))),
              if (flags.isEmpty)
                SubCard(
                  child: Row(
                    children: [
                      const Icon(Ico.flag, size: 15, color: Tok.text3),
                      const SizedBox(width: 10),
                      Text(t('trail.noneShort'), style: Tok.body.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t('trail.noFlagMsg'), style: Tok.body.copyWith(color: Tok.text2))),
                    ],
                  ),
                ),
              for (final f in flags) _FlagRow(f, w: w, road: road, canOpen: canSeeFlags),
            ],
          );

    final stages = [complaintsStage, issueStage, woStage, roadStage, outcomeStage];
    final nodes = [
      complaints.isEmpty ? TrailNode.missing : TrailNode.recorded,
      issue == null ? TrailNode.missing : TrailNode.recorded,
      w == null ? TrailNode.missing : TrailNode.recorded,
      road == null ? TrailNode.missing : TrailNode.recorded,
      w == null ? TrailNode.missing : (openFlags.isEmpty ? TrailNode.recorded : TrailNode.flagged),
    ];
    final recorded = nodes.where((n) => n != TrailNode.missing).length;
    final empties = [for (final (i, n) in nodes.indexed) if (n == TrailNode.missing) t(const ['trail.stage.complaints', 'trail.stage.issue', 'trail.stage.workOrder', 'trail.stage.road', 'trail.stage.outcome'][i])];

    final stagePanel = Panel(
      title: t('trail.byStage'),
      sub: t('trail.byStageSub'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          for (final (i, s) in stages.indexed) _Rail(node: nodes[i], next: i + 1 < nodes.length ? nodes[i + 1] : null, child: s),
          const SizedBox(height: Tok.s3),
          const Divider(color: Tok.line),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Ico.check, size: 14, color: Tok.text3),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: Tok.sub,
                    children: [
                      TextSpan(text: '${t('trail.end')}  '),
                      TextSpan(text: t('trail.nOf5', {'n': recorded}), style: const TextStyle(color: Tok.ink, fontWeight: FontWeight.w600)),
                      TextSpan(text: ' ${t('trail.stagesRecorded')}'),
                      if (empties.isNotEmpty) TextSpan(text: ' ${t('trail.emptyStages', {'list': empties.join(t('trail.and'))})}'),
                      if (openFlags.isNotEmpty) TextSpan(text: ' ${t(openFlags.length == 1 ? 'trail.flagOpen1' : 'trail.flagOpenN', {'n': openFlags.length})}'),
                    ],
                  ),
                ),
              ),
              AppButton.quiet(t('trail.searchAnother'), onPressed: () => context.go('/trail')),
            ],
          ),
        ],
      ),
    );

    // ---- At a glance
    final flagAmount = openFlags.fold<num>(0, (s, f) => s + ((f['amount_at_stake'] as num?) ?? 0));
    final flagsValue = openFlags.isEmpty ? t('trail.noneShort') : t('trail.openAmount', {'n': openFlags.length, 'amount': fmt.rupees(flagAmount)});
    final glance = <(String, String)>[
      if (w != null) ...[
        (t('trail.g.cost'), fmt.rupees(w['cost_inr'])),
        (t('trail.g.expected'), fmt.rupees(w['expected_cost'])),
        (t('trail.g.ratio'), _x(w['cost_ratio'])),
        (t('trail.f.method'), '${w['repair_method']}'),
        (t('trail.f.timeTaken'), taken?.$1 ?? '–'),
        if (w['sla_hours'] != null) (t('trail.g.slaLimit'), '${w['sla_hours']} h'),
        if (slaMet != null) (t('trail.slaLabel'), t(slaMet ? 'trail.met' : 'trail.missed')),
        if (reopened != null) (t('trail.g.reopened'), t(reopened ? 'trail.yes' : 'trail.no')),
        if (road != null) (t('trail.g.dlp'), t(road['under_dlp'] == true ? 'trail.yes' : 'trail.no')),
        (t('trail.f.complaints'), complaints.isEmpty ? t('trail.noneShort') : '${complaints.length}'),
      ] else ...[
        (t('trail.f.status'), t('trail.state.${issue?['state'] ?? 'open'}')),
        (t('trail.f.complaints'), '${complaints.length}'),
        (t('trail.g.upvotes'), '$upvotes'),
        if (issue != null) (t('trail.f.severity'), t('trail.sevVal', {'n': issue['severity']})),
        if (issue != null) (t('trail.g.firstReported'), fmt.date(issue['first_reported_at'])),
        (t('trail.stage.workOrder'), t('trail.noneShort')),
        if (plan != null) (t('trail.g.planRank'), t('trail.planRankVal', {'rank': plan['rank'], 'ward': ward})),
      ],
    ];
    final glancePanel = Panel(
      title: t('trail.glance'),
      trailing: Caps(t('trail.fromTrail')),
      child: Column(
        children: [
          for (final (k, v) in glance) _GlanceRow(k, v),
          _GlanceRow(t('trail.g.flags'), flagsValue, amber: openFlags.isNotEmpty, last: true),
        ],
      ),
    );

    return PageBody(
      children: [
        header,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: stagePanel),
            const SizedBox(width: Tok.gapPanels),
            SizedBox(width: 384, child: glancePanel),
          ],
        ),
      ],
    );
  }
}

Widget _slaPill(String label, bool met) => met ? Pill(label, tone: Tone.success, icon: Ico.check) : Pill(label, icon: Icons.schedule);

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Tok.sub),
        const SizedBox(height: 2),
        Text(value, style: Tok.body.copyWith(fontSize: 14, height: 20 / 14)),
      ],
    ),
  );
}

class _GlanceRow extends StatelessWidget {
  const _GlanceRow(this.label, this.value, {this.amber = false, this.last = false});
  final String label, value;
  final bool amber, last;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: last ? null : const BoxDecoration(border: Border(bottom: BorderSide(color: Tok.lineSoft))),
    child: Row(
      children: [
        Expanded(child: Text(label, style: Tok.body.copyWith(color: Tok.text2))),
        if (amber) ...[const Icon(Ico.flag, size: 13, color: Tok.amberIcon), const SizedBox(width: 4)],
        Text(value, style: Tok.body.copyWith(fontWeight: FontWeight.w600, color: amber ? Tok.amberText : Tok.ink)),
      ],
    ),
  );
}

class _ComplaintCard extends ConsumerWidget {
  const _ComplaintCard(this.k, {required this.highlighted});
  final Map<String, dynamic> k;
  final bool highlighted;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final corrected = k['category_clean'] != null && k['category_clean'] != k['category_reported'];
    final translated = k['text_en'] != null && k['text_en'] != k['description'];
    Widget labelled(String label, String text) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 88, child: Padding(padding: const EdgeInsets.only(top: 2), child: Caps(label))),
          Expanded(child: Text(text, style: Tok.body.copyWith(fontSize: 13.5))),
        ],
      ),
    );
    return Container(
      // The complaint the user searched for is marked with a teal rule, not colour alone: it also leads the crumb.
      decoration: highlighted ? const BoxDecoration(border: Border(left: BorderSide(color: Tok.teal, width: 3))) : null,
      child: SubCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('${k['complaint_id']}', style: Tok.emph.copyWith(color: Tok.tealDark, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                if (k['language'] != null) ...[Pill('${k['language']}'), const SizedBox(width: 8)],
                Text('${k['channel']} · ${fmt.date(k['received_at'])}', style: Tok.sub),
                if ((k['upvotes'] as num? ?? 0) > 0) ...[
                  const SizedBox(width: 10),
                  const Icon(Ico.arrowUp, size: 12, color: Tok.text2),
                  Text(' ${t('trail.upvotesN', {'n': k['upvotes']})}', style: Tok.sub.copyWith(color: Tok.ink)),
                ],
                const Spacer(),
                if (corrected) ...[
                  Text('${k['category_reported']}', style: Tok.sub.copyWith(decoration: TextDecoration.lineThrough)),
                  const SizedBox(width: 6),
                ],
                Text('${k['category_clean'] ?? k['category_reported']}', style: Tok.body.copyWith(fontWeight: FontWeight.w500)),
                if (corrected) ...[const SizedBox(width: 6), Pill(t('trail.corrected'), tone: Tone.info, icon: Icons.edit_outlined)],
              ],
            ),
            if (translated) ...[
              labelled(t('trail.originalLabel'), '${k['description']}'),
              labelled(t('trail.translated'), '${k['text_en']}'),
            ] else
              Padding(padding: const EdgeInsets.only(top: 6), child: Text('“${k['description']}”', style: Tok.body.copyWith(fontSize: 13.5))),
          ],
        ),
      ),
    );
  }
}

class _FlagRow extends ConsumerWidget {
  const _FlagRow(this.f, {required this.w, required this.road, required this.canOpen});
  final Map<String, dynamic> f, w;
  final Map<String, dynamic>? road;
  final bool canOpen;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final watch = f['tier'] == 'watch';
    // The evidence this page already holds for each flag type.
    final evidence = switch (f['flag_type']) {
      'dlp' => road?['under_dlp'] == true ? t('trail.underDlpEvidence') : null,
      'overbilled' => t('trail.ratioExpected', {'x': _x(w['cost_ratio'])}),
      _ => null,
    };
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      decoration: BoxDecoration(
        color: watch ? Tok.panel : Tok.amberFill.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(Tok.rCard),
        border: Border.all(color: watch ? Tok.line : Tok.amberLine),
      ),
      child: Row(
        children: [
          Icon(watch ? Ico.eye : Ico.flag, size: 15, color: watch ? Tok.text3 : Tok.amberIcon),
          const SizedBox(width: 10),
          Text(
            t('flags.tab.${watch ? 'watch' : f['flag_type']}'),
            style: Tok.body.copyWith(fontWeight: FontWeight.w600, color: watch ? Tok.ink : Tok.amberText),
          ),
          if (evidence != null) ...[const SizedBox(width: 10), Flexible(child: Text(evidence, style: Tok.sub))],
          const Spacer(),
          Text(fmt.rupees(f['amount_at_stake']), style: Tok.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          DecisionChip(watch ? 'watch' : '${f['decision'] ?? 'open'}'),
          if (canOpen && !watch) ...[
            const SizedBox(width: 4),
            AppButton.quiet(t('trail.openFlag'), onPressed: () => context.go('/flags/${f['flag_type']}/${w['work_order_id']}')),
          ],
        ],
      ),
    );
  }
}

/// A stage card: grey inset with a title row and white sub-cards, or a dashed hatched "nothing recorded" card.
class _Stage extends StatelessWidget {
  const _Stage({this.title, this.titleWidget, this.sub, this.trailing, this.trailingInline = false, required this.children})
    : eyebrow = null,
      body = null,
      footer = null;
  const _Stage.missing({required String this.eyebrow, required String this.title, this.body, this.footer})
    : titleWidget = null,
      sub = null,
      trailing = null,
      trailingInline = false,
      children = const [];
  final String? title, sub, eyebrow, body;
  final Widget? titleWidget, trailing, footer;
  final bool trailingInline;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (eyebrow != null) {
      return DashedBorder(
        radius: Tok.rCard,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Tok.rCard),
          child: Hatch(
            stripe: const Color(0xFFF1F2F4),
            background: const Color(0xFFFAFAFB),
            width: 6,
            gap: 6,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Caps(eyebrow!),
                  const SizedBox(height: 2),
                  Text(title!, style: Tok.cardTitle.copyWith(fontSize: 16)),
                  if (body != null) ...[const SizedBox(height: 4), Text(body!, style: Tok.body.copyWith(color: Tok.text2))],
                  if (footer != null) ...[
                    const SizedBox(height: 12),
                    const Divider(color: Tok.line),
                    const SizedBox(height: 8),
                    footer!,
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }
    return InsetCard(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
            child: Row(
              children: [
                Flexible(
                  child:
                      titleWidget ??
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: title, style: Tok.cardTitle),
                            if (sub != null) TextSpan(text: '   $sub', style: Tok.body.copyWith(color: Tok.text2)),
                          ],
                        ),
                      ),
                ),
                if (trailing != null) ...[const SizedBox(width: 10), if (!trailingInline) const Spacer(), trailing!],
              ],
            ),
          ),
          for (final (i, c) in children.indexed) ...[if (i > 0) const SizedBox(height: 6), c],
        ],
      ),
    );
  }
}

/// Left rail of the stage list: the stage's node and the connector down to the next one
/// (solid teal between two recorded stages, dashed grey next to an empty one).
class _Rail extends StatelessWidget {
  const _Rail({required this.node, required this.next, required this.child});
  final TrailNode node;
  final TrailNode? next;
  final Widget child;
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 26,
          child: Column(
            children: [
              const SizedBox(height: 12),
              TrailStepper.node(node),
              if (next != null)
                Expanded(
                  child: CustomPaint(
                    size: const Size(2, double.infinity),
                    painter: _VRule(dashed: node == TrailNode.missing || next == TrailNode.missing),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 10), child: child)),
      ],
    ),
  );
}

class _VRule extends CustomPainter {
  _VRule({required this.dashed});
  final bool dashed;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = dashed ? Tok.dash : Tok.tealRail
      ..strokeWidth = 2;
    final x = size.width / 2;
    if (!dashed) return canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    for (var y = 0.0; y < size.height; y += 9) {
      canvas.drawLine(Offset(x, y), Offset(x, (y + 5).clamp(0, size.height)), p);
    }
  }

  @override
  bool shouldRepaint(_VRule o) => o.dashed != dashed;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/format.dart' as fmt;
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../ask/ask.dart';
import '../contractors/scorecard.dart';
import '../plan/plan_tab.dart';
import 'city_screen.dart';

final wardDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, code) => apiGet(ref, wardPath(code)));

final breakdownProvider = FutureProvider.family<List<Map<String, dynamic>>, (String, String)>((ref, a) async =>
    List<Map<String, dynamic>>.from((await apiGet(ref, '${wardPath(a.$1)}/breakdown', {'dimension': a.$2}))['items']));

/// Ward page. The shell's sidebar switches between Money trail, Plan and Scorecard with `?tab=`.
class WardScreen extends ConsumerWidget {
  const WardScreen(this.code, {super.key, this.tab = 'money'});
  final String code, tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final session = ref.watch(sessionProvider)!;
    final detail = ref.watch(wardDetailProvider(code));
    final w = detail.value == null ? null : Map<String, dynamic>.from(detail.value!['ward']);
    return SetTopBar(
      title: t('ward.label', {'code': code}),
      titleSuffix: w == null ? null : '${w['ward_name']}',
      titleTapLabel: t('ward.choose'),
      // A ward officer is tied to one ward; everyone else can move between wards.
      onTitleTap: session.isOfficer ? null : () => _pickWard(context, ref),
      action: !session.canSeeFlags
          ? AskButton('ward', code)
          : w == null
              ? null
              : AppButton.primary(t('ward.mt.reviewFlags', {'n': w['open_flags']}),
                  icon: Ico.flag, onPressed: () => context.go('/flags?ward=${Uri.encodeComponent(code)}')),
      child: PageBody(children: [
        if (tab == 'plan')
          PlanTab(code)
        else if (tab == 'scorecard')
          WardScorecardTab(code)
        else
          AsyncView(
            value: detail,
            onRetry: () => ref.invalidate(wardDetailProvider(code)),
            lines: 8,
            builder: (data) => _MoneyTrail(code, Map<String, dynamic>.from(data['ward'])),
          ),
      ]),
    );
  }

  Future<void> _pickWard(BuildContext context, WidgetRef ref) async {
    final t = ref.read(stringsProvider);
    final wards = [...await ref.read(wardsProvider.future)]..sort((a, b) => '${a['ward_code']}'.compareTo('${b['ward_code']}'));
    if (!context.mounted) return;
    final c = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(t('ward.choose'), style: Tok.cardTitle),
        children: [
          for (final w in wards)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, '${w['ward_code']}'),
              child: Text.rich(TextSpan(style: Tok.body, children: [
                TextSpan(text: t('ward.label', {'code': w['ward_code']}), style: TextStyle(fontWeight: w['ward_code'] == code ? FontWeight.w600 : FontWeight.w500)),
                TextSpan(text: '  ${w['ward_name']}', style: const TextStyle(color: Tok.text2)),
              ])),
            ),
        ],
      ),
    );
    if (c != null && c != code && context.mounted) context.goWard(c);
  }
}

class _MoneyTrail extends ConsumerWidget {
  const _MoneyTrail(this.code, this.w);
  final String code;
  final Map<String, dynamic> w;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = '${wardPath(code)}/work-orders';
    void open(String title, String query) => showDetail(context, title: title, child: WorkOrderList('$base?$query'));
    final week = _WeekChart(code, w['budget'] as num);
    final summary = SummaryCard('ward', code);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Overview(code, w, onOpen: open),
      const SizedBox(height: Tok.gapPanels),
      _MoneyInQuestion(code, w, onOpen: open),
      const SizedBox(height: Tok.gapPanels),
      LayoutBuilder(builder: (_, box) {
        final table = _SpendTable(code, onOpen: open);
        if (box.maxWidth >= 1000) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: table),
            const SizedBox(width: Tok.gapPanels),
            SizedBox(width: 424, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [week, const SizedBox(height: Tok.gapPanels), summary])),
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          table,
          const SizedBox(height: Tok.gapPanels),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 58, child: week),
            const SizedBox(width: Tok.gapPanels),
            Expanded(flex: 42, child: summary),
          ]),
        ]);
      }),
    ]);
  }
}

// ---------------------------------------------------------------------------------------------------
// Ward overview: four figures, two mini figures and the budget bar
// ---------------------------------------------------------------------------------------------------

class _Overview extends ConsumerWidget {
  const _Overview(this.code, this.w, {required this.onOpen});
  final String code;
  final Map<String, dynamic> w;
  final void Function(String title, String query) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final session = ref.watch(sessionProvider)!;
    final budget = w['budget'] as num, spend = w['spend'] as num, remaining = w['remaining'] as num;
    final over = remaining < 0;
    String share(num part) => fmt.pct(spend <= 0 ? 0 : part / spend);

    final stats = StatRow(children: [
      StatBlock(
        label: t('ward.budget'),
        value: fmt.money(budget),
        icon: Ico.budget,
        sub: t('ward.mt.workOrders', {'n': fmt.count(w['jobs'] as num)}),
        onTap: () => onOpen(t('ward.allJobs', {'n': w['jobs']}), 'filter=all'),
      ),
      StatBlock(label: t('ward.spent'), value: fmt.money(spend), icon: Ico.receipt, sub: t('ward.mt.ofBudget', {'pct': fmt.pct(w['spend_share'] as num)})),
      over
          ? StatBlock(
              label: t('ward.mt.overBy'),
              value: fmt.money(-remaining),
              icon: Ico.alert,
              tone: StatTone.red,
              subLead: t('ward.mt.overBudget'),
              sub: t('ward.mt.past', {'over': fmt.money(-remaining), 'budget': fmt.money(budget)}),
            )
          : StatBlock(label: t('ward.mt.left'), value: fmt.money(remaining), icon: Ico.budget, sub: t('ward.mt.within')),
      // Citizens see the amount in open flags, not the queue behind it.
      StatBlock(
        label: t('ward.tile.flags'),
        value: fmt.money(w['open_flag_amount'] as num),
        icon: Ico.flag,
        tone: StatTone.amber,
        subLead: t('ward.flagsN', {'n': w['open_flags']}),
        sub: t('ward.mt.unreviewed'),
        onTap: session.canSeeFlags ? () => context.go('/flags?ward=${Uri.encodeComponent(code)}') : null,
      ),
    ]);

    Widget mini(IconData icon, String label, num amount, num jobs, String query) => Pressable(
          onTap: () => onOpen(label, query),
          radius: 10,
          child: MiniStat(icon: icon, label: label, value: fmt.money(amount), sub: t('ward.mt.jobsShare', {'n': jobs, 'pct': share(amount)})),
        );
    final reopened = mini(Ico.reopened, t('ward.mt.reopened30'), w['reopened_spend'] as num, w['reopened_jobs'] as num, 'filter=reopened');
    final dlp = mini(Ico.dlp, t('ward.tile.dlp'), w['dlp_spend'] as num, w['dlp_jobs'] as num, 'filter=dlp');
    final bar = BudgetBar(budget: budget, spent: spend);
    Widget rule() => Container(width: 1, height: 44, color: Tok.line, margin: const EdgeInsets.only(right: 20));

    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionHeader(t('ward.mt.overview')),
        const SizedBox(height: 14),
        stats,
        Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.only(top: 14),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Tok.line))),
          child: LayoutBuilder(
            builder: (_, box) => box.maxWidth >= 900
                ? Row(children: [
                    Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: reopened)),
                    rule(),
                    Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: dlp)),
                    rule(),
                    Expanded(flex: 2, child: bar),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: reopened)),
                      rule(),
                      Expanded(child: dlp),
                    ]),
                    Container(
                      margin: const EdgeInsets.only(top: 14),
                      padding: const EdgeInsets.only(top: 14),
                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Tok.line))),
                      child: bar,
                    ),
                  ]),
          ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------------------------------
// Money in question: re-opened, under DLP, in open flags
// ---------------------------------------------------------------------------------------------------

class _MoneyInQuestion extends ConsumerWidget {
  const _MoneyInQuestion(this.code, this.w, {required this.onOpen});
  final String code;
  final Map<String, dynamic> w;
  final void Function(String title, String query) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final session = ref.watch(sessionProvider)!;
    final spend = w['spend'] as num;
    double share(num part) => spend <= 0 ? 0 : (part / spend).toDouble();
    _MiqCard card(int kind, Widget pill, String title, num amount, String unit, {bool amberUnit = false, required String link, VoidCallback? onLink}) => _MiqCard(
          kind: kind,
          illus: t(['ward.mt.illus.reopened', 'ward.mt.illus.dlp', 'ward.mt.illus.flags'][kind]),
          pill: pill,
          title: title,
          amount: fmt.money(amount),
          unit: unit,
          amberUnit: amberUnit,
          share: share(amount),
          shareText: t('ward.mt.shareOfSpend', {'pct': fmt.pct(share(amount))}),
          ofText: t('ward.mt.amountOf', {'part': fmt.money(amount), 'total': fmt.money(spend)}),
          link: link,
          onLink: onLink,
        );
    final cards = [
      card(0, StatusPill(t('ward.mt.repeat')), t('ward.mt.reopened30'), w['reopened_spend'] as num, t('ward.jobs', {'n': w['reopened_jobs']}),
          link: t('ward.mt.seeJobs'), onLink: () => onOpen(t('ward.mt.reopened30'), 'filter=reopened')),
      card(1, StatusPill(t('ward.mt.underDlp'), dot: Tok.amberIcon), t('ward.tile.dlp'), w['dlp_spend'] as num, t('ward.jobs', {'n': w['dlp_jobs']}),
          link: t('ward.mt.seeJobs'), onLink: () => onOpen(t('ward.tile.dlp'), 'filter=dlp')),
      card(2, FlagPill(t('ward.mt.unreviewedPill')), t('ward.tile.flags'), w['open_flag_amount'] as num, t('ward.flagsN', {'n': w['open_flags']}),
          amberUnit: true,
          link: t('ward.mt.reviewFlags', {'n': w['open_flags']}),
          onLink: session.canSeeFlags ? () => context.go('/flags?ward=${Uri.encodeComponent(code)}') : null),
    ];
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 28,
          child: Row(children: [
            Padding(padding: const EdgeInsets.only(left: 2), child: Text(t('ward.mt.miq'), style: Tok.cardTitle)),
            const SizedBox(width: 18),
            Expanded(
              child: Text(t('ward.mt.miqSub', {'amount': fmt.money(spend)}),
                  overflow: TextOverflow.ellipsis, style: Tok.sub.copyWith(fontSize: 12.5)),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 26,
              height: 6,
              child: Row(children: [
                Expanded(flex: 55, child: Container(decoration: BoxDecoration(color: Tok.teal, borderRadius: BorderRadius.circular(Tok.rPill)))),
                Expanded(flex: 45, child: Container(decoration: BoxDecoration(color: Tok.hatchRest1, borderRadius: BorderRadius.circular(Tok.rPill)))),
              ]),
            ),
            const SizedBox(width: 8),
            Text(t('ward.mt.miqLegend'), style: Tok.sub.copyWith(fontSize: 12.5)),
          ]),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (_, box) => box.maxWidth >= 560
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final (i, c) in cards.indexed) ...[if (i > 0) const SizedBox(width: Tok.gapCards), Expanded(child: c)],
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final (i, c) in cards.indexed) ...[if (i > 0) const SizedBox(height: Tok.gapCards), c],
                ]),
        ),
      ]),
    );
  }
}

class _MiqCard extends StatelessWidget {
  const _MiqCard({
    required this.kind,
    required this.illus,
    required this.pill,
    required this.title,
    required this.amount,
    required this.unit,
    required this.amberUnit,
    required this.share,
    required this.shareText,
    required this.ofText,
    required this.link,
    this.onLink,
  });
  final int kind;
  final String illus, title, amount, unit, shareText, ofText, link;
  final Widget pill;
  final bool amberUnit;
  final double share;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) {
    final figure = Text.rich(
      TextSpan(children: [
        TextSpan(text: amount, style: Tok.figure),
        TextSpan(text: '  $unit', style: Tok.emph.copyWith(color: amberUnit ? Tok.amberText : Tok.ink)),
      ]),
      maxLines: 1,
      softWrap: false,
    );
    final heading = Text(title, style: Tok.cardTitle.copyWith(height: 19 / 15, letterSpacing: -0.15));
    Widget slab(double scale) => Semantics(
          label: illus,
          image: true,
          child: SizedBox(width: 216 * scale, height: 160 * scale, child: CustomPaint(painter: _SlabPainter(kind, scale))),
        );
    return InsetCard(
      radius: Tok.rPanel,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LayoutBuilder(
          builder: (_, box) => box.maxWidth >= 330
              ? SizedBox(
                  height: 150,
                  child: Stack(clipBehavior: Clip.none, children: [
                    Positioned(top: -10, right: -6, child: slab(1)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 11),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        pill,
                        const Spacer(),
                        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 152), child: heading),
                        const SizedBox(height: 4),
                        figure,
                      ]),
                    ),
                  ]),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 11),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Stack(children: [Align(alignment: Alignment.topRight, child: slab(0.62)), pill]),
                    heading,
                    const SizedBox(height: 4),
                    FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: figure),
                  ]),
                ),
        ),
        SubCard(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(shareText, style: Tok.body.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Expanded(child: Text(ofText, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, style: Tok.body.copyWith(color: Tok.text2))),
            ]),
            const SizedBox(height: 8),
            ProgressBar(share),
            const SizedBox(height: 11),
            if (onLink == null)
              const SizedBox(height: 13)
            else
              Pressable(
                onTap: onLink,
                radius: 6,
                child: Container(
                  height: 40,
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: Tok.line))),
                  child: Row(children: [
                    Expanded(child: Text(link, style: Tok.body.copyWith(color: Tok.tealDark, fontWeight: FontWeight.w500))),
                    const Icon(Ico.arrowRight, size: 14, color: Tok.tealDark),
                  ]),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// An isometric road slab: 0 asphalt with a pin, 1 concrete with a DLP shield, 2 pavers with a flag.
/// Coordinates follow the mockup's 216 x 160 drawing.
class _SlabPainter extends CustomPainter {
  _SlabPainter(this.kind, this.scale);
  final int kind;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    Path poly(List<double> p) {
      final path = Path()..moveTo(p[0], p[1]);
      for (var i = 2; i < p.length; i += 2) {
        path.lineTo(p[i], p[i + 1]);
      }
      return path..close();
    }

    Paint fill(int c) => Paint()..color = Color(c);
    final edge = Paint()
      ..color = const Color(0xFF2A2E33)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeJoin = StrokeJoin.round;
    final (top, side1, side2) = switch (kind) {
      0 => (0xFF41454B, 0xFF6D737A, 0xFF5B6067),
      1 => (0xFFD6D9DC, 0xFFC4C8CC, 0xFFB9BDC2),
      _ => (0xFFCDBFA6, 0xFFB3A68E, 0xFF9E927C),
    };

    canvas.scale(scale);
    canvas.translate(6, 110.9);
    canvas.scale(1.16);
    // Soft shadow under the slab.
    canvas.drawPath(poly([5, 9, 125.3, -23, 175.7, 7.2, 55.4, 39.2]), Paint()
      ..color = const Color(0x2614181C)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    final left = poly([0, -16, 50.4, 14.2, 50.4, 30.2, 0, 0]);
    final right = poly([50.4, 14.2, 170.7, -17.8, 170.7, -1.8, 50.4, 30.2]);
    canvas.drawPath(left, fill(side1));
    canvas.drawPath(right, fill(side2));
    canvas.drawPath(left, edge);
    canvas.drawPath(right, edge);

    // Top face in its own 128 x 84 plane.
    canvas.save();
    canvas.transform(Matrix4(0.94, -0.25, 0, 0, 0.6, 0.36, 0, 0, 0, 0, 1, 0, 0, -16, 0, 1).storage);
    const face = Rect.fromLTWH(0, 0, 128, 84);
    canvas.drawRect(face, fill(top));
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    void dashed(Offset a, Offset b, Paint p, {double on = 13, double off = 10}) {
      final d = b - a, len = d.distance;
      for (var s = 0.0; s < len; s += on + off) {
        canvas.drawLine(a + d * (s / len), a + d * (math.min(s + on, len) / len), p);
      }
    }

    switch (kind) {
      case 0:
        line.color = const Color(0xFFF4F5F6);
        canvas.drawLine(const Offset(0, 6), const Offset(128, 6), line);
        canvas.drawLine(const Offset(0, 78), const Offset(128, 78), line);
        dashed(const Offset(0, 42), const Offset(128, 42), Paint()
          ..color = Colors.white
          ..strokeWidth = 1.8);
        canvas.drawRect(const Rect.fromLTWH(46, 16, 38, 30), fill(0xFF6D737A));
        canvas.drawRect(const Rect.fromLTWH(46, 16, 38, 30), Paint()
          ..color = const Color(0xFFE9EAEC)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1);
      case 1:
        line.color = const Color(0xFFA2A7AD);
        for (final x in [32.0, 64.0, 96.0]) {
          canvas.drawLine(Offset(x, 0), Offset(x, 84), line);
        }
        canvas.drawLine(const Offset(0, 42), const Offset(128, 42), line);
        canvas.drawRect(const Rect.fromLTWH(38, 10, 52, 40), fill(0xCCE2F1EE));
        final teal = Paint()
          ..color = Tok.teal
          ..strokeWidth = 1.3;
        for (final (a, b) in [
          (const Offset(38, 10), const Offset(90, 10)),
          (const Offset(90, 10), const Offset(90, 50)),
          (const Offset(90, 50), const Offset(38, 50)),
          (const Offset(38, 50), const Offset(38, 10)),
        ]) {
          dashed(a, b, teal, on: 4, off: 3);
        }
        canvas.drawRect(const Rect.fromLTWH(72, 56, 22, 15), fill(0xFF565A60));
      default:
        line.color = const Color(0xFFA89B85);
        for (var x = 8.0; x < 128; x += 8) {
          canvas.drawLine(Offset(x, 0), Offset(x, 84), line..strokeWidth = 0.5);
        }
        for (var y = 6.0; y < 84; y += 6) {
          canvas.drawLine(Offset(0, y), Offset(128, y), line);
        }
        canvas.drawRect(const Rect.fromLTWH(30, 18, 30, 20), fill(0xFFEDE6D8));
        canvas.drawRect(const Rect.fromLTWH(74, 46, 26, 18), fill(0xFFEDE6D8));
    }
    canvas.drawRect(face, edge..strokeWidth = 1.1);
    canvas.restore();

    // Marker standing on the slab.
    final stem = Paint()
      ..color = kind == 2 ? const Color(0xFF3A3F45) : Tok.tealDark
      ..strokeWidth = 1.4;
    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;
    switch (kind) {
      case 0:
        canvas.drawLine(const Offset(79.7, -21.1), const Offset(79.7, -36.1), stem);
        canvas.drawCircle(const Offset(79.7, -40.1), 5.2, fill(0xFF0E6F66));
        canvas.drawCircle(const Offset(79.7, -40.1), 5.2, white);
        canvas.drawCircle(const Offset(79.7, -40.1), 1.6, fill(0xFFFFFFFF));
      case 1:
        canvas.drawLine(const Offset(78.2, -21.2), const Offset(78.2, -35.2), stem);
        final shield = poly([78.2, -51.2, 85.6, -48.3, 85.6, -43, 78.2, -32.7, 70.8, -43, 70.8, -48.3]);
        canvas.drawPath(shield, fill(0xFF0E6F66));
        canvas.drawPath(shield, white);
        canvas.drawPath(
            Path()
              ..moveTo(74.9, -42.3)
              ..lineTo(77.2, -40)
              ..lineTo(81.4, -44.4),
            white..strokeWidth = 1.5);
      default:
        canvas.drawLine(const Offset(80, -20), const Offset(80, -50), stem);
        canvas.drawPath(poly([80, -50, 94, -46, 80, -41]), fill(0xFFE8A33D));
        canvas.drawPath(poly([80, -50, 94, -46, 80, -41]), Paint()
          ..color = Tok.amberIcon
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    }
  }

  @override
  bool shouldRepaint(_SlabPainter o) => o.kind != kind || o.scale != scale;
}

// ---------------------------------------------------------------------------------------------------
// Where did the money go? (spend breakdown, A-Z never needed: sorted by amount, captioned "not a ranking")
// ---------------------------------------------------------------------------------------------------

/// A round axis step near [raw] (1, 2 or 5 times a power of ten).
double _niceStep(num raw) {
  if (raw <= 0) return 1e5;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  return [1, 2, 5, 10].map((m) => m * mag).firstWhere((s) => s >= raw);
}

String _axis(num v) {
  String trim(double x) => x == x.roundToDouble() ? '${x.toInt()}' : x.toStringAsFixed(1);
  if (v == 0) return fmt.rupees(0);
  if (v >= 1e7) return '₹${trim(v / 1e7)} cr';
  if (v >= 1e5) return '₹${trim(v / 1e5)} L';
  return fmt.money(v);
}

String _weekLabel(String label) => label.replaceFirst(RegExp(r'^0'), '');

class _SpendTable extends ConsumerStatefulWidget {
  const _SpendTable(this.code, {required this.onOpen});
  final String code;
  final void Function(String title, String query) onOpen;
  @override
  ConsumerState<_SpendTable> createState() => _SpendTableState();
}

class _SpendTableState extends ConsumerState<_SpendTable> {
  String _dim = 'contractor';
  static const _param = {'contractor': 'contractor_id', 'method': 'method', 'week': 'week'};
  static const _spentW = 84.0, _jobsW = 72.0, _chevW = 24.0;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final key = (widget.code, _dim);
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Padding(padding: const EdgeInsets.only(left: 2), child: Text(t('ward.mt.whereMoney'), style: Tok.cardTitle))),
          Text(t('ward.mt.spendBy'), style: Tok.body.copyWith(color: Tok.text2)),
          const SizedBox(width: 10),
          SegmentedTabs<String>(
            items: [for (final d in _param.keys) TabItem(d, t('ward.dim.$d'))],
            value: _dim,
            onChanged: (d) => setState(() => _dim = d),
          ),
        ]),
        const SizedBox(height: 10),
        AsyncView(
          value: ref.watch(breakdownProvider(key)),
          onRetry: () => ref.invalidate(breakdownProvider(key)),
          builder: (items) => items.isEmpty ? EmptyState(t('wo.empty')) : _table(t, items),
        ),
      ]),
    );
  }

  Widget _table(Strings t, List<Map<String, dynamic>> items) {
    final contractor = _dim == 'contractor';
    final maxSpend = items.fold<num>(0, (m, i) => math.max(m, i['spend'] as num));
    final step = _niceStep(maxSpend / 3);
    final axisMax = math.max(step, (maxSpend / step).ceil() * step);
    final ticks = [for (var v = 0.0; v <= axisMax + 1; v += step) v];
    final total = items.fold<num>(0, (a, i) => a + (i['spend'] as num));
    final jobs = items.fold<num>(0, (a, i) => a + (i['jobs'] as num));
    String label(Map<String, dynamic> i) => _dim == 'week' ? _weekLabel('${i['label']}') : '${i['label']}';

    Widget grid({Widget? child}) => LayoutBuilder(
          builder: (_, box) => Stack(clipBehavior: Clip.none, children: [
            for (final v in ticks.skip(1))
              Positioned(left: box.maxWidth * v / axisMax, top: -16, bottom: -16, child: Container(width: 1, color: Tok.lineInset)),
            ?child,
          ]),
        );

    Widget row({required Widget lead, required Widget bar, required Widget spent, required Widget count, Widget? trail}) => Row(children: [
          Expanded(flex: 5, child: lead),
          Expanded(flex: 4, child: bar),
          SizedBox(width: _spentW, child: Align(alignment: Alignment.centerRight, child: spent)),
          SizedBox(width: _jobsW, child: Align(alignment: Alignment.centerRight, child: count)),
          SizedBox(width: _chevW, child: trail),
        ]);

    final header = SizedBox(
      height: 30,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: row(
          lead: Caps(t('ward.dim.$_dim')),
          bar: LayoutBuilder(
            builder: (_, box) => Stack(clipBehavior: Clip.none, children: [
              for (final v in ticks)
                Positioned(
                  left: box.maxWidth * v / axisMax - (v == 0 ? 0 : 14),
                  top: 7,
                  child: Text(_axis(v), style: Tok.caps.copyWith(letterSpacing: 0.3)),
                ),
            ]),
          ),
          spent: Caps(t('ward.mt.colSpent')),
          count: Caps(t('ward.mt.colJobs')),
        ),
      ),
    );

    final rows = [
      for (final i in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Pressable(
            onTap: () => widget.onOpen(label(i), '${_param[_dim]}=${Uri.encodeQueryComponent('${i['key']}')}'),
            radius: 10,
            builder: (_, hover) => Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: hover ? Tok.lineSoft : Tok.inset,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Tok.lineInset),
              ),
              child: row(
                lead: Row(children: [
                  if (contractor) ...[_Initials(label(i)), const SizedBox(width: 14)],
                  Expanded(child: _Name(label(i))),
                  const SizedBox(width: 12),
                ]),
                bar: grid(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: ((i['spend'] as num) / axisMax).clamp(0, 1).toDouble(),
                      child: Container(height: 10, decoration: BoxDecoration(color: Tok.teal, borderRadius: BorderRadius.circular(Tok.rPill))),
                    ),
                  ),
                ),
                spent: Text(fmt.money(i['spend'] as num), style: Tok.body.copyWith(fontWeight: FontWeight.w600)),
                count: Text(t('ward.jobs', {'n': i['jobs']}), style: Tok.body.copyWith(color: Tok.text2)),
                trail: const Align(alignment: Alignment.centerRight, child: Icon(Ico.chevronRight, size: 16, color: Tok.text3)),
              ),
            ),
          ),
        ),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      header,
      const SizedBox(height: 4),
      ...rows,
      Container(
        height: 44,
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Tok.line), bottom: BorderSide(color: Tok.line))),
        child: row(
          lead: Text.rich(TextSpan(style: Tok.body, children: [
            TextSpan(text: t('ward.mt.total'), style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: ' · ${t('ward.mt.totalN.$_dim', {'n': items.length})}', style: const TextStyle(color: Tok.text2)),
          ])),
          bar: const SizedBox(),
          spent: Text(fmt.money(total), style: Tok.body.copyWith(fontWeight: FontWeight.w600)),
          count: Text(t('ward.jobs', {'n': jobs}), style: Tok.body.copyWith(color: Tok.text2)),
        ),
      ),
      const SizedBox(height: 10),
      Row(children: [
        const SizedBox(width: 4),
        const Icon(Ico.info, size: 14, color: Tok.text3),
        const SizedBox(width: 8),
        Expanded(child: Text(t('ward.mt.note.$_dim'), style: Tok.sub.copyWith(fontSize: 12.5))),
      ]),
    ]);
  }
}

class _Initials extends StatelessWidget {
  const _Initials(this.name);
  final String name;
  @override
  Widget build(BuildContext context) {
    final words = name.replaceAll(RegExp(r'\(.*?\)'), '').trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final initials = words.take(2).map((w) => w[0].toUpperCase()).join();
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Tok.panel, borderRadius: BorderRadius.circular(7), border: Border.all(color: Tok.line)),
      child: Text(initials, style: Tok.caps.copyWith(color: Tok.text2, fontWeight: FontWeight.w600, letterSpacing: 0)),
    );
  }
}

/// A name as stored, with a trailing "(synthetic)" shown in grey.
class _Name extends StatelessWidget {
  const _Name(this.name);
  final String name;
  @override
  Widget build(BuildContext context) {
    final m = RegExp(r'^(.*?)(\s*\(.*\))$').firstMatch(name);
    return Text.rich(
      TextSpan(style: Tok.body.copyWith(fontWeight: FontWeight.w500), children: [
        TextSpan(text: m?.group(1) ?? name),
        if (m != null) TextSpan(text: m.group(2), style: const TextStyle(color: Tok.text2, fontWeight: FontWeight.w400)),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ---------------------------------------------------------------------------------------------------
// Spend by week, with the week the running total crossed the budget
// ---------------------------------------------------------------------------------------------------

class _WeekChart extends ConsumerWidget {
  const _WeekChart(this.code, this.budget);
  final String code;
  final num budget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final key = (code, 'week');
    return Panel(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(t('ward.mt.byWeek'), style: Tok.cardTitle)),
          Text(t('ward.mt.byWeekUnit'), style: Tok.sub.copyWith(fontSize: 12.5)),
        ]),
        const SizedBox(height: 8),
        AsyncView(
          value: ref.watch(breakdownProvider(key)),
          onRetry: () => ref.invalidate(breakdownProvider(key)),
          builder: (items) {
            if (items.isEmpty) return EmptyState(t('wo.empty'));
            final spend = [for (final i in items) (i['spend'] as num).toDouble()];
            final within = <double>[];
            var cum = 0.0;
            int? crossed;
            for (final (i, s) in spend.indexed) {
              within.add((budget - cum).clamp(0, s).toDouble());
              cum += s;
              if (crossed == null && cum > budget) crossed = i;
            }
            final over = crossed != null;
            Widget swatch(Widget fill) => SizedBox(width: 14, height: 10, child: ClipRRect(borderRadius: BorderRadius.circular(3), child: fill));
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                height: 24,
                child: over
                    ? Align(alignment: Alignment.centerRight, child: Pill(t('ward.mt.crossed', {'amount': fmt.money(budget)}), tone: Tone.error, icon: Ico.alert))
                    : null,
              ),
              SizedBox(
                height: 200,
                child: CustomPaint(
                  painter: _WeekPainter(
                    labels: [for (final i in items) _weekLabel('${i['label']}')],
                    spend: spend,
                    within: within,
                    crossed: crossed,
                    overLabel: t('ward.mt.overLabel'),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.only(top: 10),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Tok.line))),
                child: Wrap(spacing: 16, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    swatch(const ColoredBox(color: Tok.teal)),
                    const SizedBox(width: 7),
                    Text(t('ward.mt.within'), style: Tok.sub.copyWith(fontSize: 12.5)),
                  ]),
                  if (over)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      swatch(Container(foregroundDecoration: BoxDecoration(border: Border.all(color: Tok.red), borderRadius: BorderRadius.circular(3)), child: const Hatch.over())),
                      const SizedBox(width: 7),
                      Text(t('ward.mt.overBudget'), style: Tok.sub.copyWith(fontSize: 12.5)),
                    ]),
                  Text.rich(TextSpan(style: Tok.body.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500), children: [
                    TextSpan(text: t('ward.mt.weeks', {'n': items.length})),
                    const TextSpan(text: ' · ', style: TextStyle(color: Tok.sep, fontWeight: FontWeight.w400)),
                    TextSpan(text: fmt.money(cum)),
                  ])),
                ]),
              ),
            ]);
          },
        ),
      ]),
    );
  }
}

class _WeekPainter extends CustomPainter {
  _WeekPainter({required this.labels, required this.spend, required this.within, required this.crossed, required this.overLabel});
  final List<String> labels;
  final List<double> spend, within;
  final int? crossed;
  final String overLabel;

  static const _axisW = 40.0, _top = 20.0, _bottom = 46.0;

  void _text(Canvas canvas, String s, TextStyle style, Offset at, {double align = 0}) {
    final tp = TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, at - Offset(tp.width * align, 0));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = spend.length;
    final maxV = spend.fold<double>(1, math.max);
    final step = _niceStep(maxV / 2);
    final plotH = size.height - _top - _bottom, plotW = size.width - _axisW;
    final base = _top + plotH;
    double y(double v) => base - plotH * v / maxV;
    final small = Tok.caps.copyWith(fontSize: 11.5, letterSpacing: 0, color: Tok.text2);

    final gridPaint = Paint()..color = Tok.lineSoft;
    for (var v = 0.0; v <= maxV; v += step) {
      canvas.drawLine(Offset(_axisW, y(v)), Offset(size.width, y(v)), gridPaint);
      _text(canvas, _axis(v), small.copyWith(color: Tok.text3), Offset(_axisW - 6, y(v) - 8), align: 1);
    }

    final slot = plotW / n;
    final barW = math.min(slot * 0.62, 28.0);
    // Thin the labels when weeks are narrow; the crossing week always keeps its figure.
    final labelEvery = math.max(1, (44 / slot).ceil());
    final showValues = slot >= 26;
    int? firstOver, lastOver;
    for (var i = 0; i < n; i++) {
      final cx = _axisW + slot * (i + 0.5);
      final l = cx - barW / 2;
      final wTop = y(within[i]);
      final topY = y(spend[i]);
      final overPart = spend[i] - within[i] > 0.5;
      if (within[i] > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(Rect.fromLTRB(l, wTop, l + barW, base),
              topLeft: overPart ? Radius.zero : const Radius.circular(3), topRight: overPart ? Radius.zero : const Radius.circular(3)),
          Paint()..color = Tok.teal,
        );
      }
      if (overPart) {
        firstOver ??= i;
        lastOver = i;
        final r = Rect.fromLTRB(l, topY, l + barW, within[i] > 0 ? wTop - 2 : base);
        canvas.save();
        canvas.clipRRect(RRect.fromRectAndCorners(r, topLeft: const Radius.circular(3), topRight: const Radius.circular(3)));
        paintHatch(canvas, r, Tok.red, Tok.redHatch, width: 2.5, gap: 3.5);
        canvas.restore();
        canvas.drawRRect(
          RRect.fromRectAndCorners(r.deflate(0.5), topLeft: const Radius.circular(3), topRight: const Radius.circular(3)),
          Paint()
            ..color = Tok.red
            ..style = PaintingStyle.stroke,
        );
      }
      if (showValues || i == crossed) {
        _text(canvas, (spend[i] / 1e5).toStringAsFixed(1), Tok.body.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: overPart ? Tok.red : Tok.ink),
            Offset(cx, topY - 17), align: 0.5);
      }
      if (i % labelEvery == 0) _text(canvas, labels[i], small, Offset(cx, base + 6), align: 0.5);
      if (i == crossed) {
        final dash = Paint()
          ..color = Tok.text2
          ..strokeWidth = 1;
        for (var yy = -4.0; yy < topY - 20; yy += 6) {
          canvas.drawLine(Offset(cx, yy), Offset(cx, math.min(yy + 3, topY - 20)), dash);
        }
      }
    }
    if (firstOver != null) {
      final x0 = _axisW + slot * firstOver + 2, x1 = _axisW + slot * (lastOver! + 1) - 2;
      canvas.drawLine(Offset(x0, base + 24), Offset(x1, base + 24), Paint()
        ..color = Tok.red
        ..strokeWidth = 1.5);
      _text(canvas, overLabel, small.copyWith(color: Tok.red, fontWeight: FontWeight.w500), Offset((x0 + x1) / 2, base + 27), align: 0.5);
    }
    canvas.drawLine(Offset(_axisW, base), Offset(size.width, base), Paint()..color = Tok.line);
  }

  @override
  bool shouldRepaint(_WeekPainter o) => o.spend != spend || o.within != within || o.labels != labels || o.overLabel != overLabel;
}

/// Shared "Works" components. Every screen builds from these and from `Tok` in theme.dart.
/// Text comes from strings.dart (`ref.watch(stringsProvider)`), never hard-coded.
///
/// Layout and chrome
///   SetTopBar({title, titleSuffix, crumbs, onBack, onTitleTap, titleTapLabel, action, required child})
///   Crumb(label, {onTap})
///   DetailPanelLayout({required main, panel, onClose})        page + 440 px right panel, no dimming
///   DetailPanel({required title, required onClose, required child, eyebrow, eyebrowIcon, eyebrowColor, subtitle, footer, scroll = true})
///   showDetail(context, {required title, required child}) / closeDetail(context)   shell-level panel; child must scroll itself (ListView)
///   PageBody({required children, gap = 10})                   scrolling column of panels
///   Panel({required child, title, sub, trailing, padding})    white r16 section panel
///   SectionHeader(title, {sub, trailing, large = false})
///   InsetCard({required child, padding, radius = 12})         grey card
///   SubCard({required child, padding})                        white sub-card inside an InsetCard
///   Caps(text, {color})                                       11 px tiny caps label
/// Figures
///   StatBlock({required label, required value, icon, unit, sub, subLead, tone = StatTone.neutral, onTap})
///   StatRow({required children, flex})                        stats split by thin vertical rules
///   MiniStat({required icon, required label, required value, sub})
/// Controls
///   AppButton.primary(label, {icon, onPressed}) / .outlined(label, {icon, trailingIcon, onPressed}) / .quiet(label, {icon, trailingIcon = Ico.arrowRight, onPressed})
///   AppIconButton(icon, {required tooltip, onPressed})
///   Pressable({child | builder, onTap, radius, semanticLabel, selected, tooltip})   focus ring + hover for custom controls
///   `SegmentedTabs<T>`({required items, required value, required onChanged})      white segmented control
///   `UnderlineTabs<T>`({required items, required value, required onChanged})      tabs with teal underline
///   `TabItem<T>`(value, label, {count})
///   CountBadge(n)                                             dark count badge
/// Chips
///   StatusPill(label, {dot = Tok.dot})                        white pill with a dot (No DLP, Under DLP, Bus route)
///   FlagPill(label)                                           amber pill with flag icon ("4 open flags")
///   DecisionChip(decision)    'open' | 'needs_explanation' | 'confirmed' | 'not_an_issue' | 'watch'
///   BandChip(band, {label})   'well_above' | 'above' | 'similar' | 'typical' | 'below' | 'well_below' | 'too_few' | 'review'
///   Pill(label, {tone = Tone.neutral, icon})                  generic 24 px chip
///   SyntheticTag() (alias SyntheticDataTag)                   dashed "Synthetic data" tag
/// Bars and charts
///   Hatch({required stripe, required background, width = 4, gap = 4, child})  135° stripes (CustomPainter)
///   ProgressBar(value, {height = 6})                          teal on pale hatched remainder
///   BudgetBar({required budget, required spent, showLabels = true})
///   CompareBars({required bars, caption}) with CompareBar(label, share, valueText, {hatched = false})
///   RangeStrip({required ratio, low = 0.77, watch = 1.3, flag = 1.5, max = 2.0})
///   TrailStepper({required steps}) with TrailStep(label, title, {sub, node = TrailNode.recorded})
///   EvidencePair({required leftTitle, required rightTitle, rightNote, required rows})
///     EvidenceRow(label, {required left, required right, matches = true, tag, tagIcon})
///   BudgetLine(title, {sub, above, below, icon})              dashed divider with a centred label
///   WorksTable({required columns, required rows, onRowTap, selected})
///     WorksColumn(label, {flex = 1, width, numeric = false, sorted})
///   BarList(items) with BarItem(...)                          (older screens)
/// States
///   EmptyState(message, {lead, icon})                         dashed box
///   ErrorState(error, {onRetry, title})                       red box with Retry and request id
///   LoadingSkeleton({lines = 4})
///   `AsyncView<T>`({required value, required builder, onRetry, lines})
/// Data helpers kept from before: StatTile, SectionCard, WorkOrderList, WorkOrderCard, ComingSoon, context.goWard.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_state.dart';
import 'format.dart' as fmt;
import 'theme.dart';

// =====================================================================================================
// Icons: thin outlined Material icons standing in for the board's 1.6-stroke set. Use these names.
// =====================================================================================================

abstract final class Ico {
  static const home = Icons.home_outlined;
  static const budget = Icons.account_balance_wallet_outlined;
  static const flag = Icons.outlined_flag;
  static const contractor = Icons.work_outline;
  static const trail = Icons.route_outlined;
  static const newRecord = Icons.note_add_outlined;
  static const data = Icons.storage_outlined;
  static const question = Icons.help_outline;
  static const settings = Icons.settings_outlined;
  static const darkMode = Icons.dark_mode_outlined;
  static const search = Icons.search;
  static const filter = Icons.tune;
  static const grid = Icons.grid_view_outlined;
  static const sidebar = Icons.view_sidebar_outlined;
  static const chevronDown = Icons.keyboard_arrow_down;
  static const chevronUp = Icons.keyboard_arrow_up;
  static const chevronLeft = Icons.chevron_left;
  static const chevronRight = Icons.chevron_right;
  static const arrowRight = Icons.arrow_forward;
  static const arrowUp = Icons.arrow_upward;
  static const arrowDown = Icons.arrow_downward;
  static const upDouble = Icons.keyboard_double_arrow_up;
  static const downDouble = Icons.keyboard_double_arrow_down;
  static const equals = Icons.drag_handle;
  static const minus = Icons.remove;
  static const sort = Icons.swap_vert;
  static const more = Icons.more_vert;
  static const receipt = Icons.receipt_long_outlined;
  static const alert = Icons.warning_amber_rounded;
  static const reopened = Icons.history;
  static const dlp = Icons.shield_outlined;
  static const summary = Icons.auto_awesome_outlined;
  static const ask = Icons.chat_bubble_outline;
  static const synthetic = Icons.science_outlined;
  static const map = Icons.map_outlined;
  static const table = Icons.table_chart_outlined;
  static const check = Icons.check;
  static const eye = Icons.visibility_outlined;
  static const close = Icons.close;
  static const calendar = Icons.calendar_today_outlined;
  static const link = Icons.link;
  static const rupee = Icons.currency_rupee;
  static const open = Icons.radio_button_unchecked;
  static const pin = Icons.place_outlined;
  static const export = Icons.file_download_outlined;
  static const retry = Icons.refresh;
  static const info = Icons.info_outline;
  static const logout = Icons.logout;
}

// =====================================================================================================
// Primitives
// =====================================================================================================

/// 2 px white + 2 px teal ring outside the control, shown for keyboard focus only.
const _focusRing = [BoxShadow(color: Tok.teal, spreadRadius: 4), BoxShadow(color: Colors.white, spreadRadius: 2)];

/// A focusable, hoverable tap target with the design's keyboard focus ring. Enter and Space activate it.
/// Pass [child], or [builder] to style by hover state.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    this.child,
    this.builder,
    this.onTap,
    this.radius = Tok.rControl,
    this.semanticLabel,
    this.selected = false,
    this.tooltip,
  }) : assert(child != null || builder != null);
  final Widget? child;
  final Widget Function(BuildContext context, bool hovered)? builder;
  final VoidCallback? onTap;
  final double radius;
  final String? semanticLabel, tooltip;
  final bool selected;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _focus = false, _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    Widget w = FocusableActionDetector(
      enabled: enabled,
      mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: (v) => setState(() => _focus = v),
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onTap?.call())},
      child: Semantics(
        button: enabled,
        selected: widget.selected,
        label: widget.semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(widget.radius), boxShadow: _focus ? _focusRing : null),
            child: widget.builder?.call(context, _hover && enabled) ?? widget.child,
          ),
        ),
      ),
    );
    if (widget.tooltip != null) w = Tooltip(message: widget.tooltip!, child: w);
    return w;
  }
}

/// Tiny caps label: 11 px, weight 500, +0.06em, grey.
class Caps extends StatelessWidget {
  const Caps(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: Tok.caps.copyWith(color: color));
}

/// Paints a dashed rounded-rectangle border over its child.
class DashedBorder extends StatelessWidget {
  const DashedBorder({
    super.key,
    required this.child,
    this.color = Tok.dash,
    this.radius = Tok.rPill,
    this.width = 1,
    this.dash = 3,
    this.gap = 2.5,
  });
  final Widget child;
  final Color color;
  final double radius, width, dash, gap;
  @override
  Widget build(BuildContext context) => CustomPaint(foregroundPainter: _DashedRRectPainter(color, radius, width, dash, gap), child: child);
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter(this.color, this.radius, this.width, this.dash, this.gap);
  final Color color;
  final double radius, width, dash, gap;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(radius, size.shortestSide / 2);
    final rect = (Offset.zero & size).deflate(width / 2);
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)));
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += dash + gap) {
        canvas.drawPath(m.extractPath(d, math.min(d + dash, m.length)), p);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter o) => o.color != color || o.radius != radius || o.width != width;
}

/// A horizontal dashed or solid rule.
class _HRule extends StatelessWidget {
  const _HRule({required this.color, this.dashed = true});
  static const width = 2.0;
  final Color color;
  final bool dashed;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: width,
    child: dashed ? CustomPaint(painter: _DashLinePainter(color, width)) : ColoredBox(color: color),
  );
}

class _DashLinePainter extends CustomPainter {
  _DashLinePainter(this.color, this.width);
  static const dash = 5.0, gap = 4.0;
  final Color color;
  final double width;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = width;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + dash, size.width), y), p);
    }
  }

  @override
  bool shouldRepaint(_DashLinePainter o) => o.color != color;
}

/// 135° stripes: [width] px of [stripe] then [gap] px of [background], like CSS repeating-linear-gradient(135deg, ...).
void paintHatch(Canvas canvas, Rect rect, Color stripe, Color background, {double width = 4, double gap = 4}) {
  canvas.save();
  canvas.clipRect(rect);
  canvas.drawRect(rect, Paint()..color = background);
  final p = Paint()
    ..color = stripe
    ..strokeWidth = width;
  final step = (width + gap) * math.sqrt2; // spacing along x for lines x + y = c
  final h = rect.height;
  for (var c = rect.left - h; c < rect.right + h; c += step) {
    canvas.drawLine(Offset(c + h, rect.top), Offset(c, rect.bottom), p);
  }
  canvas.restore();
}

class HatchPainter extends CustomPainter {
  HatchPainter({required this.stripe, required this.background, this.width = 4, this.gap = 4});
  final Color stripe, background;
  final double width, gap;
  @override
  void paint(Canvas canvas, Size size) => paintHatch(canvas, Offset.zero & size, stripe, background, width: width, gap: gap);
  @override
  bool shouldRepaint(HatchPainter o) => o.stripe != stripe || o.background != background || o.width != width || o.gap != gap;
}

/// A box filled with 135° stripes. Presets: [Hatch.rest] (pale remainder), [Hatch.over] (red overspend),
/// [Hatch.similar] (grey "similar jobs" bar).
class Hatch extends StatelessWidget {
  const Hatch({super.key, required this.stripe, required this.background, this.width = 4, this.gap = 4, this.child});
  const Hatch.rest({super.key, this.child}) : stripe = Tok.hatchRest1, background = Tok.hatchRest2, width = 3, gap = 3;
  const Hatch.over({super.key, this.child}) : stripe = Tok.red, background = Tok.redHatch, width = 2.5, gap = 3.5;
  const Hatch.similar({super.key, this.child}) : stripe = Tok.strongLine, background = Tok.hatchRest1, width = 2, gap = 3;
  final Color stripe, background;
  final double width, gap;
  final Widget? child;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: HatchPainter(stripe: stripe, background: background, width: width, gap: gap),
    child: child ?? const SizedBox.expand(),
  );
}

// =====================================================================================================
// Panels, cards and headers
// =====================================================================================================

/// Panel title row (28 px): 15 px title, optional grey sub-line beside it, trailing widget at the right.
/// [large] uses the 18 px section size for long pages.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.sub, this.trailing, this.large = false});
  final String title;
  final String? sub;
  final Widget? trailing;
  final bool large;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 28),
    child: Row(
      children: [
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: title, style: large ? Tok.section : Tok.cardTitle),
                if (sub != null)
                  TextSpan(
                    text: '    $sub',
                    style: Tok.body.copyWith(color: Tok.text2),
                  ),
              ],
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: Tok.s3), const Spacer(), trailing!],
      ],
    ),
  );
}

/// White section panel: radius 16, 1 px line, faint shadow.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.title,
    this.sub,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(18, 14, 18, 16),
  });
  final Widget child;
  final String? title, sub;
  final Widget? trailing;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Tok.panel,
      borderRadius: BorderRadius.circular(Tok.rPanel),
      border: Border.all(color: Tok.line),
      boxShadow: Tok.shadowPanel,
    ),
    child: title == null
        ? child
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SectionHeader(title!, sub: sub, trailing: trailing),
              const SizedBox(height: Tok.s3),
              child,
            ],
          ),
  );
}

/// Grey card (inset ground). Put a [SubCard] inside for the white sub-card.
class InsetCard extends StatelessWidget {
  const InsetCard({super.key, required this.child, this.padding = const EdgeInsets.all(6), this.radius = Tok.rCard});
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Tok.inset,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Tok.lineInset),
    ),
    child: child,
  );
}

/// White sub-card inside an InsetCard.
class SubCard extends StatelessWidget {
  const SubCard({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(14, 10, 14, 13)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Tok.panel,
      borderRadius: BorderRadius.circular(Tok.rCard),
      border: Border.all(color: Tok.line),
      boxShadow: Tok.shadowControl,
    ),
    child: child,
  );
}

/// A page body: scrolls, panels stacked with a 10 px gap. Sits inside the shell's content column.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.gap = Tok.gapPanels});
  final List<Widget> children;
  final double gap;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, w) in children.indexed) ...[if (i > 0) SizedBox(height: gap), w],
      ],
    ),
  );
}

/// Older screens' titled card; now a [Panel].
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.title, this.trailing, this.padding = const EdgeInsets.fromLTRB(18, 14, 18, 16)});
  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Panel(title: title, trailing: trailing, padding: padding, child: child);
}

// =====================================================================================================
// Figures
// =====================================================================================================

/// red = overspend or confirmed only; amber = unreviewed flags only.
enum StatTone { neutral, red, amber }

(Color fig, Color icon) _statColors(StatTone t) => switch (t) {
  StatTone.red => (Tok.red, Tok.red),
  StatTone.amber => (Tok.amberText, Tok.amberIcon),
  StatTone.neutral => (Tok.ink, Tok.text3),
};

/// Small icon + grey label, 28 px figure (with optional [unit] word), grey sub-line. [subLead] is a coloured
/// lead word in the sub-line ("Over budget", "Unreviewed").
class StatBlock extends StatelessWidget {
  const StatBlock({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.unit,
    this.sub,
    this.subLead,
    this.tone = StatTone.neutral,
    this.onTap,
  });
  final String label, value;
  final IconData? icon;
  final String? unit, sub, subLead;
  final StatTone tone;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final (fig, ic) = _statColors(tone);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 14, color: ic), const SizedBox(width: 7)],
            Flexible(
              child: Text(
                label,
                style: Tok.body.copyWith(color: Tok.text2, height: 18 / 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: Tok.figure.copyWith(color: fig),
              ),
              if (unit != null)
                TextSpan(
                  text: ' $unit',
                  style: Tok.emph.copyWith(fontSize: 16, color: fig),
                ),
            ],
          ),
        ),
        if (sub != null || subLead != null) ...[
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              style: Tok.sub.copyWith(fontSize: 12.5),
              children: [
                if (subLead != null)
                  TextSpan(
                    text: subLead,
                    style: TextStyle(color: fig == Tok.ink ? Tok.ink : fig, fontWeight: FontWeight.w500),
                  ),
                if (subLead != null && sub != null) const TextSpan(text: ' · '),
                if (sub != null) TextSpan(text: sub),
              ],
            ),
          ),
        ],
      ],
    );
    return onTap == null ? body : Pressable(onTap: onTap, radius: 8, child: body);
  }
}

/// Stats in a row, divided by thin vertical rules (20 px padding after each rule).
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.children, this.flex});
  final List<Widget> children;
  final List<int>? flex;
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, c) in children.indexed)
          Expanded(
            flex: flex?[i] ?? 1,
            child: Container(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 20, right: 12, top: 2, bottom: 2),
              decoration: i == 0
                  ? null
                  : const BoxDecoration(
                      border: Border(left: BorderSide(color: Tok.line)),
                    ),
              child: c,
            ),
          ),
      ],
    ),
  );
}

/// Compact stat: 34 px grey icon tile, label, 16 px figure with a sub-line beside it.
class MiniStat extends StatelessWidget {
  const MiniStat({super.key, required this.icon, required this.label, required this.value, this.sub});
  final IconData icon;
  final String label, value;
  final String? sub;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Tok.inset,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Tok.lineInset),
        ),
        child: Icon(icon, size: 15, color: Tok.text2),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: Tok.sub.copyWith(fontSize: 12.5)),
            const SizedBox(height: 1),
            Text.rich(
              TextSpan(
                style: Tok.body.copyWith(color: Tok.text2),
                children: [
                  TextSpan(
                    text: value,
                    style: Tok.emph.copyWith(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.16),
                  ),
                  if (sub != null) TextSpan(text: '  $sub'),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Older screens' clickable stat card; now a Panel with a StatBlock.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.sub, this.onTap, this.tone = Tone.neutral});
  final String label, value;
  final String? sub;
  final VoidCallback? onTap;
  final Tone tone;
  @override
  Widget build(BuildContext context) => Panel(
    child: StatBlock(
      label: label,
      value: value,
      sub: sub,
      onTap: onTap,
      tone: switch (tone) {
        Tone.error => StatTone.red,
        Tone.flag => StatTone.amber,
        _ => StatTone.neutral,
      },
    ),
  );
}

// =====================================================================================================
// Buttons, tabs, badges
// =====================================================================================================

enum BtnKind { primary, outlined, quiet }

/// 34 px, radius 10, 13 px label. One primary per screen.
class AppButton extends StatelessWidget {
  const AppButton.primary(this.label, {super.key, this.icon, this.onPressed}) : kind = BtnKind.primary, trailingIcon = null;
  const AppButton.outlined(this.label, {super.key, this.icon, this.trailingIcon, this.onPressed}) : kind = BtnKind.outlined;
  const AppButton.quiet(this.label, {super.key, this.icon, this.trailingIcon = Ico.arrowRight, this.onPressed}) : kind = BtnKind.quiet;
  final String label;
  final IconData? icon, trailingIcon;
  final VoidCallback? onPressed;
  final BtnKind kind;

  @override
  Widget build(BuildContext context) {
    final off = onPressed == null;
    return Pressable(
      onTap: onPressed,
      builder: (_, hover) {
        final (Color bg, Color? border, Color fg, List<BoxShadow>? shadow) = switch (kind) {
          _ when off && kind != BtnKind.quiet => (Tok.inset, Tok.line, Tok.text3, null),
          BtnKind.primary => (
            hover ? Tok.tealDark : Tok.teal,
            Tok.tealDark,
            Colors.white,
            const [BoxShadow(color: Color(0x590A5750), offset: Offset(0, 1), blurRadius: 2)],
          ),
          BtnKind.outlined => (hover ? Tok.inset : Tok.panel, Tok.line, Tok.ink, Tok.shadowControl),
          BtnKind.quiet => (hover && !off ? Tok.tealTint : Colors.transparent, null, off ? Tok.text3 : Tok.tealDark, null),
        };
        return Container(
          height: Tok.controlH,
          padding: EdgeInsets.fromLTRB(
            kind == BtnKind.quiet ? 10 : 12,
            0,
            kind == BtnKind.primary ? 14 : (kind == BtnKind.quiet ? 10 : 12),
            0,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Tok.rControl),
            border: Border.all(color: border ?? Colors.transparent),
            boxShadow: shadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 7)],
              Text(
                label,
                style: Tok.body.copyWith(color: fg, fontWeight: kind == BtnKind.primary ? FontWeight.w600 : FontWeight.w500),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 6),
                Icon(trailingIcon, size: 13, color: kind == BtnKind.outlined ? Tok.text3 : fg),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// 34 px square outlined icon button. [tooltip] doubles as the accessible label.
class AppIconButton extends StatelessWidget {
  const AppIconButton(this.icon, {super.key, required this.tooltip, this.onPressed});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onPressed,
    tooltip: tooltip,
    semanticLabel: tooltip,
    builder: (_, hover) => Container(
      width: Tok.controlH,
      height: Tok.controlH,
      decoration: BoxDecoration(
        color: onPressed == null || hover ? Tok.inset : Tok.panel,
        borderRadius: BorderRadius.circular(Tok.rControl),
        border: Border.all(color: Tok.line),
        boxShadow: Tok.shadowControl,
      ),
      child: Icon(icon, size: 16, color: onPressed == null ? Tok.text3 : Tok.ink),
    ),
  );
}

/// Dark count badge (Flags 12).
class CountBadge extends StatelessWidget {
  const CountBadge(this.n, {super.key});
  final int n;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 18),
    height: 18,
    padding: const EdgeInsets.symmetric(horizontal: 5),
    alignment: Alignment.center,
    decoration: BoxDecoration(color: Tok.ink, borderRadius: BorderRadius.circular(Tok.rPill)),
    child: Text(
      '$n',
      style: Tok.caps.copyWith(color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 0),
    ),
  );
}

class TabItem<T> {
  const TabItem(this.value, this.label, {this.count});
  final T value;
  final String label;
  final int? count;
}

/// White segmented control (34 px, 3 px inner padding, selected segment grey). Used for EN | मराठी and tab bars.
class SegmentedTabs<T> extends StatelessWidget {
  const SegmentedTabs({super.key, required this.items, required this.value, required this.onChanged});
  final List<TabItem<T>> items;
  final T value;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    height: Tok.controlH,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: Tok.panel,
      borderRadius: BorderRadius.circular(Tok.rControl),
      border: Border.all(color: Tok.line),
      boxShadow: Tok.shadowControl,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final it in items)
          Pressable(
            onTap: () => onChanged(it.value),
            radius: 7,
            selected: it.value == value,
            child: Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: it.value == value ? Tok.lineSoft : null, borderRadius: BorderRadius.circular(7)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    it.label,
                    style: it.value == value
                        ? Tok.body.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600)
                        : Tok.body.copyWith(color: Tok.text2, fontWeight: FontWeight.w500),
                  ),
                  if (it.count != null) ...[
                    const SizedBox(width: 7),
                    Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: it.value == value ? Tok.tealTint : Tok.lineSoft,
                        borderRadius: BorderRadius.circular(Tok.rPill),
                      ),
                      child: Text(
                        '${it.count}',
                        style: Tok.caps.copyWith(color: Tok.ink, fontWeight: FontWeight.w600, letterSpacing: 0),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

/// Tabs with a 2 px teal underline on the selected one; counts show as a dark badge.
class UnderlineTabs<T> extends StatelessWidget {
  const UnderlineTabs({super.key, required this.items, required this.value, required this.onChanged});
  final List<TabItem<T>> items;
  final T value;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Tok.line)),
    ),
    child: Row(
      children: [
        for (final (i, it) in items.indexed) ...[
          if (i > 0) const SizedBox(width: 22),
          Pressable(
            onTap: () => onChanged(it.value),
            radius: 4,
            selected: it.value == value,
            child: Container(
              height: 36,
              decoration: it.value == value
                  ? const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Tok.teal, width: 2)),
                    )
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    it.label,
                    style: it.value == value
                        ? Tok.nav.copyWith(fontWeight: FontWeight.w600, color: Tok.tealDark)
                        : Tok.nav.copyWith(color: Tok.text2),
                  ),
                  if (it.count != null) ...[const SizedBox(width: 7), CountBadge(it.count!)],
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

// =====================================================================================================
// Chips and pills (24 px, radius 999, 12 px w500, icon 13)
// =====================================================================================================

Widget _chip(
  String label, {
  IconData? icon,
  Widget? lead,
  required Color bg,
  required Color border,
  required Color fg,
  Color? iconColor,
  bool dashed = false,
  FontWeight weight = FontWeight.w500,
}) {
  final box = Container(
    height: 24,
    padding: EdgeInsets.fromLTRB(lead != null ? 9 : 8, 0, 10, 0),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(Tok.rPill),
      border: dashed ? null : Border.all(color: border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (lead != null) ...[lead, const SizedBox(width: 6)],
        if (icon != null) ...[Icon(icon, size: 13, color: iconColor ?? fg), const SizedBox(width: 6)],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: Tok.sub.copyWith(color: fg, fontWeight: weight, height: 1.2),
          ),
        ),
      ],
    ),
  );
  return dashed ? DashedBorder(color: border, child: box) : box;
}

/// White pill with a coloured dot: "No DLP" (Tok.dot), "Under DLP" (Tok.amberIcon), "Bus route" (StatusPill.routeDot).
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.dot = Tok.dot});
  static const routeDot = Color(0xFF3B6FB6);
  final String label;
  final Color dot;
  @override
  Widget build(BuildContext context) => _chip(
    label,
    lead: Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
    ),
    bg: Tok.panel,
    border: Tok.line,
    fg: Tok.ink,
  );
}

/// Amber pill with a flag icon: "4 open flags". Unreviewed flags only.
class FlagPill extends StatelessWidget {
  const FlagPill(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) =>
      _chip(label, icon: Ico.flag, iconColor: Tok.amberIcon, bg: Tok.amberFill, border: Tok.amberLine, fg: Tok.amberText);
}

/// Decision state of a flag: 'open' (dashed amber), 'needs_explanation' (amber), 'confirmed' (red),
/// 'not_an_issue' (neutral), 'watch' (grey, no decision). Unknown values show as open.
class DecisionChip extends ConsumerWidget {
  const DecisionChip(this.decision, {super.key});
  final String decision;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    return switch (decision) {
      'needs_explanation' => _chip(
        t('decision.needs_explanation'),
        icon: Ico.question,
        iconColor: Tok.amberIcon,
        bg: Tok.amberFill,
        border: Tok.amberLine,
        fg: Tok.amberText,
      ),
      'confirmed' => _chip(t('decision.confirmed'), icon: Ico.alert, bg: Tok.redTint, border: Tok.redLine, fg: Tok.red),
      'not_an_issue' => _chip(
        t('decision.not_an_issue'),
        icon: Ico.check,
        iconColor: Tok.text2,
        bg: Tok.inset,
        border: Tok.line,
        fg: Tok.ink,
      ),
      'watch' => _chip(t('decision.watch'), icon: Ico.eye, iconColor: Tok.text3, bg: Tok.panel, border: Tok.neutralLine, fg: Tok.text2),
      _ => _chip(
        t('decision.open'),
        icon: Ico.open,
        iconColor: Tok.amberIcon,
        bg: Tok.panel,
        border: Tok.amberIcon,
        fg: Tok.amberText,
        dashed: true,
      ),
    };
  }
}

/// Scorecard band. Below / Well below are neutral with a stronger border, never red. [label] overrides the
/// short default text (`bandChip.<band>`).
class BandChip extends ConsumerWidget {
  const BandChip(this.band, {super.key, this.label});
  final String band;
  final String? label;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = label ?? ref.watch(stringsProvider)('bandChip.$band');
    return switch (band) {
      'well_above' => _chip(l, icon: Ico.upDouble, bg: Tok.tealTint, border: Tok.tealLine, fg: Tok.tealDark),
      'above' => _chip(l, icon: Ico.arrowUp, bg: Tok.tealTint, border: Tok.tealLine, fg: Tok.tealDark),
      'typical' => _chip(l, icon: Ico.minus, bg: Tok.panel, border: Tok.neutralLine, fg: Tok.text2),
      'below' => _chip(l, icon: Ico.arrowDown, bg: Tok.inset, border: Tok.strongLine, fg: Tok.ink),
      'well_below' => _chip(l, icon: Ico.downDouble, bg: Tok.inset, border: Tok.strongLine, fg: Tok.ink),
      'too_few' => _chip(l, icon: Ico.open, iconColor: Tok.text3, bg: Tok.panel, border: Tok.dot, fg: Tok.text2, dashed: true),
      'review' => _chip(l, icon: Ico.flag, iconColor: Tok.amberIcon, bg: Tok.amberFill, border: Tok.amberLine, fg: Tok.amberText),
      _ => _chip(l, icon: Ico.equals, iconColor: Tok.text3, bg: Tok.panel, border: Tok.neutralLine, fg: Tok.ink),
    };
  }
}

/// Generic tones for [Pill]. flag = amber (unreviewed/watch), error = red (overspend/confirmed),
/// success = teal tint, info/neutral = grey.
enum Tone { neutral, flag, error, success, info }

(Color fg, Color bg) toneColors(SathiColors c, Tone t) => switch (t) {
  Tone.flag => (c.flag, c.flagTint),
  Tone.error => (c.error, c.errorTint),
  Tone.success => (c.success, c.successTint),
  Tone.info => (c.info, c.infoTint),
  Tone.neutral => (c.textSecondary, c.surfaceAlt),
};

/// A labelled 24 px chip. Colour is never the only signal: there is always text, and an icon where it helps.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.tone = Tone.neutral, this.icon});
  final String label;
  final Tone tone;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => switch (tone) {
    Tone.flag => _chip(label, icon: icon, iconColor: Tok.amberIcon, bg: Tok.amberFill, border: Tok.amberLine, fg: Tok.amberText),
    Tone.error => _chip(label, icon: icon, bg: Tok.redTint, border: Tok.redLine, fg: Tok.red),
    Tone.success => _chip(label, icon: icon, iconColor: Tok.teal, bg: Tok.tealTint, border: Tok.tealZone, fg: Tok.tealDark),
    Tone.info => _chip(label, icon: icon, iconColor: Tok.text3, bg: Tok.panel, border: Tok.line, fg: Tok.text2),
    Tone.neutral => _chip(label, icon: icon, iconColor: Tok.text2, bg: Tok.inset, border: Tok.line, fg: Tok.ink),
  };
}

/// Dashed "Synthetic data" tag, 32 px. Shown in the top bar on every screen.
class SyntheticTag extends ConsumerWidget {
  const SyntheticTag({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => DashedBorder(
    radius: Tok.rControl,
    color: Tok.dash,
    child: Container(
      height: 32,
      padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Ico.synthetic, size: 14, color: Tok.text2),
          const SizedBox(width: 6),
          Text(
            ref.watch(stringsProvider)('app.synthetic'),
            style: Tok.body.copyWith(color: Tok.text2, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    ),
  );
}

typedef SyntheticDataTag = SyntheticTag;

// =====================================================================================================
// Bars
// =====================================================================================================

/// Teal progress on a pale hatched remainder. [value] is 0..1.
class ProgressBar extends StatelessWidget {
  const ProgressBar(this.value, {super.key, this.height = 6});
  final double value;
  final double height;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(Tok.rPill),
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        children: [
          const Positioned.fill(child: Hatch.rest()),
          FractionallySizedBox(
            widthFactor: value.clamp(0, 1).toDouble(),
            child: Container(
              decoration: BoxDecoration(color: Tok.teal, borderRadius: BorderRadius.circular(Tok.rPill)),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Spend against budget: teal up to 100% then hatched red overspend, with the figures above and the
/// scale below. Within budget, teal to the share spent on a pale hatched remainder.
class BudgetBar extends ConsumerWidget {
  const BudgetBar({super.key, required this.budget, required this.spent, this.showLabels = true});
  final num budget, spent;
  final bool showLabels;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final over = spent > budget;
    final split = budget <= 0 ? 0.0 : (over ? budget / spent : spent / budget).toDouble().clamp(0.0, 1.0);
    final pct = budget <= 0 ? '–' : fmt.pct(spent / budget);
    const small = TextStyle(fontSize: 11.5, height: 16 / 11.5);
    final bar = SizedBox(
      height: 10,
      child: LayoutBuilder(
        builder: (_, c) {
          if (!over) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(Tok.rPill),
              child: Stack(
                children: [
                  const Positioned.fill(child: Hatch.rest()),
                  Container(
                    width: c.maxWidth * split,
                    decoration: BoxDecoration(color: Tok.teal, borderRadius: BorderRadius.circular(Tok.rPill)),
                  ),
                ],
              ),
            );
          }
          final tealW = math.max(0.0, c.maxWidth * split - 1.5);
          return Row(
            children: [
              Container(
                width: tealW,
                decoration: const BoxDecoration(
                  color: Tok.teal,
                  borderRadius: BorderRadius.horizontal(left: Radius.circular(999), right: Radius.circular(3)),
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Container(
                  foregroundDecoration: BoxDecoration(
                    border: Border.all(color: Tok.red),
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(3), right: Radius.circular(999)),
                  ),
                  child: const ClipRRect(
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(3), right: Radius.circular(999)),
                    child: Hatch.over(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    if (!showLabels) return bar;
    final s = Tok.sub.copyWith(fontSize: 12.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('budget.label'), style: s),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                textAlign: TextAlign.right,
                TextSpan(
                  style: s,
                  children: over
                      ? [
                          TextSpan(
                            text: t('budget.budget', {'amount': fmt.money(budget)}),
                            style: const TextStyle(color: Tok.ink, fontWeight: FontWeight.w500),
                          ),
                          const TextSpan(text: '  +  '),
                          TextSpan(
                            text: t('budget.over', {'amount': fmt.money(spent - budget)}),
                            style: const TextStyle(color: Tok.red, fontWeight: FontWeight.w600),
                          ),
                          const TextSpan(text: '  =  '),
                          TextSpan(
                            text: t('budget.spent', {'amount': fmt.money(spent)}),
                            style: const TextStyle(color: Tok.ink, fontWeight: FontWeight.w500),
                          ),
                        ]
                      : [
                          TextSpan(
                            text: t('budget.spent', {'amount': fmt.money(spent)}),
                            style: const TextStyle(color: Tok.ink, fontWeight: FontWeight.w500),
                          ),
                          const TextSpan(text: '  ·  '),
                          TextSpan(text: t('budget.left', {'amount': fmt.money(budget - spent)})),
                        ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        bar,
        const SizedBox(height: 5),
        SizedBox(
          height: 16,
          child: LayoutBuilder(
            builder: (_, c) {
              final x = c.maxWidth * split;
              final mid = over ? t('budget.atBudget') : t('budget.pctSpent', {'pct': pct});
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(left: 0, child: Text(fmt.rupees(0), style: s.merge(small))),
                  Positioned(
                    right: math.max(0, c.maxWidth - x) + 4,
                    child: Text(mid, style: s.merge(small)),
                  ),
                  if (over)
                    Positioned(
                      right: 0,
                      child: Text(
                        t('budget.pctSpent', {'pct': pct}),
                        style: s.merge(small).copyWith(color: Tok.red, fontWeight: FontWeight.w500),
                      ),
                    )
                  else if (split < 0.85)
                    Positioned(right: 0, child: Text(t('budget.atBudget'), style: s.merge(small))),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class CompareBar {
  const CompareBar(this.label, this.share, this.valueText, {this.hatched = false});
  final String label, valueText;

  /// 0..1 of the track.
  final double share;

  /// true for the "Similar jobs" comparison bar (grey hatch); false for the solid teal subject bar.
  final bool hatched;
}

/// Compare bars: solid teal ("This contractor") against grey hatched ("Similar jobs").
class CompareBars extends StatelessWidget {
  const CompareBars({super.key, required this.bars, this.caption});
  final List<CompareBar> bars;
  final String? caption;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (caption != null) ...[Text(caption!, style: Tok.sub.copyWith(fontSize: 12.5)), const SizedBox(height: 6)],
      for (final b in bars)
        SizedBox(
          height: 24,
          child: Row(
            children: [
              SizedBox(
                width: 104,
                child: Text(b.label, style: Tok.body, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(color: Tok.inset, borderRadius: BorderRadius.circular(Tok.rPill)),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: b.share.clamp(0, 1).toDouble(),
                    child: Container(
                      foregroundDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Tok.rPill),
                        border: Border.all(color: b.hatched ? Tok.strongLine : Tok.teal),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(Tok.rPill),
                        child: b.hatched ? const Hatch.similar() : const ColoredBox(color: Tok.teal, child: SizedBox.expand()),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 38,
                child: Text(
                  b.valueText,
                  textAlign: TextAlign.right,
                  style: Tok.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

/// Where a job's cost ratio sits: 0x to [max]x with zones normal [low]-[watch], watch [watch]-[flag],
/// flag above [flag], the rate card at 1.0x and a pin "this job". Includes the three-part legend.
class RangeStrip extends ConsumerWidget {
  const RangeStrip({super.key, required this.ratio, this.low = 0.77, this.watch = 1.3, this.flag = 1.5, this.max = 2.0});
  final double ratio, low, watch, flag, max;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    String x(double v) => v == v.roundToDouble() ? v.toStringAsFixed(1) : fmt.ratio(v);
    Widget legend(Widget swatch, String name, String span, Color c) => Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: swatch),
          const SizedBox(width: 7),
          Flexible(
            child: Text.rich(
              TextSpan(
                style: Tok.sub.copyWith(fontSize: 11.5, height: 15 / 11.5),
                children: [
                  TextSpan(
                    text: '$name\n',
                    style: TextStyle(color: c, fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: span),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    Widget sw(Widget fill) => ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        width: 16,
        height: 11,
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: const Color(0x4D2A2E33)),
        ),
        child: fill,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: t('range.label', {'max': x(max), 'low': x(low), 'watch': x(watch), 'flag': x(flag), 'ratio': fmt.ratio(ratio)}),
          child: SizedBox(
            height: 92,
            child: CustomPaint(
              size: Size.infinite,
              painter: _RangePainter(ratio, low, watch, flag, max, x, t('range.rateCard'), t('range.thisJob', {'ratio': fmt.ratio(ratio)})),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, color: Tok.lineSoft),
        const SizedBox(height: 9),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            legend(
              sw(const ColoredBox(color: Tok.tealZone)),
              t('range.normal'),
              t('range.span', {'a': x(low), 'b': x(watch)}),
              Tok.tealDark,
            ),
            const SizedBox(width: 8),
            legend(
              sw(const Hatch(stripe: Color(0xFFD9A441), background: Tok.amberFill, width: 1.2, gap: 3)),
              t('range.watch'),
              t('range.span', {'a': x(watch), 'b': x(flag)}),
              Tok.amberText,
            ),
            const SizedBox(width: 8),
            legend(
              sw(const Hatch(stripe: Tok.amberIcon, background: Color(0xFFFBE3A0), width: 1.3, gap: 1.2)),
              t('range.flag'),
              t('range.above', {'a': x(flag)}),
              Tok.amberText,
            ),
          ],
        ),
      ],
    );
  }
}

class _RangePainter extends CustomPainter {
  _RangePainter(this.ratio, this.low, this.watch, this.flag, this.max, this.x, this.rateCard, this.pinLabel);
  final double ratio, low, watch, flag, max;
  final String Function(double) x;
  final String rateCard, pinLabel;

  void _text(
    Canvas c,
    String s,
    double cx,
    double baselineTop, {
    TextAlign align = TextAlign.center,
    Color color = Tok.text2,
    FontWeight w = FontWeight.w400,
    double size = 11,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: Tok.caps.copyWith(fontSize: size, letterSpacing: 0, color: color, fontWeight: w, height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      TextAlign.left || TextAlign.start => cx,
      TextAlign.right || TextAlign.end => cx - tp.width,
      _ => cx - tp.width / 2,
    };
    tp.paint(c, Offset(dx, baselineTop));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const l = 8.0, top = 34.0, h = 16.0;
    final w = size.width - 2 * l;
    double px(double v) => l + w * (v.clamp(0, max) / max);
    final bar = RRect.fromRectAndRadius(Rect.fromLTWH(l, top, w, h), const Radius.circular(5));
    canvas.save();
    canvas.clipRRect(bar);
    canvas.drawRect(Rect.fromLTRB(l, top, px(low), top + h), Paint()..color = Tok.lineInset);
    canvas.drawRect(Rect.fromLTRB(px(low), top, px(watch), top + h), Paint()..color = Tok.tealZone);
    paintHatch(canvas, Rect.fromLTRB(px(watch), top, px(flag), top + h), const Color(0xFFD9A441), Tok.amberFill, width: 1.2, gap: 3);
    paintHatch(canvas, Rect.fromLTRB(px(flag), top, l + w, top + h), Tok.amberIcon, const Color(0xFFFBE3A0), width: 1.3, gap: 1.2);
    canvas.restore();
    canvas.drawRRect(
      bar,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0x472A2E33),
    );
    // rate card at 1.0x, dashed
    final rc = px(1.0);
    final dash = Paint()
      ..color = Tok.tealDark
      ..strokeWidth = 1.4;
    for (var y = top - 4; y < top + h + 4; y += 4.5) {
      canvas.drawLine(Offset(rc, y), Offset(rc, math.min(y + 2.5, top + h + 4)), dash);
    }
    // scale
    _text(canvas, '0x', l, 61, align: TextAlign.left);
    _text(canvas, '${x(low)}x', px(low), 61);
    _text(canvas, '1.0x', rc, 61, color: Tok.tealDark, w: FontWeight.w600);
    _text(canvas, rateCard, rc, 75, color: Tok.tealDark);
    _text(canvas, '${x(watch)}x', px(watch), 61);
    _text(canvas, '${x(flag)}x', px(flag), 61);
    _text(canvas, '${x(max)}x', l + w, 61, align: TextAlign.right);
    // pin
    final p = px(ratio);
    final inNormal = ratio < watch;
    final pinColor = inNormal ? Tok.teal : Tok.amberIcon;
    canvas.drawLine(
      Offset(p, 22),
      Offset(p, top + h),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(p, 22),
      Offset(p, top + h),
      Paint()
        ..color = Tok.ink
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(p, 42), 4.6, Paint()..color = pinColor);
    canvas.drawCircle(
      Offset(p, 42),
      4.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.white,
    );
    // pin label
    final tp = TextPainter(
      text: TextSpan(
        text: pinLabel,
        style: Tok.caps.copyWith(
          fontSize: 11.5,
          letterSpacing: 0,
          height: 1,
          fontWeight: FontWeight.w600,
          color: inNormal ? Tok.tealDark : Tok.amberText,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final bw = tp.width + 22;
    final bx = (p - bw / 2).clamp(0.0, size.width - bw);
    final box = RRect.fromRectAndRadius(Rect.fromLTWH(bx, 1, bw, 21), const Radius.circular(10.5));
    canvas.drawRRect(box, Paint()..color = Colors.white);
    canvas.drawRRect(
      box,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = inNormal ? Tok.tealLine : const Color(0xFFE5BE5F),
    );
    tp.paint(canvas, Offset(bx + 11, 1 + (21 - tp.height) / 2));
  }

  @override
  bool shouldRepaint(_RangePainter o) => o.ratio != ratio || o.pinLabel != pinLabel || o.rateCard != rateCard;
}

/// Older screens' labelled horizontal bars.
class BarItem {
  const BarItem({required this.label, required this.value, this.sub, this.onTap});
  final String label;
  final num value;
  final String? sub;
  final VoidCallback? onTap;
}

class BarList extends StatelessWidget {
  const BarList(this.items, {super.key});
  final List<BarItem> items;
  @override
  Widget build(BuildContext context) {
    final max = items.fold<num>(1, (m, i) => i.value > m ? i.value : m);
    return Column(
      children: [
        for (final i in items)
          Pressable(
            onTap: i.onTap,
            radius: 8,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Tok.s2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(i.label, style: Tok.body)),
                      Text(fmt.money(i.value), style: Tok.body.copyWith(fontWeight: FontWeight.w600)),
                      if (i.sub != null) ...[
                        const SizedBox(width: Tok.s3),
                        SizedBox(
                          width: 72,
                          child: Text(i.sub!, style: Tok.sub, textAlign: TextAlign.end),
                        ),
                      ],
                      if (i.onTap != null) const Icon(Ico.chevronRight, size: 16, color: Tok.text3),
                    ],
                  ),
                  const SizedBox(height: Tok.s1),
                  Container(
                    height: 10,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: (i.value / max).clamp(0, 1).toDouble(),
                      child: Container(
                        decoration: BoxDecoration(color: Tok.teal, borderRadius: BorderRadius.circular(Tok.rPill)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// =====================================================================================================
// Trail stepper, evidence pair, budget line
// =====================================================================================================

/// recorded = filled teal check; missing = hollow dashed ("No complaint linked", "Never fixed"); flagged = amber (open flag).
enum TrailNode { recorded, missing, flagged }

class TrailStep {
  const TrailStep(this.label, this.title, {this.sub, this.node = TrailNode.recorded});

  /// Stage name ("Complaints"); the stepper prefixes the number and sets it in tiny caps.
  final String label, title;
  final String? sub;
  final TrailNode node;
}

/// Five-stage trail summary (Complaints, Issue, Work order, Road, Outcome). Connectors are solid teal
/// between two stages with records and dashed grey next to a missing one.
class TrailStepper extends StatelessWidget {
  const TrailStepper({super.key, required this.steps});
  final List<TrailStep> steps;

  static Widget node(TrailNode n) {
    final deco = BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: const [BoxShadow(color: Colors.white, spreadRadius: 3)],
      color: switch (n) {
        TrailNode.recorded => Tok.teal,
        TrailNode.missing => Colors.white,
        TrailNode.flagged => Tok.amberFill,
      },
      border: switch (n) {
        TrailNode.recorded => Border.all(color: Tok.tealDark),
        TrailNode.flagged => Border.all(color: Tok.amberNode, width: 1.5),
        TrailNode.missing => null,
      },
    );
    final c = Container(
      width: 26,
      height: 26,
      decoration: deco,
      child: switch (n) {
        TrailNode.recorded => const Icon(Ico.check, size: 15, color: Colors.white),
        TrailNode.flagged => const Icon(Ico.flag, size: 14, color: Tok.amberIcon),
        TrailNode.missing => null,
      },
    );
    return n == TrailNode.missing ? DashedBorder(color: const Color(0xFF8B9198), width: 1.5, child: c) : c;
  }

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (i, s) in steps.indexed)
        Expanded(
          flex: i == steps.length - 1 ? 86 : 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 26,
                child: Row(
                  children: [
                    node(s.node),
                    if (i < steps.length - 1)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: s.node == TrailNode.missing || steps[i + 1].node == TrailNode.missing
                              ? const _HRule(color: Tok.dash)
                              : const _HRule(color: Tok.tealRail, dashed: false),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 9),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Caps('${i + 1} · ${s.label}'),
                    const SizedBox(height: 3),
                    Text(
                      s.title,
                      style: Tok.emph.copyWith(fontWeight: FontWeight.w600, height: 19 / 14),
                    ),
                    if (s.sub != null) ...[const SizedBox(height: 1), Text(s.sub!, style: Tok.sub.copyWith(fontSize: 12.5))],
                  ],
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class EvidenceRow {
  const EvidenceRow(this.label, {required this.left, required this.right, this.matches = true, this.tag, this.tagIcon});
  final String label;
  final Widget left, right;

  /// Centre tag: "Matches" (check) or "Differs" (minus) unless [tag] gives custom words ("4 days apart").
  final bool matches;
  final String? tag;
  final IconData? tagIcon;
}

/// Two grey columns (earlier job / second job) with a 102 px centre column of Matches / Differs tags.
class EvidencePair extends ConsumerWidget {
  const EvidencePair({super.key, required this.leftTitle, required this.rightTitle, this.rightNote, required this.rows});
  final String leftTitle, rightTitle;

  /// Amber note after the right title, e.g. "(flagged)".
  final String? rightNote;
  final List<EvidenceRow> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    // Cells are transparent with a top rule; the two grey columns are painted once behind all rows.
    Widget cell(Widget child, {required bool first}) => Container(
      padding: const EdgeInsets.fromLTRB(11, 7, 10, 7),
      alignment: Alignment.centerLeft,
      decoration: first
          ? null
          : const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE1E3E6))),
            ),
      child: DefaultTextStyle.merge(
        style: Tok.body.copyWith(height: 18 / 13),
        child: child,
      ),
    );
    Widget centre(EvidenceRow r) => Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          r.label,
          style: Tok.sub.copyWith(fontSize: 11.5, height: 15 / 11.5, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Stack(
          alignment: Alignment.center,
          children: [
            const Positioned(left: 0, right: 0, child: Divider(height: 1, thickness: 1, color: Tok.dash)),
            Container(
              constraints: const BoxConstraints(minHeight: 20),
              padding: const EdgeInsets.fromLTRB(6, 1, 8, 1),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(Tok.rPill),
                border: Border.all(color: Tok.neutralLine),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(r.tagIcon ?? (r.matches ? Ico.check : Ico.minus), size: 12, color: Tok.text2),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      r.tag ?? t(r.matches ? 'evidence.matches' : 'evidence.differs'),
                      textAlign: TextAlign.center,
                      style: Tok.sub.copyWith(fontSize: 11.5, height: 14 / 11.5, color: Tok.ink, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
    final header = [
      Text(leftTitle, style: Tok.nav.copyWith(fontWeight: FontWeight.w600)),
      Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: rightTitle,
              style: Tok.nav.copyWith(fontWeight: FontWeight.w600),
            ),
            if (rightNote != null)
              TextSpan(
                text: ' $rightNote',
                style: Tok.body.copyWith(color: Tok.amberText, fontWeight: FontWeight.w500),
              ),
          ],
        ),
      ),
    ];
    final all = [null, ...rows];
    final column = BoxDecoration(
      color: Tok.inset,
      borderRadius: BorderRadius.circular(Tok.rCard),
      border: Border.all(color: Tok.lineInset),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: DecoratedBox(decoration: column)),
              const SizedBox(width: 102),
              Expanded(child: DecoratedBox(decoration: column)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, r) in all.indexed)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cell(r == null ? header[0] : r.left, first: i == 0)),
                    SizedBox(
                      width: 102,
                      child: r == null ? null : Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: centre(r)),
                    ),
                    Expanded(child: cell(r == null ? header[1] : r.right, first: i == 0)),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Plan list divider: full-width 2 px dashed ink rule with a centred white label ("Budget runs out here",
/// or "Budget already used up" at the top for an overspent ward). [above]/[below] are small notes at the left.
class BudgetLine extends StatelessWidget {
  const BudgetLine(this.title, {super.key, this.sub, this.above, this.below, this.icon = Ico.budget});
  final String title;
  final String? sub, above, below;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: [title, ?sub].join('. '),
    child: SizedBox(
      height: 66,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(left: 0, right: 0, child: _HRule(color: Tok.ink)),
          if (above != null)
            Positioned(
              left: 0,
              top: 6,
              child: Row(
                children: [
                  const Icon(Icons.arrow_upward, size: 12, color: Tok.tealDark),
                  const SizedBox(width: 5),
                  Text(
                    above!,
                    style: Tok.sub.copyWith(color: Tok.tealDark, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          if (below != null)
            Positioned(
              left: 0,
              bottom: 6,
              child: Row(
                children: [
                  const Icon(Icons.arrow_downward, size: 12, color: Tok.text2),
                  const SizedBox(width: 5),
                  Text(below!, style: Tok.sub.copyWith(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 18, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(Tok.rPanel),
              border: Border.all(color: Tok.ink, width: 1.5),
              boxShadow: const [BoxShadow(color: Color(0x1A14181C), offset: Offset(0, 2), blurRadius: 6)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: Tok.ink, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: Tok.body.copyWith(fontWeight: FontWeight.w600)),
                    if (sub != null) Text(sub!, style: Tok.sub),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// =====================================================================================================
// Table
// =====================================================================================================

class WorksColumn {
  const WorksColumn(this.label, {this.flex = 1, this.width, this.numeric = false, this.sorted});
  final String label;
  final int flex;

  /// Fixed width instead of [flex].
  final double? width;

  /// Right-aligned, weight 600 figures.
  final bool numeric;

  /// null = not sorted; true = sorted descending (down arrow); false = ascending.
  final bool? sorted;
}

/// Table: 36 px tiny-caps header on a grey rounded strip, rows 46 px+ with a soft rule, figures
/// right-aligned in tabular numerals. Cells are widgets (wrap plain values in Text).
class WorksTable extends StatelessWidget {
  const WorksTable({super.key, required this.columns, required this.rows, this.onRowTap, this.selected});
  final List<WorksColumn> columns;
  final List<List<Widget>> rows;
  final void Function(int index)? onRowTap;

  /// Highlighted row (teal tint), e.g. the flag open in the detail panel.
  final int? selected;

  Widget _cell(WorksColumn c, Widget child) {
    final w = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Align(alignment: c.numeric ? Alignment.centerRight : Alignment.centerLeft, child: child),
    );
    return c.width != null ? SizedBox(width: c.width, child: w) : Expanded(flex: c.flex, child: w);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        height: 36,
        decoration: BoxDecoration(
          color: Tok.inset,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Tok.lineInset),
        ),
        child: Row(
          children: [
            for (final c in columns)
              _cell(
                c,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        c.label.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: c.sorted != null ? Tok.caps.copyWith(color: Tok.ink, fontWeight: FontWeight.w600) : Tok.caps,
                      ),
                    ),
                    if (c.sorted != null) ...[
                      const SizedBox(width: 5),
                      Icon(c.sorted! ? Ico.arrowDown : Ico.arrowUp, size: 12, color: Tok.teal),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
      for (final (i, r) in rows.indexed)
        Pressable(
          onTap: onRowTap == null ? null : () => onRowTap!(i),
          radius: 10,
          selected: selected == i,
          builder: (_, hover) => Container(
            constraints: const BoxConstraints(minHeight: 46),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected == i ? Tok.tealTint : (hover ? Tok.inset : null),
              border: const Border(bottom: BorderSide(color: Tok.lineSoft)),
            ),
            child: DefaultTextStyle.merge(
              style: Tok.body,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (j, c) in columns.indexed)
                    _cell(
                      c,
                      c.numeric
                          ? DefaultTextStyle.merge(
                              style: const TextStyle(fontWeight: FontWeight.w600),
                              child: r[j],
                            )
                          : r[j],
                    ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}

// =====================================================================================================
// States
// =====================================================================================================

/// Dashed 44 px box: icon, optional bold [lead] sentence, then [message].
class EmptyState extends StatelessWidget {
  const EmptyState(this.message, {super.key, this.lead, this.icon = Ico.flag});
  final String message;
  final String? lead;
  final IconData icon;
  @override
  Widget build(BuildContext context) => DashedBorder(
    radius: Tok.rCard,
    child: Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 15, color: Tok.text3),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: Tok.body.copyWith(color: Tok.text2),
                children: [
                  if (lead != null)
                    TextSpan(
                      text: '$lead ',
                      style: const TextStyle(color: Tok.ink, fontWeight: FontWeight.w500),
                    ),
                  TextSpan(text: message),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Red-tint box: what failed, the request id, and Retry.
class ErrorState extends ConsumerWidget {
  const ErrorState(this.error, {super.key, this.onRetry, this.title});
  final Object error;
  final VoidCallback? onRetry;

  /// What could not be loaded, e.g. "Work orders could not be loaded." Defaults to the server message.
  final String? title;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final e = asApiError(error);
    return Semantics(
      liveRegion: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
        decoration: BoxDecoration(
          color: Tok.redTint,
          borderRadius: BorderRadius.circular(Tok.rCard),
          border: Border.all(color: Tok.redLine),
        ),
        child: Row(
          children: [
            const Icon(Ico.alert, size: 16, color: Tok.red),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title ?? (e.code == 'network' ? t('err.network') : (e.message.isEmpty ? t('state.error') : e.message)),
                    style: Tok.body.copyWith(fontWeight: FontWeight.w600, height: 18 / 13),
                  ),
                  if (e.requestId != null) Text(t('state.requestId', {'id': e.requestId}), style: Tok.sub),
                ],
              ),
            ),
            if (onRetry != null) ...[const SizedBox(width: 10), AppButton.outlined(t('action.retry'), icon: Ico.retry, onPressed: onRetry)],
          ],
        ),
      ),
    );
  }
}

/// Grey blocks in the shape of the content to come.
class LoadingSkeleton extends ConsumerWidget {
  const LoadingSkeleton({super.key, this.lines = 4});
  final int lines;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget block(double? w, double h, {double r = 6}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        gradient: const LinearGradient(colors: [Tok.lineInset, Tok.hatchRest2, Tok.lineInset]),
      ),
    );
    return Semantics(
      label: ref.watch(stringsProvider)('state.loading'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Tok.rCard),
          border: Border.all(color: Tok.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [block(120, 12), block(76, 12)]),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: block(104, 24)),
            const SizedBox(height: 12),
            Container(
              height: 6,
              decoration: BoxDecoration(color: Tok.lineInset, borderRadius: BorderRadius.circular(Tok.rPill)),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < math.max(1, lines - 2); i++)
              Container(
                height: 28,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: Tok.inset,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Tok.lineInset),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Renders loading, error or data for any provider.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.builder, this.onRetry, this.lines = 4});
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  final int lines;
  @override
  Widget build(BuildContext context) => value.when(
    skipLoadingOnRefresh: true,
    data: builder,
    loading: () => LoadingSkeleton(lines: lines),
    error: (e, _) => ErrorState(e, onRetry: onRetry),
  );
}

// =====================================================================================================
// Top bar and detail panel plumbing (read by the shell)
// =====================================================================================================

class Crumb {
  const Crumb(this.label, {this.onTap});
  final String label;
  final VoidCallback? onTap;
}

/// What the shell's top bar shows for the current page.
class TopBarSpec {
  const TopBarSpec({this.title, this.titleSuffix, this.crumbs = const [], this.onBack, this.onTitleTap, this.titleTapLabel, this.action});
  final String? title, titleSuffix, titleTapLabel;
  final List<Crumb> crumbs;
  final VoidCallback? onBack, onTitleTap;
  final Widget? action;
}

class TopBarController extends Notifier<TopBarSpec?> {
  Object? _owner;
  @override
  TopBarSpec? build() => null;
  void set(Object owner, TopBarSpec spec) {
    if (!ref.mounted) return;
    _owner = owner;
    state = spec;
  }

  void release(Object owner) {
    if (!ref.mounted || _owner != owner) return;
    _owner = null;
    state = null;
  }
}

final topBarProvider = NotifierProvider<TopBarController, TopBarSpec?>(TopBarController.new);

/// Sets the shell's top bar while this widget is mounted, then renders [child].
///   [title] ("Rule settings"), optionally with [titleSuffix] after a grey dot ("Ward E · Byculla, Agripada").
///   [crumbs] instead of a title for a breadcrumb ("Trail / WO25-00008"); [onBack] adds a back button before it.
///   [onTitleTap] makes the title a button with the ward-selector chevron ([titleTapLabel] is its accessible label).
///   [action] is the page's single primary button (AppButton.primary) or an outlined one; at most one.
/// Without a SetTopBar the shell shows the selected nav item's name.
class SetTopBar extends ConsumerStatefulWidget {
  const SetTopBar({
    super.key,
    this.title,
    this.titleSuffix,
    this.crumbs = const [],
    this.onBack,
    this.onTitleTap,
    this.titleTapLabel,
    this.action,
    required this.child,
  });
  final String? title, titleSuffix, titleTapLabel;
  final List<Crumb> crumbs;
  final VoidCallback? onBack, onTitleTap;
  final Widget? action;
  final Widget child;
  @override
  ConsumerState<SetTopBar> createState() => _SetTopBarState();
}

class _SetTopBarState extends ConsumerState<SetTopBar> {
  late final TopBarController _ctrl = ref.read(topBarProvider.notifier);
  final _token = Object();

  void _push() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    final w = widget;
    _ctrl.set(
      _token,
      TopBarSpec(
        title: w.title,
        titleSuffix: w.titleSuffix,
        crumbs: w.crumbs,
        onBack: w.onBack,
        onTitleTap: w.onTitleTap,
        titleTapLabel: w.titleTapLabel,
        action: w.action,
      ),
    );
  });

  @override
  void initState() {
    super.initState();
    _push();
  }

  @override
  void didUpdateWidget(SetTopBar old) {
    super.didUpdateWidget(old);
    _push();
  }

  @override
  void dispose() {
    final c = _ctrl, token = _token;
    // After the frame, so the next page's SetTopBar wins and no provider changes during a build.
    WidgetsBinding.instance.addPostFrameCallback((_) => c.release(token));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The shell-level detail panel opened by [showDetail].
class DetailRequest {
  DetailRequest(this.title, this.child) : done = Completer<void>();
  final String title;
  final Widget child;
  final Completer<void> done;
}

class DetailController extends Notifier<DetailRequest?> {
  @override
  DetailRequest? build() => null;
  void open(DetailRequest r) {
    close();
    state = r;
  }

  void close() {
    final r = state;
    if (r == null) return;
    state = null;
    if (!r.done.isCompleted) r.done.complete();
  }
}

final detailProvider = NotifierProvider<DetailController, DetailRequest?>(DetailController.new);

/// Opens [child] in the shell's 440 px right panel (page narrows, no dimming). Completes when it closes.
/// The panel also closes when the route changes. [child] fills the panel body, so it must scroll itself
/// (a ListView with padding 18, 14, 18, 18) or be short.
Future<void> showDetail(BuildContext context, {required String title, required Widget child}) {
  final r = DetailRequest(title, child);
  ProviderScope.containerOf(context, listen: false).read(detailProvider.notifier).open(r);
  return r.done.future;
}

void closeDetail(BuildContext context) => ProviderScope.containerOf(context, listen: false).read(detailProvider.notifier).close();

/// The 440 px white detail panel: tiny-caps [eyebrow] with icon, 18 px [title], grey [subtitle], close
/// button, scrolling body ([scroll] = false if [child] scrolls itself), optional [footer] (e.g. decision form).
class DetailPanel extends ConsumerWidget {
  const DetailPanel({
    super.key,
    required this.title,
    required this.onClose,
    required this.child,
    this.eyebrow,
    this.eyebrowIcon,
    this.eyebrowColor,
    this.subtitle,
    this.footer,
    this.scroll = true,
  });
  final String title;
  final String? eyebrow, subtitle;
  final IconData? eyebrowIcon;

  /// Icon colour of the eyebrow (amber for an unreviewed flag).
  final Color? eyebrowColor;
  final VoidCallback onClose;
  final Widget child;
  final Widget? footer;
  final bool scroll;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    return Container(
      decoration: BoxDecoration(
        color: Tok.panel,
        borderRadius: BorderRadius.circular(Tok.rPanel),
        border: Border.all(color: Tok.line),
        boxShadow: Tok.shadowPanel,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (eyebrow != null)
                        SizedBox(
                          height: 20,
                          child: Row(
                            children: [
                              if (eyebrowIcon != null) ...[
                                Icon(eyebrowIcon, size: 13, color: eyebrowColor ?? Tok.text3),
                                const SizedBox(width: 6),
                              ],
                              Caps(eyebrow!),
                            ],
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.only(top: eyebrow != null ? 4 : 5),
                        child: Text(title, style: Tok.section.copyWith(letterSpacing: -0.18)),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(subtitle!, style: Tok.body.copyWith(color: Tok.text2)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AppIconButton(Ico.close, tooltip: t('action.close'), onPressed: onClose),
              ],
            ),
          ),
          Expanded(
            child: scroll ? SingleChildScrollView(padding: const EdgeInsets.fromLTRB(18, 14, 18, 18), child: child) : child,
          ),
          if (footer != null)
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Tok.line)),
              ),
              child: footer,
            ),
        ],
      ),
    );
  }
}

/// Page with an optional 440 px right [panel] (usually a [DetailPanel]); the page narrows, nothing dims.
/// Escape calls [onClose].
class DetailPanelLayout extends StatelessWidget {
  const DetailPanelLayout({super.key, required this.main, this.panel, this.onClose});
  final Widget main;
  final Widget? panel;
  final VoidCallback? onClose;
  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: main),
        if (panel != null) ...[const SizedBox(width: Tok.gapPanels), SizedBox(width: Tok.detailW, child: panel)],
      ],
    );
    if (panel == null || onClose == null) return row;
    return CallbackShortcuts(bindings: {const SingleActivator(LogicalKeyboardKey.escape): onClose!}, child: row);
  }
}

// =====================================================================================================
// Work orders behind a figure (data helpers kept from before)
// =====================================================================================================

/// Keyed by the full request path with its query, e.g. `/wards/E/work-orders?filter=dlp`.
final workOrdersProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, url) => apiGet(ref, url));

/// The work orders behind a figure, as stacked cards with the total they add up to.
class WorkOrderList extends ConsumerWidget {
  const WorkOrderList(this.url, {super.key});
  final String url;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    return AsyncView(
      value: ref.watch(workOrdersProvider(url)),
      onRetry: () => ref.invalidate(workOrdersProvider(url)),
      builder: (data) {
        final items = List<Map<String, dynamic>>.from(data['items']);
        if (items.isEmpty) return EmptyState(t('wo.empty'));
        // Scrolls itself: it is shown in the detail panel.
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          children: [
            Text(t('wo.total', {'n': fmt.count(data['total']), 'amount': fmt.money(data['total_cost'])}), style: Tok.cardTitle),
            if (data['total'] > items.length) Text(t('wo.showing', {'n': items.length}), style: Tok.sub),
            for (final w in items) ...[const SizedBox(height: Tok.s2), WorkOrderCard(w)],
          ],
        );
      },
    );
  }
}

class WorkOrderCard extends ConsumerWidget {
  const WorkOrderCard(this.w, {super.key});
  final Map<String, dynamic> w;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final r = (w['cost_ratio'] as num?) ?? 1;
    return SubCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${w['work_order_id']}',
                  style: Tok.body.copyWith(color: Tok.tealDark, fontWeight: FontWeight.w500),
                ),
              ),
              Text(fmt.money(w['cost_inr']), style: Tok.body.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          Text('${w['road_name']} · ${w['repair_method']}', style: Tok.body),
          Text('${w['contractor_name']} · ${fmt.date(w['assigned_at'])} · ${t('wo.area', {'area': w['area_sqm']})}', style: Tok.sub),
          const SizedBox(height: Tok.s2),
          Wrap(
            spacing: Tok.s2,
            runSpacing: Tok.s1,
            children: [
              Pill(t('wo.timesRate', {'ratio': fmt.ratio(r)}), tone: r > 1.5 ? Tone.flag : Tone.neutral),
              if (w['sla_met'] != null)
                Pill(t(w['sla_met'] ? 'wo.slaMet' : 'wo.slaMissed'), icon: w['sla_met'] ? Ico.check : Icons.schedule),
              if (w['reopened_within_30d'] != null)
                Pill(t(w['reopened_within_30d'] ? 'wo.reopened' : 'wo.held'), icon: w['reopened_within_30d'] ? Ico.reopened : Ico.check),
              if (w['road_under_dlp'] == true) Pill(t('wo.dlp'), tone: Tone.flag),
              if (w['has_complaint'] == false) Pill(t('wo.noComplaint'), tone: Tone.flag),
            ],
          ),
        ],
      ),
    );
  }
}

/// A titled placeholder for a screen a later task delivers.
class ComingSoon extends ConsumerWidget {
  const ComingSoon(this.titleKey, {super.key});
  final String titleKey;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    return SetTopBar(
      title: t(titleKey),
      child: PageBody(
        children: [Panel(child: EmptyState(t('state.comingSoon'), icon: Icons.construction_outlined))],
      ),
    );
  }
}

extension GoHome on BuildContext {
  void goWard(String code) => go('/ward/${wardSlug(code)}');
}

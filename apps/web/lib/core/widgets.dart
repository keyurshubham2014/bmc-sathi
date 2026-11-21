import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_state.dart';
import 'format.dart' as fmt;
import 'theme.dart';

enum Tone { neutral, flag, error, success, info }

(Color fg, Color bg) toneColors(SathiColors c, Tone t) => switch (t) {
      Tone.flag => (c.flag, c.flagTint),
      Tone.error => (c.error, c.errorTint),
      Tone.success => (c.success, c.successTint),
      Tone.info => (c.info, c.infoTint),
      Tone.neutral => (c.textSecondary, c.surfaceAlt),
    };

/// A labelled chip. Colour is never the only signal: there is always text, and an icon where it helps.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.tone = Tone.neutral, this.icon});
  final String label;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = toneColors(SathiColors.of(context), tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(kRadius), border: Border.all(color: fg.withValues(alpha: 0.5))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: Gap.xs)],
        Flexible(child: Text(label, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: fg))),
      ]),
    );
  }
}

/// Decision state of a flag. Unreviewed is amber, confirmed is red, cleared is green.
class DecisionChip extends ConsumerWidget {
  const DecisionChip(this.decision, {super.key});
  final String decision;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final (tone, icon) = switch (decision) {
      'confirmed' => (Tone.error, Icons.error_outline),
      'needs_explanation' => (Tone.info, Icons.help_outline),
      'not_an_issue' => (Tone.success, Icons.check_circle_outline),
      _ => (Tone.flag, Icons.flag_outlined),
    };
    return Pill(t('decision.$decision'), tone: tone, icon: icon);
  }
}

class SyntheticTag extends ConsumerWidget {
  const SyntheticTag({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Pill(ref.watch(stringsProvider)('app.synthetic'), tone: Tone.info, icon: Icons.science_outlined);
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.title, this.trailing, this.padding = const EdgeInsets.all(Gap.lg)});
  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: padding,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.md),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: Gap.md,
                  runSpacing: Gap.sm,
                  children: [Text(title!, style: Theme.of(context).textTheme.titleMedium), ?trailing],
                ),
              ),
            child,
          ]),
        ),
      );
}

/// Label, figure and a sub-line. Opens the rows behind the figure when tappable.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.sub, this.onTap, this.tone = Tone.neutral});
  final String label, value;
  final String? sub;
  final VoidCallback? onTap;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final c = SathiColors.of(context);
    final tt = Theme.of(context).textTheme;
    final (fg, _) = toneColors(c, tone);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(label, style: tt.labelLarge!.copyWith(color: c.textSecondary))),
              if (onTap != null) Icon(Icons.chevron_right, size: 18, color: c.textSecondary),
            ]),
            const SizedBox(height: Gap.xs),
            Text(value, style: tt.headlineMedium!.copyWith(color: tone == Tone.neutral ? c.textPrimary : fg)),
            if (sub != null) Text(sub!, style: tt.bodySmall),
          ]),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.message, {super.key, this.icon = Icons.inbox_outlined});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = SathiColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 32, color: c.textSecondary),
          const SizedBox(height: Gap.sm),
          Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: c.textSecondary)),
        ]),
      ),
    );
  }
}

class ErrorState extends ConsumerWidget {
  const ErrorState(this.error, {super.key, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final c = SathiColors.of(context);
    final e = asApiError(error);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_outlined, size: 32, color: c.textSecondary),
          const SizedBox(height: Gap.sm),
          Text(e.code == 'network' ? t('err.network') : (e.message.isEmpty ? t('state.error') : e.message), textAlign: TextAlign.center),
          if (e.requestId != null) Text(t('state.requestId', {'id': e.requestId}), style: Theme.of(context).textTheme.bodySmall),
          if (onRetry != null) ...[
            const SizedBox(height: Gap.md),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh, size: 18), label: Text(t('action.retry'))),
          ],
        ]),
      ),
    );
  }
}

/// Grey bars in the shape of the content to come.
class LoadingSkeleton extends ConsumerWidget {
  const LoadingSkeleton({super.key, this.lines = 4});
  final int lines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SathiColors.of(context);
    return Semantics(
      label: ref.watch(stringsProvider)('state.loading'),
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < lines; i++)
            Container(
              height: 18,
              width: i.isEven ? double.infinity : 220,
              margin: const EdgeInsets.only(bottom: Gap.md),
              decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(4)),
            ),
        ]),
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

class BarItem {
  const BarItem({required this.label, required this.value, this.sub, this.onTap});
  final String label;
  final num value;
  final String? sub;
  final VoidCallback? onTap;
}

/// Labelled horizontal bars. Every chart in the app is one of these.
class BarList extends StatelessWidget {
  const BarList(this.items, {super.key});
  final List<BarItem> items;

  @override
  Widget build(BuildContext context) {
    final c = SathiColors.of(context);
    final tt = Theme.of(context).textTheme;
    final max = items.fold<num>(1, (m, i) => i.value > m ? i.value : m);
    return Column(children: [
      for (final i in items)
        InkWell(
          onTap: i.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.sm),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(i.label, style: tt.bodyMedium)),
                Text(fmt.money(i.value), style: tt.labelLarge),
                if (i.sub != null) ...[const SizedBox(width: Gap.md), SizedBox(width: 72, child: Text(i.sub!, style: tt.bodySmall, textAlign: TextAlign.end))],
                if (i.onTap != null) Icon(Icons.chevron_right, size: 18, color: c.textSecondary),
              ]),
              const SizedBox(height: Gap.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: (i.value / max).clamp(0, 1).toDouble(), minHeight: 8, backgroundColor: c.surfaceAlt, color: c.accent),
              ),
            ]),
          ),
        ),
    ]);
  }
}

/// Opens detail beside the page when wide, as a sheet when medium, as a full page when narrow.
Future<void> showDetail(BuildContext context, {required String title, required Widget child}) {
  final width = MediaQuery.sizeOf(context).width;
  Widget panel(BuildContext ctx) => Material(
        color: SathiColors.of(ctx).background,
        child: SafeArea(
          child: Column(children: [
            Container(
              color: SathiColors.of(ctx).surface,
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.sm, Gap.sm),
              child: Row(children: [
                Expanded(child: Text(title, style: Theme.of(ctx).textTheme.titleMedium)),
                IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close), tooltip: MaterialLocalizations.of(ctx).closeButtonTooltip),
              ]),
            ),
            const Divider(),
            Expanded(child: child),
          ]),
        ),
      );
  if (width < 720) {
    return Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: panel, fullscreenDialog: true));
  }
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    transitionDuration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 180),
    pageBuilder: (ctx, _, _) => Align(alignment: Alignment.centerRight, child: SizedBox(width: 460, height: double.infinity, child: panel(ctx))),
    transitionBuilder: (_, a, _, w) => SlideTransition(position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOut)), child: w),
  );
}

// ---------- work orders behind a figure ----------

/// Keyed by the full request path with its query, e.g. `/wards/E/work-orders?filter=dlp`.
final workOrdersProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, url) => apiGet(ref, url));

/// The work orders behind a figure, as stacked cards with the total they add up to.
class WorkOrderList extends ConsumerWidget {
  const WorkOrderList(this.url, {super.key});
  final String url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final tt = Theme.of(context).textTheme;
    return AsyncView(
      value: ref.watch(workOrdersProvider(url)),
      onRetry: () => ref.invalidate(workOrdersProvider(url)),
      builder: (data) {
        final items = List<Map<String, dynamic>>.from(data['items']);
        if (items.isEmpty) return EmptyState(t('wo.empty'));
        return ListView.separated(
          padding: const EdgeInsets.all(Gap.lg),
          itemCount: items.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: Gap.sm),
          itemBuilder: (_, i) {
            if (i == 0) {
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t('wo.total', {'n': fmt.count(data['total']), 'amount': fmt.money(data['total_cost'])}), style: tt.titleMedium),
                if (data['total'] > items.length) Text(t('wo.showing', {'n': items.length}), style: tt.bodySmall),
              ]);
            }
            return WorkOrderCard(items[i - 1]);
          },
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
    final tt = Theme.of(context).textTheme;
    final r = (w['cost_ratio'] as num?) ?? 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${w['work_order_id']}', style: tt.labelLarge)),
            Text(fmt.money(w['cost_inr']), style: tt.titleMedium),
          ]),
          Text('${w['road_name']} · ${w['repair_method']}', style: tt.bodyMedium),
          Text('${w['contractor_name']} · ${fmt.date(w['assigned_at'])} · ${t('wo.area', {'area': w['area_sqm']})}', style: tt.bodySmall),
          const SizedBox(height: Gap.sm),
          Wrap(spacing: Gap.sm, runSpacing: Gap.xs, children: [
            Pill(t('wo.timesRate', {'ratio': fmt.ratio(r)}), tone: r > 1.5 ? Tone.flag : Tone.neutral),
            if (w['sla_met'] != null) Pill(t(w['sla_met'] ? 'wo.slaMet' : 'wo.slaMissed'), icon: w['sla_met'] ? Icons.check : Icons.schedule),
            if (w['reopened_within_30d'] != null) Pill(t(w['reopened_within_30d'] ? 'wo.reopened' : 'wo.held'), icon: w['reopened_within_30d'] ? Icons.replay : Icons.check),
            if (w['road_under_dlp'] == true) Pill(t('wo.dlp'), tone: Tone.flag),
            if (w['has_complaint'] == false) Pill(t('wo.noComplaint'), tone: Tone.flag),
          ]),
        ]),
      ),
    );
  }
}

/// A page body: scrolls, with comfortable margins and a maximum width.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 720;
    return SingleChildScrollView(
      padding: EdgeInsets.all(narrow ? Gap.lg : Gap.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final (i, w) in children.indexed) ...[if (i > 0) const SizedBox(height: Gap.lg), w],
          ]),
        ),
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
    return PageBody(children: [
      Text(t(titleKey), style: Theme.of(context).textTheme.titleLarge),
      SectionCard(child: EmptyState(t('state.comingSoon'), icon: Icons.construction_outlined)),
    ]);
  }
}

extension GoHome on BuildContext {
  void goWard(String code) => go('/ward/${wardSlug(code)}');
}

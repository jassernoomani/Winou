import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../api/providers.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';

/// The admin Dashboard tab: totals as tiles, then lost reports, sightings and reunions per week.
class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return switch (ref.watch(adminStatsProvider)) {
      AsyncData(:final value) => RefreshIndicator(
        onRefresh: () => ref.refresh(adminStatsProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            FadeSlideIn(
              child: _Tiles([
                _Stat(LucideIcons.users, l10n.statUsers, value.users, l10n.statNewThisWeek(value.newUsersThisWeek)),
                _Stat(
                  LucideIcons.megaphone,
                  l10n.statOpenLost,
                  value.openLostReports,
                  l10n.statOfTotal(value.lostReportsTotal),
                ),
                _Stat(
                  LucideIcons.house,
                  l10n.statReunited,
                  value.reunited,
                  value.reunionRate == null ? null : l10n.statReunionRate('${(value.reunionRate! * 100).round()}%'),
                ),
                _Stat(LucideIcons.heartHandshake, l10n.statMatchesConfirmed, value.matchesConfirmed, null),
                _Stat(LucideIcons.eye, l10n.statSightings, value.sightings, null),
                _Stat(LucideIcons.pawPrint, l10n.statStraysOnMap, value.straysOnMap, null),
                _Stat(
                  LucideIcons.building2,
                  l10n.statAssociations,
                  value.associations,
                  l10n.statStraysHelped(value.strayHelpedByAssociations),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(index: 1, child: _WeeklyCard(value.weeks)),
          ],
        ),
      ),
      AsyncError(:final error) => ErrorView(error: error, onRetry: () => ref.invalidate(adminStatsProvider)),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _Stat {
  const _Stat(this.icon, this.label, this.value, this.caption);

  final IconData icon;
  final String label;
  final int value;
  final String? caption;
}

/// Two per row, as tall as the taller of the two; an odd last one spans the row.
class _Tiles extends StatelessWidget {
  const _Tiles(this.stats);

  final List<_Stat> stats;

  @override
  Widget build(BuildContext context) {
    const gap = 10.0;
    return Column(
      spacing: gap,
      children: [
        for (var i = 0; i < stats.length; i += 2)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: gap,
              children: [for (final stat in stats.skip(i).take(2)) Expanded(child: _Tile(stat))],
            ),
          ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.stat);

  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            Row(
              spacing: 6,
              children: [
                Icon(stat.icon, size: 16, color: tokens.muted),
                Expanded(
                  child: Text(
                    stat.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
                  ),
                ),
              ],
            ),
            Text(NumberFormat.decimalPattern().format(stat.value), style: theme.textTheme.headlineMedium),
            if (stat.caption case final caption?)
              Text(caption, style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted)),
          ],
        ),
      ),
    );
  }
}

/// The three weekly series. Colours were checked for colour-blind separation and contrast on the
/// card, separately in each theme: lost = coral, sightings = blue, reunited = green, as everywhere.
List<Color> _seriesColors(Brightness brightness) => brightness == Brightness.dark
    ? const [Color(0xFFF43F5E), Color(0xFF3B82F6), Color(0xFF16A34A)]
    : const [Color(0xFFE11D48), Color(0xFF2563EB), Color(0xFF16A34A)];

List<int> _values(WeekStats w) => [w.lostReports, w.sightings, w.reunited];

class _WeeklyCard extends StatefulWidget {
  const _WeeklyCard(this.weeks);

  final List<WeekStats> weeks;

  @override
  State<_WeeklyCard> createState() => _WeeklyCardState();
}

class _WeeklyCardState extends State<_WeeklyCard> {
  int? _selected; // the week being inspected, while a finger is on the chart
  bool _table = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final colors = _seriesColors(theme.brightness);
    final names = [l10n.seriesLost, l10n.seriesSightings, l10n.seriesReunited];
    final locale = dateLocale(context);
    final weeks = widget.weeks;
    final shown = _selected ?? weeks.length - 1; // the legend shows this week's numbers
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.lastWeeks(weeks.length), style: theme.textTheme.titleMedium),
                      Text(
                        l10n.weekOf(DateFormat.MMMd(locale).format(weeks[shown].start)),
                        style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _table ? l10n.showChart : l10n.showTable,
                  onPressed: () => setState(() => _table = !_table),
                  icon: Icon(_table ? LucideIcons.chartLine : LucideIcons.table),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Legend: always there, with the inspected week's values, so colour is never the only key
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (var s = 0; s < 3; s++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 6,
                    children: [
                      Container(
                        width: 12,
                        height: 3,
                        decoration: BoxDecoration(color: colors[s], borderRadius: BorderRadius.circular(2)),
                      ),
                      Text(names[s], style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted)),
                      Text('${_values(weeks[shown])[s]}', style: theme.textTheme.labelLarge),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_table)
              _WeeklyTable(weeks: weeks, names: names, locale: locale)
            else
              SizedBox(
                height: 200,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    void pick(Offset position) {
                      final i = _ChartPainter.indexAt(position.dx, constraints.maxWidth, weeks.length);
                      if (i != _selected) setState(() => _selected = i);
                    }

                    return Semantics(
                      label: l10n.weeklyChartLabel,
                      child: GestureDetector(
                        onTapDown: (d) => pick(d.localPosition),
                        onHorizontalDragStart: (d) => pick(d.localPosition),
                        onHorizontalDragUpdate: (d) => pick(d.localPosition),
                        onHorizontalDragEnd: (_) => setState(() => _selected = null),
                        onTapUp: (_) => setState(() => _selected = null),
                        child: CustomPaint(
                          size: Size(constraints.maxWidth, 200),
                          painter: _ChartPainter(
                            weeks: weeks,
                            colors: colors,
                            selected: _selected,
                            grid: tokens.muted.withValues(alpha: 0.18),
                            axisText: theme.textTheme.bodySmall!.copyWith(color: tokens.muted, fontSize: 11),
                            surface: theme.cardTheme.color ?? theme.colorScheme.surface,
                            locale: locale,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The same numbers as rows, newest week first.
class _WeeklyTable extends StatelessWidget {
  const _WeeklyTable({required this.weeks, required this.names, required this.locale});

  final List<WeekStats> weeks;
  final List<String> names;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final head = theme.textTheme.labelMedium?.copyWith(color: context.tokens.muted);
    Widget cell(String text, {TextStyle? style, bool end = true}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(text, textAlign: end ? TextAlign.end : TextAlign.start, style: style),
    );
    return Table(
      columnWidths: const {0: FlexColumnWidth(1.4)},
      border: TableBorder(horizontalInside: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4))),
      children: [
        TableRow(
          children: [
            cell(context.l10n.weekColumn, style: head, end: false),
            for (final name in names) cell(name, style: head),
          ],
        ),
        for (final w in weeks.reversed)
          TableRow(
            children: [
              cell(DateFormat.MMMd(locale).format(w.start), end: false),
              for (final v in _values(w)) cell('$v', style: theme.textTheme.bodyMedium),
            ],
          ),
      ],
    );
  }
}

/// Three 2px lines on one shared axis, a recessive grid, and a crosshair with markers on the
/// inspected week.
class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.weeks,
    required this.colors,
    required this.selected,
    required this.grid,
    required this.axisText,
    required this.surface,
    required this.locale,
  });

  final List<WeekStats> weeks;
  final List<Color> colors;
  final int? selected;
  final Color grid;
  final TextStyle axisText;
  final Color surface;
  final String locale;

  static const _left = 28.0; // y labels
  static const _bottom = 22.0; // x labels
  static const _top = 8.0;
  static const _right = 8.0;

  static double _x(int i, double width, int count) =>
      _left + (count == 1 ? 0 : i * (width - _left - _right) / (count - 1));

  /// The week closest to a horizontal position.
  static int indexAt(double dx, double width, int count) {
    if (count < 2) return 0;
    final step = (width - _left - _right) / (count - 1);
    return ((dx - _left) / step).round().clamp(0, count - 1);
  }

  /// A round top for the axis: four ticks of 1, 2 or 5 × 10ⁿ (max 7 → 8, 13 → 20, 30 → 40).
  static int _niceMax(int max) {
    if (max <= 4) return 4;
    final rough = max / 4;
    final magnitude = math.pow(10, (math.log(rough) / math.ln10).floor()).toInt();
    final step = [1, 2, 5, 10].map((f) => f * magnitude).firstWhere((s) => s >= rough);
    return step * 4;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final count = weeks.length;
    final top = _niceMax(weeks.map((w) => _values(w).reduce(math.max)).fold(0, math.max));
    final plotBottom = size.height - _bottom;
    double y(int v) => plotBottom - (plotBottom - _top) * v / top;

    // Grid and y labels
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var t = 0; t <= 4; t++) {
      final value = top * t ~/ 4;
      final dy = y(value);
      canvas.drawLine(Offset(_left, dy), Offset(size.width - _right, dy), gridPaint);
      _text(canvas, '$value', Offset(_left - 6, dy), align: Alignment.centerRight);
    }

    // x labels: every third week, the latest always
    final format = DateFormat.MMMd(locale);
    for (var i = count - 1; i >= 0; i -= 3) {
      _text(
        canvas,
        format.format(weeks[i].start),
        Offset(_x(i, size.width, count), plotBottom + 6),
        align: i == count - 1 ? Alignment.topRight : Alignment.topCenter,
      );
    }

    // Crosshair under the lines
    if (selected case final s?) {
      final dx = _x(s, size.width, count);
      canvas.drawLine(Offset(dx, _top), Offset(dx, plotBottom), gridPaint..color = grid.withValues(alpha: 0.6));
    }

    for (var s = 0; s < 3; s++) {
      final path = Path();
      for (var i = 0; i < count; i++) {
        final point = Offset(_x(i, size.width, count), y(_values(weeks[i])[s]));
        i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = colors[s]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }

    // Markers on the inspected week, ringed with the card colour so overlapping ones stay apart
    if (selected case final i?) {
      for (var s = 0; s < 3; s++) {
        final center = Offset(_x(i, size.width, count), y(_values(weeks[i])[s]));
        canvas
          ..drawCircle(center, 6, Paint()..color = surface)
          ..drawCircle(center, 4, Paint()..color = colors[s]);
      }
    }
  }

  void _text(Canvas canvas, String text, Offset at, {required Alignment align}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: axisText),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      Alignment.centerRight || Alignment.topRight => at.dx - painter.width,
      Alignment.topCenter => at.dx - painter.width / 2,
      _ => at.dx,
    };
    final dy = align == Alignment.centerRight ? at.dy - painter.height / 2 : at.dy;
    painter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.weeks != weeks || old.selected != selected || old.colors != colors || old.surface != surface;
}

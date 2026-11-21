import 'dart:math' as math;

import 'package:bmc_sathi/core/format.dart';
import 'package:bmc_sathi/core/strings.dart';
import 'package:bmc_sathi/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _lum(Color c) {
  double f(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

double contrast(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  test('money uses Indian units', () {
    expect(money(16200000), '₹1.62 cr');
    expect(money(420000), '₹4.2 L');
    expect(money(9500), '₹9,500');
    expect(money(134328183), '₹13.43 cr');
    expect(money(-250000), '-₹2.5 L');
    expect(money(null), '–');
  });

  test('every English string has a Marathi one', () {
    const en = Strings('en'), mr = Strings('mr');
    for (final key in ['nav.overview', 'flags.tab.duplicate', 'decision.needs_explanation', 'ward.overBy']) {
      expect(mr(key), isNot(en(key)), reason: key);
    }
    expect(en('ward.label', {'code': 'E'}), 'Ward E');
    expect(en('no.such.key'), 'no.such.key');
  });

  for (final (name, c) in [('light', SathiColors.light), ('dark', SathiColors.dark)]) {
    test('$name theme meets WCAG AA contrast', () {
      // Body text needs 4.5:1.
      final text = <String, (Color, Color)>{
        'textPrimary/background': (c.textPrimary, c.background),
        'textPrimary/surface': (c.textPrimary, c.surface),
        'textPrimary/surfaceAlt': (c.textPrimary, c.surfaceAlt),
        'textPrimary/primaryContainer': (c.textPrimary, c.primaryContainer),
        'textSecondary/background': (c.textSecondary, c.background),
        'textSecondary/surface': (c.textSecondary, c.surface),
        'textSecondary/surfaceAlt': (c.textSecondary, c.surfaceAlt),
        'primary/surface': (c.primary, c.surface),
        'primary/background': (c.primary, c.background),
        'primary/primaryContainer': (c.primary, c.primaryContainer),
        'onPrimary/primary': (c.onPrimary, c.primary),
        'flag/flagTint': (c.flag, c.flagTint),
        'flag/surface': (c.flag, c.surface),
        'error/errorTint': (c.error, c.errorTint),
        'error/surface': (c.error, c.surface),
        'success/successTint': (c.success, c.successTint),
        'info/infoTint': (c.info, c.infoTint),
        'textPrimary/infoTint': (c.textPrimary, c.infoTint),
        for (var i = 0; i < 5; i++) 'onMapScale$i/mapScale$i': (c.onMapScale[i], c.mapScale[i]),
      };
      for (final e in text.entries) {
        expect(contrast(e.value.$1, e.value.$2), greaterThanOrEqualTo(4.5), reason: e.key);
      }
      // Bars, borders of controls and the focus ring need 3:1.
      final shapes = <String, (Color, Color)>{
        'accent/surface': (c.accent, c.surface),
        'borderStrong/surface': (c.borderStrong, c.surface),
        'focusRing/surface': (c.focusRing, c.surface),
      };
      for (final e in shapes.entries) {
        expect(contrast(e.value.$1, e.value.$2), greaterThanOrEqualTo(3.0), reason: e.key);
      }
    });
  }
}

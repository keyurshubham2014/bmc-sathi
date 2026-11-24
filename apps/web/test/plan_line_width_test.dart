import 'package:bmc_sathi/core/strings.dart';
import 'package:bmc_sathi/core/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 360 px phone less the page and panel padding leaves about 300 px for a plan line.
  for (final lang in ['en', 'mr']) {
    for (final key in ['plan.lineConfirmed', 'plan.linePossible']) {
      testWidgets('$key fits a phone-width plan ($lang)', (tester) async {
        final t = Strings(lang);
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 300, child: BudgetLine(t(key), sub: t('plan.lineRecoverSub', {'amount': '₹45.3 L'}), icon: Ico.flag)),
            ),
          ),
        ));
        expect(tester.takeException(), isNull);
      });
    }
  }
}

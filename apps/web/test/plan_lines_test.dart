import 'package:bmc_sathi/features/plan/plan_tab.dart';
import 'package:flutter_test/flutter_test.dart';

List<Map<String, dynamic>> _items(List<String> s) => [
      for (final c in s) {'within_budget': c == 'b', 'within_recovered': c == 'b' || c == 'r', 'within_possible': c != 'x'},
    ];

void main() {
  // b = budget covers it, r = confirmed recovery would, p = every open flag would, x = nothing would.
  test('no extra lines while nothing is flagged', () {
    final l = recoveryLines(_items(['b', 'x', 'x']), {'confirmed_total': 0, 'possible_total': 0});
    expect((l.confirmed, l.possible), (null, null));
  });
  test('each line sits before the first item its money cannot cover', () {
    final l = recoveryLines(_items(['b', 'r', 'r', 'p', 'x']), {'confirmed_total': 5, 'possible_total': 9});
    expect((l.confirmed, l.possible), (3, 4));
  });
  test('a line that covers every item goes at the end', () {
    final l = recoveryLines(_items(['b', 'p', 'p']), {'confirmed_total': 0, 'possible_total': 9});
    expect((l.confirmed, l.possible), (null, 3));
  });
  test('a line that would sit on the line above it is left out', () {
    // Confirmed money funds nothing beyond the budget; open flags fund nothing beyond that either.
    final l = recoveryLines(_items(['b', 'x']), {'confirmed_total': 5, 'possible_total': 9});
    expect((l.confirmed, l.possible), (null, null));
  });
  test('an overspent ward starts from nothing funded', () {
    final l = recoveryLines(_items(['r', 'p', 'x']), {'confirmed_total': 5, 'possible_total': 9});
    expect((l.confirmed, l.possible), (1, 2));
  });
}

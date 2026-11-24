import 'dart:convert';

import 'package:bmc_sathi/core/app_state.dart';
import 'package:bmc_sathi/core/widgets.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

String jwtWithExp(DateTime exp) {
  String part(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'exp': exp.millisecondsSinceEpoch ~/ 1000})}.sig';
}

Future<ProviderContainer> withStoredToken(String token) async {
  SharedPreferences.setMockInitialValues({
    'session': jsonEncode({'token': token, 'name': 'Officer', 'role': 'ward_officer', 'wardCode': 'E'}),
  });
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
}

void main() {
  test('an expired stored session is dropped on launch', () async {
    final c = await withStoredToken(jwtWithExp(DateTime.now().subtract(const Duration(hours: 1))));
    expect(c.read(sessionProvider), isNull);
    expect(c.read(prefsProvider).getString('session'), isNull);
  });

  test('a live stored session is kept', () async {
    final c = await withStoredToken(jwtWithExp(DateTime.now().add(const Duration(hours: 1))));
    expect(c.read(sessionProvider)?.name, 'Officer');
  });

  testWidgets('a 401 shows no Retry box', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final err = DioException(requestOptions: RequestOptions(), error: const ApiError('not_signed_in', 'Your session has ended.', status: 401));
    await tester.pumpWidget(ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: MaterialApp(home: Scaffold(body: ErrorState(err, onRetry: () {}))),
    ));
    expect(find.text('Your session has ended.'), findsNothing);
  });
}

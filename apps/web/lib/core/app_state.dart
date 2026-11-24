import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'strings.dart';

const apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:4000/api/v1');

/// Overridden in main() once preferences have loaded.
final prefsProvider = Provider<SharedPreferences>((_) => throw UnimplementedError());

// ---------- theme and language, saved per device ----------

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final raw = ref.watch(prefsProvider).getString('themeMode');
    return ThemeMode.values.firstWhere((m) => m.name == raw, orElse: () => ThemeMode.system);
  }

  void set(ThemeMode mode) {
    state = mode;
    ref.read(prefsProvider).setString('themeMode', mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class LangController extends Notifier<String> {
  @override
  String build() => ref.watch(prefsProvider).getString('lang') == 'mr' ? 'mr' : 'en';

  void set(String lang) {
    state = lang;
    ref.read(prefsProvider).setString('lang', lang);
  }
}

final langProvider = NotifierProvider<LangController, String>(LangController.new);
final stringsProvider = Provider<Strings>((ref) => Strings(ref.watch(langProvider)));

// ---------- session ----------

class Session {
  const Session({required this.token, required this.name, required this.role, this.wardCode});
  final String token, name, role;
  final String? wardCode;

  bool get canSeeFlags => role == 'ward_officer' || role == 'auditor';
  bool get isOfficer => role == 'ward_officer';
  bool get isAuditor => role == 'auditor';

  /// Where this role starts. Citizens default to Ward E and change it from the ward page.
  String get home => isAuditor ? '/city' : '/ward/${wardSlug(wardCode ?? 'E')}';

  Map<String, Object?> toJson() => {'token': token, 'name': name, 'role': role, 'wardCode': wardCode};
  static Session fromJson(Map<String, dynamic> j) =>
      Session(token: j['token'], name: j['name'], role: j['role'], wardCode: j['wardCode']);
}

class SessionController extends Notifier<Session?> {
  @override
  Session? build() {
    // shortcut: token in browser storage is fine for a demo, move to an http-only cookie for real use.
    final raw = ref.watch(prefsProvider).getString('session');
    if (raw == null) return null;
    try {
      final s = Session.fromJson(jsonDecode(raw));
      // Drop a token past its `exp` so a returning user lands on sign-in, not on a page of 401s.
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(s.token.split('.')[1]))));
      if (DateTime.now().millisecondsSinceEpoch ~/ 1000 < payload['exp']) return s;
    } catch (_) {}
    ref.read(prefsProvider).remove('session');
    return null;
  }

  Future<void> signIn(String username, String password) async {
    final res = await ref.read(dioProvider).post('/auth/login', data: {'username': username, 'password': password});
    final u = res.data['user'];
    final s = Session(token: res.data['token'], name: u['display_name'], role: u['role'], wardCode: u['ward_code']);
    await ref.read(prefsProvider).setString('session', jsonEncode(s.toJson()));
    state = s;
  }

  void signOut() {
    ref.read(prefsProvider).remove('session');
    state = null;
  }
}

final sessionProvider = NotifierProvider<SessionController, Session?>(SessionController.new);

// ---------- API client ----------

/// An error the screen can show: a translated message key or the server's own message.
class ApiError implements Exception {
  const ApiError(this.code, this.message, {this.requestId, this.status});
  final String code, message;
  final String? requestId;
  final int? status;
}

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(baseUrl: apiBase, connectTimeout: const Duration(seconds: 8), receiveTimeout: const Duration(seconds: 25)));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (o, h) {
      final token = ref.read(sessionProvider)?.token;
      if (token != null) o.headers['Authorization'] = 'Bearer $token';
      h.next(o);
    },
    onError: (e, h) {
      final data = e.response?.data;
      final status = e.response?.statusCode;
      // An expired session returns the user to sign-in. A failed login must not.
      if (status == 401 && !e.requestOptions.path.endsWith('/auth/login')) {
        Future.microtask(() => ref.read(sessionProvider.notifier).signOut());
      }
      final err = data is Map
          ? ApiError('${data['code']}', '${data['message']}', requestId: data['request_id'], status: status)
          : const ApiError('network', '');
      h.reject(DioException(requestOptions: e.requestOptions, response: e.response, error: err));
    },
  ));
  return dio;
});

ApiError asApiError(Object e) =>
    e is DioException && e.error is ApiError ? e.error as ApiError : const ApiError('network', '');

/// GET that returns the decoded body.
Future<Map<String, dynamic>> apiGet(Ref ref, String path, [Map<String, Object?>? query]) async {
  final q = {...?query}..removeWhere((_, v) => v == null);
  final res = await ref.watch(dioProvider).get(path, queryParameters: q);
  return Map<String, dynamic>.from(res.data);
}

// Ward codes such as F/S contain a slash, which cannot sit in a URL path segment.
String wardSlug(String code) => code.replaceAll('/', '-');
String wardFromSlug(String slug) => slug.replaceAll('-', '/');
String wardPath(String code) => '/wards/${Uri.encodeComponent(code)}';

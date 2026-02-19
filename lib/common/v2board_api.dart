import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class V2BoardSession {
  final String baseUrl;
  final String authData;
  final String cookie;

  const V2BoardSession({
    required this.baseUrl,
    required this.authData,
    required this.cookie,
  });

  V2BoardSession copyWith({String? cookie}) {
    return V2BoardSession(
      baseUrl: baseUrl,
      authData: authData,
      cookie: cookie ?? this.cookie,
    );
  }

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'authData': authData,
    'cookie': cookie,
  };

  static V2BoardSession? fromJson(dynamic j) {
    if (j is! Map) return null;
    final base = (j['baseUrl'] ?? '').toString();
    final auth = (j['authData'] ?? '').toString();
    if (base.isEmpty || auth.isEmpty) return null;
    return V2BoardSession(
      baseUrl: base,
      authData: auth,
      cookie: (j['cookie'] ?? '').toString(),
    );
  }
}

class V2BoardApi {
  static const _prefix = '/api/v1';
  static const _kSession = 'v2board_client_session';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      sendTimeout: const Duration(seconds: 12),
      responseType: ResponseType.json,
      validateStatus: (_) => true,
      headers: const {'Accept': 'application/json'},
    ),
  );

  Future<V2BoardSession?> restoreSession() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kSession);
    if (raw == null || raw.isEmpty) return null;
    try {
      return V2BoardSession.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kSession);
  }

  Future<void> _saveSession(V2BoardSession session) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kSession, jsonEncode(session.toJson()));
  }

  String _normBase(String baseUrl) {
    var s = baseUrl.trim();
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'https://$s';
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  String _extractAuthData(dynamic root) {
    if (root is Map && root['data'] is Map && root['data']['auth_data'] != null) {
      return root['data']['auth_data'].toString();
    }
    return '';
  }

  String _extractCookie(List<dynamic> setCookies) {
    for (final raw in setCookies) {
      final c = raw.toString();
      final m = RegExp(r'([A-Za-z0-9_]+_session=[^;]+)').firstMatch(c);
      if (m != null) return m.group(1) ?? '';
    }
    return '';
  }

  Map<String, dynamic> _headers(V2BoardSession session) => {
    'Authorization': session.authData,
    if (session.cookie.isNotEmpty) 'Cookie': session.cookie,
  };

  Future<Response<dynamic>> _get(
    String baseUrl,
    String path, {
    V2BoardSession? session,
    Map<String, dynamic>? query,
  }) async {
    final resp = await _dio.get(
      '${_normBase(baseUrl)}$_prefix$path',
      queryParameters: query,
      options: Options(headers: session == null ? null : _headers(session)),
    );
    _ensureSuccess(resp);
    return resp;
  }

  Future<Response<dynamic>> _post(
    String baseUrl,
    String path, {
    V2BoardSession? session,
    Map<String, dynamic>? data,
  }) async {
    final resp = await _dio.post(
      '${_normBase(baseUrl)}$_prefix$path',
      data: data,
      options: Options(headers: session == null ? null : _headers(session)),
    );
    _ensureSuccess(resp);
    return resp;
  }

  dynamic _extractData(dynamic root) {
    if (root is Map && root.containsKey('data')) {
      return root['data'];
    }
    return root;
  }

  Map<String, dynamic> asDataMap(dynamic root) {
    final data = _extractData(root);
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  List<dynamic> asDataList(dynamic root) {
    final data = _extractData(root);
    if (data is List) return data;
    return const [];
  }

  void _ensureSuccess(Response<dynamic> resp) {
    final code = resp.statusCode ?? 0;
    if (code < 200 || code >= 300) {
      throw Exception('HTTP $code');
    }
    final root = resp.data;
    if (root is Map) {
      final msg = (root['message'] ?? '').toString();
      if (msg.isNotEmpty && msg.toLowerCase() != 'success' && root['data'] == null) {
        throw Exception(msg);
      }
      if (root['success'] == false) {
        throw Exception(msg.isEmpty ? 'request failed' : msg);
      }
    }
  }

  // 1. auth.js
  Future<V2BoardSession> login({
    required String baseUrl,
    required String email,
    required String password,
    bool? rememberMe,
  }) async {
    final resp = await _post(
      baseUrl,
      '/passport/auth/login',
      data: {
        'email': email,
        'password': password,
        if (rememberMe != null) 'rememberMe': rememberMe,
      },
    );
    final authData = _extractAuthData(resp.data);
    if (authData.isEmpty) throw Exception('auth_data missing');
    final session = V2BoardSession(
      baseUrl: _normBase(baseUrl),
      authData: authData,
      cookie: _extractCookie(resp.headers.map['set-cookie'] ?? const []),
    );
    await _saveSession(session);
    return session;
  }

  Future<V2BoardSession> register({
    required String baseUrl,
    required String email,
    required String password,
    String inviteCode = '',
    required String emailCode,
  }) async {
    await _post(
      baseUrl,
      '/passport/auth/register',
      data: {
        'email': email,
        'password': password,
        'email_code': emailCode,
        if (inviteCode.trim().isNotEmpty) 'invite_code': inviteCode.trim(),
      },
    );
    return login(
      baseUrl: baseUrl,
      email: email,
      password: password,
      rememberMe: true,
    );
  }

  Future<void> resetPassword({
    required String baseUrl,
    required String email,
    required String password,
    required String emailCode,
  }) async {
    await _post(
      baseUrl,
      '/passport/auth/forget',
      data: {'email': email, 'password': password, 'email_code': emailCode},
    );
  }

  Future<void> sendEmailVerify({
    required String baseUrl,
    required String email,
    bool isForgetPassword = false,
  }) async {
    await _post(
      baseUrl,
      '/passport/comm/sendEmailVerify',
      data: {'email': email, 'isForgetPassword': isForgetPassword},
    );
  }

  Future<Map<String, dynamic>> getWebsiteConfig({required String baseUrl}) async {
    final resp = await _get(baseUrl, '/guest/comm/config');
    return asDataMap(resp.data);
  }

  Future<Map<String, dynamic>> getUserInfo(V2BoardSession session) async {
    final resp = await _get(session.baseUrl, '/user/info', session: session);
    return asDataMap(resp.data);
  }

  Future<void> logout() async {
    await clearSession();
  }

  Future<Map<String, dynamic>> tokenLogin({
    required String baseUrl,
    required String verifyToken,
    String? redirect,
  }) async {
    final resp = await _get(
      baseUrl,
      '/passport/auth/token2Login',
      query: {'verify': verifyToken, if (redirect != null) 'redirect': redirect},
    );
    return asDataMap(resp.data);
  }

  Future<bool> checkLoginStatus() async {
    final session = await restoreSession();
    return session != null && session.authData.isNotEmpty;
  }

  Future<Map<String, dynamic>> checkUserLoginStatus(V2BoardSession session) async {
    final resp = await _get(session.baseUrl, '/user/checkLogin', session: session);
    return asDataMap(resp.data);
  }

  Future<void> forceLogout() async {
    await clearSession();
  }

  // 2. dashboard.js
  Future<Map<String, dynamic>> getSubscribe(V2BoardSession session) async {
    final resp = await _get(session.baseUrl, '/user/getSubscribe', session: session);
    final newCookie = _extractCookie(resp.headers.map['set-cookie'] ?? const []);
    if (newCookie.isNotEmpty && newCookie != session.cookie) {
      await _saveSession(session.copyWith(cookie: newCookie));
    }
    return asDataMap(resp.data);
  }

  Future<List<dynamic>> getNotices(V2BoardSession session) async {
    final resp = await _get(session.baseUrl, '/user/notice/fetch', session: session);
    return asDataList(resp.data);
  }

  Future<Map<String, dynamic>> getUserStats(V2BoardSession session) async {
    final resp = await _get(session.baseUrl, '/user/getStat', session: session);
    return asDataMap(resp.data);
  }

  Future<Map<String, dynamic>> getUserConfig(V2BoardSession session) async {
    final resp = await _get(session.baseUrl, '/user/comm/config', session: session);
    return asDataMap(resp.data);
  }

  Future<Map<String, dynamic>> setNextPeriod(V2BoardSession session) async {
    final resp = await _post(session.baseUrl, '/user/newPeriod', session: session);
    return asDataMap(resp.data);
  }

  // 4. invite.js
  Future<Map<String, dynamic>> getInviteData(V2BoardSession session) async {
    final resp = await _get(session.baseUrl, '/user/invite/fetch', session: session);
    return asDataMap(resp.data);
  }

  Future<List<dynamic>> getInviteDetails(
    V2BoardSession session, {
    required int current,
    required int pageSize,
  }) async {
    final resp = await _get(
      session.baseUrl,
      '/user/invite/details',
      session: session,
      query: {'current': current, 'page_size': pageSize},
    );
    return asDataList(resp.data);
  }

  Future<Map<String, dynamic>> getCommissionConfig(V2BoardSession session) {
    return getUserConfig(session);
  }

  Future<Map<String, dynamic>> generateInviteCode(V2BoardSession session) async {
    final resp = await _get(session.baseUrl, '/user/invite/save', session: session);
    return asDataMap(resp.data);
  }

  Future<Map<String, dynamic>> transferCommission(
    V2BoardSession session, {
    required num amount,
  }) async {
    final resp = await _post(
      session.baseUrl,
      '/user/transfer',
      session: session,
      data: {'transfer_amount': amount},
    );
    return asDataMap(resp.data);
  }

  Future<Map<String, dynamic>> withdrawCommission(
    V2BoardSession session, {
    required num amount,
    required String account,
    required String method,
  }) async {
    final resp = await _post(
      session.baseUrl,
      '/user/ticket/withdraw',
      session: session,
      data: {
        'withdraw_amount': amount,
        'withdraw_account': account,
        'withdraw_method': method,
      },
    );
    return asDataMap(resp.data);
  }

  // 5. orderlist.js
  Future<List<dynamic>> fetchOrderList(V2BoardSession session) async {
    final resp = await _get(session.baseUrl, '/user/order/fetch', session: session);
    return asDataList(resp.data);
  }

  Future<Map<String, dynamic>> cancelOrder(V2BoardSession session, {required String tradeNo}) async {
    final resp = await _post(
      session.baseUrl,
      '/user/order/cancel',
      session: session,
      data: {'trade_no': tradeNo},
    );
    return asDataMap(resp.data);
  }

  // 6. servers.js
  Future<List<dynamic>> fetchServerNodes(V2BoardSession session) async {
    final resp = await _get(session.baseUrl, '/user/server/fetch', session: session);
    return asDataList(resp.data);
  }

  // 7. shop.js
  Future<List<dynamic>> fetchPlans(V2BoardSession session, {int? id}) async {
    final resp = await _get(
      session.baseUrl,
      '/user/plan/fetch',
      session: session,
      query: id == null ? null : {'id': id},
    );
    return asDataList(resp.data);
  }

  Future<Map<String, dynamic>> getCommConfig(V2BoardSession session) {
    return getUserConfig(session);
  }

  Future<Map<String, dynamic>> verifyCoupon(
    V2BoardSession session, {
    required String code,
    required int planId,
  }) async {
    final resp = await _post(
      session.baseUrl,
      '/user/coupon/check',
      session: session,
      data: {'code': code, 'plan_id': planId},
    );
    return asDataMap(resp.data);
  }

  Future<Map<String, dynamic>> submitOrder(
    V2BoardSession session, {
    required int planId,
    required String period,
    String? couponCode,
  }) async {
    final resp = await _post(
      session.baseUrl,
      '/user/order/save',
      session: session,
      data: {
        'plan_id': planId,
        'period': period,
        if (couponCode != null && couponCode.isNotEmpty) 'coupon_code': couponCode,
      },
    );
    return asDataMap(resp.data);
  }

  Future<Map<String, dynamic>> getOrderDetail(V2BoardSession session, {required String tradeNo}) async {
    final resp = await _get(
      session.baseUrl,
      '/user/order/detail',
      session: session,
      query: {'trade_no': tradeNo},
    );
    return asDataMap(resp.data);
  }

  Future<List<dynamic>> getPaymentMethods(V2BoardSession session) async {
    final resp = await _get(session.baseUrl, '/user/order/getPaymentMethod', session: session);
    return asDataList(resp.data);
  }

  Future<Map<String, dynamic>> checkOrderStatus(V2BoardSession session, {required String tradeNo}) async {
    final resp = await _get(
      session.baseUrl,
      '/user/order/check',
      session: session,
      query: {'trade_no': tradeNo},
    );
    return asDataMap(resp.data);
  }

  Future<Map<String, dynamic>> checkoutOrder(
    V2BoardSession session, {
    required String tradeNo,
    required int methodId,
  }) async {
    final resp = await _post(
      session.baseUrl,
      '/user/order/checkout',
      session: session,
      data: {'trade_no': tradeNo, 'method': methodId},
    );
    return asDataMap(resp.data);
  }

  // 8. ticket.js
  Future<List<dynamic>> fetchTicketList(V2BoardSession session) async {
    final resp = await _get(session.baseUrl, '/user/ticket/fetch', session: session);
    return asDataList(resp.data);
  }

  Future<Map<String, dynamic>> createTicket(
    V2BoardSession session, {
    required String subject,
    required int level,
    required String message,
  }) async {
    final resp = await _post(
      session.baseUrl,
      '/user/ticket/save',
      session: session,
      data: {'subject': subject, 'level': level, 'message': message},
    );
    return asDataMap(resp.data);
  }

  Future<dynamic> getTicketDetail(V2BoardSession session, {required int id}) async {
    final resp = await _get(
      session.baseUrl,
      '/user/ticket/fetch',
      session: session,
      query: {'id': id},
    );
    final data = _extractData(resp.data);
    if (data is List) {
      return data.whereType<Map>().cast<Map>().firstWhere(
            (e) => e['id']?.toString() == id.toString(),
            orElse: () => {},
          );
    }
    return data;
  }

  Future<Map<String, dynamic>> replyTicket(
    V2BoardSession session, {
    required int id,
    required String message,
  }) async {
    final resp = await _post(
      session.baseUrl,
      '/user/ticket/reply',
      session: session,
      data: {'id': id, 'message': message},
    );
    return asDataMap(resp.data);
  }

  Future<Map<String, dynamic>> closeTicket(V2BoardSession session, {required int id}) async {
    final resp = await _post(
      session.baseUrl,
      '/user/ticket/close',
      session: session,
      data: {'id': id},
    );
    return asDataMap(resp.data);
  }

  // 9. trafficLog.js
  Future<List<dynamic>> getTrafficLog(V2BoardSession session) async {
    final resp = await _get(session.baseUrl, '/user/stat/getTrafficLog', session: session);
    return asDataList(resp.data);
  }

  // 10. user.js
  Future<Map<String, dynamic>> getIpLocationInfo() async {
    final resp = await _dio.get('https://ipwho.is/');
    if ((resp.statusCode ?? 0) < 200 || (resp.statusCode ?? 0) >= 300) {
      throw Exception('HTTP ${resp.statusCode}');
    }
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<Map<String, dynamic>> redeemGiftCard(V2BoardSession session, {required String giftcard}) async {
    final resp = await _post(
      session.baseUrl,
      '/user/redeemgiftcard',
      session: session,
      data: {'giftcard': giftcard},
    );
    return asDataMap(resp.data);
  }

  Future<Map<String, dynamic>> changePassword(
    V2BoardSession session, {
    required String oldPassword,
    required String newPassword,
  }) async {
    final resp = await _post(
      session.baseUrl,
      '/user/changePassword',
      session: session,
      data: {'old_password': oldPassword, 'new_password': newPassword},
    );
    return asDataMap(resp.data);
  }

  Future<Map<String, dynamic>> resetSecurity(V2BoardSession session) async {
    final resp = await _get(session.baseUrl, '/user/resetSecurity', session: session);
    return asDataMap(resp.data);
  }

  Future<Map<String, dynamic>> updateRemindSettings(
    V2BoardSession session, {
    required int remindExpire,
    required int remindTraffic,
  }) async {
    final resp = await _post(
      session.baseUrl,
      '/user/update',
      session: session,
      data: {'remind_expire': remindExpire, 'remind_traffic': remindTraffic},
    );
    return asDataMap(resp.data);
  }

  Future<List<dynamic>> getActiveSession(V2BoardSession session) async {
    final resp = await _get(session.baseUrl, '/user/getActiveSession', session: session);
    return asDataList(resp.data);
  }

  Future<Map<String, dynamic>> getTelegramBotInfo(V2BoardSession session) async {
    final resp = await _get(session.baseUrl, '/user/telegram/getBotInfo', session: session);
    return asDataMap(resp.data);
  }

  Future<Map<String, dynamic>> getUserSubscribe(V2BoardSession session) {
    return getSubscribe(session);
  }

  // 11. wallet.js
  Future<Map<String, dynamic>> createOrderDeposit(V2BoardSession session, {required num amount}) async {
    final resp = await _post(
      session.baseUrl,
      '/user/order/save',
      session: session,
      data: {'period': 'deposit', 'deposit_amount': amount, 'plan_id': 0},
    );
    return asDataMap(resp.data);
  }

  Future<V2BoardAllData> fetchAll(V2BoardSession session) async {
    final user = await getUserInfo(session);
    final subscribe = await getSubscribe(session);
    final plans = await fetchPlans(session);
    return V2BoardAllData(user: user, subscribe: subscribe, plans: plans);
  }
}

class V2BoardAllData {
  final Map<String, dynamic> user;
  final Map<String, dynamic> subscribe;
  final List<dynamic> plans;

  const V2BoardAllData({
    required this.user,
    required this.subscribe,
    required this.plans,
  });
}
  Future<({Map<String, dynamic> user, Map<String, dynamic> subscribe, List<dynamic> plans})>
  fetchAll(V2BoardSession session) async {
    final user = await getUserInfo(session);
    final subscribe = await getSubscribe(session);
    final plans = await fetchPlans(session);
    return (user: user, subscribe: subscribe, plans: plans);
  }
}

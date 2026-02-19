import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/v2board_api.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class V2BoardClientView extends ConsumerStatefulWidget {
  const V2BoardClientView({super.key});

  @override
  ConsumerState<V2BoardClientView> createState() => _V2BoardClientViewState();
}

class _V2BoardClientViewState extends ConsumerState<V2BoardClientView> {
  final _api = V2BoardApi();
  int _authTab = 0;
  int _mainTab = 0;

  bool _loading = true;
  bool _submitting = false;
  String? _error;

  V2BoardSession? _session;
  _UserInfo? _user;
  _SubscribeInfo? _subscribe;
  List<_PlanInfo> _plans = const [];

  final _baseCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _registerEmailCtrl = TextEditingController();
  final _registerPasswordCtrl = TextEditingController();
  final _registerCodeCtrl = TextEditingController();
  final _inviteCtrl = TextEditingController();
  final _resetEmailCtrl = TextEditingController();
  final _resetCodeCtrl = TextEditingController();
  final _resetPasswordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _baseCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _registerEmailCtrl.dispose();
    _registerPasswordCtrl.dispose();
    _registerCodeCtrl.dispose();
    _inviteCtrl.dispose();
    _resetEmailCtrl.dispose();
    _resetCodeCtrl.dispose();
    _resetPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    final session = await _api.restoreSession();
    if (!mounted) return;
    _session = session;
    _baseCtrl.text = session?.baseUrl ?? '';
    if (session != null) {
      await _refreshAll(silent: true);
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _refreshAll({bool silent = false}) async {
    final session = _session;
    if (session == null) return;
    if (!silent && mounted) setState(() => _submitting = true);
    try {
      final data = await _api.fetchAll(session);
      if (!mounted) return;
      final user = _UserInfo.fromJson(data.user);
      final subscribe = _SubscribeInfo.fromJson(data.subscribe);
      final plans = data.plans.map((e) => _PlanInfo.fromJson(e)).whereType<_PlanInfo>().toList();
      setState(() {
        _user = user;
        _subscribe = subscribe;
        _plans = plans;
        _error = null;
      });
      if (subscribe.subscribeUrl.isNotEmpty) {
        await appController.addProfileFormURL(subscribe.subscribeUrl);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!silent && mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleLogin() async {
    if (_baseCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _passwordCtrl.text.isEmpty) {
      _toast('请完整输入域名、邮箱和密码');
      return;
    }
    setState(() => _submitting = true);
    try {
      final session = await _api.login(
        baseUrl: _baseCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        rememberMe: true,
      );
      if (!mounted) return;
      setState(() => _session = session);
      await _refreshAll(silent: true);
      _toast('登录成功');
    } catch (e) {
      _toast('登录失败：$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleRegister() async {
    if (_baseCtrl.text.trim().isEmpty ||
        _registerEmailCtrl.text.trim().isEmpty ||
        _registerPasswordCtrl.text.isEmpty ||
        _registerCodeCtrl.text.trim().isEmpty) {
      _toast('请完整输入注册信息');
      return;
    }
    setState(() => _submitting = true);
    try {
      final session = await _api.register(
        baseUrl: _baseCtrl.text.trim(),
        email: _registerEmailCtrl.text.trim(),
        password: _registerPasswordCtrl.text,
        emailCode: _registerCodeCtrl.text.trim(),
        inviteCode: _inviteCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _authTab = 0;
        _session = session;
      });
      await _refreshAll(silent: true);
      _toast('注册成功并已自动登录');
    } catch (e) {
      _toast('注册失败：$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _sendRegisterCode() async {
    if (_baseCtrl.text.trim().isEmpty || _registerEmailCtrl.text.trim().isEmpty) {
      _toast('请先输入域名和注册邮箱');
      return;
    }
    setState(() => _submitting = true);
    try {
      await _api.sendEmailVerify(
        baseUrl: _baseCtrl.text.trim(),
        email: _registerEmailCtrl.text.trim(),
        isForgetPassword: false,
      );
      _toast('注册验证码已发送');
    } catch (e) {
      _toast('发送失败：$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleSendResetCode() async {
    if (_baseCtrl.text.trim().isEmpty || _resetEmailCtrl.text.trim().isEmpty) {
      _toast('请先输入域名和邮箱');
      return;
    }
    setState(() => _submitting = true);
    try {
      await _api.sendEmailVerify(
        baseUrl: _baseCtrl.text.trim(),
        email: _resetEmailCtrl.text.trim(),
        isForgetPassword: true,
      );
      _toast('验证码已发送');
    } catch (e) {
      _toast('发送失败：$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleResetPassword() async {
    if (_baseCtrl.text.trim().isEmpty ||
        _resetEmailCtrl.text.trim().isEmpty ||
        _resetCodeCtrl.text.trim().isEmpty ||
        _resetPasswordCtrl.text.isEmpty) {
      _toast('请完整输入重置信息');
      return;
    }
    setState(() => _submitting = true);
    try {
      await _api.resetPassword(
        baseUrl: _baseCtrl.text.trim(),
        email: _resetEmailCtrl.text.trim(),
        emailCode: _resetCodeCtrl.text.trim(),
        password: _resetPasswordCtrl.text,
      );
      _toast('重置成功，请登录');
      setState(() => _authTab = 0);
    } catch (e) {
      _toast('重置失败：$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _logout() async {
    await _api.logout();
    if (!mounted) return;
    setState(() {
      _session = null;
      _user = null;
      _subscribe = null;
      _plans = const [];
      _mainTab = 0;
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_session == null) {
      return _buildAuthView();
    }

    return _buildMainView();
  }

  Widget _buildAuthView() {
    return CommonScaffold(
      title: 'V2Board 客户端',
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1067BF), Color(0xFF5C8FC4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              margin: const EdgeInsets.all(18),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _baseCtrl,
                      decoration: const InputDecoration(
                        labelText: '面板域名',
                        hintText: 'https://example.com',
                        prefixIcon: Icon(Icons.language),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('登录')),
                        ButtonSegment(value: 1, label: Text('注册')),
                        ButtonSegment(value: 2, label: Text('找回密码')),
                      ],
                      selected: {_authTab},
                      onSelectionChanged: (v) => setState(() => _authTab = v.first),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 380,
                      child: SingleChildScrollView(
                        child: switch (_authTab) {
                          0 => _buildLoginForm(),
                          1 => _buildRegisterForm(),
                          _ => _buildResetForm(),
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        TextField(
          controller: _emailCtrl,
          decoration: const InputDecoration(labelText: '邮箱', prefixIcon: Icon(Icons.email_outlined)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passwordCtrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: '密码', prefixIcon: Icon(Icons.lock_outline)),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submitting ? null : _handleLogin,
            child: Text(_submitting ? '处理中...' : '登录'),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      children: [
        TextField(
          controller: _registerEmailCtrl,
          decoration: const InputDecoration(labelText: '邮箱', prefixIcon: Icon(Icons.email_outlined)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _registerCodeCtrl,
          decoration: InputDecoration(
            labelText: '邮箱验证码',
            prefixIcon: const Icon(Icons.shield_outlined),
            suffixIcon: TextButton(
              onPressed: _submitting ? null : _sendRegisterCode,
              child: const Text('发送'),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _registerPasswordCtrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: '密码', prefixIcon: Icon(Icons.lock_outline)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _inviteCtrl,
          decoration: const InputDecoration(labelText: '邀请码(选填)', prefixIcon: Icon(Icons.card_giftcard_outlined)),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submitting ? null : _handleRegister,
            child: Text(_submitting ? '处理中...' : '注册'),
          ),
        ),
      ],
    );
  }

  Widget _buildResetForm() {
    return Column(
      children: [
        TextField(
          controller: _resetEmailCtrl,
          decoration: const InputDecoration(labelText: '邮箱', prefixIcon: Icon(Icons.email_outlined)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _resetCodeCtrl,
          decoration: InputDecoration(
            labelText: '邮箱验证码',
            prefixIcon: const Icon(Icons.shield_outlined),
            suffixIcon: TextButton(
              onPressed: _submitting ? null : _handleSendResetCode,
              child: const Text('发送'),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _resetPasswordCtrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: '新密码', prefixIcon: Icon(Icons.lock_reset_outlined)),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submitting ? null : _handleResetPassword,
            child: Text(_submitting ? '处理中...' : '重置密码'),
          ),
        ),
      ],
    );
  }

  Widget _buildMainView() {
    final expired = _subscribe?.expiredAt != null && _subscribe!.expiredAt!.isBefore(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (_mainTab) { 0 => '主页', 1 => '套餐', _ => '我的' }),
        actions: [
          IconButton(onPressed: _submitting ? null : () => _refreshAll(), icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _mainTab,
            children: [_buildHomeTab(), _buildPlanTab(), _buildMeTab()],
          ),
          if (expired)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 44,
                width: double.infinity,
                color: Colors.redAccent,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const Row(
                  children: [
                    Expanded(child: Text('您的套餐已过期,请续费后使用', style: TextStyle(color: Colors.white))),
                    Text('购买套餐', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _mainTab,
        onDestinationSelected: (i) => setState(() => _mainTab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: '主页'),
          NavigationDestination(icon: Icon(Icons.storefront_outlined), label: '套餐'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: '我的'),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    final mode = ref.watch(patchClashConfigProvider.select((s) => s.mode));
    final tunEnable = ref.watch(realTunEnableProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _userCard(),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('功能', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _statTile(
                        '出站模式',
                        switch (mode) { Mode.rule => '智能', Mode.global => '全局', Mode.direct => '直连' },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _statTile('VPN', tunEnable ? '已开启' : '未开启')),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _statTile('上传', _fmtBytes(_subscribe?.u ?? 0))),
                    const SizedBox(width: 10),
                    Expanded(child: _statTile('下载', _fmtBytes(_subscribe?.d ?? 0))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanTab() {
    if (_plans.isEmpty) return const Center(child: Text('暂无套餐'));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _plans.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final p = _plans[i];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(p.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700))),
                    Text(p.priceText, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 10),
                Text('流量限制 ${_fmtBytes(p.transferEnable)}'),
                Text('设备限制 ${p.deviceLimit <= 0 ? '以套餐说明为准' : '${p.deviceLimit}台'}'),
                if (p.content.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(p.content),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _toast('请在面板购买: ${p.name}'),
                    child: const Text('购买'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMeTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _userCard(),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              _linkTile('订单记录', Icons.receipt_long_outlined),
              _linkTile('流量明细', Icons.pie_chart_outline),
              _linkTile('我的工单', Icons.support_agent_outlined),
              _linkTile('在线客服', Icons.headset_mic_outlined),
              _linkTile('官方网站', Icons.public_outlined),
              _linkTile('邀请码管理', Icons.group_outlined),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: context.colorScheme.error)),
        ],
      ],
    );
  }

  Widget _userCard() {
    final user = _user;
    final subscribe = _subscribe;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user?.email ?? '-', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('套餐: ${user?.planName ?? '未知套餐'}'),
            const SizedBox(height: 4),
            Text('已用流量: ${_fmtBytes(subscribe == null ? 0 : subscribe.u + subscribe.d)} / ${_fmtBytes(subscribe?.transferEnable ?? 0)}'),
            const SizedBox(height: 4),
            Text('到期时间: ${subscribe?.expiredText ?? '-'}'),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _linkTile(String title, IconData icon) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _toast('接口已就绪，待接页面: $title'),
    );
  }

  String _fmtBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double size = bytes.toDouble();
    int index = 0;
    while (size >= 1024 && index < units.length - 1) {
      size /= 1024;
      index++;
    }
    return '${size.toStringAsFixed(index == 0 ? 0 : 2)} ${units[index]}';
  }
}

class _UserInfo {
  final String email;
  final String planName;

  const _UserInfo({required this.email, required this.planName});

  static _UserInfo fromJson(Map<String, dynamic> j) {
    return _UserInfo(
      email: (j['email'] ?? '').toString(),
      planName: (j['plan_name'] ?? j['planName'] ?? '未知套餐').toString(),
    );
  }
}

class _SubscribeInfo {
  final int u;
  final int d;
  final int transferEnable;
  final DateTime? expiredAt;
  final String subscribeUrl;

  const _SubscribeInfo({
    required this.u,
    required this.d,
    required this.transferEnable,
    required this.expiredAt,
    required this.subscribeUrl,
  });

  String get expiredText {
    final t = expiredAt;
    if (t == null) return '-';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  static _SubscribeInfo fromJson(Map<String, dynamic> j) {
    final expRaw = j['expired_at'];
    DateTime? exp;
    if (expRaw is num) {
      final v = expRaw.toInt();
      exp = DateTime.fromMillisecondsSinceEpoch(v > 1000000000000 ? v : v * 1000);
    } else if (expRaw is String && expRaw.trim().isNotEmpty) {
      exp = DateTime.tryParse(expRaw.replaceFirst(' ', 'T'));
    }
    return _SubscribeInfo(
      u: (j['u'] as num?)?.toInt() ?? 0,
      d: (j['d'] as num?)?.toInt() ?? 0,
      transferEnable: (j['transfer_enable'] as num?)?.toInt() ?? 0,
      expiredAt: exp,
      subscribeUrl: (j['subscribe_url'] ?? '').toString(),
    );
  }
}

class _PlanInfo {
  final String name;
  final String priceText;
  final int transferEnable;
  final int deviceLimit;
  final String content;

  const _PlanInfo({
    required this.name,
    required this.priceText,
    required this.transferEnable,
    required this.deviceLimit,
    required this.content,
  });

  static _PlanInfo? fromJson(dynamic j) {
    if (j is! Map) return null;
    final monthPrice = (j['month_price'] as num?)?.toDouble() ?? 0;
    return _PlanInfo(
      name: (j['name'] ?? '').toString(),
      priceText: '¥${(monthPrice / 100).toStringAsFixed(2)} /月',
      transferEnable: (j['transfer_enable'] as num?)?.toInt() ?? 0,
      deviceLimit: (j['device_limit'] as num?)?.toInt() ?? 0,
      content: (j['content'] ?? '').toString(),
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() => runApp(const MyApp());

// 全局日志管理
class LogManager {
  static final LogManager _instance = LogManager._internal();
  factory LogManager() => _instance;
  LogManager._internal();
  
  final List<LogEntry> logs = [];
  
  void add(String type, String action, {String? request, String? response, String? error}) {
    logs.insert(0, LogEntry(
      time: DateTime.now(),
      type: type,
      action: action,
      request: request,
      response: response,
      error: error,
    ));
    if (logs.length > 100) logs.removeLast(); // 最多保留100条
  }
  
  void clear() => logs.clear();
}

class LogEntry {
  final DateTime time;
  final String type;
  final String action;
  final String? request;
  final String? response;
  final String? error;
  
  LogEntry({required this.time, required this.type, required this.action, this.request, this.response, this.error});
  
  String get timeStr => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  bool get isError => error != null;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '安达管理系统',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, scaffoldBackgroundColor: const Color(0xFFF5F5F5)),
      home: const MobileWrapper(child: HomePage()),
    );
  }
}

// 手机端包装器 - 限制最大宽度模拟手机屏幕
class MobileWrapper extends StatelessWidget {
  final Widget child;
  const MobileWrapper({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 30)],
          ),
          child: child,
        ),
      ),
    );
  }
}

class ApiClient {
  static const baseUrl = 'https://apiam.andahuandian.com';
  static const loginMobile = '刘兴';
  static const loginPassword = '123456';
  static const cid = '3b48cf71d353d1a38741c3faced30185';
  String? token;
  final _log = LogManager();
  
  Map<String, String> get headers => {'sType': '1906', 'token': token ?? '', 'Content-Type': 'application/json',
    'user-agent': 'Mozilla/5.0 (Linux; Android 9) AppleWebKit/537.36'};

  String generateSign(Map<String, dynamic> data) {
    var sorted = data.entries.where((e) => e.key != 'sign').toList()..sort((a, b) => a.key.compareTo(b.key));
    return md5.convert(utf8.encode(sorted.map((e) => '${e.key}=${e.value}').join('&'))).toString().toUpperCase();
  }

  bool _isTokenExpired(Map<String, dynamic> result) {
    var code = result['code']?.toString() ?? '';
    var msg = result['msg']?.toString().toLowerCase() ?? '';
    return code == '401' || code == '403' || msg.contains('token') || msg.contains('失效') || msg.contains('过期');
  }

  String _getApiName(String url) {
    if (url.contains('login')) return '登录';
    if (url.contains('queryUserList')) return '查询用户';
    if (url.contains('userDespositOpe')) return '押金操作';
    if (url.contains('queryMealDaysInfo')) return '查询套餐';
    if (url.contains('sendMealToUser')) return '充值套餐';
    if (url.contains('batteryBind')) return '电池绑定';
    if (url.contains('seekBatteryInfo')) return '查询电池';
    return url.split('/').last;
  }

  Future<Map<String, dynamic>> _request(String url, Map<String, dynamic> data) async {
    var apiName = _getApiName(url);
    try {
      _log.add('请求', apiName, request: jsonEncode(data));
      var resp = await http.post(Uri.parse(url), headers: headers, body: jsonEncode(data));
      var result = jsonDecode(resp.body);
      
      if (_isTokenExpired(result)) {
        _log.add('系统', 'Token过期，重新登录');
        await login();
        resp = await http.post(Uri.parse(url), headers: headers, body: jsonEncode(data));
        result = jsonDecode(resp.body);
      }
      
      _log.add('响应', apiName, response: jsonEncode(result));
      return result;
    } catch (e) {
      _log.add('错误', apiName, error: e.toString());
      return {'code': '500', 'msg': e.toString()};
    }
  }

  Future<Map<String, dynamic>> login() async {
    var data = {'appVersion': '2.1.9', 'cid': cid, 'mobile': loginMobile, 'password': loginPassword,
      'smsCode': '', 'type': '3', 'loginLat': '', 'loginLon': '', 'wxCode': '', 'iosId': '', 'timeStamp': DateTime.now().millisecondsSinceEpoch};
    data['sign'] = generateSign(data);
    try {
      _log.add('请求', '登录', request: '账号: $loginMobile');
      var resp = await http.post(Uri.parse('$baseUrl/adminService/api/login'),
          headers: {'sType': '1906', 'token': '', 'Content-Type': 'application/json'}, body: jsonEncode(data));
      var result = jsonDecode(resp.body);
      if (result['code'] == '200') {
        token = result['data']?['token'] ?? '';
        _log.add('响应', '登录', response: '登录成功');
        return {'success': true};
      }
      _log.add('错误', '登录', error: result['msg'] ?? '登录失败');
      return {'success': false, 'msg': result['msg'] ?? '登录失败'};
    } catch (e) {
      _log.add('错误', '登录', error: e.toString());
      return {'success': false, 'msg': e.toString()};
    }
  }

  Future<Map<String, dynamic>> queryUserList(String sifting, {String listType = '1', String depositTypeId = '', String opeFlag = '', String odUserId = ''}) async {
    var data = {'page': '1', 'limit': '10', 'sifting': sifting, 'listType': listType, 'despositTypeId': depositTypeId,
      'opeFlag': opeFlag, 'userId': odUserId, 'batterySN': '', 'mealRecovery': '', 'opeType': '', 'reason': '', 'status': '', 'timeStamp': DateTime.now().millisecondsSinceEpoch};
    data['sign'] = generateSign(data);
    return _request('$baseUrl/adminService/api/promter/queryUserList', data);
  }

  Future<Map<String, dynamic>> userDepositOpe(String sifting, String odUserId) async {
    var data = {'page': '1', 'limit': '10', 'sifting': sifting, 'listType': '0', 'despositTypeId': '2310291606277978810',
      'opeFlag': '1', 'userId': odUserId, 'batterySN': '', 'mealRecovery': '', 'opeType': '', 'reason': '个人原因，不想用了', 'status': '', 'timeStamp': DateTime.now().millisecondsSinceEpoch};
    data['sign'] = generateSign(data);
    return _request('$baseUrl/adminService/api/promter/userDespositOpe', data);
  }

  Future<Map<String, dynamic>> queryMealDaysInfo(String phone, String odUserId) async {
    var data = {'page': '1', 'limit': '10', 'inviteStatus': '', 'phone': phone, 'pageFlag': '0', 'days': '30', 'flag': 1, 'userId': odUserId, 'timeStamp': DateTime.now().millisecondsSinceEpoch};
    data['sign'] = generateSign(data);
    return _request('$baseUrl/adminService/api/promter/queryMealDaysInfo', data);
  }

  Future<Map<String, dynamic>> sendMealToUser(String odUserId, String poolId, String days) async {
    var data = {'days': days, 'userId': odUserId, 'poolId': poolId, 'remark': null, 'timeStamp': DateTime.now().millisecondsSinceEpoch};
    data['sign'] = generateSign(data);
    return _request('$baseUrl/adminService/api/promter/sendMealToUser', data);
  }

  Future<Map<String, dynamic>> bindBattery(String realName, String odUserId, String batterySN, String opeType) async {
    var data = {'page': '1', 'limit': '10', 'sifting': realName, 'listType': '1', 'despositTypeId': '', 'opeFlag': '',
      'userId': odUserId, 'batterySN': batterySN, 'mealRecovery': '1', 'opeType': opeType, 'reason': '', 'status': '', 'timeStamp': DateTime.now().millisecondsSinceEpoch};
    data['sign'] = generateSign(data);
    return _request('$baseUrl/adminService/api/promter/batteryBind', data);
  }

  Future<Map<String, dynamic>> unbindUser(String odUserId) async {
    var data = {'page': '2', 'limit': '10', 'sifting': '', 'listType': '1', 'despositTypeId': '', 'opeFlag': '2',
      'userId': odUserId, 'batterySN': '', 'mealRecovery': '', 'opeType': '', 'reason': '租户退租归还电池', 'status': '', 'timeStamp': DateTime.now().millisecondsSinceEpoch};
    data['sign'] = generateSign(data);
    return _request('$baseUrl/adminService/api/promter/userDespositOpe', data);
  }

  Future<Map<String, dynamic>> getBatterySoc(String batteryId) async {
    var data = {'batteryId': batteryId, 'timeStamp': DateTime.now().millisecondsSinceEpoch};
    data['sign'] = generateSign(data);
    return _request('$baseUrl/adminService/api/repairman/seekBatteryInfo', data);
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final api = ApiClient();
  bool isLoggedIn = false;
  bool isLoading = false;
  int currentTab = 0;

  @override
  void initState() { super.initState(); _login(); }

  Future<void> _login() async {
    setState(() => isLoading = true);
    var result = await api.login();
    setState(() { isLoggedIn = result['success'] == true; isLoading = false; });
    if (result['success'] != true) _showMsg('登录失败', result['msg'] ?? '');
  }

  void _showMsg(String title, String msg) => showDialog(context: context, builder: (ctx) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
    content: Text(msg, style: const TextStyle(fontSize: 15)),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('确定', style: TextStyle(color: Color(0xFF1E88E5))))],
  ));

  Future<bool> _showConfirm(String title, String msg) async => await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
    content: Text(msg),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消', style: TextStyle(color: Colors.grey))),
      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定', style: TextStyle(color: Color(0xFF1E88E5)))),
    ],
  )) ?? false;

  Future<int?> _showDaysDialog(String title, String subtitle, {int defaultDays = 30}) async {
    int days = defaultDays;
    return await showDialog<int>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _circleBtn(Icons.remove, () => setDialogState(() => days = days > 1 ? days - 1 : 1)),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(12)),
              child: Text('$days 天', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E88E5))),
            ),
            _circleBtn(Icons.add, () => setDialogState(() => days = days < 365 ? days + 1 : 365)),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(ctx, days), child: const Text('确定充值', style: TextStyle(color: Color(0xFF1E88E5), fontWeight: FontWeight.w600))),
        ],
      ),
    ));
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xFF1E88E5), shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 22),
    ),
  );

  Future<String?> _openScanner() => Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const ScannerPage()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: isLoading ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E88E5)))
          : IndexedStack(index: currentTab, children: [
              ChargePage(api: api, showMsg: _showMsg, showDaysDialog: _showDaysDialog, openScanner: _openScanner, isLoggedIn: isLoggedIn),
              ScanPage(api: api, showMsg: _showMsg, showConfirm: _showConfirm),
              LocationPage(api: api, openScanner: _openScanner),
            ]),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFEEEEEE)))),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _navItem(0, Icons.bolt, '开通充值'),
              _navItem(1, Icons.qr_code_scanner, '扫一扫'),
              _navItem(2, Icons.location_on, '查定位'),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isActive = currentTab == index;
    return GestureDetector(
      onTap: () => setState(() => currentTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: isActive ? const Color(0xFF1E88E5) : Colors.grey, size: 26),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: isActive ? const Color(0xFF1E88E5) : Colors.grey, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
        ]),
      ),
    );
  }
}


// 开通充值页面
class ChargePage extends StatefulWidget {
  final ApiClient api;
  final Function(String, String) showMsg;
  final Future<int?> Function(String, String, {int defaultDays}) showDaysDialog;
  final Future<String?> Function() openScanner;
  final bool isLoggedIn;
  const ChargePage({super.key, required this.api, required this.showMsg, required this.showDaysDialog, required this.openScanner, required this.isLoggedIn});
  @override
  State<ChargePage> createState() => _ChargePageState();
}

class _ChargePageState extends State<ChargePage> {
  final phoneCtrl = TextEditingController();
  bool isLoading = false;

  Future<void> _guaranteeOpen() async {
    var phone = phoneCtrl.text.trim();
    if (phone.length != 11) { widget.showMsg('提示', '请输入正确的11位手机号'); return; }
    setState(() => isLoading = true);
    var result = await widget.api.queryUserList(phone, listType: '1');
    if (result['code'] == '200') {
      var userList = result['data']?['userList'] ?? [];
      if (userList.isNotEmpty) {
        widget.showMsg('查询结果', '${userList[0]['mobile']} ${userList[0]['realName']} 已实名注册免押');
        setState(() => isLoading = false); return;
      }
      var result2 = await widget.api.queryUserList(phone, listType: '0', depositTypeId: '2310291606277978810', opeFlag: '1');
      if (result2['code'] == '200') {
        var list2 = result2['data']?['userList'] ?? [];
        if (list2.isEmpty) { widget.showMsg('提示', '该手机号未注册'); }
        else if (list2[0]['realName'] == '未实名') { widget.showMsg('提示', '该手机号已注册未实名'); }
        else { await _doDeposit(phone, list2[0]['id'], list2[0]['realName']); }
      }
    }
    setState(() => isLoading = false);
  }

  Future<void> _doDeposit(String phone, String odUserId, String realName) async {
    var result = await widget.api.userDepositOpe(phone, odUserId);
    if (result['code'] == '200') {
      var days = await widget.showDaysDialog('免押成功', '是否进行充值？');
      if (days != null) await _doRecharge(phone, odUserId, realName, days);
    } else { widget.showMsg('错误', '免押失败: ${result['msg']}'); }
  }

  Future<void> _doRecharge(String phone, String odUserId, String realName, int days) async {
    var poolResult = await widget.api.queryMealDaysInfo(phone, odUserId);
    var poolList = poolResult['data']?['mealPoolList'] ?? [];
    if (poolList.isEmpty) { widget.showMsg('错误', '没有可用套餐池'); return; }
    var result = await widget.api.sendMealToUser(odUserId, poolList[0]['poolId'], days.toString());
    if (result['code'] == '200') {
      var choice = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('充值成功', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        content: const Text('请选择电池方式'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'self'), child: const Text('自取电池', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(ctx, 'bind'), child: const Text('绑定电池', style: TextStyle(color: Color(0xFF1E88E5)))),
        ],
      ));
      if (choice == 'bind') {
        var sn = await widget.openScanner();
        if (sn != null && sn.toUpperCase().startsWith('AD')) {
          var bindResult = await widget.api.bindBattery(realName, odUserId, sn, '2304');
          widget.showMsg(bindResult['code'] == '200' ? '成功' : '错误', bindResult['code'] == '200' ? '$realName绑定完成' : '绑定失败');
        }
      }
    } else { widget.showMsg('错误', '充值失败'); }
  }

  Future<void> _renewMeal() async {
    var phone = phoneCtrl.text.trim();
    if (phone.length != 11) { widget.showMsg('提示', '请输入正确的11位手机号'); return; }
    setState(() => isLoading = true);
    var result = await widget.api.queryUserList(phone, listType: '1');
    if (result['code'] == '200') {
      var userList = result['data']?['userList'] ?? [];
      if (userList.isEmpty) { widget.showMsg('提示', '未找到用户资料'); }
      else {
        var days = await widget.showDaysDialog('续租充值', '是否为 ${userList[0]['realName']} 充值？');
        if (days != null) {
          var poolResult = await widget.api.queryMealDaysInfo(userList[0]['mobile'], userList[0]['id']);
          var poolList = poolResult['data']?['mealPoolList'] ?? [];
          if (poolList.isNotEmpty) {
            var r = await widget.api.sendMealToUser(userList[0]['id'], poolList[0]['poolId'], days.toString());
            widget.showMsg(r['code'] == '200' ? '成功' : '错误', r['code'] == '200' ? '续租充值成功（$days天）' : '充值失败');
          }
        }
      }
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // 顶部蓝色区域
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF1976D2)]),
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('开通充值', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: widget.isLoggedIn ? Colors.greenAccent : Colors.redAccent, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(widget.isLoggedIn ? '已连接' : '未连接', style: const TextStyle(color: Colors.white, fontSize: 12)),
                ]),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LogPage())),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.article_outlined, color: Colors.white, size: 18),
                ),
              ),
            ]),
          ]),
          const SizedBox(height: 8),
          Text('输入手机号进行担保开通或续租', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
        ]),
      ),
      
      // 内容区域
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // 输入框
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
            child: TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: '请输入手机号码',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.phone_android, color: Color(0xFF1E88E5)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // 两个按钮
          Row(children: [
            Expanded(child: _actionBtn('担保开通', Icons.verified_user, const Color(0xFF1E88E5), _guaranteeOpen)),
            const SizedBox(width: 12),
            Expanded(child: _actionBtn('续租套餐', Icons.refresh, const Color(0xFF26A69A), _renewMeal)),
          ]),
          
          const SizedBox(height: 30),
          
          // 功能说明
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('功能说明', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _infoItem(Icons.verified_user, const Color(0xFF1E88E5), '担保开通', '新用户免押金开通服务'),
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
              _infoItem(Icons.refresh, const Color(0xFF26A69A), '续租套餐', '老用户续费充值套餐'),
            ]),
          ),
        ]),
      )),
    ]);
  }

  Widget _actionBtn(String text, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (isLoading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          else ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8), Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))],
        ]),
      ),
    );
  }

  Widget _infoItem(IconData icon, Color color, String title, String desc) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 22)),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 2),
        Text(desc, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      ]),
    ]);
  }
}


// 扫一扫页面
class ScanPage extends StatefulWidget {
  final ApiClient api;
  final Function(String, String) showMsg;
  final Future<bool> Function(String, String) showConfirm;
  const ScanPage({super.key, required this.api, required this.showMsg, required this.showConfirm});
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool isReturnMode = false;
  bool isLoading = false;
  String resultText = '';
  MobileScannerController? controller;
  bool isScanning = false;
  String lastBatteryId = '';

  void _startScanning() {
    controller = MobileScannerController();
    setState(() { isScanning = true; resultText = ''; });
  }

  void _stopScanning() {
    controller?.dispose();
    controller = null;
    setState(() => isScanning = false);
  }

  void _onDetect(BarcodeCapture capture) async {
    if (isLoading) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;
    var batteryId = barcode!.rawValue!;
    if (batteryId == lastBatteryId || !batteryId.toUpperCase().startsWith('AD')) return;
    lastBatteryId = batteryId;
    setState(() => isLoading = true);
    
    if (isReturnMode) {
      var result = await widget.api.queryUserList(batteryId, listType: '1');
      if (result['code'] == '200') {
        var userList = result['data']?['userList'] ?? [];
        if (userList.isEmpty) { setState(() { resultText = '未找到该电池对应的用户'; isLoading = false; }); }
        else {
          var user = userList[0];
          var r = await widget.api.bindBattery(user['realName'], user['id'], user['batterySN'], '2305');
          if (r['code'] == '200') {
            setState(() { resultText = '${user['realName']} ${user['mobile']}\n电池归还回收成功'; isLoading = false; });
            var confirm = await widget.showConfirm('回收成功', '是否解绑用户？');
            if (confirm) {
              var unbind = await widget.api.unbindUser(user['id']);
              widget.showMsg(unbind['code'] == '200' ? '成功' : '错误', unbind['code'] == '200' ? '电池解绑完成' : '解绑失败');
            }
          } else { setState(() { resultText = '回收失败'; isLoading = false; }); }
        }
      }
    } else {
      var result = await widget.api.getBatterySoc(batteryId);
      if (result['code'] == '200') {
        setState(() { resultText = '电池: $batteryId\n电量: ${result['data']?['soc'] ?? '未知'}%'; isLoading = false; });
      } else { setState(() { resultText = '查询失败'; isLoading = false; }); }
    }
    Future.delayed(const Duration(seconds: 2), () { lastBatteryId = ''; });
  }

  @override
  void dispose() { controller?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // 顶部蓝色区域
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF1976D2)]),
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('扫一扫', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: isReturnMode ? Colors.redAccent : Colors.white24, borderRadius: BorderRadius.circular(16)),
              child: Text(isReturnMode ? '退租模式' : '查电量模式', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(isReturnMode ? '扫码进行电池退租操作' : '扫码查看电池当前电量', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
        ]),
      ),
      
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          if (!isScanning) ...[
            // 扫码按钮
            GestureDetector(
              onTap: _startScanning,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)]),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: isReturnMode ? const Color(0xFFFFEBEE) : const Color(0xFFE3F2FD), shape: BoxShape.circle),
                    child: Icon(Icons.qr_code_scanner, size: 50, color: isReturnMode ? Colors.redAccent : const Color(0xFF1E88E5)),
                  ),
                  const SizedBox(height: 16),
                  Text('点击开始扫码', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isReturnMode ? Colors.redAccent : const Color(0xFF1E88E5))),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            
            // 操作退租按钮
            GestureDetector(
              onTap: () => setState(() => isReturnMode = !isReturnMode),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: isReturnMode ? const LinearGradient(colors: [Color(0xFFEF5350), Color(0xFFE53935)]) : null,
                  color: isReturnMode ? null : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: isReturnMode ? null : Border.all(color: Colors.grey.shade300),
                  boxShadow: isReturnMode ? [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.battery_alert, color: isReturnMode ? Colors.white : Colors.grey.shade600, size: 22),
                  const SizedBox(width: 10),
                  Text('操作退租', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isReturnMode ? Colors.white : Colors.grey.shade600)),
                  if (isReturnMode) ...[const SizedBox(width: 8), const Icon(Icons.check_circle, color: Colors.white, size: 18)],
                ]),
              ),
            ),
          ] else ...[
            // 扫码界面
            Container(
              height: 280,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15)]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(children: [
                  MobileScanner(controller: controller!, onDetect: _onDetect),
                  Center(child: Container(width: 180, height: 180, decoration: BoxDecoration(
                    border: Border.all(color: isReturnMode ? Colors.redAccent : Colors.white, width: 3), borderRadius: BorderRadius.circular(16)))),
                  if (isLoading) Center(child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                    child: const CircularProgressIndicator(color: Colors.white))),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _stopScanning,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16)),
                child: const Center(child: Text('停止扫码', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey))),
              ),
            ),
          ],
          
          if (resultText.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.battery_charging_full, color: Color(0xFF1E88E5), size: 26)),
                const SizedBox(width: 16),
                Expanded(child: Text(resultText, style: const TextStyle(fontSize: 15, height: 1.5, fontWeight: FontWeight.w500))),
              ]),
            ),
          ],
        ]),
      )),
    ]);
  }
}


// 查定位页面
class LocationPage extends StatefulWidget {
  final ApiClient api;
  final Future<String?> Function() openScanner;
  const LocationPage({super.key, required this.api, required this.openScanner});
  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  final phoneCtrl = TextEditingController();
  bool isLoading = false;
  String resultText = '';

  Future<void> _queryByPhone() async {
    var phone = phoneCtrl.text.trim();
    if (phone.length != 11) { setState(() => resultText = '请输入正确的11位手机号'); return; }
    setState(() { isLoading = true; resultText = ''; });
    var result = await widget.api.queryUserList(phone, listType: '1');
    if (result['code'] != '200' || (result['data']?['userList'] ?? []).isEmpty) {
      setState(() { resultText = '当前手机号无法查询到用户'; isLoading = false; }); return;
    }
    var user = result['data']['userList'][0];
    var batterySN = user['batterySN'];
    if (batterySN == null || batterySN.toString().isEmpty) {
      setState(() { resultText = '租户 ${user['realName']} 当前未绑定电池'; isLoading = false; }); return;
    }
    await _queryLocation(batterySN, user['realName']);
  }

  Future<void> _scanAndQuery() async {
    var batterySN = await widget.openScanner();
    if (batterySN == null || !batterySN.toUpperCase().startsWith('AD')) return;
    setState(() { isLoading = true; resultText = ''; });
    await _queryLocation(batterySN, '');
  }

  Future<void> _queryLocation(String batterySN, String realName) async {
    var result = await widget.api.getBatterySoc(batterySN);
    if (result['code'] == '200') {
      var data = result['data'] ?? {};
      setState(() {
        resultText = '${realName.isNotEmpty ? "👤 用户: $realName\n" : ""}🔋 电池: $batterySN\n\n📍 ${data['address'] ?? '未知地址'}\n\n经度: ${data['lon'] ?? '-'}\n纬度: ${data['lat'] ?? '-'}';
        isLoading = false;
      });
    } else { setState(() { resultText = '查询失败'; isLoading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // 顶部蓝色区域
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF1976D2)]),
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('查定位', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('输入手机号或扫描电池查看定位', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
        ]),
      ),
      
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // 查询卡片
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)]),
            child: Column(children: [
              Row(children: [
                Expanded(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(14)),
                  child: TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: '请输入手机号码',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      prefixIcon: const Icon(Icons.phone_android, color: Color(0xFF1E88E5)),
                      border: InputBorder.none,
                    ),
                  ),
                )),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: isLoading ? null : _scanAndQuery,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)]), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 26),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: isLoading ? null : _queryByPhone,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: const Color(0xFF1E88E5).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: Center(child: isLoading 
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('查询定位', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))),
                ),
              ),
            ]),
          ),
          
          if (resultText.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.location_on, color: Color(0xFF1E88E5), size: 24)),
                  const SizedBox(width: 12),
                  const Text('定位信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ]),
                const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
                Text(resultText, style: const TextStyle(fontSize: 15, height: 1.8)),
              ]),
            ),
          ],
        ]),
      )),
    ]);
  }
}

// 扫码页面
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});
  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  MobileScannerController controller = MobileScannerController();
  bool hasScanned = false;
  final manualCtrl = TextEditingController();

  @override
  void dispose() { controller.dispose(); super.dispose(); }

  void _onDetect(BarcodeCapture capture) {
    if (hasScanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue != null) { hasScanned = true; Navigator.pop(context, barcode!.rawValue); }
  }

  void _manualInput() => showDialog(context: context, builder: (ctx) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: const Text('手动输入', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
    content: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
      child: TextField(controller: manualCtrl, decoration: const InputDecoration(hintText: '请输入电池编号（AD开头）', border: InputBorder.none)),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: Colors.grey))),
      TextButton(onPressed: () { Navigator.pop(ctx); Navigator.pop(context, manualCtrl.text.trim()); }, child: const Text('确定', style: TextStyle(color: Color(0xFF1E88E5)))),
    ],
  ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        MobileScanner(controller: controller, onDetect: _onDetect),
        // 顶部
        Positioned(top: 0, left: 0, right: 0, child: Container(
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 10, 16, 16),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.black.withOpacity(0.6), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20))),
            const Text('扫描二维码', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            GestureDetector(onTap: _manualInput, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.edit, color: Colors.white, size: 20))),
          ]),
        )),
        // 扫描框
        Center(child: Container(width: 240, height: 240, decoration: BoxDecoration(border: Border.all(color: const Color(0xFF1E88E5), width: 3), borderRadius: BorderRadius.circular(20)))),
        // 底部提示
        Positioned(bottom: 80, left: 0, right: 0, child: Center(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(24)),
          child: const Text('将二维码放入框内自动扫描', style: TextStyle(color: Colors.white, fontSize: 14)),
        ))),
      ]),
    );
  }
}


// 日志查看页面
class LogPage extends StatefulWidget {
  const LogPage({super.key});
  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  final _log = LogManager();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(children: [
        // 顶部
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 10, 16, 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF1976D2)]),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
              ),
            ),
            const Text('系统日志', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            GestureDetector(
              onTap: () {
                _log.clear();
                setState(() {});
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                child: const Text('清空', style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ),
          ]),
        ),
        
        // 日志列表
        Expanded(
          child: _log.logs.isEmpty
            ? const Center(child: Text('暂无日志', style: TextStyle(color: Colors.grey)))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _log.logs.length,
                itemBuilder: (context, index) {
                  var log = _log.logs[index];
                  return GestureDetector(
                    onTap: () => _showLogDetail(log),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: log.isError ? Border.all(color: Colors.redAccent.withOpacity(0.3)) : null,
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getTypeColor(log.type).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(_getTypeIcon(log.type), color: _getTypeColor(log.type), size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text(log.action, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: _getTypeColor(log.type).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                              child: Text(log.type, style: TextStyle(fontSize: 10, color: _getTypeColor(log.type))),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Text(log.timeStr, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        ])),
                        Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
                      ]),
                    ),
                  );
                },
              ),
        ),
      ]),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case '请求': return const Color(0xFF1E88E5);
      case '响应': return const Color(0xFF43A047);
      case '错误': return Colors.redAccent;
      case '系统': return Colors.orange;
      default: return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case '请求': return Icons.upload_outlined;
      case '响应': return Icons.download_outlined;
      case '错误': return Icons.error_outline;
      case '系统': return Icons.info_outline;
      default: return Icons.circle;
    }
  }

  void _showLogDetail(LogEntry log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Icon(_getTypeIcon(log.type), color: _getTypeColor(log.type)),
                const SizedBox(width: 8),
                Text('${log.action} - ${log.type}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ]),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: Colors.grey),
              ),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _detailSection('时间', log.time.toString()),
                if (log.request != null) _detailSection('请求数据', _formatJson(log.request!)),
                if (log.response != null) _detailSection('响应数据', _formatJson(log.response!)),
                if (log.error != null) _detailSection('错误信息', log.error!, isError: true),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _detailSection(String title, String content, {bool isError = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isError ? Colors.red.shade50 : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SelectableText(content, style: TextStyle(fontSize: 13, color: isError ? Colors.red : Colors.black87, height: 1.5)),
      ),
      const SizedBox(height: 16),
    ]);
  }

  String _formatJson(String jsonStr) {
    try {
      var obj = jsonDecode(jsonStr);
      return const JsonEncoder.withIndent('  ').convert(obj);
    } catch (e) {
      return jsonStr;
    }
  }
}

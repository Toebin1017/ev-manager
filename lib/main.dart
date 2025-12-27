import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '安达充值系统',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.grey,
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class ApiClient {
  static const baseUrl = 'https://apiam.andahuandian.com';
  static const loginMobile = '刘兴';
  static const loginPassword = '123456';
  static const cid = '3b48cf71d353d1a38741c3faced30185';
  String? token;
  
  Map<String, String> get headers => {
    'sType': '1906', 'token': token ?? '', 'Content-Type': 'application/json',
    'user-agent': 'Mozilla/5.0 (Linux; Android 9) AppleWebKit/537.36',
  };

  String generateSign(Map<String, dynamic> data) {
    var sorted = data.entries.where((e) => e.key != 'sign').toList()..sort((a, b) => a.key.compareTo(b.key));
    var signStr = sorted.map((e) => '${e.key}=${e.value}').join('&');
    return md5.convert(utf8.encode(signStr)).toString().toUpperCase();
  }

  Future<Map<String, dynamic>> login() async {
    var timestamp = DateTime.now().millisecondsSinceEpoch;
    var data = {'appVersion': '2.1.9', 'cid': cid, 'mobile': loginMobile, 'password': loginPassword,
      'smsCode': '', 'type': '3', 'loginLat': '', 'loginLon': '', 'wxCode': '', 'iosId': '', 'timeStamp': timestamp};
    data['sign'] = generateSign(data);
    try {
      var resp = await http.post(Uri.parse('$baseUrl/adminService/api/login'),
          headers: {'sType': '1906', 'token': '', 'Content-Type': 'application/json'}, body: jsonEncode(data));
      var result = jsonDecode(resp.body);
      if (result['code'] == '200') { token = result['data']?['token'] ?? ''; return {'success': true, 'msg': '登录成功'}; }
      return {'success': false, 'msg': result['msg'] ?? '登录失败'};
    } catch (e) { return {'success': false, 'msg': e.toString()}; }
  }

  Future<Map<String, dynamic>> queryUserList(String sifting, {String listType = '1', String depositTypeId = '', String opeFlag = '', String odUserId = ''}) async {
    var timestamp = DateTime.now().millisecondsSinceEpoch;
    var data = {'page': '1', 'limit': '10', 'sifting': sifting, 'listType': listType, 'despositTypeId': depositTypeId,
      'opeFlag': opeFlag, 'userId': odUserId, 'batterySN': '', 'mealRecovery': '', 'opeType': '', 'reason': '', 'status': '', 'timeStamp': timestamp};
    data['sign'] = generateSign(data);
    try {
      var resp = await http.post(Uri.parse('$baseUrl/adminService/api/promter/queryUserList'), headers: headers, body: jsonEncode(data));
      return jsonDecode(resp.body);
    } catch (e) { return {'code': '500', 'msg': e.toString()}; }
  }

  Future<Map<String, dynamic>> userDepositOpe(String sifting, String odUserId) async {
    var timestamp = DateTime.now().millisecondsSinceEpoch;
    var data = {'page': '1', 'limit': '10', 'sifting': sifting, 'listType': '0', 'despositTypeId': '2310291606277978810',
      'opeFlag': '1', 'userId': odUserId, 'batterySN': '', 'mealRecovery': '', 'opeType': '', 'reason': '个人原因，不想用了', 'status': '', 'timeStamp': timestamp};
    data['sign'] = generateSign(data);
    try {
      var resp = await http.post(Uri.parse('$baseUrl/adminService/api/promter/userDespositOpe'), headers: headers, body: jsonEncode(data));
      return jsonDecode(resp.body);
    } catch (e) { return {'code': '500', 'msg': e.toString()}; }
  }

  Future<Map<String, dynamic>> queryMealDaysInfo(String phone, String odUserId) async {
    var timestamp = DateTime.now().millisecondsSinceEpoch;
    var data = {'page': '1', 'limit': '10', 'inviteStatus': '', 'phone': phone, 'pageFlag': '0', 'days': '30', 'flag': 1, 'userId': odUserId, 'timeStamp': timestamp};
    data['sign'] = generateSign(data);
    try {
      var resp = await http.post(Uri.parse('$baseUrl/adminService/api/promter/queryMealDaysInfo'), headers: headers, body: jsonEncode(data));
      return jsonDecode(resp.body);
    } catch (e) { return {'code': '500', 'msg': e.toString()}; }
  }

  Future<Map<String, dynamic>> sendMealToUser(String odUserId, String poolId, String days) async {
    var timestamp = DateTime.now().millisecondsSinceEpoch;
    var data = {'days': days, 'userId': odUserId, 'poolId': poolId, 'remark': null, 'timeStamp': timestamp};
    data['sign'] = generateSign(data);
    try {
      var resp = await http.post(Uri.parse('$baseUrl/adminService/api/promter/sendMealToUser'), headers: headers, body: jsonEncode(data));
      return jsonDecode(resp.body);
    } catch (e) { return {'code': '500', 'msg': e.toString()}; }
  }

  Future<Map<String, dynamic>> bindBattery(String realName, String odUserId, String batterySN, String opeType) async {
    var timestamp = DateTime.now().millisecondsSinceEpoch;
    var data = {'page': '1', 'limit': '10', 'sifting': realName, 'listType': '1', 'despositTypeId': '', 'opeFlag': '',
      'userId': odUserId, 'batterySN': batterySN, 'mealRecovery': '1', 'opeType': opeType, 'reason': '', 'status': '', 'timeStamp': timestamp};
    data['sign'] = generateSign(data);
    try {
      var resp = await http.post(Uri.parse('$baseUrl/adminService/api/promter/batteryBind'), headers: headers, body: jsonEncode(data));
      return jsonDecode(resp.body);
    } catch (e) { return {'code': '500', 'msg': e.toString()}; }
  }

  Future<Map<String, dynamic>> unbindUser(String odUserId) async {
    var timestamp = DateTime.now().millisecondsSinceEpoch;
    var data = {'page': '2', 'limit': '10', 'sifting': '', 'listType': '1', 'despositTypeId': '', 'opeFlag': '2',
      'userId': odUserId, 'batterySN': '', 'mealRecovery': '', 'opeType': '', 'reason': '租户退租归还电池', 'status': '', 'timeStamp': timestamp};
    data['sign'] = generateSign(data);
    try {
      var resp = await http.post(Uri.parse('$baseUrl/adminService/api/promter/userDespositOpe'), headers: headers, body: jsonEncode(data));
      return jsonDecode(resp.body);
    } catch (e) { return {'code': '500', 'msg': e.toString()}; }
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
    setState(() { isLoggedIn = result['success']; isLoading = false; });
    if (!result['success']) _showMsg('登录失败', result['msg']);
  }

  void _showMsg(String title, String msg) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      content: Text(msg),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('确定', style: TextStyle(color: Colors.black)))],
    ));
  }

  Future<bool> _showConfirm(String title, String msg) async {
    return await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消', style: TextStyle(color: Colors.grey))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定', style: TextStyle(color: Colors.black))),
      ],
    )) ?? false;
  }

  Future<int?> _showDaysDialog(String title, String subtitle, {int defaultDays = 30}) async {
    int days = defaultDays;
    return await showDialog<int>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => setDialogState(() => days = (days > 1) ? days - 1 : 1)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
              child: Text('$days 天', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setDialogState(() => days = (days < 365) ? days + 1 : 365)),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(ctx, days), child: const Text('确定充值', style: TextStyle(color: Colors.black))),
        ],
      ),
    ));
  }

  Future<String?> _openScanner() async {
    return await Navigator.push<String>(context, MaterialPageRoute(builder: (ctx) => const ScannerPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('安达充值系统', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [Padding(padding: const EdgeInsets.only(right: 16), child: Icon(Icons.circle, size: 12, color: isLoggedIn ? Colors.green : Colors.red))],
      ),
      body: isLoading ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : IndexedStack(index: currentTab, children: [
              NewRentPage(api: api, showMsg: _showMsg, showDaysDialog: _showDaysDialog, openScanner: _openScanner),
              BatteryReturnPage(api: api, showMsg: _showMsg, showConfirm: _showConfirm, openScanner: _openScanner),
              RenewPage(api: api, showMsg: _showMsg, showDaysDialog: _showDaysDialog),
            ]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentTab, onTap: (i) => setState(() => currentTab = i),
        selectedItemColor: Colors.black, unselectedItemColor: Colors.grey, type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.add_box_outlined), activeIcon: Icon(Icons.add_box), label: '新租开电'),
          BottomNavigationBarItem(icon: Icon(Icons.battery_alert_outlined), activeIcon: Icon(Icons.battery_alert), label: '电池退租'),
          BottomNavigationBarItem(icon: Icon(Icons.refresh_outlined), activeIcon: Icon(Icons.refresh), label: '续租电池'),
        ],
      ),
    );
  }
}


class NewRentPage extends StatefulWidget {
  final ApiClient api;
  final Function(String, String) showMsg;
  final Future<int?> Function(String, String, {int defaultDays}) showDaysDialog;
  final Future<String?> Function() openScanner;
  const NewRentPage({super.key, required this.api, required this.showMsg, required this.showDaysDialog, required this.openScanner});
  @override
  State<NewRentPage> createState() => _NewRentPageState();
}

class _NewRentPageState extends State<NewRentPage> {
  final phoneController = TextEditingController();
  bool isLoading = false;

  Future<void> _query() async {
    var phone = phoneController.text.trim();
    if (phone.length != 11) { widget.showMsg('提示', '请输入正确的11位手机号'); return; }
    setState(() => isLoading = true);
    var result = await widget.api.queryUserList(phone, listType: '1');
    if (result['code'] == '200') {
      var userList = result['data']?['userList'] ?? [];
      if (userList.isNotEmpty) {
        widget.showMsg('查询结果', '${userList[0]['mobile']}${userList[0]['realName']}已实名注册免押');
        setState(() => isLoading = false); return;
      }
      await _queryStep2(phone);
    }
    setState(() => isLoading = false);
  }

  Future<void> _queryStep2(String phone) async {
    var result = await widget.api.queryUserList(phone, listType: '0', depositTypeId: '2310291606277978810', opeFlag: '1');
    if (result['code'] == '200') {
      var userList = result['data']?['userList'] ?? [];
      if (userList.isEmpty) { widget.showMsg('提示', '该手机号未注册'); return; }
      if (userList[0]['realName'] == '未实名') { widget.showMsg('提示', '该手机号已注册未实名'); return; }
      await _doDepositOpe(phone, userList[0]['id'], userList[0]['realName']);
    }
  }

  Future<void> _doDepositOpe(String phone, String odUserId, String realName) async {
    var result = await widget.api.userDepositOpe(phone, odUserId);
    if (result['code'] == '200') {
      var days = await widget.showDaysDialog('免押成功', '是否进行充值？');
      if (days != null) await _doRecharge(phone, odUserId, realName, days);
    } else { widget.showMsg('错误', '免押失败: ${result['msg']}'); }
  }

  Future<void> _doRecharge(String phone, String odUserId, String realName, int days) async {
    var poolResult = await widget.api.queryMealDaysInfo(phone, odUserId);
    if (poolResult['code'] != '200') { widget.showMsg('错误', '查询套餐池失败'); return; }
    var poolList = poolResult['data']?['mealPoolList'] ?? [];
    if (poolList.isEmpty) { widget.showMsg('错误', '没有可用套餐池'); return; }
    var rechargeResult = await widget.api.sendMealToUser(odUserId, poolList[0]['poolId'], days.toString());
    if (rechargeResult['code'] == '200') { await _showBatteryChoice(odUserId, realName); }
    else { widget.showMsg('错误', '充值失败: ${rechargeResult['msg']}'); }
  }

  Future<void> _showBatteryChoice(String odUserId, String realName) async {
    var choice = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('充值成功', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      content: const Text('请选择电池方式'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, 'self'), child: const Text('自取电池', style: TextStyle(color: Colors.grey))),
        TextButton(onPressed: () => Navigator.pop(ctx, 'bind'), child: const Text('绑定电池', style: TextStyle(color: Colors.black))),
      ],
    ));
    if (choice == 'bind') {
      var batterySN = await widget.openScanner();
      if (batterySN != null && batterySN.toUpperCase().startsWith('AD')) {
        var bindResult = await widget.api.bindBattery(realName, odUserId, batterySN, '2304');
        widget.showMsg(bindResult['code'] == '200' ? '成功' : '错误', bindResult['code'] == '200' ? '$realName绑定完成' : '绑定失败: ${bindResult['msg']}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('新租开电', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('输入手机号查询用户信息', style: TextStyle(color: Colors.grey.shade600)),
      const SizedBox(height: 24),
      TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: '请输入手机号码', prefixIcon: Icon(Icons.phone_outlined))),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: isLoading ? null : _query, child: isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('确认查询')),
    ]));
  }
}


class BatteryReturnPage extends StatefulWidget {
  final ApiClient api;
  final Function(String, String) showMsg;
  final Future<bool> Function(String, String) showConfirm;
  final Future<String?> Function() openScanner;
  const BatteryReturnPage({super.key, required this.api, required this.showMsg, required this.showConfirm, required this.openScanner});
  @override
  State<BatteryReturnPage> createState() => _BatteryReturnPageState();
}

class _BatteryReturnPageState extends State<BatteryReturnPage> {
  bool isLoading = false;

  Future<void> _scan() async {
    var batterySN = await widget.openScanner();
    if (batterySN == null || !batterySN.toUpperCase().startsWith('AD')) return;
    setState(() => isLoading = true);
    var result = await widget.api.queryUserList(batterySN, listType: '1');
    if (result['code'] == '200') {
      var userList = result['data']?['userList'] ?? [];
      if (userList.isEmpty) { widget.showMsg('提示', '未找到该电池对应的用户'); setState(() => isLoading = false); return; }
      await _doRecovery(userList[0]);
    }
    setState(() => isLoading = false);
  }

  Future<void> _doRecovery(Map<String, dynamic> user) async {
    var result = await widget.api.bindBattery(user['realName'], user['id'], user['batterySN'], '2305');
    if (result['code'] == '200') {
      var confirm = await widget.showConfirm('回收成功', '${user['realName']}${user['mobile']}电池归还回收成功，是否解绑用户？');
      if (confirm) {
        var unbindResult = await widget.api.unbindUser(user['id']);
        widget.showMsg(unbindResult['code'] == '200' ? '成功' : '错误', unbindResult['code'] == '200' ? '电池解绑完成' : '解绑失败: ${unbindResult['msg']}');
      }
    } else { widget.showMsg('错误', '回收失败: ${result['msg']}'); }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('电池退租', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('扫描电池二维码进行退租', style: TextStyle(color: Colors.grey.shade600)),
      const SizedBox(height: 24),
      Expanded(child: Center(child: GestureDetector(
        onTap: isLoading ? null : _scan,
        child: Container(width: 200, height: 200,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))]),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(isLoading ? Icons.hourglass_empty : Icons.qr_code_scanner, size: 64, color: Colors.black),
            const SizedBox(height: 16),
            Text(isLoading ? '处理中...' : '点击扫一扫', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ]),
        ),
      ))),
    ]));
  }
}

class RenewPage extends StatefulWidget {
  final ApiClient api;
  final Function(String, String) showMsg;
  final Future<int?> Function(String, String, {int defaultDays}) showDaysDialog;
  const RenewPage({super.key, required this.api, required this.showMsg, required this.showDaysDialog});
  @override
  State<RenewPage> createState() => _RenewPageState();
}

class _RenewPageState extends State<RenewPage> {
  final phoneController = TextEditingController();
  bool isLoading = false;

  Future<void> _query() async {
    var phone = phoneController.text.trim();
    if (phone.length != 11) { widget.showMsg('提示', '请输入正确的11位手机号'); return; }
    setState(() => isLoading = true);
    var result = await widget.api.queryUserList(phone, listType: '1');
    if (result['code'] == '200') {
      var userList = result['data']?['userList'] ?? [];
      if (userList.isEmpty) { widget.showMsg('提示', '未找到用户资料'); setState(() => isLoading = false); return; }
      var days = await widget.showDaysDialog('续租充值', '是否为${userList[0]['realName']}${userList[0]['mobile']}充值？');
      if (days != null) await _doRecharge(userList[0], days);
    }
    setState(() => isLoading = false);
  }

  Future<void> _doRecharge(Map<String, dynamic> user, int days) async {
    var poolResult = await widget.api.queryMealDaysInfo(user['mobile'], user['id']);
    if (poolResult['code'] != '200') { widget.showMsg('错误', '查询套餐池失败'); return; }
    var poolList = poolResult['data']?['mealPoolList'] ?? [];
    if (poolList.isEmpty) { widget.showMsg('错误', '没有可用套餐池'); return; }
    var result = await widget.api.sendMealToUser(user['id'], poolList[0]['poolId'], days.toString());
    widget.showMsg(result['code'] == '200' ? '成功' : '错误', result['code'] == '200' ? '${user['realName']}续租充值成功（$days天）' : '充值失败: ${result['msg']}');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('续租电池', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('输入手机号为用户续租充值', style: TextStyle(color: Colors.grey.shade600)),
      const SizedBox(height: 24),
      TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: '请输入手机号码', prefixIcon: Icon(Icons.phone_outlined))),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: isLoading ? null : _query, child: isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('确认查询')),
    ]));
  }
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});
  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  MobileScannerController controller = MobileScannerController();
  bool hasScanned = false;
  final manualController = TextEditingController();

  @override
  void dispose() { controller.dispose(); super.dispose(); }

  void _onDetect(BarcodeCapture capture) {
    if (hasScanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue != null) { hasScanned = true; Navigator.pop(context, barcode!.rawValue); }
  }

  void _manualInput() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('手动输入', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      content: TextField(controller: manualController, decoration: const InputDecoration(hintText: '请输入电池编号（AD开头）')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: Colors.grey))),
        TextButton(onPressed: () { Navigator.pop(ctx); Navigator.pop(context, manualController.text.trim()); }, child: const Text('确定', style: TextStyle(color: Colors.black))),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: const Text('扫描二维码'),
        actions: [IconButton(icon: const Icon(Icons.edit), onPressed: _manualInput)]),
      body: Stack(children: [
        MobileScanner(controller: controller, onDetect: _onDetect),
        Center(child: Container(width: 250, height: 250, decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(12)))),
        Positioned(bottom: 100, left: 0, right: 0, child: Center(child: Text('将二维码放入框内自动扫描', style: TextStyle(color: Colors.white.withOpacity(0.8))))),
      ]),
    );
  }
}

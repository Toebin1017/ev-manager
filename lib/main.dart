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
      title: '电动车管理系统',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
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
    'sType': '1906',
    'token': token ?? '',
    'Content-Type': 'application/json',
    'user-agent': 'Mozilla/5.0 (Linux; Android 9) AppleWebKit/537.36',
  };

  String generateSign(Map<String, dynamic> data) {
    var sorted = data.entries.where((e) => e.key != 'sign').toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    var signStr = sorted.map((e) => '${e.key}=${e.value}').join('&');
    return md5.convert(utf8.encode(signStr)).toString().toUpperCase();
  }

  Future<Map<String, dynamic>> login() async {
    var timestamp = DateTime.now().millisecondsSinceEpoch;
    var data = {
      'appVersion': '2.1.9', 'cid': cid, 'mobile': loginMobile,
      'password': loginPassword, 'smsCode': '', 'type': '3',
      'loginLat': '', 'loginLon': '', 'wxCode': '', 'iosId': '',
      'timeStamp': timestamp,
    };
    data['sign'] = generateSign(data);
    
    try {
      var resp = await http.post(
        Uri.parse('$baseUrl/adminService/api/login'),
        headers: headers,
        body: jsonEncode(data),
      );
      var result = jsonDecode(resp.body);
      if (result['code'] == '200') {
        token = result['data']?['token'] ?? '';
        return {'success': true, 'msg': '登录成功'};
      }
      return {'success': false, 'msg': result['msg'] ?? '登录失败'};
    } catch (e) {
      return {'success': false, 'msg': e.toString()};
    }
  }

  Future<Map<String, dynamic>> queryUserList(String sifting, {
    String listType = '1', String depositTypeId = '', String opeFlag = '',
    String userId = '', String batterySN = '', String mealRecovery = '', String opeType = '',
  }) async {
    var timestamp = DateTime.now().millisecondsSinceEpoch;
    var data = {
      'page': '1', 'limit': '10', 'sifting': sifting, 'listType': listType,
      'despositTypeId': depositTypeId, 'opeFlag': opeFlag, 'userId': userId,
      'batterySN': batterySN, 'mealRecovery': mealRecovery, 'opeType': opeType,
      'reason': '', 'status': '', 'timeStamp': timestamp,
    };
    data['sign'] = generateSign(data);
    
    try {
      var resp = await http.post(
        Uri.parse('$baseUrl/adminService/api/promter/queryUserList'),
        headers: headers, body: jsonEncode(data),
      );
      return jsonDecode(resp.body);
    } catch (e) {
      return {'code': '500', 'msg': e.toString()};
    }
  }

  Future<Map<String, dynamic>> userDepositOpe(String sifting, String userId, {
    String opeFlag = '1', String reason = '个人原因，不想用了',
    String listType = '0', String depositTypeId = '2310291606277978810',
  }) async {
    var timestamp = DateTime.now().millisecondsSinceEpoch;
    var data = {
      'page': opeFlag == '1' ? '1' : '2', 'limit': '10', 'sifting': sifting,
      'listType': listType, 'despositTypeId': depositTypeId, 'opeFlag': opeFlag,
      'userId': userId, 'batterySN': '', 'mealRecovery': '', 'opeType': '',
      'reason': reason, 'status': '', 'timeStamp': timestamp,
    };
    data['sign'] = generateSign(data);
    
    try {
      var resp = await http.post(
        Uri.parse('$baseUrl/adminService/api/promter/userDespositOpe'),
        headers: headers, body: jsonEncode(data),
      );
      return jsonDecode(resp.body);
    } catch (e) {
      return {'code': '500', 'msg': e.toString()};
    }
  }

  Future<Map<String, dynamic>> queryMealDaysInfo(String phone, String userId) async {
    var timestamp = DateTime.now().millisecondsSinceEpoch;
    var data = {
      'page': '1', 'limit': '10', 'inviteStatus': '', 'phone': phone,
      'pageFlag': '0', 'days': '30', 'flag': 1, 'userId': userId,
      'timeStamp': timestamp,
    };
    data['sign'] = generateSign(data);
    
    try {
      var resp = await http.post(
        Uri.parse('$baseUrl/adminService/api/promter/queryMealDaysInfo'),
        headers: headers, body: jsonEncode(data),
      );
      return jsonDecode(resp.body);
    } catch (e) {
      return {'code': '500', 'msg': e.toString()};
    }
  }
}


class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final api = ApiClient();
  final phoneController = TextEditingController();
  final batteryController = TextEditingController();
  final logs = <String>[];
  bool isLoggedIn = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _login();
  }

  void log(String msg) {
    setState(() {
      logs.add('[${DateTime.now().toString().substring(11, 19)}] $msg');
    });
  }

  Future<void> _login() async {
    setState(() => isLoading = true);
    var result = await api.login();
    setState(() {
      isLoggedIn = result['success'];
      isLoading = false;
    });
    log(result['msg']);
  }

  void showMsg(String title, String msg, {VoidCallback? onOk}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); onOk?.call(); },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void showConfirm(String title, String msg, VoidCallback onYes) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); onYes(); },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _queryUser() async {
    var phone = phoneController.text.trim();
    if (phone.length != 11) {
      showMsg('提示', '请输入正确的11位手机号');
      return;
    }
    log('查询手机号: $phone');
    setState(() => isLoading = true);
    
    var result = await api.queryUserList(phone, listType: '1');
    log('查询结果: ${jsonEncode(result)}');
    
    if (result['code'] == '200') {
      var userList = result['data']?['userList'] ?? [];
      if (userList.isNotEmpty) {
        var user = userList[0];
        showMsg('查询结果', '${user['mobile']}${user['realName']}已实名注册免押');
        setState(() => isLoading = false);
        return;
      }
      await _queryStep2(phone);
    }
    setState(() => isLoading = false);
  }

  Future<void> _queryStep2(String phone) async {
    var result = await api.queryUserList(phone, listType: '0',
        depositTypeId: '2310291606277978810', opeFlag: '1');
    log('第二步查询: ${jsonEncode(result)}');
    
    if (result['code'] == '200') {
      var userList = result['data']?['userList'] ?? [];
      if (userList.isEmpty) {
        showMsg('提示', '该手机号未注册');
        return;
      }
      var user = userList[0];
      if (user['realName'] == '未实名') {
        showMsg('提示', '该手机号已注册未实名');
        return;
      }
      await _doDepositOpe(phone, user['id']);
    }
  }

  Future<void> _doDepositOpe(String phone, String userId) async {
    var result = await api.userDepositOpe(phone, userId);
    log('免押结果: ${jsonEncode(result)}');
    
    if (result['code'] == '200') {
      showConfirm('免押成功', '免押成功，是否进行充值？', () => _doRecharge(phone, userId));
    } else {
      showMsg('错误', '免押失败: ${result['msg']}');
    }
  }

  Future<void> _doRecharge(String phone, String userId) async {
    var result = await api.queryMealDaysInfo(phone, userId);
    log('充值结果: ${jsonEncode(result)}');
    showMsg('结果', result['code'] == '200' ? '套餐充值成功' : '充值失败: ${result['msg']}');
  }

  Future<void> _openScanner() async {
    var result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (ctx) => const ScannerPage()),
    );
    if (result != null && result.isNotEmpty) {
      batteryController.text = result;
      _processBattery();
    }
  }

  Future<void> _processBattery() async {
    var batterySN = batteryController.text.trim();
    if (batterySN.isEmpty) {
      showMsg('提示', '请输入电池编号');
      return;
    }
    if (!batterySN.toUpperCase().startsWith('AD')) {
      showMsg('提示', '电池编号必须以AD开头');
      return;
    }
    log('电池编号: $batterySN');
    setState(() => isLoading = true);
    
    var result = await api.queryUserList(batterySN, listType: '1');
    log('查询结果: ${jsonEncode(result)}');
    
    if (result['code'] != '200') {
      showMsg('错误', '查询失败: ${result['msg']}');
      setState(() => isLoading = false);
      return;
    }
    
    var userList = result['data']?['userList'] ?? [];
    if (userList.isEmpty) {
      showMsg('提示', '未找到该电池对应的用户');
      setState(() => isLoading = false);
      return;
    }
    
    await _doBatteryRecovery(userList[0]);
    setState(() => isLoading = false);
  }

  Future<void> _doBatteryRecovery(Map<String, dynamic> user) async {
    var userId = user['id'];
    var batterySN = user['batterySN'];
    var realName = user['realName'];
    var mobile = user['mobile'];
    
    var result = await api.queryUserList(batterySN, listType: '1',
        userId: userId, batterySN: batterySN, mealRecovery: '1', opeType: '2305');
    log('回收结果: ${jsonEncode(result)}');
    
    if (result['code'] != '200') {
      showMsg('错误', '回收失败: ${result['msg']}');
      return;
    }
    
    showConfirm('回收成功', '$realName$mobile电池归还回收成功，是否解绑用户？',
        () => _doUnbind(userId));
  }

  Future<void> _doUnbind(String userId) async {
    var result = await api.userDepositOpe('', userId,
        opeFlag: '2', reason: '租户退租归还电池', listType: '1', depositTypeId: '');
    log('解绑结果: ${jsonEncode(result)}');
    showMsg('结果', result['code'] == '200' ? '电池解绑完成' : '解绑失败: ${result['msg']}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('电动车管理系统')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              color: isLoggedIn ? Colors.green[100] : Colors.red[100],
              child: Text(isLoggedIn ? '已登录' : '未登录', textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            const Text('功能①：新租开电', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: phoneController, keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: '请输入手机号码')),
            ElevatedButton(onPressed: isLoggedIn && !isLoading ? _queryUser : null,
                child: const Text('确认查询')),
            const SizedBox(height: 16),
            const Text('功能②：电池退租', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: batteryController,
                decoration: const InputDecoration(hintText: '输入电池编号或点击扫一扫')),
            Row(children: [
              Expanded(child: ElevatedButton(
                  onPressed: isLoggedIn && !isLoading ? _openScanner : null,
                  child: const Text('扫一扫'))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton(
                  onPressed: isLoggedIn && !isLoading ? _processBattery : null,
                  child: const Text('确认退租'))),
            ]),
            const SizedBox(height: 16),
            const Text('操作日志:', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.grey[200],
                child: ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (ctx, i) => Text(logs[i], style: const TextStyle(fontSize: 12)),
                ),
              ),
            ),
            if (isLoading) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
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

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (hasScanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue != null) {
      hasScanned = true;
      Navigator.pop(context, barcode!.rawValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫描二维码')),
      body: Stack(
        children: [
          MobileScanner(controller: controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 50, left: 0, right: 0,
            child: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

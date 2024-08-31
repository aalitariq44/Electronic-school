import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:to_users/login/login.dart';
import 'package:to_users/personal/personal_page.dart';
import 'package:to_users/students/home_student.dart';
import 'package:to_users/suggestions.dart';
import 'package:to_users/techers/home_techers.dart';

class CustomDrawer extends StatefulWidget {
  final String userUid;
  final String myName;
  final VoidCallback onLogout;

  const CustomDrawer({
    Key? key,
    required this.userUid,
    required this.onLogout,
    required this.myName,
  }) : super(key: key);

  @override
  _CustomDrawerState createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  List<Map<String, dynamic>> accounts = [];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _logoutAndSwitchAccount() async {
    // تسجيل الخروج من الحساب الحالي
    await FirebaseAuth.instance.signOut();
    await _removeCurrentAccount();

    // البحث عن حساب آخر مخزن
    final prefs = await SharedPreferences.getInstance();
    List<String>? accountsJsonList = prefs.getStringList('accounts');

    if (accountsJsonList != null && accountsJsonList.isNotEmpty) {
      // إذا وجدنا حسابات أخرى، نسجل الدخول بأول حساب
      Map<String, dynamic> nextAccount = json.decode(accountsJsonList.first);
      await _loginWithAccount(context, nextAccount);
    } else {
      // إذا لم نجد أي حسابات، ننتقل إلى صفحة تسجيل الدخول
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    }
  }

  Future<void> _loginWithAccount(
      BuildContext context, Map<String, dynamic> account) async {
    try {
      // قم بتسجيل الخروج من الحساب الحالي
      await FirebaseAuth.instance.signOut();

      // قم بتسجيل الدخول بالحساب الجديد
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: account['email'],
        password: account['password'],
      );

      // قم بتحديث الحساب الحالي في SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentAccount', json.encode(account));

      // انتقل إلى الصفحة المناسبة بناءً على نوع المستخدم
      if (account['userType'] == 'student') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePageStudents()),
        );
      } else if (account['userType'] == 'teacher') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePageTeachers()),
        );
      }
    } catch (e) {
      print('Error logging in with account: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تسجيل الدخول: $e')),
      );
    }
  }

  Future<void> _removeCurrentAccount() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? accountsJsonList = prefs.getStringList('accounts');

    if (accountsJsonList != null) {
      List<Map<String, dynamic>> accountsList = accountsJsonList
          .map((jsonString) => json.decode(jsonString) as Map<String, dynamic>)
          .toList();

      accountsList.removeWhere((account) => account['uid'] == widget.userUid);

      List<String> updatedAccountsJsonList =
          accountsList.map((account) => json.encode(account)).toList();

      await prefs.setStringList('accounts', updatedAccountsJsonList);
    }
  }

  Future<void> _loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? accountsJsonList = prefs.getStringList('accounts');
    print(
        '_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_');
    print('Retrieved accounts JSON List: $accountsJsonList');

    if (accountsJsonList != null && accountsJsonList.isNotEmpty) {
      setState(() {
        accounts = accountsJsonList.map((jsonString) {
          Map<String, dynamic> accountMap = json.decode(jsonString);
          print('Decoded account: $accountMap');
          return accountMap;
        }).toList();
        print('All decoded accounts: $accounts');
      });
      print(
          '_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_');
    } else {
      print('No accounts found or accounts list is empty');
    }
  }

  Widget _buildAccountTile(Map<String, dynamic> account) {
    bool isCurrentAccount = account['uid'] == widget.userUid;
    return ListTile(
      leading: FaIcon(
        FontAwesomeIcons.userCircle,
        color: isCurrentAccount ? Colors.blue : null,
      ),
      title: Text(
        account['email'] ?? 'بريد إلكتروني غير معروف',
        style: TextStyle(
          color: isCurrentAccount ? Colors.blue : null,
          fontWeight: isCurrentAccount ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        account['userType'] ?? 'غير محدد',
        style: TextStyle(
          color: isCurrentAccount ? Colors.blue.shade300 : null,
        ),
      ),
      tileColor: isCurrentAccount ? Colors.blue.withOpacity(0.1) : null,
      onTap: () {
        if (!isCurrentAccount) {
          _loginWithAccount(context, account);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue[700],
            ),
            child: Text(
              'الإعدادات',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          ListTile(
            title:
                Text('الحسابات', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ...accounts.map((account) => _buildAccountTile(account)).toList(),
          ListTile(
            leading: FaIcon(FontAwesomeIcons.userPlus),
            title: Text('إضافة حساب جديد'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LoginPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: FaIcon(FontAwesomeIcons.userCircle),
            title: Text('الملف الشخصي'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PersonalPage(
                    userUid: widget.userUid,
                    showGradesTab: 1,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: FaIcon(FontAwesomeIcons.lightbulb),
            title: Text('الاقتراحات'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SuggestionPage(
                    userUid: widget.userUid,
                    myName: widget.myName,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: FaIcon(FontAwesomeIcons.cogs),
            title: Text('إعدادات التطبيق'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: FaIcon(FontAwesomeIcons.infoCircle),
            title: Text('حول التطبيق'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: FaIcon(FontAwesomeIcons.questionCircle),
            title: Text('المساعدة'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: FaIcon(FontAwesomeIcons.signOutAlt),
            title: Text('تسجيل الخروج من الحساب الحالي'),
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('تأكيد تسجيل الخروج'),
                    content: Text(
                        'هل أنت متأكد أنك تريد تسجيل الخروج من هذا الحساب؟'),
                    actions: <Widget>[
                      TextButton(
                        child: Text('إلغاء'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: Text('تأكيد'),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await _logoutAndSwitchAccount();
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

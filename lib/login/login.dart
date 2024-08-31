import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:to_users/login/account_model.dart';
import 'package:to_users/login/user_type_check.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth = FirebaseAuth.instance;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _clearSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String email = _emailController.text.trim() + "@school.com";

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      // إنشاء كائن Account جديد
      Account newAccount = Account(
        email: email,
        password: _passwordController.text.trim(),
        uid: userCredential.user!.uid,
        userType: '', // سيتم تحديثه لاحقاً
        isInitialSetupDone: false,
      );

      // استرجاع القائمة الحالية للحسابات
      final prefs = await SharedPreferences.getInstance();
      List<String> accountsJson = prefs.getStringList('accounts') ?? [];
      List<Account> accounts = accountsJson
          .map((json) => Account.fromJson(jsonDecode(json)))
          .toList();

      // البحث عن الحساب الحالي في القائمة
      int existingIndex =
          accounts.indexWhere((account) => account.email == email);

      if (existingIndex != -1) {
        // تحديث الحساب الموجود
        accounts[existingIndex] = newAccount;
      } else {
        // إضافة الحساب الجديد إلى القائمة
        accounts.add(newAccount);
      }

      // تحويل القائمة إلى JSON وحفظها
      List<String> updatedAccountsJson =
          accounts.map((account) => jsonEncode(account.toJson())).toList();
      await prefs.setStringList('accounts', updatedAccountsJson);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => UserTypeCheck()),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'حدث خطأ ما')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue[700]!, Colors.blue[400]!],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      FontAwesomeIcons.graduationCap,
                      size: 80,
                      color: Colors.white,
                    ),
                    SizedBox(height: 30),
                    Text(
                      'مرحبًا بك في تطبيق المدرسة',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Cairo-Medium',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 40),
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailController,
                              textDirection: TextDirection.ltr,
                              decoration: InputDecoration(
                                labelText: 'اسم المستخدم',
                                prefixIcon: Icon(FontAwesomeIcons.user,
                                    color: Colors.blue[700]),
                                suffixIcon: Container(
                                  padding: EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 5),
                                  child: Text(
                                    '@school.com',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              keyboardType: TextInputType.text,
                            ),
                            SizedBox(height: 20),
                            TextFormField(
                              controller: _passwordController,
                              textDirection: TextDirection.ltr,
                              decoration: InputDecoration(
                                labelText: 'كلمة المرور',
                                prefixIcon: Icon(FontAwesomeIcons.lock,
                                    color: Colors.blue[700]),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? FontAwesomeIcons.eyeSlash
                                        : FontAwesomeIcons.eye,
                                    color: Colors.blue[700],
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              obscureText: _obscurePassword,
                            ),
                            SizedBox(height: 30),
                            _isLoading
                                ? CircularProgressIndicator()
                                : ElevatedButton(
                                    onPressed: _login,
                                    child: Text(
                                      'تسجيل الدخول',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontFamily: 'Cairo-Medium',
                                          color: Colors.white),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[700],
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 50, vertical: 15),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        // TODO: Implement forgot password functionality
                      },
                      child: Text(
                        'نسيت كلمة المرور؟',
                        style: TextStyle(
                            color: Colors.white, fontFamily: 'Cairo-Medium'),
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
}

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:to_users/login/account_model.dart';
import 'package:to_users/login/login.dart';
import 'package:to_users/students/home_student.dart';
import 'package:to_users/techers/home_techers.dart';

class UserTypeCheck extends StatefulWidget {
  @override
  _UserTypeCheckState createState() => _UserTypeCheckState();
}

class _UserTypeCheckState extends State<UserTypeCheck> {
  User? user = FirebaseAuth.instance.currentUser;
  Account? currentAccount;
  bool isLoading = true;

  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _checkInitialSetup();
  }

  Future<void> _checkInitialSetup() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> accountsJson = prefs.getStringList('accounts') ?? [];
    List<Account> accounts =
        accountsJson.map((json) => Account.fromJson(jsonDecode(json))).toList();

    // استخدام where بدلاً من firstWhere
    List<Account> matchingAccounts =
        accounts.where((account) => account.uid == user?.uid).toList();

    if (matchingAccounts.isNotEmpty) {
      currentAccount = matchingAccounts.first;
      if (currentAccount!.isInitialSetupDone) {
        _navigateToCorrectPage();
      } else {
        _fetchUserData();
      }
    } else {
      // إذا لم يتم العثور على الحساب، قم بإنشاء حساب جديد
      await _createNewAccount();
    }
  }

  Future<void> _createNewAccount() async {
    // قم بإنشاء حساب جديد باستخدام بيانات المستخدم الحالي
    currentAccount = Account(
      email: user!.email!,
      password: '', // يمكنك تعيين كلمة مرور افتراضية أو تركها فارغة
      uid: user!.uid,
      userType: '', // سيتم تحديثه لاحقًا
      isInitialSetupDone: false,
    );

    // قم بحفظ الحساب الجديد في SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> accountsJson = prefs.getStringList('accounts') ?? [];
    List<Account> accounts =
        accountsJson.map((json) => Account.fromJson(jsonDecode(json))).toList();
    accounts.add(currentAccount!);
    List<String> updatedAccountsJson =
        accounts.map((account) => jsonEncode(account.toJson())).toList();
    await prefs.setStringList('accounts', updatedAccountsJson);

    // استمر بجلب بيانات المستخدم
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (user != null) {
      try {
        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('userUid', isEqualTo: user!.uid)
            .get();

        if (!mounted) return;

        if (querySnapshot.docs.isNotEmpty) {
          var data = querySnapshot.docs.first;
          currentAccount!.userType = data['type'];

          if (currentAccount!.password == '00000000') {
            _showChangePasswordDialog();
          } else {
            await _setInitialSetupDone();
            _navigateToCorrectPage();
          }
        } else {
          _showErrorMessage('لم يتم العثور على مستخدم. اتصل بنا 07710995922');
        }
      } catch (e) {
        if (mounted) {
          _showErrorMessage('حدث خطأ أثناء تحميل البيانات: $e');
        }
      }
    } else {
      _showErrorMessage('المستخدم غير متصل.');
    }
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _setInitialSetupDone() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> accountsJson = prefs.getStringList('accounts') ?? [];
    List<Account> accounts =
        accountsJson.map((json) => Account.fromJson(jsonDecode(json))).toList();

    int index =
        accounts.indexWhere((account) => account.uid == currentAccount!.uid);
    if (index != -1) {
      accounts[index].isInitialSetupDone = true;
      accounts[index].userType = currentAccount!.userType;

      List<String> updatedAccountsJson =
          accounts.map((account) => jsonEncode(account.toJson())).toList();
      await prefs.setStringList('accounts', updatedAccountsJson);
    }
  }

  Future<void> _handleLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginPage()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      print("Error during logout: $e");
      _showErrorMessage("حدث خطأ أثناء تسجيل الخروج: $e");
    }
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('خطأ'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('حسنًا'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('تغيير كلمة المرور'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(labelText: 'كلمة المرور الجديدة'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال كلمة المرور الجديدة';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(labelText: 'تأكيد كلمة المرور'),
                  validator: (value) {
                    if (value != _newPasswordController.text) {
                      return 'كلمات المرور غير متطابقة';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('تغيير'),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _changePassword(_newPasswordController.text);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _changePassword(String newPassword) async {
    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: user!.email!,
        password: currentAccount!.password,
      );
      await user!.reauthenticateWithCredential(credential);

      await user!.updatePassword(newPassword);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({'password': newPassword});

      // تحديث كلمة المرور في SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> accountsJson = prefs.getStringList('accounts') ?? [];
      List<Account> accounts = accountsJson
          .map((json) => Account.fromJson(jsonDecode(json)))
          .toList();

      int index =
          accounts.indexWhere((account) => account.uid == currentAccount!.uid);
      if (index != -1) {
        accounts[index].password = newPassword;
        List<String> updatedAccountsJson =
            accounts.map((account) => jsonEncode(account.toJson())).toList();
        await prefs.setStringList('accounts', updatedAccountsJson);
      }

      Navigator.of(context).pop();
      _showSuccessMessage('تم تغيير كلمة المرور بنجاح');
      await _setInitialSetupDone();
      _navigateToCorrectPage();
    } catch (e) {
      print('خطأ في تغيير كلمة المرور: $e');
      String errorMessage = 'حدث خطأ أثناء تغيير كلمة المرور';
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'weak-password':
            errorMessage = 'كلمة المرور ضعيفة جدًا';
            break;
          case 'requires-recent-login':
            errorMessage =
                'يرجى تسجيل الخروج وإعادة تسجيل الدخول قبل تغيير كلمة المرور';
            break;
        }
      }
      _showErrorMessage(errorMessage);
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _navigateToCorrectPage() {
    if (!mounted) return;

    if (currentAccount!.userType == 'student') {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => HomePageStudents()));
    } else if (currentAccount!.userType == 'teacher') {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => HomePageTeachers()));
    } else {
      _showErrorMessage('نوع المستخدم غير معروف: ${currentAccount!.userType}');
      _handleLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('جاري التحميل'),
      ),
      body: Center(
        child: isLoading
            ? CircularProgressIndicator()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('تم التحقق من نوع المستخدم'),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _handleLogout,
                    child: Text('تسجيل الخروج'),
                  )
                ],
              ),
      ),
    );
  }
}

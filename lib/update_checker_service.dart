import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';

class UpdateCheckerService {
  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  final String currentVersion;

  UpdateCheckerService({required this.currentVersion});

  Future<void> initialize() async {
    await _remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: Duration.zero,
    ));
    await _remoteConfig.fetchAndActivate();
  }

  Future<bool> checkForUpdates() async {
    String latestVersion = _remoteConfig.getString('version');

    // طباعة الإصدار الحالي وآخر إصدار في console
    debugPrint('الإصدار الحالي للتطبيق: $currentVersion');
    debugPrint('آخر إصدار متوفر في Firebase Remote Config: $latestVersion');

    return latestVersion != currentVersion;
  }

  void showUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // منع الإغلاق بالنقر خارج النافذة
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false, // منع الخروج بزر الرجوع
          child: AlertDialog(
            title: Text('تحديث'),
            content: Text(
                'هناك إصدار جديد من التطبيق متاح. يجب عليك التحديث للاستمرار.'),
            actions: <Widget>[
              TextButton(
                child: Text('تحديث الآن'),
                onPressed: () {
                  // هنا يمكنك إضافة الكود لفتح متجر التطبيقات أو تنزيل التحديث
                  // مثال:
                  // launchUrl(Uri.parse('https://play.google.com/store/apps/details?id=your.app.id'));

                  // لا تغلق النافذة هنا، اتركها مفتوحة حتى يتم التحديث
                  // يمكنك إضافة منطق للتحقق من اكتمال التحديث قبل إغلاق النافذة
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

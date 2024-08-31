import 'package:flutter/material.dart';

class GifPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('عرض صورة GIF'),
      ),
      body: Center(
        child: Image.asset(
          'images/loading.gif',
          width: 300, // يمكنك تعديل العرض حسب الحاجة
          height: 300, // يمكنك تعديل الارتفاع حسب الحاجة
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
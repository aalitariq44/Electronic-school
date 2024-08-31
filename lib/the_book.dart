import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class ClassesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[700],
        title: Text(
          'الصفوف الدراسية',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Cairo-Medium',
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: FaIcon(FontAwesomeIcons.arrowRight, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[700]!, Colors.blue[100]!],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionTitle('المرحلة الابتدائية'),
                _buildButtonGroup(context, [
                  'الأول ابتدائي',
                  'الثاني ابتدائي',
                  'الثالث ابتدائي',
                  'الرابع ابتدائي',
                  'الخامس ابتدائي',
                  'السادس ابتدائي',
                ]),
                SizedBox(height: 20),
                _buildSectionTitle('المرحلة المتوسطة'),
                _buildButtonGroup(context, [
                  'الأول متوسط',
                  'الثاني متوسط',
                  'الثالث متوسط',
                ]),
                SizedBox(height: 20),
                _buildSectionTitle('المرحلة الإعدادية - العلمي'),
                _buildButtonGroup(context, [
                  'الرابع العلمي',
                  'الخامس العلمي',
                  'السادس العلمي',
                ]),
                SizedBox(height: 20),
                _buildSectionTitle('المرحلة الإعدادية - الأدبي'),
                _buildButtonGroup(context, [
                  'الرابع الأدبي',
                  'الخامس الأدبي',
                  'السادس الأدبي',
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontFamily: 'Cairo-Medium',
        ),
      ),
    );
  }

  Widget _buildButtonGroup(BuildContext context, List<String> classNames) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: classNames.map((className) {
        return ElevatedButton(
          onPressed: () => _openClassFolder(context, className),
          child: Text(
            className,
            style: TextStyle(fontFamily: 'Cairo-Medium'),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 5,
          ),
        );
      }).toList(),
    );
  }

  void _openClassFolder(BuildContext context, String className) {
    String folderName;
    switch (className) {
      case 'الأول ابتدائي':
        folderName = 'th1';
        break;
      case 'الثاني ابتدائي':
        folderName = 'th2';
        break;
      case 'الثالث ابتدائي':
        folderName = 'th3';
        break;
      case 'الرابع ابتدائي':
        folderName = 'th4';
        break;
      case 'الخامس ابتدائي':
        folderName = 'th5';
        break;
      case 'السادس ابتدائي':
        folderName = 'th6';
        break;
      case 'الأول متوسط':
        folderName = 'th7';
        break;
      case 'الثاني متوسط':
        folderName = 'th8';
        break;
      case 'الثالث متوسط':
        folderName = 'th9';
        break;
      case 'الرابع العلمي':
        folderName = 'th10';
        break;
      case 'الخامس العلمي':
        folderName = 'th11';
        break;
      case 'السادس العلمي':
        folderName = 'th12';
        break;
      case 'الرابع الأدبي':
        folderName = 'th13';
        break;
      case 'الخامس الأدبي':
        folderName = 'th14';
        break;
      case 'السادس الأدبي':
        folderName = 'th15';
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('لم يتم تعريف مجلد لهذا الصف')),
        );
        return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            FilesPage(folderName: folderName, className: className),
      ),
    );
  }
}

class FilesPage extends StatelessWidget {
  final String folderName;
  final String className;
  final FirebaseStorage storage = FirebaseStorage.instance;

  FilesPage({Key? key, required this.folderName, required this.className})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[700],
        title: Text(
          'ملفات $className',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Cairo-Medium',
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: FaIcon(FontAwesomeIcons.arrowRight, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[700]!, Colors.blue[100]!],
          ),
        ),
        child: FutureBuilder<ListResult>(
          future: storage.ref('books/$folderName').listAll(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: Colors.white));
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'حدث خطأ: ${snapshot.error}',
                  style: TextStyle(color: Colors.white, fontFamily: 'Cairo-Medium'),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.items.isEmpty) {
              return Center(
                child: Text(
                  'لا توجد ملفات في هذا المجلد',
                  style: TextStyle(color: Colors.white, fontFamily: 'Cairo-Medium'),
                ),
              );
            }

            return ListView.builder(
              itemCount: snapshot.data!.items.length,
              itemBuilder: (context, index) {
                Reference ref = snapshot.data!.items[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    title: Text(
                      ref.name,
                      style: TextStyle(fontFamily: 'Cairo-Medium'),
                    ),
                    leading: FaIcon(FontAwesomeIcons.filePdf, color: Colors.red),
                    trailing: FaIcon(FontAwesomeIcons.download, color: Colors.blue[700]),
                    onTap: () => _downloadAndOpenPDF(context, ref),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _downloadAndOpenPDF(BuildContext context, Reference ref) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${ref.name}');

    if (await file.exists()) {
      _openPDF(file.path);
    } else {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return DownloadDialog(ref: ref, file: file);
          },
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تنزيل الملف: $e')),
        );
      }
    }
  }

  void _openPDF(String filePath) async {
    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done) {
      print('حدث خطأ أثناء فتح الملف: ${result.message}');
    }
  }
}

class DownloadDialog extends StatefulWidget {
  final Reference ref;
  final File file;

  DownloadDialog({required this.ref, required this.file});

  @override
  _DownloadDialogState createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<DownloadDialog> {
  double _progress = 0;
  late DownloadTask _downloadTask;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    _downloadTask = widget.ref.writeToFile(widget.file);
    _downloadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
      setState(() {
        _progress = snapshot.bytesTransferred / snapshot.totalBytes;
      });
    }, onError: (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تنزيل الملف: $e')),
      );
    });

    try {
      await _downloadTask;
      Navigator.of(context).pop();
      _openPDF(widget.file.path);
    } catch (e) {
      // تم التعامل مع الخطأ في onError أعلاه
    }
  }

  void _openPDF(String filePath) async {
    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done) {
      print('حدث خطأ أثناء فتح الملف: ${result.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'جاري تنزيل الملف',
        style: TextStyle(fontFamily: 'Cairo-Medium'),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(value: _progress),
          SizedBox(height: 16),
          Text(
            '${(_progress * 100).toStringAsFixed(0)}%',
            style: TextStyle(fontFamily: 'Cairo-Medium'),
          ),
        ],
      ),
    );
  }
}
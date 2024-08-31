import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'all_notes.dart';

class NotesPage extends StatefulWidget {
  final DocumentSnapshot? note;

  NotesPage({this.note});

  @override
  _NotesPageState createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late bool isEditing;

  @override
  void initState() {
    super.initState();
    isEditing = widget.note != null;
    if (isEditing) {
      _titleController.text = widget.note!['title'];
      _contentController.text = widget.note!['content'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'تعديل ملاحظة' : 'ملاحظة جديدة',
          style: TextStyle(fontFamily: 'Cairo-Medium'),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        actions: [
          IconButton(
            icon: FaIcon(FontAwesomeIcons.save),
            onPressed: _saveNote,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[700]!, Colors.blue[50]!],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'العنوان',
                      labelStyle: TextStyle(
                        fontFamily: 'Cairo-Medium',
                        color: Colors.blue[700],
                      ),
                      border: InputBorder.none,
                      icon: FaIcon(FontAwesomeIcons.heading,
                          color: Colors.blue[700]),
                    ),
                    style: TextStyle(
                      fontFamily: 'Cairo-Medium',
                      fontSize: 18,
                      color: Colors.blue[900],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16.0),
              Expanded(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _contentController,
                      decoration: InputDecoration(
                        hintText: 'اكتب هنا ملاحظاتك',
                        hintStyle: TextStyle(
                          fontFamily: 'Cairo-Medium',
                          color: Colors.grey[400],
                        ),
                        border: InputBorder.none,
                      ),
                      maxLines: null,
                      expands: true,
                      style: TextStyle(
                        fontFamily: 'Cairo-Medium',
                        fontSize: 16,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveNote() async {
    String title = _titleController.text.trim();
    String content = _contentController.text.trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لا يمكن حفظ ملاحظة فارغة',
              style: TextStyle(fontFamily: 'Cairo-Medium')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String uid = _auth.currentUser?.uid ?? 'unknown';
    DateTime now = DateTime.now();

    if (title.isEmpty) {
      title = content.length > 15 ? content.substring(0, 15) : content;
    }

    try {
      if (isEditing) {
        await FirebaseFirestore.instance
            .collection('notes')
            .doc(widget.note!.id)
            .update({
          'title': title,
          'content': content,
          'date': now,
          'uid': uid,
        });
      } else {
        await FirebaseFirestore.instance.collection('notes').add({
          'title': title,
          'content': content,
          'date': now,
          'uid': uid,
        });
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => NotesListPage()),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حفظ الملاحظة بنجاح',
              style: TextStyle(fontFamily: 'Cairo-Medium')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error saving note: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء حفظ الملاحظة',
              style: TextStyle(fontFamily: 'Cairo-Medium')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

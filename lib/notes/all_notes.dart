import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import 'notes_write.dart';

class NotesListPage extends StatefulWidget {
  @override
  _NotesListPageState createState() => _NotesListPageState();
}

class _NotesListPageState extends State<NotesListPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final DateFormat _timeFormat = DateFormat('hh:mm a');

  String _formatDate(DateTime dateTime) {
    return '${_dateFormat.format(dateTime)}\n${_timeFormat.format(dateTime)}';
  }

  @override
  Widget build(BuildContext context) {
    print('User UID: ${_auth.currentUser?.uid}');

    return Scaffold(
      appBar: AppBar(
        title: Text('ملاحظاتي', style: TextStyle(fontFamily: 'Cairo-Medium')),
        backgroundColor: Colors.blue[700],
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[700]!, Colors.blue[50]!],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('notes')
              .where('uid', isEqualTo: _auth.currentUser?.uid)
              .orderBy('date', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              print('Error: ${snapshot.error}');
              return Center(child: Text('حدث خطأ ما'));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              print('No notes found');
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FaIcon(FontAwesomeIcons.notesMedical, size: 50, color: Colors.white),
                    SizedBox(height: 20),
                    Text(
                      'لا توجد ملاحظات',
                      style: TextStyle(fontSize: 18, color: Colors.white, fontFamily: 'Cairo-Medium'),
                    ),
                  ],
                ),
              );
            }

            final notes = snapshot.data!.docs;
            print('Notes count: ${notes.length}');

            return ListView.builder(
              itemCount: notes.length,
              itemBuilder: (context, index) {
                var note = notes[index];
                var title = note['title'];
                var content = note['content'];
                var date = (note['date'] as Timestamp).toDate();
                _formatDate(date);

                String truncatedContent = content.length > 100
                    ? content.substring(0, 100) + '...'
                    : content;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => NotesPage(note: note)),
                    );
                  },
                  child: Card(
                    margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    color: Colors.white.withOpacity(0.9),
                    child: Stack(
                      children: [
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  FaIcon(FontAwesomeIcons.stickyNote, color: Colors.blue[700], size: 20),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        fontFamily: 'Cairo-Medium',
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Text(
                                truncatedContent,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  fontFamily: 'Cairo-Medium',
                                ),
                              ),
                              SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  FaIcon(FontAwesomeIcons.clock, color: Colors.grey[500], size: 14),
                                  Text(
                                    '${_dateFormat.format(date)} ${_timeFormat.format(date)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                      fontFamily: 'Cairo-Medium',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: IconButton(
                            icon: FaIcon(
                              FontAwesomeIcons.trashAlt,
                              color: Colors.red[400],
                              size: 20,
                            ),
                            onPressed: () {
                              _showDeleteConfirmation(note.id);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NotesPage(note: null)),
          );
        },
        child: FaIcon(FontAwesomeIcons.plus),
        backgroundColor: Colors.blue[700],
      ),
    );
  }

  void _showDeleteConfirmation(String noteId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حذف الملاحظة', style: TextStyle(fontFamily: 'Cairo-Medium')),
        content: Text('هل أنت متأكد من أنك تريد حذف هذه الملاحظة؟', style: TextStyle(fontFamily: 'Cairo-Medium')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('إلغاء', style: TextStyle(color: Colors.blue[700], fontFamily: 'Cairo-Medium')),
          ),
          TextButton(
            onPressed: () {
              _deleteNote(noteId);
              Navigator.of(context).pop();
            },
            child: Text('حذف', style: TextStyle(color: Colors.red, fontFamily: 'Cairo-Medium')),
          ),
        ],
      ),
    );
  }

  void _deleteNote(String noteId) {
    FirebaseFirestore.instance
        .collection('notes')
        .doc(noteId)
        .delete()
        .then((_) {
      print('Note deleted successfully');
    }).catchError((error) {
      print('Error deleting note: $error');
    });
  }
}
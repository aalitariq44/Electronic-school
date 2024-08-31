import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

class TasksPage extends StatefulWidget {
  @override
  _TasksPageState createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _truncateDetails(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('مهامي', style: TextStyle(fontFamily: 'Cairo-Medium')),
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
          stream: _firestore
              .collection('tasks')
              .where('uid', isEqualTo: _auth.currentUser?.uid)
              .orderBy('date', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              if (snapshot.error.toString().contains('FAILED_PRECONDITION')) {
                return Center(
                    child: Text('الفهرس قيد الإنشاء، يرجى الانتظار...',
                        style: TextStyle(fontFamily: 'Cairo-Medium')));
              }
              return Center(
                  child: Text('حدث خطأ ما: ${snapshot.error}',
                      style: TextStyle(fontFamily: 'Cairo-Medium')));
            }

            final tasks = snapshot.data?.docs ?? [];

            if (tasks.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FaIcon(FontAwesomeIcons.tasks,
                        size: 50, color: Colors.white),
                    SizedBox(height: 20),
                    Text('لا توجد مهام حالياً',
                        style: TextStyle(
                            fontFamily: 'Cairo-Medium',
                            color: Colors.white,
                            fontSize: 18)),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView.builder(
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  final date =
                      (task['date'] as Timestamp?)?.toDate() ?? DateTime.now();
                  final formattedDate =
                      DateFormat('yyyy-MM-dd hh:mm a').format(date);
                  final truncatedDetails =
                      _truncateDetails(task['details'] ?? '', 100);

                  return GestureDetector(
                    onTap: () => _showEditTaskDialog(context, task),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                      elevation: 4.0,
                      margin: EdgeInsets.symmetric(vertical: 8.0),
                      color: Colors.white.withOpacity(0.9),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    task['title'],
                                    style: TextStyle(
                                      fontSize: 18.0,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Cairo-Medium',
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: FaIcon(
                                        task['isCompleted']
                                            ? FontAwesomeIcons.checkCircle
                                            : FontAwesomeIcons.circle,
                                        color: task['isCompleted']
                                            ? Colors.green
                                            : Colors.grey,
                                      ),
                                      onPressed: () {
                                        _firestore
                                            .collection('tasks')
                                            .doc(task.id)
                                            .update({
                                          'isCompleted': !task['isCompleted'],
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: FaIcon(FontAwesomeIcons.trashAlt,
                                          color: Colors.red[400]),
                                      onPressed: () {
                                        _deleteTask(task.id);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 8.0),
                            Text(
                              truncatedDetails,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14.0,
                                fontFamily: 'Cairo-Medium',
                              ),
                            ),
                            SizedBox(height: 8.0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                FaIcon(FontAwesomeIcons.clock,
                                    size: 12, color: Colors.grey[600]),
                                SizedBox(width: 4),
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12.0,
                                    fontFamily: 'Cairo-Medium',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskDialog(context),
        child: FaIcon(FontAwesomeIcons.plus),
        backgroundColor: Colors.blue[700],
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    final titleController = TextEditingController();
    final detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('إضافة مهمة جديدة',
              style: TextStyle(fontFamily: 'Cairo-Medium')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'عنوان المهمة',
                  labelStyle: TextStyle(fontFamily: 'Cairo-Medium'),
                ),
              ),
              TextField(
                controller: detailsController,
                decoration: InputDecoration(
                  labelText: 'تفاصيل المهمة',
                  labelStyle: TextStyle(fontFamily: 'Cairo-Medium'),
                ),
                maxLines: 4,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child:
                  Text('إلغاء', style: TextStyle(fontFamily: 'Cairo-Medium')),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                final details = detailsController.text.trim();

                if (title.isNotEmpty) {
                  _firestore.collection('tasks').add({
                    'title': title,
                    'details': details.isNotEmpty ? details : '',
                    'date': FieldValue.serverTimestamp(),
                    'isCompleted': false,
                    'uid': _auth.currentUser?.uid,
                  });
                }

                Navigator.of(context).pop();
              },
              child:
                  Text('إضافة', style: TextStyle(fontFamily: 'Cairo-Medium')),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]),
            ),
          ],
        );
      },
    );
  }

  void _showEditTaskDialog(BuildContext context, DocumentSnapshot task) {
    final titleController = TextEditingController(text: task['title']);
    final detailsController = TextEditingController(text: task['details']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('تعديل المهمة',
              style: TextStyle(fontFamily: 'Cairo-Medium')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'عنوان المهمة',
                  labelStyle: TextStyle(fontFamily: 'Cairo-Medium'),
                ),
              ),
              TextField(
                controller: detailsController,
                decoration: InputDecoration(
                  labelText: 'تفاصيل المهمة',
                  labelStyle: TextStyle(fontFamily: 'Cairo-Medium'),
                ),
                maxLines: 4,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child:
                  Text('إلغاء', style: TextStyle(fontFamily: 'Cairo-Medium')),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                final details = detailsController.text.trim();

                if (title.isNotEmpty) {
                  _firestore.collection('tasks').doc(task.id).update({
                    'title': title,
                    'details': details.isNotEmpty ? details : '',
                  });
                }

                Navigator.of(context).pop();
              },
              child: Text('حفظ التغييرات',
                  style: TextStyle(fontFamily: 'Cairo-Medium')),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]),
            ),
          ],
        );
      },
    );
  }

  void _deleteTask(String taskId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
              Text('حذف المهمة', style: TextStyle(fontFamily: 'Cairo-Medium')),
          content: Text('هل أنت متأكد أنك تريد حذف هذه المهمة؟',
              style: TextStyle(fontFamily: 'Cairo-Medium')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child:
                  Text('إلغاء', style: TextStyle(fontFamily: 'Cairo-Medium')),
            ),
            ElevatedButton(
              onPressed: () {
                _firestore.collection('tasks').doc(taskId).delete();
                Navigator.of(context).pop();
              },
              child: Text('حذف', style: TextStyle(fontFamily: 'Cairo-Medium')),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        );
      },
    );
  }
}

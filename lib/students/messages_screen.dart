import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MessagesScreen extends StatefulWidget {
  final String subject;

  MessagesScreen({required this.subject});

  @override
  _MessagesScreenState createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  User? user = FirebaseAuth.instance.currentUser;
  String _studentGrade = '';
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStudentGrade();
  }

  Future<void> _fetchStudentGrade() async {
    if (user != null) {
      try {
        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('userUid', isEqualTo: user!.uid)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          var data = querySnapshot.docs.first.data() as Map<String, dynamic>;
          setState(() {
            _studentGrade = data['grade'];
            fetchData(); // تأكد من استدعاء fetchData بعد الحصول على _studentGrade
          });
        }
      } catch (e) {
        print("Error fetching student grade: $e");
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void fetchData() async {
    if (_studentGrade.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return; // تحقق من أن _studentGrade ليس فارغًا
    }

    CollectionReference channels =
        FirebaseFirestore.instance.collection('Channels');

    QuerySnapshot querySnapshot = await channels
        .where('Subject', isEqualTo: widget.subject)
        .where('stage', isEqualTo: _studentGrade)
        .get();

    if (querySnapshot.docs.isEmpty) {
      print('لا توجد بيانات لـ ${widget.subject}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لا توجد بيانات لـ ${widget.subject}')),
      );
    } else {
      List<Map<String, dynamic>> messages = [];
      for (var doc in querySnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        DateTime dateTime = (data['date'] as Timestamp).toDate(); // تحويل Timestamp إلى DateTime
        String formattedDate = DateFormat('yyyy-MM-dd – kk:mm').format(dateTime); // تحويل DateTime إلى String
        String period = dateTime.hour < 12 ? 'صباحاً' : 'مساءً'; // إضافة صباحاً أو مساءً
        messages.add({
          ...data,
          'date': '$formattedDate $period',
        });

        // تحديث الوثيقة لتسجيل قراءة البيانات من قبل المستخدم الحالي
        await doc.reference.update({
          'readBy': FieldValue.arrayUnion([user!.uid]),
        });
      }

      messages.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String)); // ترتيب الرسائل حسب التاريخ

      setState(() {
        _messages = messages;
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subject + " " + _studentGrade),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _messages.isEmpty
              ? Center(child: Text('لا توجد رسائل لعرضها'))
              : ListView.builder(
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    var message = _messages[index];
                    return Container(
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                          bottomRight: Radius.circular(0),
                          bottomLeft: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message['messages'],
                            style: const TextStyle(fontSize: 18, color: Colors.black),
                          ),
                          Text(
                            message['date'],
                            style: const TextStyle(fontSize: 10, color: Colors.black),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

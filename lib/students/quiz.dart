import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

class Quiz extends StatefulWidget {
  final String schoolId;
  final String myUid;

  const Quiz({super.key, required this.schoolId, required this.myUid});

  @override
  State<Quiz> createState() => _QuizState();

  // New static method to check for unread grades
  static Future<bool> checkUnreadGrades(String schoolId, String myUid) async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('grades')
        .doc(schoolId)
        .collection('GradesQuizMonthly')
        .where('grades.$myUid.isSeen', isEqualTo: false)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }
}

class _QuizState extends State<Quiz> {
  String _formatDateTime(dynamic dateTime) {
    if (dateTime is Timestamp) {
      DateTime dt = dateTime.toDate();
      String formattedDate = DateFormat('yyyy/MM/dd').format(dt);
      String formattedTime = DateFormat('hh:mm a').format(dt);
      formattedTime = formattedTime.replaceAll('AM', 'ص').replaceAll('PM', 'م');
      return '$formattedDate $formattedTime';
    } else if (dateTime is String) {
      try {
        DateTime dt = DateTime.parse(dateTime);
        String formattedDate = DateFormat('yyyy/MM/dd').format(dt);
        String formattedTime = DateFormat('hh:mm a').format(dt);
        formattedTime =
            formattedTime.replaceAll('AM', 'ص').replaceAll('PM', 'م');
        return '$formattedDate $formattedTime';
      } catch (e) {
        return dateTime;
      }
    }
    return 'تاريخ غير معروف';
  }

  Future<void> _updateIsSeen(String docId) async {
    await FirebaseFirestore.instance
        .collection('grades')
        .doc(widget.schoolId)
        .collection('GradesQuizMonthly')
        .doc(docId)
        .update({
      'grades.${widget.myUid}.isSeen': true,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('درجات الاختبار الشهري والكوز'),
        backgroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.indigo.shade300, Colors.indigo.shade100],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('grades')
              .doc(widget.schoolId)
              .collection('GradesQuizMonthly')
              .where('grades.${widget.myUid}.degree', isNotEqualTo: '')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.indigo));
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'حدث خطأ: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red, fontSize: 18),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  'لا توجد درجات متاحة',
                  style: TextStyle(color: Colors.indigo, fontSize: 18),
                ),
              );
            }

            return ListView.builder(
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var doc = snapshot.data!.docs[index];
                var data = doc.data() as Map<String, dynamic>;
                var gradeData =
                    (data['grades']?[widget.myUid] as Map<String, dynamic>?) ??
                        {};
                var grade = gradeData['degree'] as String? ?? 'غير متوفر';
                var isSeen = gradeData['isSeen'] as bool? ?? false;

                if (!isSeen) {
                  // Update isSeen to true
                  _updateIsSeen(doc.id);
                }

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: Colors.indigo,
                        child: FaIcon(
                          _getSubjectIcon(data['subject'] ?? ''),
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        'المادة: ${data['subject'] ?? 'غير محدد'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.indigo,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _buildInfoRow(FontAwesomeIcons.bookOpen,
                              'العنوان: ${data['degreeTitle'] ?? 'غير محدد'}'),
                          _buildInfoRow(FontAwesomeIcons.graduationCap,
                              'الصف: ${data['grade'] ?? 'غير محدد'}  ${data['division'] ?? ''}'),
                          _buildInfoRow(FontAwesomeIcons.calendarAlt,
                              'التاريخ والوقت: ${_formatDateTime(data['time'])}'),
                          _buildInfoRow(
                            FontAwesomeIcons.star,
                            'الدرجة: $grade من ${data['totalGrade']}',
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          FaIcon(icon, size: 16, color: Colors.indigo.shade300),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSubjectIcon(String subject) {
    switch (subject.toLowerCase()) {
      case 'رياضيات':
        return FontAwesomeIcons.calculator;
      case 'علوم':
        return FontAwesomeIcons.flask;
      case 'لغة عربية':
        return FontAwesomeIcons.language;
      case 'لغة إنجليزية':
        return FontAwesomeIcons.earthAmericas;
      case 'تاريخ':
        return FontAwesomeIcons.landmark;
      case 'جغرافيا':
        return FontAwesomeIcons.globe;
      default:
        return FontAwesomeIcons.book;
    }
  }
}

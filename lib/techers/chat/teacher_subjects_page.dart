import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:to_users/techers/chat/chat.dart';

class TeacherSubjectsPage extends StatefulWidget {
  final String schoolId;
  const TeacherSubjectsPage({Key? key, required this.schoolId})
      : super(key: key);
  @override
  _TeacherSubjectsPageState createState() => _TeacherSubjectsPageState();
}

class _TeacherSubjectsPageState extends State<TeacherSubjectsPage> {
  User? user = FirebaseAuth.instance.currentUser;
  Map<String, Map<String, List<String>>> gradesAndSubjects = {};

  final List<String> orderedGrades = [
    'الاول الابتدائي',
    'الثاني الابتدائي',
    'الثالث الابتدائي',
    'الرابع الابتدائي',
    'الخامس الابتدائي',
    'السادس الابتدائي',
    'الاول المتوسط',
    'الثاني المتوسط',
    'الثالث المتوسط',
    'الرابع العلمي',
    'الرابع الادبي',
    'الخامس العلمي',
    'الخامس الادبي',
    'السادس العلمي',
    'السادس الادبي'
  ];

  @override
  void initState() {
    super.initState();
    _fetchGradesAndSubjects();
  }

  Future<void> _fetchGradesAndSubjects() async {
    if (user != null) {
      try {
        DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();

        if (docSnapshot.exists) {
          var data = docSnapshot.data() as Map<String, dynamic>;
          setState(() {
            gradesAndSubjects =
                (data['gradesAndSubjects'] as Map<String, dynamic>).map(
              (grade, sections) => MapEntry(
                grade,
                (sections as Map<String, dynamic>).map(
                  (section, subjects) => MapEntry(
                    section,
                    List<String>.from(subjects),
                  ),
                ),
              ),
            );
          });
        }
      } catch (e) {
        print("Error fetching grades and subjects: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var sortedGrades = orderedGrades
        .where((grade) => gradesAndSubjects.containsKey(grade))
        .toList();
    var unsortedGrades = gradesAndSubjects.keys
        .where((grade) => !orderedGrades.contains(grade))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('صفوف ومواد المدرس'),
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
        child: gradesAndSubjects.isNotEmpty
            ? ListView(
                padding: EdgeInsets.all(16),
                children: [
                  ...sortedGrades.expand((grade) => _buildGradeWidgets(grade)),
                  ...unsortedGrades
                      .expand((grade) => _buildGradeWidgets(grade)),
                ],
              )
            : Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
    );
  }

  List<Widget> _buildGradeWidgets(String grade) {
    var sections = gradesAndSubjects[grade]!;
    return [
      Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          grade,
          style: TextStyle(
              fontSize: 20, fontFamily: 'Cairo-Medium', color: Colors.white),
        ),
      ),
      ...sections.entries.expand((sectionEntry) {
        String section = sectionEntry.key;
        List<String> subjects = sectionEntry.value;
        return subjects.map((subject) => Card(
              elevation: 4,
              margin: EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[700],
                  child: FaIcon(_getSubjectIcon(subject),
                      color: Colors.white, size: 20),
                ),
                title: Text('$section - $subject',
                    style: TextStyle(
                      fontFamily: 'Cairo-Medium',
                    )),
                subtitle: Text(grade),
                trailing:
                    Icon(Icons.arrow_forward_ios, color: Colors.blue[700]),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatPage(
                        grade: grade,
                        subject: subject,
                        division: section,
                        schoolId: widget.schoolId,
                      ),
                    ),
                  );
                },
              ),
            ));
      }).toList(),
    ];
  }

  IconData _getSubjectIcon(String subject) {
    switch (subject.toLowerCase()) {
      case 'القراءة':
        return FontAwesomeIcons.bookOpen;
      case 'الرياضيات':
        return FontAwesomeIcons.calculator;
      case 'الإسلامية':
        return FontAwesomeIcons.mosque;
      case 'اللغة العربية':
        return FontAwesomeIcons.language;
      case 'الاجتماعيات':
        return FontAwesomeIcons.users;
      case 'العلوم':
        return FontAwesomeIcons.flask;
      case 'الفيزياء':
        return FontAwesomeIcons.atom;
      case 'الكيمياء':
        return FontAwesomeIcons.vial;
      case 'الاحياء':
        return FontAwesomeIcons.dna;
      case 'الفلسفة':
        return FontAwesomeIcons.brain;
      case 'علم الاجتماع':
        return FontAwesomeIcons.userFriends;
      case 'التاريخ':
        return FontAwesomeIcons.landmark;
      case 'الجغرافية':
        return FontAwesomeIcons.globe;
      case 'الاقتصاد':
        return FontAwesomeIcons.chartLine;
      case 'اللغة الإنجليزية':
        return FontAwesomeIcons.language;
      default:
        return FontAwesomeIcons.book;
    }
  }
}

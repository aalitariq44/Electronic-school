import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:to_users/techers/grads/models/1234.dart';
import 'package:to_users/techers/grads/models/56.dart';
import 'package:to_users/techers/grads/models/secondary_grades.dart';
import 'package:to_users/techers/grads/quiz.dart';

class TeacherSubjectsPageGrades extends StatefulWidget {
  final String DegreeType;
  final String HideAppBar;
  final String myUid;

  const TeacherSubjectsPageGrades(
      {super.key,
      required this.DegreeType,
      required this.HideAppBar,
      required this.myUid});
  @override
  _TeacherSubjectsPageGradesState createState() =>
      _TeacherSubjectsPageGradesState();
}

class _TeacherSubjectsPageGradesState extends State<TeacherSubjectsPageGrades> {
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
    return Scaffold(
      appBar: widget.HideAppBar == '1'
          ? AppBar(
              title: Text(
                widget.DegreeType == 'general'
                    ? 'الصفوف والمواد'
                    : 'الكوز والشهري',
                style: TextStyle(
                  fontFamily: 'Cairo-Medium',
                ),
              ),
              backgroundColor: Colors.teal,
              elevation: 0,
            )
          : null,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal, Colors.teal.shade100],
          ),
        ),
        child: gradesAndSubjects.isNotEmpty
            ? ListView(
                padding: EdgeInsets.only(
                  top: widget.HideAppBar == '0'
                      ? MediaQuery.of(context).padding.top
                      : 16,
                  left: 16,
                  right: 16,
                  bottom: 16,
                ),
                children: orderedGrades
                    .where((grade) => gradesAndSubjects.containsKey(grade))
                    .expand((grade) {
                  var sections = gradesAndSubjects[grade]!;
                  return [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        grade,
                        style: TextStyle(
                          fontSize: 20,
                          fontFamily: 'Cairo-Medium',
                          color: Colors.white,
                        ),
                      ),
                    ),
                    ...sections.entries.expand((sectionEntry) {
                      String section = sectionEntry.key;
                      List<String> subjects = sectionEntry.value;
                      return subjects.map((subject) => Card(
                            elevation: 4,
                            margin: EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.teal.shade700,
                                child: FaIcon(
                                  _getSubjectIcon(subject),
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                '$section - $subject',
                                style: TextStyle(
                                  fontFamily: 'Cairo-Medium',
                                ),
                              ),
                              subtitle: Text(grade),
                              trailing: Icon(Icons.arrow_forward_ios,
                                  color: Colors.teal),
                              onTap: () {
                                if (widget.DegreeType == 'general') {
                                  if ([
                                    'الاول الابتدائي',
                                    'الثاني الابتدائي',
                                    'الثالث الابتدائي',
                                    'الرابع الابتدائي'
                                  ].contains(grade)) {
                                    Navigator.of(context)
                                        .push(MaterialPageRoute(
                                            builder: (context) => Primarygrades(
                                                  grade: grade,
                                                  subject: subject,
                                                  division: section,
                                                )));
                                  } else if ([
                                    'الخامس الابتدائي',
                                    'السادس الابتدائي'
                                  ].contains(grade)) {
                                    Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                FifthAndSixthGrades(
                                                  grade: grade,
                                                  subject: subject,
                                                  division: section,
                                                )));
                                  } else if ([
                                    'الاول المتوسط',
                                    'الثاني المتوسط',
                                    'الثالث المتوسط'
                                  ].contains(grade)) {
                                    Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                SecondaryGrades(
                                                  grade: grade,
                                                  subject: subject,
                                                  division: section,
                                                )));
                                  }
                                } else if (widget.DegreeType == 'exam') {
                                  Navigator.of(context).push(MaterialPageRoute(
                                      builder: (context) => GradesQuizMonthly(
                                            grade: grade,
                                            subject: subject,
                                            division: section,
                                            myUid: widget.myUid,
                                          )));
                                }
                              },
                            ),
                          ));
                    }).toList(),
                  ];
                }).toList(),
              )
            : Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
      ),
    );
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

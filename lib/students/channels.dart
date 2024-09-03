import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:to_users/students/chatstudent.dart';

class SubjectsScreen extends StatefulWidget {
  final String schoolId;
  final Function? onReturn;

  const SubjectsScreen({Key? key, required this.schoolId, this.onReturn})
      : super(key: key);
  @override
  _SubjectsScreenState createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  User? user = FirebaseAuth.instance.currentUser;

  String _studentGrade = '';
  String _section = '';

  List<Map<String, dynamic>> subjects = [];
  Map<String, int> _unreadMessageCounts = {};

  @override
  void initState() {
    super.initState();
    _fetchStudentGrade();
  }

  @override
  void dispose() {
    widget.onReturn?.call();
    super.dispose();
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
            _section = data['section'];

            _updateSubjects();
          });
        }
      } catch (e) {
        print("Error fetching student grade: $e");
      }
    }
  }

  void _updateSubjects() {
    if (_studentGrade == 'الاول الابتدائي' ||
        _studentGrade == 'الثاني الابتدائي' ||
        _studentGrade == 'الثالث الابتدائي') {
      subjects = [
        {'name': 'الإسلامية', 'icon': FontAwesomeIcons.mosque},
        {'name': 'القراءة', 'icon': FontAwesomeIcons.bookOpen},
        {'name': 'اللغة الانكليزية', 'icon': FontAwesomeIcons.language},
        {'name': 'الرياضيات', 'icon': FontAwesomeIcons.squareRootAlt},
        {'name': 'العلوم', 'icon': FontAwesomeIcons.atom},
        {'name': 'الإدارة', 'icon': FontAwesomeIcons.building}
      ];
    } else if (_studentGrade == 'الرابع الابتدائي' ||
        _studentGrade == 'الخامس الابتدائي' ||
        _studentGrade == 'السادس الابتدائي') {
      subjects = [
        {'name': 'الإسلامية', 'icon': FontAwesomeIcons.mosque},
        {'name': 'اللغة العربية', 'icon': FontAwesomeIcons.bookOpen},
        {'name': 'اللغة الانكليزية', 'icon': FontAwesomeIcons.language},
        {'name': 'الرياضيات', 'icon': FontAwesomeIcons.squareRootAlt},
        {'name': 'العلوم', 'icon': FontAwesomeIcons.atom},
        {'name': 'الاجتماعيات', 'icon': FontAwesomeIcons.globeAmericas},
        {'name': 'الإدارة', 'icon': FontAwesomeIcons.building}
      ];
    } else if (_studentGrade == 'الاول المتوسط' ||
        _studentGrade == 'الثاني المتوسط' ||
        _studentGrade == 'الثالث المتوسط') {
      subjects = [
        {'name': 'الإسلامية', 'icon': FontAwesomeIcons.mosque},
        {'name': 'اللغة العربية', 'icon': FontAwesomeIcons.bookOpen},
        {'name': 'اللغة الانكليزية', 'icon': FontAwesomeIcons.language},
        {'name': 'الرياضيات', 'icon': FontAwesomeIcons.squareRootAlt},
        {'name': 'الفيزياء', 'icon': FontAwesomeIcons.magnet},
        {'name': 'الكيمياء', 'icon': FontAwesomeIcons.flask},
        {'name': 'الاحياء', 'icon': FontAwesomeIcons.dna},
        {'name': 'الاجتماعيات', 'icon': FontAwesomeIcons.globeAmericas},
        {'name': 'الإدارة', 'icon': FontAwesomeIcons.building}
      ];
    }
  }

  void _updateUnreadCount(String subject) {
    if (_unreadMessageCounts.containsKey(subject) &&
        _unreadMessageCounts[subject]! > 0) {
      setState(() {
        _unreadMessageCounts[subject] = _unreadMessageCounts[subject]! - 1;
      });
    }
  }

  Widget createButton(BuildContext context, String subject, IconData icon) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Channels')
          .doc(widget.schoolId)
          .collection('schoolMessages')
          .where('Subject', isEqualTo: subject)
          .where('stage', isEqualTo: _studentGrade)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        int unreadCount = 0;
        snapshot.data!.docs.forEach((doc) {
          var data = doc.data() as Map<String, dynamic>;
          if (!data['readBy'].contains(user!.uid)) {
            unreadCount++;
          }
        });

        _unreadMessageCounts[subject] = unreadCount;

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  grade: _studentGrade,
                  section: _section,
                  subject: subject,
                  onMessageRead: () => _updateUnreadCount(subject),
                  schoolId: widget.schoolId,
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[700]!, Colors.blue[500]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.5),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FaIcon(icon, size: 30, color: Colors.white),
                      SizedBox(height: 8),
                      Text(
                        subject,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'Cairo-Medium',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        unreadCount.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'المواد الدراسية',
          style: TextStyle(fontFamily: 'Cairo-Medium'),
        ),
        backgroundColor: Colors.blue[700],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[50]!, Colors.white],
          ),
        ),
        child: _studentGrade.isEmpty
            ? Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        "$_studentGrade $_section",
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.blue[800],
                          fontFamily: 'Cairo-Medium',
                        ),
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: subjects.length,
                        itemBuilder: (context, index) {
                          return createButton(
                            context,
                            subjects[index]['name'],
                            subjects[index]['icon'],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

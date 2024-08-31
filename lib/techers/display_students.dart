import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:to_users/techers/one_students.dart';

class StudentsListPage extends StatefulWidget {
  final int details;
  final String myGender;

  const StudentsListPage({super.key, required this.details, required this.myGender});

  @override
  _StudentsListPageState createState() => _StudentsListPageState();
}

class _StudentsListPageState extends State<StudentsListPage> {
  String searchQuery = '';
  String? selectedGrade;
  String? selectedSection;
  List<String> availableGrades = [];
  List<String> availableSections = [];
  User? user = FirebaseAuth.instance.currentUser;
  String schoolId = '';
  String type = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStudentData();
  }

  Future<void> _fetchStudentData() async {
    if (user != null) {
      try {
        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('userUid', isEqualTo: user!.uid)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          var data = querySnapshot.docs.first;
          schoolId = data['schoolId'];
          type = data['type'];
          await _fetchAvailableGrades();
        }
      } catch (e) {
        print("Error fetching student data: $e");
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchAvailableGrades() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('type', isEqualTo: 'student')
          .where('schoolId', isEqualTo: schoolId)
          .get();

      Set<String> grades = {};
      for (var doc in querySnapshot.docs) {
        String grade = doc['grade'];
        if (grade.isNotEmpty) {
          grades.add(grade);
        }
      }

      setState(() {
        availableGrades = grades.toList()..sort();
        if (availableGrades.isNotEmpty) {
          selectedGrade = availableGrades.first;
          _fetchAvailableSections(selectedGrade!);
        }
      });
    } catch (e) {
      print("Error fetching available grades: $e");
    }
  }

  Future<void> _fetchAvailableSections(String grade) async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('type', isEqualTo: 'student')
          .where('schoolId', isEqualTo: schoolId)
          .where('grade', isEqualTo: grade)
          .get();

      Set<String> sections = {};
      for (var doc in querySnapshot.docs) {
        String section = doc['section'];
        if (section.isNotEmpty) {
          sections.add(section);
        }
      }

      setState(() {
        availableSections = sections.toList()..sort();
        if (availableSections.isNotEmpty) {
          selectedSection = availableSections.first;
        } else {
          selectedSection = null;
        }
      });
    } catch (e) {
      print("Error fetching available sections: $e");
    }
  }

  int compareArabicNames(String name1, String name2) {
    return name1.compareTo(name2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('قائمة الطلاب',
            style: TextStyle(color: Colors.white, fontFamily: 'Cairo-Medium')),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[700]!, Colors.blue[100]!],
          ),
        ),
        child: isLoading
            ? Center(child: CircularProgressIndicator(color: Colors.white))
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'ابحث عن طالب',
                        labelStyle: TextStyle(color: Colors.white),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.2),
                        prefixIcon: Icon(FontAwesomeIcons.search, color: Colors.white),
                      ),
                      style: TextStyle(color: Colors.white),
                      onChanged: (query) {
                        setState(() {
                          searchQuery = query.trim();
                        });
                      },
                    ),
                  ),
                  Container(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      itemCount: availableGrades.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ChoiceChip(
                            label: Text(
                              availableGrades[index],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: selectedGrade == availableGrades[index]
                                    ? Colors.white
                                    : Colors.blue[700],
                              ),
                            ),
                            selected: selectedGrade == availableGrades[index],
                            onSelected: (bool selected) {
                              if (selected) {
                                setState(() {
                                  selectedGrade = availableGrades[index];
                                  _fetchAvailableSections(selectedGrade!);
                                });
                              }
                            },
                            backgroundColor: Colors.white,
                            selectedColor: Colors.blue[700],
                            elevation: 3,
                            padding: EdgeInsets.symmetric(horizontal: 16),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      itemCount: availableSections.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ChoiceChip(
                            label: Text(
                              availableSections[index],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: selectedSection == availableSections[index]
                                    ? Colors.white
                                    : Colors.blue[700],
                              ),
                            ),
                            selected: selectedSection == availableSections[index],
                            onSelected: (bool selected) {
                              if (selected) {
                                setState(() {
                                  selectedSection = availableSections[index];
                                });
                              }
                            },
                            backgroundColor: Colors.white,
                            selectedColor: Colors.blue[700],
                            elevation: 3,
                            padding: EdgeInsets.symmetric(horizontal: 16),
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where('type', isEqualTo: 'student')
                          .where('schoolId', isEqualTo: schoolId)
                          .where('grade', isEqualTo: selectedGrade)
                          .where('section', isEqualTo: selectedSection)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator(color: Colors.white));
                        }

                        if (snapshot.hasError) {
                          return Center(child: Text('حدث خطأ ما', style: TextStyle(color: Colors.white)));
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.white)));
                        }

                        final students = snapshot.data!.docs.where((doc) {
                          final studentName = doc['name']?.toString().toLowerCase() ?? '';
                          return studentName.contains(searchQuery.toLowerCase());
                        }).toList();

                        students.sort((a, b) => compareArabicNames(a['name'], b['name']));

                        if (students.isEmpty) {
                          return Center(child: Text('لم يتم العثور على نتائج', style: TextStyle(color: Colors.white)));
                        }

                        return ListView.builder(
                          itemCount: students.length,
                          itemBuilder: (context, index) {
                            final student = students[index];
                            return Card(
                              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: (widget.myGender == "ذكر" && student['gender'] == "انثى")
                                      ? Colors.red
                                      : Colors.blue[700],
                                  backgroundImage: (widget.myGender == "ذكر" && student['gender'] == "انثى")
                                      ? null
                                      : (student['image'] != null && student['image'] != '')
                                          ? NetworkImage(student['image'])
                                          : null,
                                  child: (widget.myGender == "ذكر" && student['gender'] == "انثى")
                                      ? FaIcon(FontAwesomeIcons.userSecret, color: Colors.white)
                                      : (student['image'] == null || student['image'] == '')
                                          ? FaIcon(FontAwesomeIcons.user, color: Colors.white)
                                          : null,
                                ),
                                title: Text("${index + 1}. ${student['name']}", style: TextStyle(fontFamily: 'Cairo-Medium')),
                                subtitle: Text(student['grade'] + ' ' + student['section'], style: TextStyle(fontFamily: 'Cairo-Medium')),
                                trailing: FaIcon(FontAwesomeIcons.chevronRight, color: Colors.blue[700]),
                                onTap: () {
                                  if (widget.details == 0) {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: Text('تنبيه'),
                                          content: Text('لا يمكن رؤية تفاصيل طالب آخر'),
                                          actions: <Widget>[
                                            TextButton(
                                              child: Text('حسنًا'),
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => StudentDetailsPage(
                                          id: student.id,
                                          Type: type,
                                          studentData: student.data() as Map<String, dynamic>,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
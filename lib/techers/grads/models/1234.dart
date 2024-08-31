import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Primarygrades extends StatefulWidget {
  final String grade;
  final String subject;
  final String division;

  const Primarygrades({
    Key? key,
    required this.grade,
    required this.subject,
    required this.division,
  }) : super(key: key);

  @override
  _PrimarygradesState createState() => _PrimarygradesState();
}

class _PrimarygradesState extends State<Primarygrades> {
  List<Map<String, dynamic>> studentsData = [];
  bool isLoading = true;
  User? user = FirebaseAuth.instance.currentUser;
  String schoolId = '';
  String selectedColumn = 'october';
  List<String> columnNames = [
    'تشرين الاول',
    'تشرين الثاني',
    'كانون الاول',
    'كانون الثاني',
    'امتحان نصف السنة',
    'شباط',
    'اذار',
    'نيسان',
    'ايار',
    'الامتحان النهائي',
    'الملاحظات'
  ];

  @override
  void initState() {
    super.initState();
    _fetchStudentData().then((_) => fetchStudentsAndGrades());
  }

  String _getColumnName(String columnKey) {
    switch (columnKey) {
      case 'october':
        return 'تشرين الاول';
      case 'november':
        return 'تشرين الثاني';
      case 'december':
        return 'كانون الاول';
      case 'january':
        return 'كانون الثاني';
      case 'midYear':
        return 'امتحان نصف السنة';
      case 'february':
        return 'شباط';
      case 'march':
        return 'اذار';
      case 'april':
        return 'نيسان';
      case 'may':
        return 'ايار';
      case 'finalExam':
        return 'الامتحان النهائي';
      case 'notes':
        return 'الملاحظات';
      default:
        return 'تشرين الاول';
    }
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
          setState(() {
            schoolId = data['schoolId'];
            print('SchoolId fetched: $schoolId');
          });
        } else {
          print('No user data found for the current user');
        }
      } catch (e) {
        print("Error fetching student data: $e");
      }
    } else {
      print('No user is currently signed in');
    }
  }

  Future<void> fetchStudentsAndGrades() async {
    setState(() {
      isLoading = true;
    });

    try {
      print(
          'Fetching students for grade: ${widget.grade}, schoolId: $schoolId');

      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('type', isEqualTo: 'student')
          .where('grade', isEqualTo: widget.grade)
          .where('section', isEqualTo: widget.division)
          .where('schoolId', isEqualTo: schoolId)
          .get();

      print('Number of students fetched: ${studentsSnapshot.docs.length}');

      if (studentsSnapshot.docs.isEmpty) {
        print('No students found for the given criteria');
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('لم يتم العثور على طلاب للمعايير المحددة')),
        );
        return;
      }

      List<Map<String, dynamic>> tempStudentsData = [];

      for (var studentDoc in studentsSnapshot.docs) {
        final studentData = studentDoc.data();
        final gradesDoc = await FirebaseFirestore.instance
            .collection('grades')
            .doc(schoolId)
            .collection(widget.grade)
            .doc(widget.division)
            .collection(widget.subject)
            .doc(studentData['userUid'])
            .get();

        Map<String, dynamic> studentGrades = {
          'id': studentDoc.id,
          'name': studentData['name'],
          'userUid': studentData['userUid'],
          'october': '',
          'november': '',
          'december': '',
          'january': '',
          'midYear': '',
          'february': '',
          'march': '',
          'april': '',
          'may': '',
          'finalExam': '',
          'notes': '',
        };

        if (gradesDoc.exists) {
          final gradesData = gradesDoc.data();
          studentGrades.addAll({
            'october': gradesData?['october'] ?? '',
            'november': gradesData?['november'] ?? '',
            'december': gradesData?['december'] ?? '',
            'january': gradesData?['january'] ?? '',
            'midYear': gradesData?['midYear'] ?? '',
            'february': gradesData?['february'] ?? '',
            'march': gradesData?['march'] ?? '',
            'april': gradesData?['april'] ?? '',
            'may': gradesData?['may'] ?? '',
            'finalExam': gradesData?['finalExam'] ?? '',
            'notes': gradesData?['notes'] ?? '',
          });
        }

        tempStudentsData.add(studentGrades);
      }

      tempStudentsData.sort((a, b) => a['name'].compareTo(b['name']));

      setState(() {
        studentsData = tempStudentsData;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching data: $e');
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تحميل البيانات')),
      );
    }
  }

  Future<void> saveGrades() async {
    setState(() {
      isLoading = true;
    });

    try {
      for (var student in studentsData) {
        final docRef = FirebaseFirestore.instance
            .collection('grades')
            .doc(schoolId)
            .collection(widget.grade)
            .doc(widget.division)
            .collection(widget.subject)
            .doc(student['userUid']);

        await docRef.set({
          'october': student['october'],
          'november': student['november'],
          'december': student['december'],
          'january': student['january'],
          'midYear': student['midYear'],
          'february': student['february'],
          'march': student['march'],
          'april': student['april'],
          'may': student['may'],
          'finalExam': student['finalExam'],
          'notes': student['notes'],
        }, SetOptions(merge: true));
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حفظ الدرجات بنجاح')),
      );
    } catch (e) {
      print('Error saving grades: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء حفظ الدرجات')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget buildGradeTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 10,
        headingRowHeight: 40,
        dataRowHeight: 40,
        columns: [
          DataColumn(label: Text('ت')),
          DataColumn(label: Text('اسم الطالب')),
          DataColumn(label: Text(_getColumnName(selectedColumn))),
        ],
        rows: List<DataRow>.generate(
          studentsData.length,
          (index) => DataRow(
            cells: [
              DataCell(Text('${index + 1}')),
              DataCell(Text(studentsData[index]['name'])),
              _buildDataCellForColumn(index, selectedColumn),
            ],
          ),
        ),
      ),
    );
  }

  DataCell _buildDataCellForColumn(int index, String columnKey) {
    if (columnKey == 'notes') {
      return DataCell(TextFormField(
        initialValue: studentsData[index]['notes'] ?? '',
        onChanged: (value) {
          setState(() {
            studentsData[index]['notes'] = value;
          });
        },
      ));
    } else {
      return DataCell(TextFormField(
        initialValue: studentsData[index][columnKey] ?? '',
        keyboardType: TextInputType.number,
        onChanged: (value) {
          setState(() {
            studentsData[index][columnKey] = value;
          });
        },
      ));
    }
  }

  void _showColumnSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('اختر العمود'),
          content: SingleChildScrollView(
            child: ListBody(
              children: columnNames.map((String column) {
                return ListTile(
                  title: Text(column),
                  onTap: () {
                    setState(() {
                      selectedColumn = _getColumnKey(column);
                    });
                    Navigator.of(context).pop();
                    fetchStudentsAndGrades();
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  String _getColumnKey(String columnName) {
    switch (columnName) {
      case 'تشرين الاول':
        return 'october';
      case 'تشرين الثاني':
        return 'november';
      case 'كانون الاول':
        return 'december';
      case 'كانون الثاني':
        return 'january';
      case 'امتحان نصف السنة':
        return 'midYear';
      case 'شباط':
        return 'february';
      case 'اذار':
        return 'march';
      case 'نيسان':
        return 'april';
      case 'ايار':
        return 'may';
      case 'الامتحان النهائي':
        return 'finalExam';
      case 'الملاحظات':
        return 'notes';
      default:
        return 'october';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('سجل درجات المدرسين'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: isLoading ? null : saveGrades,
          ),
          IconButton(
            icon: Icon(Icons.view_column),
            onPressed: _showColumnSelectionDialog,
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            'سجل درجات المدرسين للعام الدراسي 2024 - 2025',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'الصف: ${widget.grade} ${widget.division}      المادة: ${widget.subject}',
                          style: TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                  buildGradeTable(),
                ],
              ),
            ),
    );
  }
}
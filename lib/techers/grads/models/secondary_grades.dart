import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SecondaryGrades extends StatefulWidget {
  final String grade;
  final String subject;
  final String division;

  const SecondaryGrades({
    Key? key,
    required this.grade,
    required this.subject,
    required this.division,
  }) : super(key: key);

  @override
  _SecondaryGradesState createState() => _SecondaryGradesState();
}

class _SecondaryGradesState extends State<SecondaryGrades> {
  List<Map<String, dynamic>> studentsData = [];
  bool isLoading = true;
  User? user = FirebaseAuth.instance.currentUser;
  String schoolId = '';
  String selectedColumn = 'firstHalf';
  List<String> columnNames = [
    'النصف الاول',
    'نصف السنة',
    'النصف الثاني',
    'السعي السنوي',
    'الامتحان النهائي',
    'الدرجة النهائية',
    'الدور الثاني',
    'الدرجة الاخيرة'
  ];

  @override
  void initState() {
    super.initState();
    _fetchStudentData().then((_) => fetchStudentsAndGrades());
  }

  String _getColumnName(String columnKey) {
    switch (columnKey) {
      case 'firstHalf':
        return 'النصف الاول';
      case 'midYear':
        return 'نصف السنة';
      case 'secondHalf':
        return 'النصف الثاني';
      case 'annualEffort':
        return 'السعي السنوي';
      case 'finalExam':
        return 'الامتحان النهائي';
      case 'finalGrade':
        return 'الدرجة النهائية';
      case 'secondRound':
        return 'الدور الثاني';
      case 'finalScore':
        return 'الدرجة الاخيرة';
      default:
        return 'النصف الاول';
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
          'firstHalf': '',
          'midYear': '',
          'secondHalf': '',
          'annualEffort': '',
          'finalExam': '',
          'finalGrade': '',
          'secondRound': '',
          'finalScore': '',
        };

        if (gradesDoc.exists) {
          final gradesData = gradesDoc.data();
          studentGrades.addAll({
            'firstHalf': gradesData?['firstHalf'] ?? '',
            'midYear': gradesData?['midYear'] ?? '',
            'secondHalf': gradesData?['secondHalf'] ?? '',
            'finalExam': gradesData?['finalExam'] ?? '',
            'secondRound': gradesData?['secondRound'] ?? '',
          });
        }

        // Calculate annualEffort
        studentGrades['annualEffort'] = _calculateAnnualEffort(studentGrades);
        
        // Calculate finalGrade
        studentGrades['finalGrade'] = _calculateFinalGrade(studentGrades);
        
        // Calculate finalScore
        studentGrades['finalScore'] = _calculateFinalScore(studentGrades);

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

  String _calculateAnnualEffort(Map<String, dynamic> grades) {
    double firstHalf = double.tryParse(grades['firstHalf'] ?? '') ?? 0;
    double midYear = double.tryParse(grades['midYear'] ?? '') ?? 0;
    double secondHalf = double.tryParse(grades['secondHalf'] ?? '') ?? 0;
    double annualEffort = (firstHalf + midYear + secondHalf) / 3;
    return annualEffort.toStringAsFixed(2);
  }

  String _calculateFinalGrade(Map<String, dynamic> grades) {
    double annualEffort = double.tryParse(grades['annualEffort'] ?? '') ?? 0;
    double finalExam = double.tryParse(grades['finalExam'] ?? '') ?? 0;
    double finalGrade = (annualEffort + finalExam) / 2;
    return finalGrade.toStringAsFixed(2);
  }

  String _calculateFinalScore(Map<String, dynamic> grades) {
    double annualEffort = double.tryParse(grades['annualEffort'] ?? '') ?? 0;
    double secondRound = double.tryParse(grades['secondRound'] ?? '') ?? 0;
    double finalScore = (annualEffort + secondRound) / 2;
    return finalScore.toStringAsFixed(2);
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
          'firstHalf': student['firstHalf'],
          'midYear': student['midYear'],
          'secondHalf': student['secondHalf'],
          'annualEffort': student['annualEffort'],
          'finalExam': student['finalExam'],
          'finalGrade': student['finalGrade'],
          'secondRound': student['secondRound'],
          'finalScore': student['finalScore'],
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
    if (columnKey == 'annualEffort' || columnKey == 'finalGrade' || columnKey == 'finalScore') {
      return DataCell(Text(studentsData[index][columnKey] ?? ''));
    }

    return DataCell(TextFormField(
      initialValue: studentsData[index][columnKey] ?? '',
      keyboardType: TextInputType.number,
      onChanged: (value) {
        setState(() {
          studentsData[index][columnKey] = value;
          studentsData[index]['annualEffort'] = _calculateAnnualEffort(studentsData[index]);
          studentsData[index]['finalGrade'] = _calculateFinalGrade(studentsData[index]);
          studentsData[index]['finalScore'] = _calculateFinalScore(studentsData[index]);
        });
      },
    ));
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
      case 'النصف الاول':
        return 'firstHalf';
      case 'نصف السنة':
        return 'midYear';
      case 'النصف الثاني':
        return 'secondHalf';
      case 'السعي السنوي':
        return 'annualEffort';
      case 'الامتحان النهائي':
        return 'finalExam';
      case 'الدرجة النهائية':
        return 'finalGrade';
      case 'الدور الثاني':
        return 'secondRound';
      case 'الدرجة الاخيرة':
        return 'finalScore';
      default:
        return 'firstHalf';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('سجل درجات المتوسطة والاعدادية'),
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
                            'سجل درجات المتوسطة والاعدادية للعام الدراسي 2024 - 2025',
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
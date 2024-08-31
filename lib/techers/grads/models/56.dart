import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FifthAndSixthGrades extends StatefulWidget {
  final String grade;
  final String subject;
  final String division;

  const FifthAndSixthGrades({
    Key? key,
    required this.grade,
    required this.subject,
    required this.division,
  }) : super(key: key);

  @override
  _FifthAndSixthGradesState createState() => _FifthAndSixthGradesState();
}

class _FifthAndSixthGradesState extends State<FifthAndSixthGrades> {
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
    'معدل النصف الاول',
    'امتحان نصف السنة',
    'شباط',
    'اذار',
    'نيسان',
    'ايار',
    'معدل النصف الثاني',
    'المعدل السنوي',
    'الامتحان النهائي',
    'الدرجة النهائية',
    'امتحان الدور الثاني',
    'الدرجة الاخيرة'
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
      case 'firstHalfAverage':
        return 'معدل النصف الاول';
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
      case 'secondHalfAverage':
        return 'معدل النصف الثاني';
      case 'yearlyAverage':
        return 'المعدل السنوي';
      case 'finalExam':
        return 'الامتحان النهائي';
      case 'finalGrade':
        return 'الدرجة النهائية';
      case 'secondRoundExam':
        return 'امتحان الدور الثاني';
      case 'lastGrade':
        return 'الدرجة الاخيرة';
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
          'firstHalfAverage': '',
          'midYear': '',
          'february': '',
          'march': '',
          'april': '',
          'may': '',
          'secondHalfAverage': '',
          'yearlyAverage': '',
          'finalExam': '',
          'finalGrade': '',
          'secondRoundExam': '',
          'lastGrade': '',
        };

        if (gradesDoc.exists) {
          final gradesData = gradesDoc.data();
          studentGrades.addAll({
            'october': gradesData?['october'] ?? '',
            'november': gradesData?['november'] ?? '',
            'december': gradesData?['december'] ?? '',
            'january': gradesData?['january'] ?? '',
            'firstHalfAverage': gradesData?['firstHalfAverage'] ?? '',
            'midYear': gradesData?['midYear'] ?? '',
            'february': gradesData?['february'] ?? '',
            'march': gradesData?['march'] ?? '',
            'april': gradesData?['april'] ?? '',
            'may': gradesData?['may'] ?? '',
            'secondHalfAverage': gradesData?['secondHalfAverage'] ?? '',
            'yearlyAverage': gradesData?['yearlyAverage'] ?? '',
            'finalExam': gradesData?['finalExam'] ?? '',
            'finalGrade': gradesData?['finalGrade'] ?? '',
            'secondRoundExam': gradesData?['secondRoundExam'] ?? '',
            'lastGrade': gradesData?['lastGrade'] ?? '',
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
        _updateCalculatedFields(studentsData.indexOf(student));
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
          'firstHalfAverage': student['firstHalfAverage'],
          'midYear': student['midYear'],
          'february': student['february'],
          'march': student['march'],
          'april': student['april'],
          'may': student['may'],
          'secondHalfAverage': student['secondHalfAverage'],
          'yearlyAverage': student['yearlyAverage'],
          'finalExam': student['finalExam'],
          'finalGrade': student['finalGrade'],
          'secondRoundExam': student['secondRoundExam'],
          'lastGrade': student['lastGrade'],
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
    if (columnKey == 'firstHalfAverage' ||
        columnKey == 'secondHalfAverage' ||
        columnKey == 'yearlyAverage' ||
        columnKey == 'finalGrade' ||
        columnKey == 'lastGrade') {
      return DataCell(Text(studentsData[index][columnKey] ?? ''));
    }

    return DataCell(TextFormField(
      initialValue: studentsData[index][columnKey] ?? '',
      keyboardType: TextInputType.number,
      onChanged: (value) {
        setState(() {
          studentsData[index][columnKey] = value;
          _updateCalculatedFields(index);
        });
      },
    ));
  }

  void _updateCalculatedFields(int index) {
    // Calculate first half average
    double firstHalfAvg = _calculateAverage([
      studentsData[index]['october'],
      studentsData[index]['november'],
      studentsData[index]['december'],
      studentsData[index]['january'],
    ]);
    studentsData[index]['firstHalfAverage'] = firstHalfAvg.toStringAsFixed(2);

    // Calculate second half average
    double secondHalfAvg = _calculateAverage([
      studentsData[index]['february'],
      studentsData[index]['march'],
      studentsData[index]['april'],
      studentsData[index]['may'],
    ]);
    studentsData[index]['secondHalfAverage'] = secondHalfAvg.toStringAsFixed(2);

    // Calculate yearly average
    double yearlyAvg = _calculateAverage([
      firstHalfAvg.toString(),
      studentsData[index]['midYear'],
      secondHalfAvg.toString(),
    ]);
    studentsData[index]['yearlyAverage'] = yearlyAvg.toStringAsFixed(2);

    // Calculate final grade
    double finalGrade = _calculateAverage([
      yearlyAvg.toString(),
      studentsData[index]['finalExam'],
    ]);
    studentsData[index]['finalGrade'] = finalGrade.toStringAsFixed(2);

    // Calculate last grade
    double lastGrade = _calculateAverage([
      yearlyAvg.toString(),
      studentsData[index]['secondRoundExam'],
    ]);
    studentsData[index]['lastGrade'] = lastGrade.toStringAsFixed(2);
  }

  double _calculateAverage(List<String> values) {
    List<double> numbers = values
        .where((v) => v.isNotEmpty)
        .map((v) => double.tryParse(v) ?? 0)
        .toList();
    if (numbers.isEmpty) return 0;
    return numbers.reduce((a, b) => a + b) / numbers.length;
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
      case 'معدل النصف الاول':
        return 'firstHalfAverage';
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
      case 'معدل النصف الثاني':
        return 'secondHalfAverage';
      case 'المعدل السنوي':
        return 'yearlyAverage';
      case 'الامتحان النهائي':
        return 'finalExam';
      case 'الدرجة النهائية':
        return 'finalGrade';
      case 'امتحان الدور الثاني':
        return 'secondRoundExam';
      case 'الدرجة الاخيرة':
        return 'lastGrade';
      default:
        return 'october';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('سجل درجات الصفوف الخامس والسادس'),
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
                            'سجل درجات الصفوف الخامس والسادس للعام الدراسي 2024 - 2025',
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

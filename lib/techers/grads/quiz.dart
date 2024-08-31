import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class GradesQuizMonthly extends StatefulWidget {
  final String grade;
  final String subject;
  final String division;
  final String myUid;

  const GradesQuizMonthly({
    Key? key,
    required this.grade,
    required this.subject,
    required this.division,
    required this.myUid,
  }) : super(key: key);

  @override
  _GradesQuizMonthlyState createState() => _GradesQuizMonthlyState();
}

class _GradesQuizMonthlyState extends State<GradesQuizMonthly> {
  List<Map<String, dynamic>> studentsData = [];
  bool isLoading = true;
  User? user = FirebaseAuth.instance.currentUser;
  String schoolId = '';
  String degreeTitle = '';
  String? documentId;
  final _formKey = GlobalKey<FormState>();
  final _degreeTitleController = TextEditingController();
  final _totalGradeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStudentData().then((_) => fetchStudentsAndInitialize());
  }

  void resetDocument() {
    setState(() {
      documentId = null;
      _degreeTitleController.clear();
      _totalGradeController.clear();
      for (var student in studentsData) {
        student['grade'] = {'degree': '', 'isSeen': false};
      }
    });
  }

  @override
  void dispose() {
    _degreeTitleController.dispose();
    _totalGradeController.dispose();
    super.dispose();
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

  Future<void> fetchStudentsAndInitialize() async {
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
        final studentUid = studentData['userUid'];

        Map<String, dynamic> studentGrades = {
          'id': studentDoc.id,
          'name': studentData['name'],
          'userUid': studentUid,
          'grade': {'degree': '', 'isSeen': false},
        };

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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    int totalGrade = int.parse(_totalGradeController.text);
    bool hasError = false;
    for (var student in studentsData) {
      if (student['grade']['degree'].isNotEmpty) {
        int studentGrade = int.parse(student['grade']['degree']);
        if (studentGrade > totalGrade) {
          hasError = true;
          break;
        }
      }
    }

    if (hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يرجى تصحيح الدرجات التي تتجاوز الدرجة الكلية')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      Map<String, dynamic> gradesData = {
        'grade': widget.grade,
        'subject': widget.subject,
        'division': widget.division,
        'degreeTitle': _degreeTitleController.text,
        'totalGrade': int.parse(_totalGradeController.text),
        'time': FieldValue.serverTimestamp(),
        'myUid': widget.myUid,
        'grades': {},
      };

      for (var student in studentsData) {
        gradesData['grades'][student['userUid']] = {
          'degree': student['grade']['degree'],
          'isSeen': false,
        };
      }

      if (documentId != null) {
        // Update existing document
        await FirebaseFirestore.instance
            .collection('grades')
            .doc(schoolId)
            .collection("GradesQuizMonthly")
            .doc(documentId)
            .update(gradesData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تحديث الدرجات بنجاح')),
        );
      } else {
        // Create new document
        DocumentReference docRef = await FirebaseFirestore.instance
            .collection('grades')
            .doc(schoolId)
            .collection("GradesQuizMonthly")
            .add(gradesData);

        documentId = docRef.id;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حفظ الدرجات بنجاح')),
        );
      }
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

  void showOldDocuments() async {
    final oldDocumentsSnapshot = await FirebaseFirestore.instance
        .collection('grades')
        .doc(schoolId)
        .collection("GradesQuizMonthly")
        .where('grade', isEqualTo: widget.grade)
        .where('subject', isEqualTo: widget.subject)
        .where('division', isEqualTo: widget.division)
        .get();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                child: Text(
                  'المستندات السابقة',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: oldDocumentsSnapshot.docs.length,
                  itemBuilder: (context, index) {
                    final doc = oldDocumentsSnapshot.docs[index];
                    final data = doc.data();
                    return Card(
                      elevation: 3,
                      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        title: Text(
                          data['degreeTitle'] ?? 'بدون عنوان',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade700,
                          ),
                        ),
                        subtitle: Text(
                          data['time']?.toDate().toString() ??
                              'التاريخ غير متوفر',
                          style: TextStyle(fontSize: 12),
                        ),
                        leading:
                            Icon(Icons.document_scanner, color: Colors.teal),
                        onTap: () {
                          Navigator.of(context).pop();
                          loadOldDocument(doc.id);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void loadOldDocument(String docId) async {
    setState(() {
      isLoading = true;
    });

    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('grades')
          .doc(schoolId)
          .collection("GradesQuizMonthly")
          .doc(docId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        _degreeTitleController.text = data['degreeTitle'] ?? '';
        _totalGradeController.text = data['totalGrade']?.toString() ?? '';
        final grades = data['grades'] as Map<String, dynamic>;

        for (var student in studentsData) {
          student['grade'] =
              grades[student['userUid']] ?? {'degree': '', 'isSeen': false};
        }

        setState(() {
          documentId = docId; // Set the documentId when loading an old document
        });
      }
    } catch (e) {
      print('Error loading old document: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تحميل المستند القديم')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('الكوز والشهري',
              style: TextStyle(
                fontFamily: 'Cairo-Medium',
              )),
          backgroundColor: Colors.teal,
          elevation: 0,
          actions: [
            IconButton(
              icon: FaIcon(FontAwesomeIcons.plus),
              onPressed: resetDocument,
            ),
            IconButton(
              icon: FaIcon(FontAwesomeIcons.history),
              onPressed: showOldDocuments,
            ),
            IconButton(
              icon: FaIcon(FontAwesomeIcons.save),
              onPressed: saveGrades,
            ),
          ],
        ),
        body: isLoading
            ? Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.teal)))
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.teal.shade50, Colors.white],
                  ),
                ),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Center(
                                    child: Column(
                                      children: [
                                        Text(
                                          'عنوان الدرجات',
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontFamily: 'Cairo-Medium',
                                              color: Colors.teal),
                                        ),
                                        SizedBox(height: 8),
                                        TextFormField(
                                          controller: _degreeTitleController,
                                          textAlign: TextAlign.center,
                                          textDirection: TextDirection.rtl,
                                          decoration: InputDecoration(
                                            hintText: 'أدخل عنوان الدرجات هنا',
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                  color: Colors.teal),
                                            ),
                                            prefixIcon: Icon(
                                                FontAwesomeIcons.heading,
                                                color: Colors.teal),
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'الرجاء إدخال عنوان للدرجات';
                                            }
                                            return null;
                                          },
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'الدرجة الكلية',
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontFamily: 'Cairo-Medium',
                                              color: Colors.teal),
                                        ),
                                        SizedBox(height: 8),
                                        TextFormField(
                                          controller: _totalGradeController,
                                          textAlign: TextAlign.center,
                                          textDirection: TextDirection.ltr,
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            hintText: 'أدخل الدرجة الكلية هنا',
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                  color: Colors.teal),
                                            ),
                                            prefixIcon: Icon(
                                                FontAwesomeIcons.percent,
                                                color: Colors.teal),
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'الرجاء إدخال الدرجة الكلية';
                                            }
                                            if (int.tryParse(value) == null) {
                                              return 'الرجاء إدخال رقم صحيح';
                                            }
                                            return null;
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'الصف: ${widget.grade} ${widget.division}      المادة: ${widget.subject}',
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.teal.shade700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Card(
                          margin: EdgeInsets.all(16),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: buildGradeTable(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget buildGradeTable() {
    int? totalGrade = int.tryParse(_totalGradeController.text);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        headingRowHeight: 50,
        dataRowHeight: 56,
        headingRowColor: MaterialStateProperty.all(Colors.teal.shade100),
        columns: [
          DataColumn(
              label: Text('ت',
                  style: TextStyle(
                      fontFamily: 'Cairo-Medium',
                      color: Colors.teal.shade700))),
          DataColumn(
              label: Text('اسم الطالب',
                  style: TextStyle(
                      fontFamily: 'Cairo-Medium',
                      color: Colors.teal.shade700))),
          DataColumn(
              label: Text('الدرجة',
                  style: TextStyle(
                      fontFamily: 'Cairo-Medium',
                      color: Colors.teal.shade700))),
        ],
        rows: List<DataRow>.generate(
          studentsData.length,
          (index) => DataRow(
            color: MaterialStateProperty.resolveWith<Color?>(
                (Set<MaterialState> states) {
              if (index.isEven) return Colors.teal.shade50;
              return null;
            }),
            cells: [
              DataCell(Text('${index + 1}')),
              DataCell(Text(studentsData[index]['name'])),
              DataCell(
                TextFormField(
                  initialValue: studentsData[index]['grade']['degree'],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  onChanged: (value) {
                    setState(() {
                      studentsData[index]['grade']['degree'] = value;
                    });
                  },
                  style: TextStyle(
                    color: totalGrade != null &&
                            int.tryParse(studentsData[index]['grade']
                                        ['degree'] ??
                                    '0') !=
                                null &&
                            int.parse(studentsData[index]['grade']['degree']) >
                                totalGrade
                        ? Colors.red
                        : Colors.teal.shade700,
                  ),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

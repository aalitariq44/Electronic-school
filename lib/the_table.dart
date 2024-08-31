import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ScheduleTable extends StatefulWidget {
  final String schoolId;

  ScheduleTable({Key? key, required this.schoolId}) : super(key: key);

  @override
  _ScheduleTableState createState() => _ScheduleTableState();
}

class _ScheduleTableState extends State<ScheduleTable> {
  Map<String, dynamic> scheduleData = {};

  @override
  void initState() {
    super.initState();
    fetchScheduleData();
  }

  Future<void> fetchScheduleData() async {
    try {
      DocumentSnapshot schoolDoc = await FirebaseFirestore.instance
          .collection('School schedule published')
          .doc(widget.schoolId)
          .get();

      if (schoolDoc.exists) {
        setState(() {
          scheduleData = schoolDoc.get('publishedSchedule') ?? {};
        });
      } else {
        print('لم يتم العثور على وثيقة المدرسة');
      }
    } catch (e) {
      print('حدث خطأ أثناء جلب البيانات: $e');
    }
  }

  List<String> sortGrades(List<String> grades) {
    final orderMap = {
      'الأول الابتدائي': 1,
      'الثاني الابتدائي': 2,
      'الثالث الابتدائي': 3,
      'الرابع الابتدائي': 4,
      'الخامس الابتدائي': 5,
      'السادس الابتدائي': 6,
      'الأول المتوسط': 7,
      'الثاني المتوسط': 8,
      'الثالث المتوسط': 9,
      'الرابع العلمي': 10,
      'الرابع الأدبي': 11,
      'الخامس العلمي': 12,
      'الخامس الأدبي': 13,
      'السادس العلمي': 14,
      'السادس الأدبي': 15,
    };

    grades.sort((a, b) {
      int orderA = orderMap[a] ?? 100; // Default high value for unknown grades
      int orderB = orderMap[b] ?? 100;
      return orderA.compareTo(orderB);
    });

    return grades;
  }

  List<String> sortDays() {
    return ['السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
  }

  List<String> sortPeriods() {
    return ['الدرس الاول', 'الدرس الثاني', 'الدرس الثالث', 'الدرس الرابع', 'الدرس الخامس', 'الدرس السادس'];
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

  @override
  Widget build(BuildContext context) {
    List<String> sortedGrades = sortGrades(scheduleData.keys.toList());
    List<String> sortedDays = sortDays();
    List<String> sortedPeriods = sortPeriods();

    return Scaffold(
      appBar: AppBar(
        title: Text('جدول المدرسة', style: TextStyle(fontFamily: 'Cairo-Medium')),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.blue.shade200],
          ),
        ),
        child: scheduleData.isEmpty
            ? Center(child: CircularProgressIndicator(color: Colors.white))
            : ListView.builder(
                itemCount: sortedGrades.length,
                itemBuilder: (context, gradeIndex) {
                  String grade = sortedGrades[gradeIndex];
                  Map<String, dynamic> gradeSchedule = scheduleData[grade];
                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: ExpansionTile(
                      title: Text(grade, style: TextStyle(fontFamily: 'Cairo-Medium', color: Colors.blue)),
                      leading: Icon(FontAwesomeIcons.graduationCap, color: Colors.blue),
                      children: gradeSchedule.entries.map((sectionEntry) {
                        String section = sectionEntry.key;
                        Map<String, dynamic> sectionSchedule = sectionEntry.value;
                        return Card(
                          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: ExpansionTile(
                            title: Text(section, style: TextStyle(fontWeight: FontWeight.w500)),
                            leading: Icon(FontAwesomeIcons.chalkboardTeacher, color: Colors.blue),
                            children: [
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: MaterialStateProperty.all(Colors.blue.shade100),
                                  dataRowColor: MaterialStateProperty.all(Colors.white),
                                  columns: [
                                    DataColumn(label: Text('الحصة/اليوم', style: TextStyle(fontFamily: 'Cairo-Medium'))),
                                    ...sortedDays.map((day) => DataColumn(label: Text(day, style: TextStyle(fontFamily: 'Cairo-Medium')))),
                                  ],
                                  rows: sortedPeriods.map((period) {
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(period, style: TextStyle(fontWeight: FontWeight.w500))),
                                        ...sortedDays.map((day) {
                                          String key = '$day-$period';
                                          String subject = sectionSchedule[key] ?? '-';
                                          return DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(_getSubjectIcon(subject), size: 16, color: Colors.blue),
                                                SizedBox(width: 4),
                                                Text(subject),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
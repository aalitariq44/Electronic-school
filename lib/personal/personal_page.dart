import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:to_users/personal/my_points.dart';
import 'package:to_users/personal/my_posts.dart';
import 'package:to_users/techers/grads/teacher_subjects_page.dart';
import 'package:url_launcher/url_launcher.dart';

class PersonalPage extends StatefulWidget {
  final String userUid;
  final int showGradesTab;

  PersonalPage({required this.userUid, required this.showGradesTab});

  @override
  State<PersonalPage> createState() => _PersonalPageState();
}

class _PersonalPageState extends State<PersonalPage> {
  Map<String, dynamic> studentData = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchStudentData();
  }

  Future<void> fetchStudentData() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userUid', isEqualTo: widget.userUid)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          studentData = querySnapshot.docs.first.data() as Map<String, dynamic>;
          isLoading = false;
        });
      } else {
        print('No matching documents found');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching student data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: Image.network(imageUrl),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      Tab(icon: FaIcon(FontAwesomeIcons.userCircle), text: "المعلومات الشخصية"),
      Tab(icon: FaIcon(FontAwesomeIcons.newspaper), text: "منشوراتي"),
      Tab(icon: FaIcon(FontAwesomeIcons.star), text: "النقاط"),
    ];

    final List<Widget> tabViews = [
      _buildPersonalInfoTab(),
      _buildPostsTab(),
      _buildPointsTab(),
    ];

    if (widget.showGradesTab == 1) {
      tabs.insert(1,
          Tab(icon: FaIcon(FontAwesomeIcons.graduationCap), text: "الدرجات"));
      tabViews.insert(1, _buildGradesTab());
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text("الصفحة الشخصية", style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.teal,
          bottom: TabBar(
            isScrollable: true,
            tabs: tabs,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: TabBarView(
          children: tabViews,
        ),
      ),
    );
  }

  Widget _buildPersonalInfoTab() {
    return isLoading
        ? Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildProfileHeader(),
                  SizedBox(height: 24),
                  _buildInfoCard(),
                ],
              ),
            ),
          );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            if (studentData['image'] != null && studentData['image'] != '') {
              _showFullImage(context, studentData['image']);
            }
          },
          child: CircleAvatar(
            radius: 70,
            backgroundImage:
                studentData['image'] != null && studentData['image'] != ''
                    ? NetworkImage(studentData['image'])
                    : null,
            child: studentData['image'] == null || studentData['image'] == ''
                ? FaIcon(FontAwesomeIcons.userGraduate,
                    size: 70, color: Colors.white)
                : null,
            backgroundColor: Colors.teal,
          ),
        ),
        SizedBox(height: 16),
        Text(
          '${studentData['name'] ?? ''}',
          style: TextStyle(fontSize: 24, fontFamily: 'Cairo'),
        ),
        Text(
          '${studentData['type'] ?? ''}',
          style:
              TextStyle(fontSize: 18, color: Colors.grey, fontFamily: 'Cairo'),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'المعلومات الشخصية',
              style: TextStyle(
                  fontSize: 20, color: Colors.teal, fontFamily: 'Cairo'),
            ),
            SizedBox(height: 16),
            _buildInfoRow(
                FontAwesomeIcons.envelope, 'البريد الإلكتروني', 'email'),
            _buildInfoRow(FontAwesomeIcons.venusMars, 'الجنس', 'gender'),
            _buildInfoRow(FontAwesomeIcons.phone, 'رقم الهاتف', 'phone',
                isPhone: true),
            _buildInfoRow(
                FontAwesomeIcons.locationDot, 'عنوان المنزل', 'address'),
            _buildInfoRow(
                FontAwesomeIcons.cakeCandles, 'تاريخ الميلاد', 'birthDate'),
            _buildInfoRow(
                FontAwesomeIcons.calendarCheck, 'تاريخ المباشرة', 'startDate'),
            _buildGradesAndSubjectsInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String field,
      {bool isPhone = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          FaIcon(icon, color: Colors.teal, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: isPhone
                ? InkWell(
                    onTap: () async {
                      final Uri launchUri = Uri(
                        scheme: 'tel',
                        path: studentData[field],
                      );
                      await launch(launchUri.toString());
                    },
                    child: Text(
                      '$label: ${studentData[field] ?? 'لا يوجد'}',
                      style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue,
                          fontFamily: 'Cairo'),
                    ),
                  )
                : Text(
                    '$label: ${studentData[field] ?? 'لا يوجد'}',
                    style: TextStyle(fontSize: 16, fontFamily: 'Cairo'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradesAndSubjectsInfo() {
    if (studentData['gradesAndSubjects'] == null) {
      return SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الصفوف والشعب والمواد:',
              style: TextStyle(
                  fontSize: 18, color: Colors.teal, fontFamily: 'Cairo'),
            ),
            SizedBox(height: 16),
            ...(studentData['gradesAndSubjects'] as Map<String, dynamic>)
                .entries
                .map((entry) {
              final gradeInfo = entry.value as Map<String, dynamic>;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.blue[700],
                        fontFamily: 'Cairo'),
                  ),
                  SizedBox(height: 8),
                  ...gradeInfo.entries.map((sectionEntry) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sectionEntry.key,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.green[700],
                                fontFamily: 'Cairo'),
                          ),
                          SizedBox(height: 4),
                          ...sectionEntry.value.map<Widget>((subject) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                  left: 16.0, bottom: 4.0),
                              child: Row(
                                children: [
                                  FaIcon(FontAwesomeIcons.book,
                                      color: Colors.teal, size: 14),
                                  SizedBox(width: 8),
                                  Text(
                                    subject,
                                    style: TextStyle(
                                        fontSize: 14, fontFamily: 'Cairo'),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    );
                  }).toList(),
                  Divider(color: Colors.grey[300], thickness: 1),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildGradesTab() {
    return Center(
      child: TeacherSubjectsPageGrades(
        DegreeType: 'general',
        HideAppBar: '0',
        myUid: widget.userUid,
      ),
    );
  }

  Widget _buildPostsTab() {
    return MyPosts(
      myUid: widget.userUid,
    );
  }

  Widget _buildPointsTab() {
    return PointsHistoryPage(myUid: widget.userUid);
  }
}

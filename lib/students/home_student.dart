import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:to_users/Appbar/CustomAppBar.dart';
import 'package:to_users/calculator/calculator.dart';
import 'package:to_users/custom_drawer.dart';
import 'package:to_users/discussion.dart';
import 'package:to_users/gemini.dart';
import 'package:to_users/login/login.dart';
import 'package:to_users/notes/all_notes.dart';
import 'package:to_users/notifications/api/notifications_page.dart';
import 'package:to_users/personal/personal_page.dart';
import 'package:to_users/points/points.dart';
import 'package:to_users/posts.dart';
import 'package:to_users/students/channels_button.dart';
import 'package:to_users/students/grades.dart';
import 'package:to_users/students/meeting_student.dart';
import 'package:to_users/students/quiz.dart';
import 'package:to_users/tasks/tasks.dart';
import 'package:to_users/techers/display_students.dart';
import 'package:to_users/the_book.dart';
import 'package:to_users/the_table.dart';
import 'package:to_users/translate.dart';
import 'package:to_users/update_checker_service.dart';

class HomePageStudents extends StatefulWidget {
  @override
  _HomePageStudentsState createState() => _HomePageStudentsState();
}

class _HomePageStudentsState extends State<HomePageStudents> {
  final UpdateCheckerService _updateChecker = UpdateCheckerService(
      currentVersion: '1.0.0'); // استبدل بإصدار تطبيقك الحالي

  User? user = FirebaseAuth.instance.currentUser;
  String studentName = '';
  String studentGrade = '';
  String studentPass = '';
  String studentimage = '';
  String schoolName = '';
  String schoolId = '';
  String myUid = '';
  String myGender = '';
  String studentSection = '';
  String type = '';

  bool _hasUnreadGrades = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  NotificationsPage? notificationsPage;

  @override
  void initState() {
    super.initState();
    _fetchStudentData().then((_) {
      _checkPassword();
      _checkUnreadGrades();
    });
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    await _updateChecker.initialize();
    bool updateAvailable = await _updateChecker.checkForUpdates();

    if (updateAvailable && mounted) {
      _updateChecker.showUpdateDialog(context);
    }
  }

  Future<void> _checkUnreadGrades() async {
    bool hasUnread = await Quiz.checkUnreadGrades(schoolId, myUid);
    setState(() {
      _hasUnreadGrades = hasUnread;
    });
  }

  Future<void> _checkPassword() async {
    final prefs = await SharedPreferences.getInstance();
    String? storedPassword = prefs.getString('password');

    if (storedPassword != null && storedPassword != studentPass) {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginPage()),
        (Route<dynamic> route) => false,
      );
    }
  }

// Add this new method to handle logout
  Future<void> _handleLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginPage()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      print("Error during logout: $e");
      // You might want to show an error message to the user here
    }
  }

  void _openEndDrawer() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = Colors.blue,
  }) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.27, // تعديل العرض
          height: 100, // تقليل الارتفاع
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(icon, size: 30, color: Colors.white), // تقليل حجم الأيقونة
              SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14, // تقليل حجم الخط
                  fontFamily: 'Cairo-Medium',
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
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
          String schoolId = data['schoolId'];

          // طباعة schoolId مباشرة بعد الحصول عليه
          print('Fetched schoolId: $schoolId');

          // جلب اسم المدرسة من مجموعة schools
          DocumentSnapshot schoolDoc = await FirebaseFirestore.instance
              .collection('schools')
              .doc(schoolId)
              .get();

          setState(() {
            this.schoolId = schoolId; // تحديث متغير الحالة
            studentName = data['name'];
            studentGrade = data['grade'];
            studentPass = data['password'];
            studentSection = data['section'];
            studentimage = data['image'];
            myUid = data['userUid'];
            schoolName = schoolDoc['shName'];
            myGender = data['gender'];
            type = data['type'];
            notificationsPage = NotificationsPage(
              myUid: myUid,
              schoolId: schoolId,
            );

            // طباعة جميع البيانات التي تم جلبها
            print('Updated student data:');
            print('schoolId: $schoolId');
            print('studentName: $studentName');
            print('studentGrade: $studentGrade');
            print('studentImage: $studentimage');
            print('schoolName: $schoolName');
            print('myGender: $myGender');
          });
        } else {
          print('No user document found for the current user.');
        }
      } catch (e) {
        print("Error fetching student data: $e");
      }
    } else {
      print('No user is currently signed in.');
    }
  }

  Future<void> _fetchTotalUnreadMessages() async {
    if (user != null && schoolId.isNotEmpty && studentGrade.isNotEmpty) {
      try {
        // ignore: unused_local_variable

        setState(() {});
      } catch (e) {
        print("Error fetching total unread messages: $e");
      }
    }
  }

  void _updateUnreadMessagesCount() {
    _fetchTotalUnreadMessages();
  }

  Widget _buildSplitFeatureCard({
    required IconData icon1,
    required String title1,
    required VoidCallback onTap1,
    required IconData icon2,
    required String title2,
    required VoidCallback onTap2,
    Color color = Colors.blue,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.4,
        height: 120,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onTap1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FaIcon(icon1, size: 30, color: Colors.white),
                    SizedBox(height: 8),
                    Text(
                      title1,
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
            ),
            VerticalDivider(color: Colors.white, thickness: 1),
            Expanded(
              child: InkWell(
                onTap: onTap2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FaIcon(icon2, size: 30, color: Colors.white),
                    SizedBox(height: 8),
                    Text(
                      title2,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalSplitFeatureCard({
    required IconData icon1,
    required String title1,
    required VoidCallback onTap1,
    required IconData icon2,
    required String title2,
    required VoidCallback onTap2,
    Color color = Colors.blue,
    bool showRedDot1 = false,
    bool showRedDot2 = false,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.4,
        height: 120,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  InkWell(
                    onTap: onTap1,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FaIcon(icon1, size: 24, color: Colors.white),
                          SizedBox(height: 4),
                          Text(
                            title1,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontFamily: 'Cairo-Medium',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (showRedDot1)
                    Positioned(
                      top: 5,
                      right: 5,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Divider(color: Colors.white, height: 1, thickness: 1),
            Expanded(
              child: Stack(
                children: [
                  InkWell(
                    onTap: onTap2,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FaIcon(icon2, size: 24, color: Colors.white),
                          SizedBox(height: 4),
                          Text(
                            title2,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontFamily: 'Cairo-Medium',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (showRedDot2)
                    Positioned(
                      top: 5,
                      right: 5,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getFontSize(String name) {
    int nameLength = name.length;
    if (nameLength > 20) {
      return 14;
    } else if (nameLength > 15) {
      return 16;
    } else {
      return 18;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        key: _scaffoldKey, // أضف هذا السطر
        appBar: CustomAppBar(
          title: schoolName,
          myUid: myUid,
          schoolId: schoolId,
          openEndDrawer: _openEndDrawer,
        ),
        endDrawer: CustomDrawer(
          onLogout: _handleLogout,
          userUid: myUid,
          myName: studentName,
        ),
        body: TabBarView(
          children: [
            // الصفحة الرئيسية
            SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // معلومات المستخدم
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PersonalPage(
                              userUid: user!.uid,
                              showGradesTab: 0,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: EdgeInsets.only(
                            left: 16, right: 16, top: 8, bottom: 0),
                        padding: EdgeInsets.all(4),
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
                              spreadRadius: 2,
                              blurRadius: 7,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundImage: studentimage.isNotEmpty
                                  ? NetworkImage(studentimage)
                                  : null,
                              child: studentimage.isEmpty
                                  ? FaIcon(FontAwesomeIcons.user,
                                      color: Colors.white)
                                  : null,
                            ),
                            SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  studentName,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: _getFontSize(studentName),
                                    fontFamily: 'Cairo-Medium',
                                  ),
                                ),
                                Text(
                                  studentGrade,
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Center(
                      child: InkWell(
                        onTap: () {},
                        child: Container(
                          margin: EdgeInsets.only(
                              left: 16, right: 16, top: 10, bottom: 8),
                          width: 400,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.all(
                              Radius.circular(10),
                            ),
                            image: DecorationImage(
                              image: NetworkImage(
                                  'https://media.baamboozle.com/uploads/images/67785/1637822896_197587.jpeg'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // الميزات
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        children: [
                          ChannelsButton(
                            schoolId: schoolId,
                            studentGrade: studentGrade,
                            onReturn: () {
                              _updateUnreadMessagesCount();
                              setState(() {});
                            },
                          ),
                          _buildHorizontalSplitFeatureCard(
                            icon1: FontAwesomeIcons.table,
                            title1: "الجدول",
                            onTap1: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ScheduleTable(schoolId: schoolId),
                                ),
                              );
                            },
                            icon2: FontAwesomeIcons.stickyNote,
                            title2: "الدرجات",
                            onTap2: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => Quiz(
                                    schoolId: schoolId,
                                    myUid: myUid,
                                  ),
                                ),
                              );
                              // تحديث حالة الدرجات غير المقروءة بعد العودة من صفحة Quiz
                              _checkUnreadGrades();
                            },
                            showRedDot2: _hasUnreadGrades,
                            color: Colors.teal,
                          ),
                          _buildSplitFeatureCard(
                            icon1: FontAwesomeIcons.users,
                            title1: "الإجتماع",
                            onTap1: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MeetingStudent(
                                    schoolId: schoolId,
                                    myUid: myUid,
                                    otherUserUid: '',
                                    otherUserName: 'الإجتماع',
                                    grade: studentGrade,
                                    section: studentSection,
                                  ),
                                ),
                              );
                            },
                            icon2: FontAwesomeIcons.commentDots,
                            title2: "المناقشة",
                            onTap2: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => Discussion(
                                    schoolId: schoolId,
                                    myUid: myUid,
                                    otherUserUid: '',
                                    otherUserName: 'المناقشة',
                                  ),
                                ),
                              );
                            },
                            color: Colors.deepPurple,
                          ),
                          _buildHorizontalSplitFeatureCard(
                            icon1: FontAwesomeIcons.stickyNote,
                            title1: "ملاحظاتي",
                            onTap1: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NotesListPage(),
                                ),
                              );
                            },
                            icon2: FontAwesomeIcons.tasks,
                            title2: "مهامي",
                            onTap2: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TasksPage(),
                                ),
                              );
                            },
                          ),
                          _buildFeatureCard(
                            icon: FontAwesomeIcons.robot,
                            title: "الذكاء الاصطناعي",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AIChat(),
                                ),
                              );
                            },
                            color: Colors.deepOrange,
                          ),
                          _buildFeatureCard(
                            icon: FontAwesomeIcons.language,
                            title: "الترجمة",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TranslationPage(),
                                ),
                              );
                            },
                            color: Colors.red,
                          ),
                          _buildFeatureCard(
                            icon: FontAwesomeIcons.userGraduate,
                            title: "الطلاب",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => StudentsListPage(
                                    details: 0,
                                    myGender: myGender,
                                  ),
                                ),
                              );
                            },
                            color: Colors.amber,
                          ),
                          _buildFeatureCard(
                            icon: FontAwesomeIcons.calculator,
                            title: "الحاسبة",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CalculatorApplication(),
                                ),
                              );
                            },
                            color: Colors.cyan,
                          ),
                          _buildFeatureCard(
                            icon: FontAwesomeIcons.gamepad,
                            title: "مسابقات",
                            onTap: () {
                              // Handle meeting feature
                            },
                            color: Colors.purple,
                          ),
                          _buildHorizontalSplitFeatureCard(
                            icon1: FontAwesomeIcons.bookOpen,
                            title1: "الكتب",
                            onTap1: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => ClassesPage()),
                              );
                            },
                            icon2: FontAwesomeIcons.graduationCap,
                            title2: "الشهادة",
                            onTap2: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => StudentsGrades(),
                                ),
                              );
                            },
                            color: Colors.indigo, // تغيير اللون هنا
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 20,
                    ),
                  ],
                ),
              ),
            ),
            // صفحة المجتمع
            Center(
                child: PostsPage(
              type: type,
            )),
            // صفحة النقاط
            Center(
              child: PointsPage(
                schoolId: schoolId,
                myType: 'student',
                myUid: myUid,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

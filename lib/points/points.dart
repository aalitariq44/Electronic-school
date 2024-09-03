import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class PointsPage extends StatefulWidget {
  final String schoolId;
  final String myType;
  final String myUid;

  PointsPage({
    Key? key,
    required this.schoolId,
    required this.myType,
    required this.myUid,
  }) : super(key: key);

  @override
  _PointsPageState createState() => _PointsPageState();
}

class _PointsPageState extends State<PointsPage> {
  int _remainingPoints = 4;
  DateTime? _nextRefreshTime;
  List<QueryDocumentSnapshot> pointsList = [];
  bool isLoading = false;
  bool hasMore = true;
  int documentLimit = 10;
  DocumentSnapshot? lastDocument;
  String appbarTitle = 'نقاط المدرسين';
  String selectedUserType = 'teacher'; // متغير جديد لتتبع النوع المحدد

  @override
  void initState() {
    super.initState();
    _loadRemainingPoints();
    _loadInitialData();
  }

  Future<void> _loadRemainingPoints() async {
    final pointDoc = await FirebaseFirestore.instance
        .collection('points')
        .doc(widget.myUid)
        .get();

    if (pointDoc.exists) {
      setState(() {
        _remainingPoints = int.parse(pointDoc.data()?['available'] ?? '0');
      });
    }
  }

  String _getPointsDisplayMessage() {
    if (_remainingPoints <= 0) {
      return 'انتظر حتى اليوم التالي';
    } else {
      return 'النقاط المتاحة للمنح: $_remainingPoints';
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      isLoading = true;
    });

    var query = FirebaseFirestore.instance
        .collection('points')
        .where('schoolId', isEqualTo: widget.schoolId)
        .orderBy('points', descending: true)
        .limit(documentLimit);

    var snapshot = await query.get();

    if (snapshot.docs.isNotEmpty) {
      var filteredDocs = await _filterDocumentsByUserType(snapshot.docs);
      pointsList = filteredDocs;
      lastDocument = snapshot.docs.last;
      hasMore = snapshot.docs.length == documentLimit;
    } else {
      hasMore = false;
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadMoreData() async {
    if (!hasMore || isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      var query = FirebaseFirestore.instance
          .collection('points')
          .where('schoolId', isEqualTo: widget.schoolId)
          .orderBy('points', descending: true)
          .startAfterDocument(lastDocument!)
          .limit(documentLimit);

      var snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        var filteredDocs = await _filterDocumentsByUserType(snapshot.docs);
        setState(() {
          pointsList.addAll(filteredDocs);
          lastDocument = snapshot.docs.last;
          hasMore = snapshot.docs.length == documentLimit;
          isLoading = false;
        });
      } else {
        setState(() {
          hasMore = false;
          isLoading = false;
        });
      }
    } catch (error) {
      print('Error loading more data: $error');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<List<QueryDocumentSnapshot>> _filterDocumentsByUserType(
      List<QueryDocumentSnapshot> docs) async {
    List<String> userUids =
        docs.map((doc) => doc['userUid'] as String).toList();
    var usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('userUid', whereIn: userUids)
        .where('type', isEqualTo: selectedUserType)
        .get();

    Set<String> filteredUserUids =
        usersSnapshot.docs.map((doc) => doc['userUid'] as String).toSet();

    return docs
        .where((doc) => filteredUserUids.contains(doc['userUid']))
        .toList();
  }

  Future<void> _updateRemainingPoints(int pointsToDeduct) async {
    final newRemainingPoints = _remainingPoints - pointsToDeduct;
    await FirebaseFirestore.instance
        .collection('points')
        .doc(widget.myUid)
        .update({'available': newRemainingPoints.toString()});

    setState(() {
      _remainingPoints = newRemainingPoints;
    });
  }

  Future<void> _recordPointTransaction(
      String granteeUid, int grantedPoints) async {
    final timestamp = FieldValue.serverTimestamp();

    await FirebaseFirestore.instance
        .collection('points')
        .doc(widget.myUid)
        .collection('transactions')
        .add({
      'granteeUid': granteeUid,
      'points': grantedPoints,
      'timestamp': timestamp,
      'type': 'granted'
    });

    await FirebaseFirestore.instance
        .collection('points')
        .doc(granteeUid)
        .collection('transactions')
        .add({
      'grantorUid': widget.myUid,
      'points': grantedPoints,
      'timestamp': timestamp,
      'type': 'received'
    });
  }

  Future<void> _updatePoints(String userUid, dynamic currentPoints) async {
    if (_remainingPoints <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لا يوجد نقاط متبقية للمنح')),
      );
      return;
    }

    int currentPointsInt = int.tryParse(currentPoints.toString()) ?? 0;

    final result = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        int points = 0;
        return AlertDialog(
          title: Text('منح نقاط'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('النقاط المتبقية للمنح: $_remainingPoints'),
              TextField(
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  points = int.tryParse(value) ?? 0;
                },
                decoration: InputDecoration(hintText: "أدخل عدد النقاط"),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('إلغاء'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('منح'),
              onPressed: () => Navigator.of(context).pop(points),
            ),
          ],
        );
      },
    );

    if (result != null && result > 0) {
      if (result > _remainingPoints) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('لا يمكن منح نقاط أكثر من المتبقي')),
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('points')
          .doc(userUid)
          .update({
        'points': (currentPointsInt + result).toString(),
      });

      await _updateRemainingPoints(result);
      await _recordPointTransaction(userUid, result);
    }
  }

  Future<List<QueryDocumentSnapshot>> fetchUsers(List<String> userUids) async {
    List<QueryDocumentSnapshot> allUsers = [];
    for (var i = 0; i < userUids.length; i += 30) {
      var end = (i + 30 < userUids.length) ? i + 30 : userUids.length;
      var batch = userUids.sublist(i, end);
      var querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userUid', whereIn: batch)
          .get();
      allUsers.addAll(querySnapshot.docs);
    }
    return allUsers;
  }

  Widget _buildTrophy(int rank) {
    IconData icon;
    Color color;
    switch (rank) {
      case 1:
        icon = FontAwesomeIcons.trophy;
        color = Colors.amber;
        break;
      case 2:
        icon = FontAwesomeIcons.medal;
        color = Colors.grey[300]!;
        break;
      case 3:
        icon = FontAwesomeIcons.medal;
        color = Colors.brown[300]!;
        break;
      default:
        return SizedBox.shrink();
    }
    return Icon(icon, color: color, size: 24);
  }

  String _getRemainingTime() {
    if (_nextRefreshTime == null) return '';
    final now = DateTime.now();
    final difference = _nextRefreshTime!.difference(now);
    if (difference.isNegative) return 'جاهز للتحديث';
    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    return '$hours س و $minutes د';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(appbarTitle),
        backgroundColor: Colors.blue,
        actions: [
          ToggleButtons(
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: FaIcon(FontAwesomeIcons.chalkboardTeacher,
                    size: 24, color: Colors.white),
              ),
              Padding(
                padding: EdgeInsets.all(8),
                child: FaIcon(FontAwesomeIcons.userGraduate,
                    size: 24, color: Colors.white),
              ),
            ],
            isSelected: [
              selectedUserType == 'teacher',
              selectedUserType == 'student'
            ],
            onPressed: (index) {
              setState(() {
                if (index == 0) {
                  appbarTitle = 'نقاط المدرسين';
                  selectedUserType = 'teacher';
                } else {
                  appbarTitle = 'نقاط الطلاب';
                  selectedUserType = 'student';
                }
                _loadInitialData(); // إعادة تحميل البيانات بعد تغيير النوع
              });
            },
            color: Colors.white,
            selectedColor: Colors.white,
            fillColor: Colors.blue,
            borderColor: Colors.blue,
            selectedBorderColor: Colors.blue,
            borderWidth: 1.5,
            splashColor: Colors.white,
            highlightColor: Colors.white,
            renderBorder: true,
          ),
          SizedBox(
            width: 4,
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[50]!, Colors.white],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _remainingPoints > 0 ? Icons.stars : Icons.access_time,
                    color: _remainingPoints > 0 ? Colors.amber : Colors.grey,
                  ),
                  SizedBox(width: 8),
                  Text(
                    _getPointsDisplayMessage(),
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Cairo-Medium',
                      color: _remainingPoints > 0
                          ? Colors.blue[700]
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<QueryDocumentSnapshot>>(
                future: fetchUsers(
                    pointsList.map((doc) => doc['userUid'] as String).toList()),
                builder: (context, usersSnapshot) {
                  if (!usersSnapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final userMap = {
                    for (final userDoc in usersSnapshot.data!)
                      userDoc['userUid']: {
                        'name': userDoc['name'],
                        'image': userDoc['image'],
                        'type': userDoc['type'],
                        'gender': userDoc['gender'],
                      }
                  };

                  return ListView.builder(
                    itemCount: pointsList.length + 1,
                    itemBuilder: (context, index) {
                      if (index == pointsList.length) {
                        return _buildLoadMoreButton();
                      }

                      final point = pointsList[index];
                      final userData = userMap[point['userUid']];

                      if (userData == null) {
                        return SizedBox.shrink();
                      }

                      return Card(
                        margin:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.all(16),
                          leading: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: userData['gender'] == 'انثى'
                                    ? Colors.red
                                    : Colors.blue[100],
                                child: userData['gender'] == 'انثى'
                                    ? FaIcon(FontAwesomeIcons.userSecret,
                                        color: Colors.white, size: 30)
                                    : (userData['image'] == null ||
                                            userData['image'] == ''
                                        ? Icon(Icons.person,
                                            size: 30, color: Colors.blue[700])
                                        : null),
                                backgroundImage: userData['gender'] != 'انثى' &&
                                        userData['image'] != null &&
                                        userData['image'] != ''
                                    ? NetworkImage(userData['image']!)
                                    : null,
                              ),
                              _buildTrophy(index + 1),
                            ],
                          ),
                          title: Text(
                            userData['name']!,
                            style: TextStyle(
                              fontFamily: 'Cairo-Medium',
                              fontSize: 14,
                              color: Colors.blue[700],
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'النوع: ${userData['type'] == 'student' ? 'طالب' : 'معلم'}',
                                style: TextStyle(
                                  fontSize: 12.0,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 4.0),
                              Text(
                                'النقاط: ${int.tryParse(point['points'].toString()) ?? 0}',
                                style: TextStyle(
                                  fontSize: 16.0,
                                  fontFamily: 'Cairo-Medium',
                                  color: Colors.green[600],
                                ),
                              ),
                            ],
                          ),
                          trailing: widget.myType != userData['type']
                              ? IconButton(
                                  icon: Icon(Icons.add_circle_outline,
                                      color: Colors.green),
                                  onPressed: _remainingPoints > 0
                                      ? () {
                                          _updatePoints(point['userUid'],
                                              point['points']);
                                        }
                                      : null,
                                )
                              : null,
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

  Widget _buildLoadMoreButton() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    } else if (hasMore) {
      return ElevatedButton(
        child: Text('تحميل المزيد'),
        onPressed: _loadMoreData,
      );
    } else {
      return SizedBox.shrink();
    }
  }
}

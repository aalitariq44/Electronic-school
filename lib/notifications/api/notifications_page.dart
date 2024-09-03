import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

class NotificationsPage extends StatelessWidget {
  final String myUid;
  final String schoolId;

  const NotificationsPage({Key? key, required this.myUid, required this.schoolId})
      : super(key: key);

  Future<String> _getUserName(String uid) async {
    try {
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        return userDoc.get('name') ?? 'مستخدم غير معروف';
      }
    } catch (e) {
      print('Error fetching user name: $e');
    }
    return 'مستخدم غير معروف';
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return 'قبل ${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      return 'قبل ${difference.inHours} ساعة';
    } else {
      return DateFormat('yyyy-MM-dd hh:mm a').format(date);
    }
  }

  Timestamp _convertToTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value;
    } else if (value is int) {
      return Timestamp.fromMillisecondsSinceEpoch(value);
    } else {
      return Timestamp.now();
    }
  }

  Stream<int> getUnreadNotificationsCount() {
    return FirebaseFirestore.instance
        .collection('posts')
        .where('uid', isEqualTo: myUid)
        .snapshots()
        .asyncMap((snapshot) async {
      int count = 0;
      for (var doc in snapshot.docs) {
        var postData = doc.data() as Map<String, dynamic>;

        if (postData['likes'] != null) {
          count += (postData['likes'] as Map<String, dynamic>)
              .values
              .where((like) => !(like['isRead'] ?? false))
              .length;
        }

        if (postData['comments'] != null) {
          count += (postData['comments'] as List)
              .where((comment) => !(comment['isRead'] ?? false))
              .length;
        }
      }

      QuerySnapshot pointsSnapshot = await FirebaseFirestore.instance
          .collection('points')
          .doc(myUid)
          .collection('transactions')
          .where('isRead', isEqualTo: false)
          .get();
      count += pointsSnapshot.docs.length;

      QuerySnapshot schoolNotificationsSnapshot = await FirebaseFirestore
          .instance
          .collection('managementMessages')
          .doc(schoolId)
          .collection('schoolMessages')
          .where('studentSeenStatus.$myUid', isEqualTo: false)
          .get();
      count += schoolNotificationsSnapshot.docs.length;

      return count;
    });
  }

  Stream<QuerySnapshot> getSchoolNotifications() {
    return FirebaseFirestore.instance
        .collection('managementMessages')
        .doc(schoolId)
        .collection('schoolMessages')
        .where('studentSeenStatus.$myUid', isNull: false)
        .snapshots();
  }

  void showNotifications(BuildContext context) {
    FirebaseFirestore.instance
        .collection('posts')
        .where('uid', isEqualTo: myUid)
        .get()
        .then((snapshot) {
      for (var doc in snapshot.docs) {
        doc.reference.update({
          'likes': (doc.data()['likes'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, {...value, 'isRead': true}),
          ),
          'comments': (doc.data()['comments'] as List?)
              ?.map((comment) => {...comment, 'isRead': true})
              .toList(),
        });
      }
    });

    FirebaseFirestore.instance
        .collection('points')
        .doc(myUid)
        .collection('transactions')
        .where('isRead', isEqualTo: false)
        .get()
        .then((snapshot) {
      for (var doc in snapshot.docs) {
        doc.reference.update({'isRead': true});
      }
    });

    FirebaseFirestore.instance
        .collection('managementMessages')
        .doc(schoolId)
        .collection('schoolMessages')
        .where('studentSeenStatus.$myUid', isEqualTo: false)
        .get()
        .then((snapshot) {
      for (var doc in snapshot.docs) {
        doc.reference.update({'studentSeenStatus.$myUid': true});
      }
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'الإشعارات',
                        style: TextStyle(
                          fontSize: 18,
                          fontFamily: 'Cairo-Medium',
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildAllNotifications(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAllNotifications() {
    return StreamBuilder<List<Widget>>(
      stream: _getAllNotificationsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('حدث خطأ: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('لا توجد إشعارات'));
        }

        return ListView(children: snapshot.data!);
      },
    );
  }

  Stream<List<Widget>> _getAllNotificationsStream() {
    return Rx.combineLatest4(
      getSchoolNotifications(),
      _getPostNotificationsStream(),
      _getPointsNotificationsStream(),
      _getCommentNotificationsStream(),
      (schoolNotifications, postNotifications, pointsNotifications, commentNotifications) {
        List<Widget> allNotifications = [];
        
        // إضافة إشعارات المدرسة أولاً
        allNotifications.addAll(_buildSchoolNotificationWidgets(schoolNotifications));
        
        // إضافة باقي الإشعارات
        allNotifications.addAll(postNotifications);
        allNotifications.addAll(pointsNotifications);
        allNotifications.addAll(commentNotifications);
        
        // ترتيب الإشعارات حسب التاريخ
        allNotifications.sort((a, b) {
          DateTime timeA = (a.key as ValueKey<DateTime>).value;
          DateTime timeB = (b.key as ValueKey<DateTime>).value;
          return timeB.compareTo(timeA);
        });
        
        return allNotifications;
      },
    );
  }

  Stream<List<Widget>> _getPostNotificationsStream() {
    return FirebaseFirestore.instance
        .collection('posts')
        .where('uid', isEqualTo: myUid)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Widget> notifications = [];
      for (var doc in snapshot.docs) {
        var postData = doc.data() as Map<String, dynamic>;
        if (postData['likes'] != null) {
          var likes = postData['likes'] as Map<String, dynamic>;
          for (var entry in likes.entries) {
            String userName = await _getUserName(entry.key);
            notifications.add(_buildNotificationWidget(
              '$userName أعجب بمنشورك',
              '',
              _convertToTimestamp(entry.value['timestamp']).toDate(),
              Icons.favorite,
              Colors.red,
            ));
          }
        }
      }
      return notifications;
    });
  }

  Stream<List<Widget>> _getPointsNotificationsStream() {
    return FirebaseFirestore.instance
        .collection('points')
        .doc(myUid)
        .collection('transactions')
        .where('type', isEqualTo: 'received')
        .limit(10)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Widget> notifications = [];
      for (var doc in snapshot.docs) {
        var transactionData = doc.data();
        String userName = await _getUserName(transactionData['grantorUid']);
        notifications.add(_buildNotificationWidget(
          'حصلت على نقاط من $userName',
          '${transactionData['points']} نقطة',
          _convertToTimestamp(transactionData['timestamp']).toDate(),
          Icons.stars,
          Colors.amber,
        ));
      }
      return notifications;
    });
  }

  Stream<List<Widget>> _getCommentNotificationsStream() {
    return FirebaseFirestore.instance
        .collection('posts')
        .where('uid', isEqualTo: myUid)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Widget> notifications = [];
      for (var doc in snapshot.docs) {
        var postData = doc.data() as Map<String, dynamic>;
        if (postData['comments'] != null) {
          for (var comment in postData['comments']) {
            String userName = await _getUserName(comment['userId']);
            notifications.add(_buildNotificationWidget(
              'علق $userName على منشورك',
              comment['text'],
              _convertToTimestamp(comment['timestamp']).toDate(),
              Icons.comment,
              Colors.blue,
            ));
          }
        }
      }
      return notifications;
    });
  }

  List<Widget> _buildSchoolNotificationWidgets(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      var notificationData = doc.data() as Map<String, dynamic>;
      return _buildNotificationWidget(
        notificationData['title'],
        notificationData['content'],
        _convertToTimestamp(notificationData['timestamp']).toDate(),
        Icons.school,
        Colors.purple,
      );
    }).toList();
  }

  Widget _buildNotificationWidget(String title, String content, DateTime time, IconData icon, Color color) {
    return Card(
      key: ValueKey<DateTime>(time),
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontFamily: 'Cairo-Medium', )),
                  if (content.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(content),
                  ],
                  SizedBox(height: 4),
                  Text(
                    _formatTimestamp(Timestamp.fromDate(time)),
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: getUnreadNotificationsCount(),
      builder: (context, snapshot) {
        int unreadCount = snapshot.data ?? 0;
        return IconButton(
          icon: Stack(
            children: [
              Icon(Icons.notifications),
              if (unreadCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Text(
                      '$unreadCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () => showNotifications(context),
        );
      },
    );
  }
}
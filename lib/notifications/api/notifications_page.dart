import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationsPage extends StatelessWidget {
  final String myUid;
  final String schoolId;

  const NotificationsPage(
      {Key? key, required this.myUid, required this.schoolId})
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
          .collection('notifications')
          .doc(schoolId)
          .collection('School Notifications')
          .where('studentUid', isEqualTo: myUid)
          .where('isRead', isEqualTo: false)
          .get();
      count += schoolNotificationsSnapshot.docs.length;

      return count;
    });
  }

  Stream<QuerySnapshot> getSchoolNotifications() {
    return FirebaseFirestore.instance
        .collection('notifications')
        .doc(schoolId)
        .collection('School Notifications')
        .where('studentUid', isEqualTo: myUid)
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
        .collection('notifications')
        .doc(schoolId)
        .collection('School Notifications')
        .where('studentUid', isEqualTo: myUid)
        .where('isRead', isEqualTo: false)
        .get()
        .then((snapshot) {
      for (var doc in snapshot.docs) {
        doc.reference.update({'isRead': true});
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
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .where('uid', isEqualTo: myUid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                            child: Text('حدث خطأ: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(child: Text('لا توجد إشعارات'));
                      }

                      List<Widget> notificationWidgets = [];

                      for (var doc in snapshot.data!.docs) {
                        var postData = doc.data() as Map<String, dynamic>;

                        if (postData['likes'] != null) {
                          var likes = postData['likes'] as Map<String, dynamic>;
                          likes.forEach((userId, likeData) {
                            notificationWidgets.add(_buildLikeNotification({
                              'userId': userId,
                              'timestamp': likeData['timestamp'],
                            }));
                          });
                        }

                        if (postData['comments'] != null) {
                          for (var comment in postData['comments']) {
                            notificationWidgets
                                .add(_buildCommentNotification(comment));
                          }
                        }
                      }

                      notificationWidgets.add(_buildPointsNotifications());
                      notificationWidgets.add(_buildSchoolNotifications());

                      return ListView(children: notificationWidgets);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLikeNotification(Map<String, dynamic> like) {
    return FutureBuilder<String>(
      future: _getUserName(like['userId']),
      builder: (context, userSnapshot) {
        String userName = userSnapshot.data ?? 'جاري التحميل...';
        return Card(
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.favorite, color: Colors.red, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'أعجب $userName بمنشورك',
                        style: TextStyle(fontFamily: 'Cairo-Medium'),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _formatTimestamp(
                            _convertToTimestamp(like['timestamp'])),
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentNotification(Map<String, dynamic> comment) {
    return FutureBuilder<String>(
      future: _getUserName(comment['userId']),
      builder: (context, userSnapshot) {
        String userName = userSnapshot.data ?? 'جاري التحميل...';
        return Card(
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.comment, color: Colors.blue, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'علق $userName على منشورك:',
                        style: TextStyle(fontFamily: 'Cairo-Medium'),
                      ),
                      SizedBox(height: 8),
                      Text(comment['text']),
                      SizedBox(height: 4),
                      Text(
                        _formatTimestamp(
                            _convertToTimestamp(comment['timestamp'])),
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPointsNotifications() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('points')
          .doc(myUid)
          .collection('transactions')
          .where('type', isEqualTo: 'received')
          .limit(10)
          .snapshots(),
      builder: (context, pointsSnapshot) {
        if (pointsSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (pointsSnapshot.hasError) {
          return Center(child: Text('حدث خطأ: ${pointsSnapshot.error}'));
        }
        if (!pointsSnapshot.hasData || pointsSnapshot.data!.docs.isEmpty) {
          return SizedBox();
        }

        var transactions = pointsSnapshot.data!.docs;
        transactions.sort((a, b) => _convertToTimestamp(b['timestamp'])
            .compareTo(_convertToTimestamp(a['timestamp'])));

        return Column(
          children: transactions.map((transaction) {
            var transactionData = transaction.data() as Map<String, dynamic>;
            return FutureBuilder<String>(
              future: _getUserName(transactionData['grantorUid']),
              builder: (context, userSnapshot) {
                String userName = userSnapshot.data ?? 'جاري التحميل...';
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.stars, color: Colors.amber, size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'حصلت على نقاط من $userName',
                                style: TextStyle(fontFamily: 'Cairo-Medium'),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${transactionData['points']} نقطة',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontFamily: 'Cairo-Medium',
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _formatTimestamp(_convertToTimestamp(
                                    transactionData['timestamp'])),
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSchoolNotifications() {
    return StreamBuilder<QuerySnapshot>(
      stream: getSchoolNotifications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('حدث خطأ: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return SizedBox();
        }

        var notifications = snapshot.data!.docs;
        notifications.sort((a, b) => _convertToTimestamp(b['timestamp'])
            .compareTo(_convertToTimestamp(a['timestamp'])));

        return Column(
          children: notifications.map((doc) {
            var notificationData = doc.data() as Map<String, dynamic>;
            return Card(
              margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notification_important,
                        color: Colors.orange, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notificationData['title'],
                            style: TextStyle(
                                fontFamily: 'Cairo-Medium',
                                fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(notificationData['content']),
                          SizedBox(height: 4),
                          Text(
                            _formatTimestamp(_convertToTimestamp(
                                notificationData['timestamp'])),
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
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

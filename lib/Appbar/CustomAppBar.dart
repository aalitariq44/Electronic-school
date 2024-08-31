import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:to_users/chat_page_general/chatpage.dart';
import 'package:to_users/notifications/api/notifications_page.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String myUid;
  final String schoolId;
  final VoidCallback openEndDrawer;

  CustomAppBar({
    required this.title,
    required this.myUid,
    required this.schoolId,
    required this.openEndDrawer,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.blue[700],
      toolbarHeight: 110,
      title: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontFamily: 'Cairo-Medium',
        ),
      ),
      actions: [
        MessageIconWithBadge(myUid: myUid),
        NotificationIconWithBadge(
          myUid: myUid,
          schoolId: schoolId,
        ),
        IconButton(
          icon: FaIcon(FontAwesomeIcons.cog, color: Colors.white),
          onPressed: openEndDrawer,
        ),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(50),
        child: TabBar(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: [
            Tab(
                icon: FaIcon(FontAwesomeIcons.home, size: 20),
                text: "الرئيسية"),
            Tab(
                icon: FaIcon(FontAwesomeIcons.users, size: 20),
                text: "المجتمع"),
            Tab(icon: FaIcon(FontAwesomeIcons.star, size: 20), text: "النقاط"),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(120);
}

class NotificationIconWithBadge extends StatelessWidget {
  final String myUid;
  final String schoolId;

  const NotificationIconWithBadge({
    Key? key,
    required this.myUid,
    required this.schoolId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: NotificationsPage(
        myUid: myUid,
        schoolId: schoolId,
      ).getUnreadNotificationsCount(),
      builder: (context, snapshot) {
        int unreadCount = snapshot.data ?? 0;
        return Stack(
          children: [
            IconButton(
              icon: FaIcon(FontAwesomeIcons.bell, color: Colors.white),
              onPressed: () {
                NotificationsPage(
                  myUid: myUid,
                  schoolId: schoolId,
                ).showNotifications(context);
              },
            ),
            if (unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '$unreadCount',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class MessageIconWithBadge extends StatelessWidget {
  final String myUid;

  const MessageIconWithBadge({
    Key? key,
    required this.myUid,
  }) : super(key: key);

  Stream<int> getUnreadMessagesCount() {
    return FirebaseFirestore.instance
        .collection('Conversations')
        .where('participants', arrayContains: myUid)
        .snapshots()
        .map((snapshot) {
      int totalUnreadCount = 0;
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        Map<String, dynamic> unreadCount = data['unreadCount'] ?? {};
        totalUnreadCount += (unreadCount[myUid] ?? 0) as int;
      }
      return totalUnreadCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: getUnreadMessagesCount(),
      builder: (context, snapshot) {
        int unreadCount = snapshot.data ?? 0;
        return Stack(
          children: [
            IconButton(
              icon: FaIcon(FontAwesomeIcons.message, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatPageGeneral(
                      myUid: myUid,
                    ),
                  ),
                );
              },
            ),
            if (unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '$unreadCount',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
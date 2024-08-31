import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:to_users/students/channels.dart';

class ChannelsButton extends StatefulWidget {
  final String schoolId;
  final String studentGrade;
  final VoidCallback onReturn;

  const ChannelsButton({
    Key? key,
    required this.schoolId,
    required this.studentGrade,
    required this.onReturn,
  }) : super(key: key);

  @override
  _ChannelsButtonState createState() => _ChannelsButtonState();
}

class _ChannelsButtonState extends State<ChannelsButton> {
  int _totalUnreadMessages = 0;
  User? user = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAndFetchMessages();
  }

  @override
  void didUpdateWidget(ChannelsButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.schoolId != oldWidget.schoolId ||
        widget.studentGrade != oldWidget.studentGrade) {
      _checkAndFetchMessages();
    }
  }

  Future<void> _checkAndFetchMessages() async {
    if (widget.schoolId.isNotEmpty && widget.studentGrade.isNotEmpty) {
      await _fetchTotalUnreadMessages();
    } else {
      setState(() {
        _isLoading = true;
      });
    }
  }

  Future<void> _fetchTotalUnreadMessages() async {
    setState(() {
      _isLoading = true;
    });

    if (user != null &&
        widget.schoolId.isNotEmpty &&
        widget.studentGrade.isNotEmpty) {
      try {
        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection('Channels')
            .doc(widget.schoolId)
            .collection('schoolMessages')
            .where('stage', isEqualTo: widget.studentGrade)
            .get();

        int totalUnread = 0;
        for (var doc in querySnapshot.docs) {
          var data = doc.data() as Map<String, dynamic>;
          if (!data['readBy'].contains(user!.uid)) {
            totalUnread++;
          }
        }

        setState(() {
          _totalUnreadMessages = totalUnread;
          _isLoading = false;
        });
      } catch (e) {
        print("Error fetching total unread messages: $e");
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color color,
    int unreadCount = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: color,
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 40, color: Colors.white),
                  SizedBox(height: 8),
                  Text(
                    title,
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount.toString(),
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        color: Colors.green,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    return _buildFeatureCard(
      icon: FontAwesomeIcons.book,
      title: "القنوات",
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SubjectsScreen(
              schoolId: widget.schoolId,
              onReturn: () {
                _fetchTotalUnreadMessages();
                widget.onReturn();
              },
            ),
          ),
        );
      },
      color: Colors.green,
      unreadCount: _totalUnreadMessages,
    );
  }
}

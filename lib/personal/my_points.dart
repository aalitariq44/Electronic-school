import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

class PointsHistoryPage extends StatefulWidget {
  final String myUid;

  PointsHistoryPage({Key? key, required this.myUid}) : super(key: key);

  @override
  _PointsHistoryPageState createState() => _PointsHistoryPageState();
}

class _PointsHistoryPageState extends State<PointsHistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, String> _userNames = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<String> _getUserName(String uid) async {
    if (_userNames.containsKey(uid)) {
      return _userNames[uid]!;
    }

    try {
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (userDoc.exists) {
        String name = userDoc.get('name') ?? 'مستخدم غير معروف';
        _userNames[uid] = name;
        return name;
      }
    } catch (e) {
      print('Error fetching user name: $e');
    }

    return 'مستخدم غير معروف';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              color: Colors.blue[700],
              child: TabBar(
                controller: _tabController,
                tabs: [
                  Tab(
                    icon: FaIcon(FontAwesomeIcons.handHoldingHeart),
                    text: 'منحت',
                  ),
                  Tab(
                    icon: FaIcon(FontAwesomeIcons.gift),
                    text: 'حصلت',
                  ),
                ],
                labelColor: Colors.white,
                unselectedLabelColor: Colors.blue[200],
                indicatorColor: Colors.amber,
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTransactionsList('granted'),
                  _buildTransactionsList('received'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList(String transactionType) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('points')
          .doc(widget.myUid)
          .collection('transactions')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('حدث خطأ: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FaIcon(FontAwesomeIcons.boxOpen, size: 50, color: Colors.grey),
                SizedBox(height: 16),
                Text('لا يوجد عمليات سابقة',
                    style: TextStyle(
                        fontFamily: 'Cairo-Medium',
                        fontSize: 18,
                        color: Colors.grey)),
              ],
            ),
          );
        }

        var transactions = snapshot.data!.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .where((transaction) => transaction['type'] == transactionType)
            .toList();

        transactions.sort((a, b) => (b['timestamp'] as Timestamp)
            .compareTo(a['timestamp'] as Timestamp));

        if (transactions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FaIcon(FontAwesomeIcons.boxOpen, size: 50, color: Colors.grey),
                SizedBox(height: 16),
                Text('لا يوجد عمليات سابقة',
                    style: TextStyle(
                        fontFamily: 'Cairo-Medium',
                        fontSize: 18,
                        color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            var transaction = transactions[index];
            String uid = transactionType == 'granted'
                ? transaction['granteeUid']
                : transaction['grantorUid'];

            return FutureBuilder<String>(
              future: _getUserName(uid),
              builder: (context, snapshot) {
                String userName = snapshot.data ?? 'جاري التحميل...';
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue[100],
                      child: FaIcon(
                        transactionType == 'granted'
                            ? FontAwesomeIcons.handHoldingHeart
                            : FontAwesomeIcons.gift,
                        color: Colors.blue[700],
                      ),
                    ),
                    title: Text(
                      transactionType == 'granted'
                          ? 'منحت لـ: $userName'
                          : 'حصلت من: $userName',
                      style: TextStyle(
                        fontFamily: 'Cairo-Medium',
                        fontSize: 16,
                        color: Colors.blue[700],
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 8),
                        Row(
                          children: [
                            FaIcon(FontAwesomeIcons.star,
                                size: 16, color: Colors.amber),
                            SizedBox(width: 8),
                            Text(
                              'النقاط: ${transaction['points']}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.green[600],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            FaIcon(FontAwesomeIcons.clock,
                                size: 16, color: Colors.grey),
                            SizedBox(width: 8),
                            Text(
                              _formatTimestamp(transaction['timestamp']),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
  }
}

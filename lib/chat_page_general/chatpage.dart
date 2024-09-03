import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:to_users/chat_page_general/chat_page_general.dart';

class ChatPageGeneral extends StatefulWidget {
  final String myUid;

  const ChatPageGeneral({Key? key, required this.myUid}) : super(key: key);

  @override
  _ChatPageGeneralState createState() => _ChatPageGeneralState();
}

class _ChatPageGeneralState extends State<ChatPageGeneral> {
  Widget _buildShimmerEffect() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        itemCount: 5,
        itemBuilder: (context, index) {
          return Card(
            elevation: 0,
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: Colors.white,
              ),
              title: Container(
                width: double.infinity,
                height: 16,
                color: Colors.white,
              ),
              subtitle: Container(
                width: double.infinity,
                height: 14,
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'المحادثات',
          style: TextStyle(fontFamily: 'Cairo-Medium', color: Colors.white),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 0,
      ),
      body: Stack(
        children: [
          _buildConversationList(),
          Positioned(
            left: 20,
            bottom: 20,
            child: FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatSearchPage(myUid: widget.myUid),
                  ),
                );
              },
              child: FaIcon(FontAwesomeIcons.plus, color: Colors.white),
              backgroundColor: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Conversations')
          .where('participants', arrayContains: widget.myUid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerEffect();
        }

        if (snapshot.hasError) {
          return Center(child: Text('حدث خطأ: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'لا توجد محادثات',
              style: TextStyle(fontFamily: 'Cairo-Medium', fontSize: 18),
            ),
          );
        }

        final conversations = snapshot.data!.docs;

        conversations.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTimestamp = aData['lastMessageTimestamp'] as Timestamp?;
          final bTimestamp = bData['lastMessageTimestamp'] as Timestamp?;
          if (aTimestamp == null || bTimestamp == null) {
            return 0;
          }
          return bTimestamp.compareTo(aTimestamp);
        });

        return ListView.builder(
          itemCount: conversations.length,
          itemBuilder: (context, index) {
            final conversation =
                conversations[index].data() as Map<String, dynamic>;
            final participants =
                conversation['participants'] as List<dynamic>? ?? [];

            if (participants.isEmpty || participants.length < 2) {
              return SizedBox.shrink();
            }

            final otherUserUid = participants.firstWhere(
              (uid) => uid != widget.myUid,
              orElse: () => '',
            );

            if (conversation['lastMessageText'] == null ||
                conversation['lastMessageText'].isEmpty ||
                otherUserUid.isEmpty) {
              return SizedBox.shrink();
            }

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(otherUserUid)
                  .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return ListTile(title: Text('جاري التحميل...'));
                }

                if (userSnapshot.hasError) {
                  return ListTile(title: Text('خطأ في تحميل بيانات المستخدم'));
                }

                final otherUser =
                    userSnapshot.data?.data() as Map<String, dynamic>? ?? {};

                return Card(
                    elevation: 0,
                    margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: otherUser['gender'] == 'انثى'
                            ? Colors.red
                            : Colors.blue[100],
                        child: otherUser['gender'] == 'انثى'
                            ? FaIcon(FontAwesomeIcons.userSecret,
                                color: Colors.white)
                            : (otherUser['image'] != null &&
                                    otherUser['image'].isNotEmpty
                                ? null
                                : FaIcon(FontAwesomeIcons.user,
                                    color: Colors.blue[700])),
                        backgroundImage: otherUser['gender'] != 'انثى' &&
                                otherUser['image'] != null &&
                                otherUser['image'].isNotEmpty
                            ? NetworkImage(otherUser['image'])
                            : null,
                      ),
                      title: Text(
                        otherUser['name'] ?? 'مستخدم غير معروف',
                        style:
                            TextStyle(fontFamily: 'Cairo-Medium', fontSize: 14),
                      ),
                      subtitle: Text(
                        conversation['lastMessageText'] ?? '',
                        style: TextStyle(fontFamily: 'Cairo'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatTimestamp(
                                conversation['lastMessageTimestamp']),
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          SizedBox(height: 4),
                          Builder(
                            builder: (context) {
                              int unreadCount = ((conversation['unreadCount']
                                          as Map<String, dynamic>?)?[
                                      widget.myUid] ??
                                  0) as int;
                              if (unreadCount > 0) {
                                return Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '$unreadCount',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  ),
                                );
                              } else {
                                return SizedBox.shrink();
                              }
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        _openChatPage(conversations[index].id, otherUserUid,
                            otherUser['name'] ?? 'مستخدم غير معروف');
                      },
                    ));
              },
            );
          },
        );
      },
    );
  }

  void _openChatPage(
      String conversationId, String otherUserUid, String otherUserName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          conversationId: conversationId,
          myUid: widget.myUid,
          otherUserUid: otherUserUid,
          otherUserName: otherUserName,
        ),
      ),
    );
  }
}

class ChatSearchPage extends StatefulWidget {
  final String myUid;

  const ChatSearchPage({Key? key, required this.myUid}) : super(key: key);

  @override
  _ChatSearchPageState createState() => _ChatSearchPageState();
}

class _ChatSearchPageState extends State<ChatSearchPage> {
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  DocumentSnapshot? _lastDocument;
  static const int _limit = 10;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'ابحث عن مستخدم...',
            hintStyle:
                TextStyle(color: Colors.white70, fontFamily: 'Cairo-Medium'),
            border: InputBorder.none,
            prefixIcon: FaIcon(FontAwesomeIcons.search, color: Colors.white70),
          ),
          style: TextStyle(color: Colors.white, fontFamily: 'Cairo-Medium'),
          onChanged: (value) {
            _filterUsers(value);
          },
        ),
        backgroundColor: Colors.blue[700],
      ),
      body: _buildUserList(),
    );
  }

  Widget _buildUserList() {
    return ListView.builder(
      itemCount: _filteredUsers.length + 1,
      itemBuilder: (context, index) {
        if (index < _filteredUsers.length) {
          final user = _filteredUsers[index];
          return Card(
            elevation: 0,
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    user['gender'] == 'انثى' ? Colors.red : Colors.blue[100],
                child: user['gender'] == 'انثى'
                    ? FaIcon(FontAwesomeIcons.userSecret, color: Colors.white)
                    : (user['image'] != null && user['image'].isNotEmpty
                        ? null
                        : FaIcon(FontAwesomeIcons.user,
                            color: Colors.blue[700])),
                backgroundImage: user['gender'] != 'انثى' &&
                        user['image'] != null &&
                        user['image'].isNotEmpty
                    ? NetworkImage(user['image'])
                    : null,
              ),
              title: Text(
                user['name'] ?? '',
                style: TextStyle(fontFamily: 'Cairo-Medium', fontSize: 14),
              ),
              subtitle: Text(
                '${user['schoolId'] == '49937465' ? 'نور الخليج الأهلية' : user['schoolId'] == '69329646' ? 'مريم للصفوف التكميلية' : user['schoolId'] == '02702009' ? 'ثانوية الخليج الأهلية' : user['schoolId'] ?? 'مدرسة غير معروفة'} • ${user['type'] ?? ''}',
                style: TextStyle(fontSize: 12),
              ),
              trailing: FaIcon(FontAwesomeIcons.comment,
                  size: 16, color: Colors.blue[700]),
              onTap: () {
                _openChatPage(user['userUid'], user['name']);
              },
            ),
          );
        } else if (_hasMore) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _fetchMoreUsers,
                      child: Text('تحميل المزيد',
                          style: TextStyle(fontFamily: 'Cairo-Medium')),
                    ),
            ),
          );
        } else {
          return SizedBox.shrink();
        }
      },
    );
  }

  void _fetchUsers() async {
    setState(() {
      _isLoading = true;
    });

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .orderBy('name')
        .limit(_limit)
        .get();

    setState(() {
      _allUsers = snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
      _filteredUsers = List.from(_allUsers);
      _isLoading = false;
      _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      _hasMore = snapshot.docs.length == _limit;
    });
  }

  void _fetchMoreUsers() async {
    if (_isLoading || _lastDocument == null) return;

    setState(() {
      _isLoading = true;
    });

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .orderBy('name')
        .startAfterDocument(_lastDocument!)
        .limit(_limit)
        .get();

    setState(() {
      _allUsers.addAll(snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList());
      _filteredUsers = List.from(_allUsers);
      _isLoading = false;
      _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      _hasMore = snapshot.docs.length == _limit;
    });
  }

  void _filterUsers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = List.from(_allUsers);
      } else {
        _filteredUsers = _allUsers
            .where((user) =>
                user['name'].toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _openChatPage(String otherUserUid, String otherUserName) async {
    String conversationId =
        await _getConversationId(widget.myUid, otherUserUid);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          conversationId: conversationId,
          myUid: widget.myUid,
          otherUserUid: otherUserUid,
          otherUserName: otherUserName,
        ),
      ),
    );
  }

  Future<String> _getConversationId(String uid1, String uid2) async {
    final sortedUids = [uid1, uid2]..sort();
    final conversationId = sortedUids.join('_');

    final conversationDoc = await FirebaseFirestore.instance
        .collection('Conversations')
        .doc(conversationId)
        .get();

    if (!conversationDoc.exists) {
      await FirebaseFirestore.instance
          .collection('Conversations')
          .doc(conversationId)
          .set({
        'participants': sortedUids,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageText': '',
        'unreadCount': {
          uid1: 0,
          uid2: 0,
        },
      });
    }

    return conversationId;
  }
}

String formatTimestamp(Timestamp? timestamp) {
  if (timestamp == null) return '';

  DateTime dateTime = timestamp.toDate();
  DateTime now = DateTime.now();

  if (dateTime.year == now.year &&
      dateTime.month == now.month &&
      dateTime.day == now.day) {
    return DateFormat('HH:mm').format(dateTime);
  } else if (dateTime.year == now.year) {
    return DateFormat('dd/MM - HH:mm').format(dateTime);
  } else {
    return DateFormat('dd/MM/yyyy - HH:mm').format(dateTime);
  }
}

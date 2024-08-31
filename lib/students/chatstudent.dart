import 'package:any_link_preview/any_link_preview.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:photo_view/photo_view.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

class Comment {
  final String content;
  final String id;
  final String senderId;
  final Timestamp timestamp;

  Comment({
    required this.content,
    required this.id,
    required this.senderId,
    required this.timestamp,
  });

  factory Comment.fromMap(Map<String, dynamic> data) {
    return Comment(
      content: data['content'],
      id: data['id'],
      senderId: data['senderId'],
      timestamp: data['timestamp'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'id': id,
      'senderId': senderId,
      'timestamp': timestamp,
    };
  }
}

class Message {
  final String subject;
  final Timestamp date;
  final String division;
  final String messages;
  final List<String> readBy;
  final String stage;
  final String teacherUid;
  final String? fileName;
  final int? fileSize;
  final String? link;
  final int? duration;
  final Map<String, dynamic>? poll;
  final String id;
  final bool allowComments;
  final List<Comment> comments;
  final Map<String, List<String>> reactions;

  Message({
    required this.subject,
    required this.date,
    required this.division,
    required this.messages,
    required this.readBy,
    required this.stage,
    required this.teacherUid,
    this.fileName,
    this.fileSize,
    this.link,
    this.duration,
    this.poll,
    required this.id,
    required this.allowComments,
    required this.comments,
    required this.reactions,
  });

  factory Message.fromMap(Map<String, dynamic> data, String id) {
    return Message(
      subject: data['Subject'],
      date: data['date'],
      division: data['division'],
      messages: data['messages'],
      readBy: (data['readBy'] as List<dynamic>).cast<String>(),
      stage: data['stage'],
      teacherUid: data['teacherUid'],
      fileName: data['fileName'],
      fileSize: data['fileSize'],
      link: data['link'],
      duration: data['duration'],
      poll:
          data['poll'] != null ? Map<String, dynamic>.from(data['poll']) : null,
      id: id,
      allowComments: data['allowComments'] ?? false,
      comments: (data['comments'] as List<dynamic>?)
              ?.map((c) => Comment.fromMap(c))
              .toList() ??
          [],
      reactions: (data['reactions'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, List<String>.from(value)),
          ) ??
          {},
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String grade;
  final String section;
  final String subject;
  final Function? onMessageRead;
  final String schoolId; // Add this line

  const ChatScreen({
    Key? key,
    required this.grade,
    required this.section,
    required this.subject,
    this.onMessageRead,
    required this.schoolId, // Add this line
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final auth.User? _currentUser = auth.FirebaseAuth.instance.currentUser;
  final TextEditingController _messageController = TextEditingController();
  List<Message> _messages = [];
  late Stream<QuerySnapshot> _messagesStream;
  Map<String, String> _userNames = {};
  bool _canSendMessage = false;
  FlutterSoundPlayer? _soundPlayer;
  bool _isPlaying = false;
  String? _currentlyPlayingUrl;
  bool _isScreenActive = true;
  bool _isValidUrl(String text) {
    final urlRegExp = RegExp(
      r"^(http:\/\/www\.|https:\/\/www\.|http:\/\/|https:\/\/)?[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(:[0-9]{1,5})?(\/.*)?$",
      caseSensitive: false,
      multiLine: false,
    );
    return urlRegExp.hasMatch(text);
  }

  Widget _buildLinkPreview(String url) {
    return AnyLinkPreview(
      link: url,
      displayDirection: UIDirection.uiDirectionVertical,
      showMultimedia: true,
      bodyMaxLines: 5,
      bodyTextOverflow: TextOverflow.ellipsis,
      titleStyle: TextStyle(
        color: Colors.black,
        fontSize: 15,
      ),
      bodyStyle: TextStyle(color: Colors.grey, fontSize: 12),
      errorBody: 'لا يمكن تحميل معاينة الرابط',
      errorTitle: 'خطأ',
      errorWidget: Container(
        color: Colors.grey[300],
        child: Text('فشل تحميل معاينة الرابط'),
      ),
      errorImage: "https://google.com/",
      cache: Duration(days: 7),
      backgroundColor: Colors.white,
      borderRadius: 12,
      removeElevation: false,
      boxShadow: [BoxShadow(blurRadius: 3, color: Colors.grey)],
      onTap: () => _launchUrl(url), // تم تغيير هذا السطر
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        throw 'لا يمكن فتح الرابط: $url';
      }
    } catch (e) {
      print('خطأ في فتح الرابط: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء محاولة فتح الرابط: $e')),
      );
    } /*  */
  }

  Future<void> _markMessageAsRead(String messageId) async {
    if (_currentUser != null && _isScreenActive) {
      await _firestore
          .collection('Channels')
          .doc(widget.schoolId)
          .collection('schoolMessages')
          .doc(messageId)
          .update({
        'readBy': FieldValue.arrayUnion([_currentUser.uid])
      });
      widget.onMessageRead?.call();
    }
  }

  Future<void> _toggleLike(Message message) async {
    if (_currentUser == null) return;

    DocumentReference docRef = _firestore
        .collection('Channels')
        .doc(widget.schoolId)
        .collection('schoolMessages')
        .doc(message.id);

    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      Map<String, List<String>> reactions =
          (data['reactions'] as Map<String, dynamic>?)?.map(
                (key, value) => MapEntry(key, List<String>.from(value)),
              ) ??
              {};

      if (!reactions.containsKey('❤️')) {
        reactions['❤️'] = [];
      }

      if (reactions['❤️']!.contains(_currentUser.uid)) {
        reactions['❤️']!.remove(_currentUser.uid);
      } else {
        reactions['❤️']!.add(_currentUser.uid);
      }

      transaction.update(docRef, {'reactions': reactions});
    });
  }

  @override
  void initState() {
    super.initState();
    _isScreenActive = true;
    _setupMessagesListener();
    timeago.setLocaleMessages('ar', timeago.ArMessages());
    _initSoundPlayer();
    _markAllMessagesAsRead();
  }

  @override
  void dispose() {
    _isScreenActive = false;
    _messageController.dispose();
    _soundPlayer?.closePlayer();
    _soundPlayer = null;
    super.dispose();
  }

  Future<void> _initSoundPlayer() async {
    _soundPlayer = FlutterSoundPlayer();
    await _soundPlayer!.openPlayer();
  }

  void _setupMessagesListener() {
    _messagesStream = _firestore
        .collection('Channels')
        .doc(widget.schoolId)
        .collection('schoolMessages')
        .where('stage', isEqualTo: widget.grade)
        .where('Subject', isEqualTo: widget.subject)
        .where('division', isEqualTo: widget.section)
        .orderBy('date', descending: true)
        .limit(50)
        .snapshots();

    _messagesStream.listen((snapshot) {
      if (_isScreenActive) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            _markMessageAsRead(change.doc.id);
          }
        }
      }
    });
  }

  Future<void> _markAllMessagesAsRead() async {
    QuerySnapshot querySnapshot = await _firestore
        .collection('Channels')
        .doc(widget.schoolId)
        .collection('schoolMessages')
        .where('stage', isEqualTo: widget.grade)
        .where('Subject', isEqualTo: widget.subject)
        .where('division', isEqualTo: widget.section)
        .where('readBy', arrayContains: _currentUser!.uid)
        .get();

    for (var doc in querySnapshot.docs) {
      await _markMessageAsRead(doc.id);
    }
  }

  Future<String> _getUserName(String uid) async {
    if (_userNames.containsKey(uid)) {
      return _userNames[uid]!;
    }

    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(uid).get();
    if (userDoc.exists) {
      String name = userDoc.get('name') as String;
      _userNames[uid] = name;
      return name;
    }
    return 'مستخدم غير معروف';
  }

  Future<void> _sendMessage() async {
    if (!_canSendMessage || _messageController.text.trim().isEmpty) return;

    if (_messageController.text.startsWith("/poll ")) {
      List<String> pollParts = _messageController.text.split("\n");
      String question = pollParts[0].substring(6);
      List<String> options = pollParts.sublist(1);

      await _firestore
          .collection('Channels')
          .doc(widget.schoolId)
          .collection('schoolMessages')
          .add({
        'Subject': widget.subject,
        'allowComments': true,
        'date': Timestamp.now(),
        'division': widget.section,
        'messages': "Poll",
        'readBy': [_currentUser?.uid],
        'stage': widget.grade,
        'teacherUid': _currentUser?.uid,
        'poll': {
          'question': question,
          'options': options,
          'votes': {},
        },
        'comments': [],
      });
    } else {
      await _firestore
          .collection('Channels')
          .doc(widget.schoolId)
          .collection('schoolMessages')
          .add({
        'Subject': widget.subject,
        'allowComments': true,
        'date': Timestamp.now(),
        'division': widget.section,
        'messages': _messageController.text,
        'readBy': [_currentUser?.uid],
        'stage': widget.grade,
        'teacherUid': _currentUser?.uid,
        'comments': [],
      });
    }

    _messageController.clear();
  }

  Future<void> _sendComment(Message message, String commentContent) async {
    if (commentContent.trim().isEmpty) return;

    final newComment = Comment(
      content: commentContent,
      id: Uuid().v4(),
      senderId: _currentUser!.uid,
      timestamp: Timestamp.now(),
    );

    await _firestore
        .collection('Channels')
        .doc(widget.schoolId)
        .collection('schoolMessages')
        .doc(message.id)
        .update({
      'comments': FieldValue.arrayUnion([newComment.toMap()]),
    });
  }

  String _getTimeAgo(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return 'قبل ${(difference.inDays / 365).floor()} سنة';
    } else if (difference.inDays > 30) {
      return 'قبل ${(difference.inDays / 30).floor()} شهر';
    } else if (difference.inDays > 0) {
      return 'قبل ${difference.inDays} يوم';
    } else if (difference.inHours > 0) {
      return 'قبل ${difference.inHours} ساعة';
    } else if (difference.inMinutes > 0) {
      return 'قبل ${difference.inMinutes} دقيقة';
    } else {
      return 'الآن';
    }
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => Scaffold(
        body: Container(
          child: PhotoView(
            imageProvider: CachedNetworkImageProvider(imageUrl),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
          ),
        ),
      ),
    ));
  }

  Future<void> _playAudio(String url) async {
    if (_isPlaying && _currentlyPlayingUrl == url) {
      await _soundPlayer!.stopPlayer();
      setState(() {
        _isPlaying = false;
        _currentlyPlayingUrl = null;
      });
    } else {
      setState(() {
        _isPlaying = true;
        _currentlyPlayingUrl = url;
      });
      await _soundPlayer!.startPlayer(
        fromURI: url,
        whenFinished: () {
          setState(() {
            _isPlaying = false;
            _currentlyPlayingUrl = null;
          });
        },
      );
    }
  }

  Widget _buildAudioMessageWidget(Message message) {
    bool isCurrentlyPlaying =
        _isPlaying && _currentlyPlayingUrl == message.link;

    int minutes = (message.duration ?? 0) ~/ 60;
    int seconds = (message.duration ?? 0) % 60;

    return Row(
      children: [
        IconButton(
          icon: Icon(isCurrentlyPlaying ? Icons.stop : Icons.play_arrow),
          onPressed: () => _playAudio(message.link!),
        ),
        Text(
          'المدة: ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
          style: TextStyle(color: Colors.black),
        ),
      ],
    );
  }

  Widget _buildPollWidget(Message message) {
    if (message.poll == null) return SizedBox.shrink();

    String question = message.poll!['question'];
    List<String> options =
        (message.poll!['options'] as List<dynamic>).cast<String>();
    Map<String, List<String>> votes =
        (message.poll!['votes'] as Map<String, dynamic>).map((key, value) =>
            MapEntry(key, (value as List<dynamic>).cast<String>()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question, style: TextStyle(color: Colors.black)),
        SizedBox(height: 8),
        ...options.map((option) {
          int voteCount = votes[option]?.length ?? 0;
          bool hasVoted = votes[option]?.contains(_currentUser?.uid) ?? false;
          return ListTile(
            title: Text(option, style: TextStyle(color: Colors.black)),
            trailing:
                Text('$voteCount صوت', style: TextStyle(color: Colors.black)),
            tileColor: hasVoted ? Colors.blue.withOpacity(0.1) : null,
            onTap: () => _vote(message, option),
          );
        }),
      ],
    );
  }

  Future<void> _vote(Message message, String option) async {
    if (_currentUser == null) return;

    DocumentReference docRef = _firestore
        .collection('Channels')
        .doc(widget.schoolId)
        .collection('schoolMessages')
        .doc(message.id);

    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      Map<String, dynamic> poll = Map<String, dynamic>.from(data['poll']);
      Map<String, List<String>> votes = (poll['votes'] as Map<String, dynamic>)
          .map((key, value) =>
              MapEntry(key, (value as List<dynamic>).cast<String>()));

      votes.forEach((key, value) {
        value.remove(_currentUser.uid);
      });

      if (!votes.containsKey(option)) {
        votes[option] = [];
      }
      votes[option]!.add(_currentUser.uid);

      poll['votes'] = votes;
      transaction.update(docRef, {'poll': poll});
    });
  }

  Widget _buildMessageWidget(Message message) {
    bool userLiked =
        message.reactions['❤️']?.contains(_currentUser?.uid) ?? false;
    int likeCount = message.reactions['❤️']?.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<String>(
          future: _getUserName(message.teacherUid),
          builder: (context, snapshot) {
            final userName = snapshot.data ?? 'مستخدم غير معروف';
            return Container(
              margin: EdgeInsets.only(left: 50, right: 10, top: 5, bottom: 5),
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: message.teacherUid == _currentUser?.uid
                    ? Colors.blue[100]
                    : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الإستاذ ' + userName,
                    style: TextStyle(color: Colors.blue),
                  ),
                  SizedBox(height: 5),
                  if (message.messages == "Poll" && message.poll != null)
                    _buildPollWidget(message)
                  else if (message.messages == "Image" && message.link != null)
                    GestureDetector(
                      onTap: () => _showFullScreenImage(context, message.link!),
                      child: CachedNetworkImage(
                        imageUrl: message.link!,
                        placeholder: (context, url) =>
                            CircularProgressIndicator(),
                        errorWidget: (context, url, error) => Icon(Icons.error),
                        width: 200,
                        fit: BoxFit.cover,
                      ),
                    )
                  else if (message.messages == "Audio" && message.link != null)
                    _buildAudioMessageWidget(message)
                  else if (_isValidUrl(message.messages))
                    GestureDetector(
                      onTap: () => _launchUrl(message.messages),
                      child: _buildLinkPreview(message.messages),
                    )
                  else
                    Text(
                      message.messages,
                      style: TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                    ),
                  SizedBox(height: 5),
                  Text(
                    _getTimeAgo(message.date),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          },
        ),
        // زر الإعجاب خارج فقاعة الرسالة
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text('$likeCount'),
              IconButton(
                icon: Icon(
                  Icons.favorite,
                  color: userLiked ? Colors.red : Colors.grey,
                  size: 20,
                ),
                onPressed: () => _toggleLike(message),
              ),
            ],
          ),
        ),
        if (message.allowComments)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton(
                onPressed: () => _showCommentDialog(message),
                child: Text('إضافة تعليق'),
              ),
              ...message.comments
                  .take(3)
                  .map((comment) => _buildCommentWidget(comment)),
              if (message.comments.length > 3)
                TextButton(
                  onPressed: () => _showAllCommentsDialog(message),
                  child:
                      Text('عرض جميع التعليقات (${message.comments.length})'),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildCommentWidget(Comment comment) {
    return FutureBuilder<String>(
      future: _getUserName(comment.senderId),
      builder: (context, snapshot) {
        final userName = snapshot.data ?? 'مستخدم غير معروف';
        return Container(
          margin: EdgeInsets.only(left: 50, top: 5),
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(userName, style: TextStyle(color: Colors.green)),
              Text(comment.content, style: TextStyle(color: Colors.black)),
              Text(
                _getTimeAgo(comment.timestamp),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCommentDialog(Message message) {
    final commentController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إضافة تعليق'),
        content: TextField(
          controller: commentController,
          decoration: InputDecoration(hintText: 'اكتب تعليقك هنا'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              _sendComment(message, commentController.text);
              Navigator.pop(context);
            },
            child: Text('إرسال'),
          ),
        ],
      ),
    );
  }

  void _showAllCommentsDialog(Message message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('جميع التعليقات'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: message.comments
                .map((comment) => _buildCommentWidget(comment))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.grade} ${widget.section} ${widget.subject}'),
      ),
      body: Container(
        decoration: BoxDecoration(
            //color: Colors.amberAccent,
            // image: DecorationImage(
            //   image: AssetImage('images/Artboard.jpg'),
            //   fit: BoxFit.cover,
            // ),
            ),
        child: Column(
          children: <Widget>[
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _messagesStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('حدث خطأ: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  _messages = snapshot.data!.docs
                      .map((doc) => Message.fromMap(
                          doc.data() as Map<String, dynamic>, doc.id))
                      .toList();
                  _messages.sort((a, b) => b.date.compareTo(a.date));
                  for (var message in _messages) {
                    if (!message.readBy.contains(_currentUser?.uid) &&
                        _isScreenActive) {
                      _markMessageAsRead(message.id);
                    }
                  }
                  return ListView.builder(
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageWidget(message);
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالة...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      enabled: _canSendMessage,
                    ),
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.send),
                    onPressed: _canSendMessage ? _sendMessage : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

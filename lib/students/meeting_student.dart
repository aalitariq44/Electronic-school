import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:to_users/chat_interface.dart';

class MeetingStudent extends StatefulWidget {
  final String schoolId;
  final String myUid;
  final String myName;
  final String otherUserUid;
  final String otherUserName;
  final String grade;
  final String section;

  const MeetingStudent({
    Key? key,
    required this.schoolId,
    required this.myUid,
    required this.otherUserUid,
    required this.otherUserName,
    required this.grade,
    required this.section,
    required this.myName,
  }) : super(key: key);

  @override
  _MeetingStudentState createState() => _MeetingStudentState();
}

class _MeetingStudentState extends State<MeetingStudent> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
    _markConversationAsRead();
  }

  void _markConversationAsRead() async {
    DocumentSnapshot conversationDoc =
        await _firestore.collection('MeetingChat').doc(widget.schoolId).get();

    Map<String, dynamic> unreadCount =
        (conversationDoc.data() as Map<String, dynamic>)['unreadCount'] ?? {};
    unreadCount[widget.myUid] = 0;

    await _firestore.collection('MeetingChat').doc(widget.schoolId).update({
      'unreadCount': unreadCount,
    });

    QuerySnapshot messages = await _firestore
        .collection('MeetingChat')
        .doc(widget.schoolId)
        .collection(widget.grade + widget.section)
        .where('senderId', isEqualTo: widget.otherUserUid)
        .where('status', isNotEqualTo: 'read')
        .get();

    WriteBatch batch = _firestore.batch();
    for (DocumentSnapshot doc in messages.docs) {
      batch.update(doc.reference, {'status': 'read'});
    }
    await batch.commit();
  }

  Stream<QuerySnapshot> _getMessagesStream() {
    return _firestore
        .collection('MeetingChat')
        .doc(widget.schoolId)
        .collection(widget.grade + widget.section)
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots();
  }

  Future<QuerySnapshot> _loadMoreMessages(DocumentSnapshot lastDocument) {
    return _firestore
        .collection('MeetingChat')
        .doc(widget.schoolId)
        .collection(widget.grade + widget.section)
        .orderBy('timestamp', descending: true)
        .startAfterDocument(lastDocument)
        .limit(10)
        .get();
  }

  void _sendMessageToFirestore(String content, String type) async {
    final message = {
      'senderId': widget.myUid,
      'receiverId': widget.otherUserUid,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'type': type,
      'status': 'sent',
      'senderName': widget.myName,
    };

    await _firestore
        .collection('MeetingChat')
        .doc(widget.schoolId)
        .collection(widget.grade + widget.section)
        .add(message);

    await _firestore.collection('MeetingChat').doc(widget.schoolId).update({
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'lastMessageText':
          type == 'text' ? content : '${type.capitalize()} message',
    });

    DocumentSnapshot conversationDoc =
        await _firestore.collection('MeetingChat').doc(widget.schoolId).get();

    Map<String, dynamic> unreadCount =
        (conversationDoc.data() as Map<String, dynamic>)['unreadCount'] ?? {};
    int currentUnreadCount = unreadCount[widget.otherUserUid] ?? 0;

    await _firestore.collection('MeetingChat').doc(widget.schoolId).update({
      'unreadCount.${widget.otherUserUid}': currentUnreadCount + 1,
    });
  }

  Future<void> _deleteMessage(String messageId) async {
    await _firestore
        .collection('MeetingChat')
        .doc(widget.schoolId)
        .collection(widget.grade + widget.section)
        .doc(messageId)
        .delete();
  }

  Future<String> _uploadFile(File file, String folder) async {
    String fileName = path.basename(file.path);
    Reference firebaseStorageRef = _storage.ref().child('$folder/$fileName');

    UploadTask uploadTask = firebaseStorageRef.putFile(file);
    TaskSnapshot taskSnapshot = await uploadTask;
    String downloadUrl = await taskSnapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.otherUserName + ' ' + widget.grade + ' ' + widget.section),
        backgroundColor: Colors.deepOrange,
      ),
      body: ChatInterface(
        conversationId: widget.schoolId,
        myUid: widget.myUid,
        otherUserUid: widget.otherUserUid,
        otherUserName: widget.otherUserName,
        onSendMessage: _sendMessageToFirestore,
        messagesStream: _getMessagesStream(),
        loadMoreMessages: _loadMoreMessages,
        onDeleteMessage: _deleteMessage,
        onUploadFile: _uploadFile,
        primaryColor: Colors.deepOrange,
        secondaryColor: Colors.grey[300]!,
        myName: widget.myName,
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';

class MyPosts extends StatefulWidget {
  final String myUid;

  const MyPosts({super.key, required this.myUid});

  @override
  _MyPostsState createState() => _MyPostsState();
}

class _MyPostsState extends State<MyPosts> {
  final TextEditingController _postController = TextEditingController();
  late Stream<QuerySnapshot> _postsStream;
  File? _image;
  Map<String, bool> _isLikeLoading = {};

  Future<String> _getSchoolName(String schoolId) async {
    try {
      DocumentSnapshot schoolDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .get();
      return schoolDoc['shName'] ?? 'مدرسة غير معروفة';
    } catch (e) {
      print('Error fetching school name: $e');
      return 'مدرسة غير معروفة';
    }
  }

  void _showEditPostDialog(
      BuildContext context, String postId, String currentText) {
    TextEditingController _editController =
        TextEditingController(text: currentText);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('تعديل المنشور'),
          content: TextField(
            controller: _editController,
            maxLength: 240,
            maxLines: null,
            decoration: InputDecoration(
              hintText: 'اكتب منشورك هنا...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              child: Text('إلغاء'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text('حفظ التعديلات'),
              onPressed: () {
                if (_editController.text.isNotEmpty) {
                  _updatePost(postId, _editController.text);
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
              ),
            ),
          ],
        );
      },
    );
  }

  void _updatePost(String postId, String newText) async {
    try {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        'text': newText,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تحديث المنشور بنجاح')),
      );
    } catch (e) {
      print('Error updating post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('حدث خطأ أثناء تحديث المنشور. الرجاء المحاولة مرة أخرى.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _initPostsStream();
  }

  void _initPostsStream() {
    _postsStream = FirebaseFirestore.instance
        .collection('posts')
        .where('uid', isEqualTo: widget.myUid)
        .orderBy('date', descending: true)
        .snapshots();
  }

  void _showDeleteConfirmation(BuildContext context, String postId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من أنك تريد حذف هذا المنشور؟'),
          actions: [
            TextButton(
              child: Text('إلغاء', style: TextStyle(color: Colors.black)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('حذف', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _deletePost(postId);
              },
            ),
          ],
        );
      },
    );
  }

  void _deletePost(String postId) async {
    try {
      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حذف المنشور بنجاح')),
      );
    } catch (e) {
      print('Error deleting post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('حدث خطأ أثناء حذف المنشور. الرجاء المحاولة مرة أخرى.')),
      );
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => Scaffold(
        body: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            color: Colors.black,
            child: Center(
              child: PhotoView(
                imageProvider: NetworkImage(imageUrl),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
              ),
            ),
          ),
        ),
      ),
    ));
  }

  Future<void> _uploadPostWithImage(String text, File? image) async {
    try {
      String? imageUrl;
      if (image != null) {
        final compressedImage = await FlutterImageCompress.compressWithFile(
          image.absolute.path,
          minWidth: 1024,
          minHeight: 1024,
          quality: 30,
        );

        if (compressedImage != null) {
          final tempDir = await Directory.systemTemp.createTemp();
          final tempFile = File('${tempDir.path}/compressed_image.jpg');
          await tempFile.writeAsBytes(compressedImage);

          final ref = FirebaseStorage.instance
              .ref()
              .child('post_images')
              .child('${DateTime.now().toIso8601String()}.jpg');

          await ref.putFile(tempFile);
          imageUrl = await ref.getDownloadURL();

          await tempFile.delete();
        }
      }

      await FirebaseFirestore.instance.collection('posts').add({
        'text': text,
        'uid': FirebaseAuth.instance.currentUser?.uid,
        'date': FieldValue.serverTimestamp(),
        'likes': {},
        'comments': [],
        'imageUrl': imageUrl,
      });
    } catch (e) {
      print('Error creating post in background: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => setState(() => _initPostsStream()),
        child: StreamBuilder<QuerySnapshot>(
          stream: _postsStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return Center(child: CircularProgressIndicator());
            return ListView(
              children: snapshot.data!.docs.map((doc) {
                var data = doc.data() as Map<String, dynamic>;
                return FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .where('userUid', isEqualTo: data['uid'])
                      .get(),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData ||
                        userSnapshot.data!.docs.isEmpty) {
                      return SizedBox.shrink();
                    }
                    var userData = userSnapshot.data!.docs.first.data()
                        as Map<String, dynamic>;
                    return _buildPostCard(context, doc.id, data, userData);
                  },
                );
              }).toList(),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewPostDialog(context),
        child: FaIcon(FontAwesomeIcons.plus),
        backgroundColor: Colors.blue[700],
      ),
    );
  }

  Widget _buildPostCard(BuildContext context, String docId,
      Map<String, dynamic> data, Map<String, dynamic> userData) {
    bool isCurrentUserPost =
        data['uid'] == FirebaseAuth.instance.currentUser?.uid;

    return Card(
      margin: EdgeInsets.all(10),
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.grey[300],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundImage: userData['image']?.isNotEmpty == true
                  ? NetworkImage(userData['image'])
                  : null,
              child: userData['image']?.isEmpty != false
                  ? FaIcon(FontAwesomeIcons.user)
                  : null,
            ),
            title: Text(
              userData['name'] ?? 'Unknown User',
              style: TextStyle(
                fontFamily: 'Cairo-Medium',
              ),
            ),
            subtitle: FutureBuilder<String>(
              future: _getSchoolName(userData['schoolId'] ?? ''),
              builder: (context, snapshot) {
                return Text(
                  '${snapshot.data ?? 'جاري التحميل...'} • ${userData['type'] ?? ''} • ${_formatDate(data['date'])}',
                  style: TextStyle(fontSize: 12),
                );
              },
            ),
            trailing: isCurrentUserPost
                ? PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert),
                    onSelected: (String result) {
                      if (result == 'edit') {
                        _showEditPostDialog(context, docId, data['text']);
                      } else if (result == 'delete') {
                        _showDeleteConfirmation(context, docId);
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: ListTile(
                          leading: FaIcon(FontAwesomeIcons.edit, size: 20),
                          title: Text('تعديل'),
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: ListTile(
                          leading: FaIcon(FontAwesomeIcons.trash, size: 20),
                          title: Text('حذف'),
                        ),
                      ),
                    ],
                  )
                : null,
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              data['text'] ?? '',
              style: TextStyle(fontSize: 16),
            ),
          ),
          if (data['imageUrl'] != null) ...[
            GestureDetector(
              onTap: () => _showFullScreenImage(context, data['imageUrl']),
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(data['imageUrl']),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
          _buildInteractionRow(context, docId, data),
        ],
      ),
    );
  }

  Widget _buildInteractionRow(
      BuildContext context, String docId, Map<String, dynamic> data) {
    return Padding(
      padding: EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInteractionButton(
            onTap: () => _handleLike(docId),
            icon: _isLikeLoading[docId] == true
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : FaIcon(
                    _userLikedPost(data['likes'],
                            FirebaseAuth.instance.currentUser?.uid)
                        ? FontAwesomeIcons.solidHeart
                        : FontAwesomeIcons.heart,
                    color: _userLikedPost(data['likes'],
                            FirebaseAuth.instance.currentUser?.uid)
                        ? Colors.red
                        : Colors.grey,
                    size: 20,
                  ),
            label: "${_getLikesCount(data['likes'])} اعجاب",
          ),
          _buildInteractionButton(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => CommentsWidget(postId: docId))),
            icon:
                FaIcon(FontAwesomeIcons.comment, color: Colors.blue, size: 20),
            label:
                "${(data['comments'] as List<dynamic>?)?.length ?? 0} تعليقات",
          ),
        ],
      ),
    );
  }

  bool _userLikedPost(dynamic likes, String? userId) {
    if (likes is Map) {
      return likes.containsKey(userId);
    }
    return false;
  }

  int _getLikesCount(dynamic likes) {
    if (likes is Map) {
      return likes.length;
    }
    return 0;
  }

  Widget _buildInteractionButton(
      {required VoidCallback onTap,
      required Widget icon,
      required String label}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            icon,
            SizedBox(width: 8),
            Text(label, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  void _showNewPostDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text('إنشاء منشور جديد'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _postController,
                        maxLength: 240,
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: 'اكتب منشورك هنا...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 10),
                      _image != null
                          ? Image.file(_image!, height: 100)
                          : SizedBox(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              await _pickImage();
                              setState(() {});
                            },
                            icon: FaIcon(FontAwesomeIcons.image, size: 14),
                            label: Text('إضافة صورة',
                                style: TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              minimumSize: Size(110, 36),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('سيتم دعم نشر الفيديو قريبا')),
                              );
                            },
                            icon: FaIcon(FontAwesomeIcons.video, size: 14),
                            label: Text('إضافة فيديو',
                                style: TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              minimumSize: Size(110, 36),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    child: Text('إلغاء'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _image = null;
                    },
                  ),
                  ElevatedButton(
                    child: Text('نشر'),
                    onPressed: () {
                      if (_postController.text.isNotEmpty || _image != null) {
                        _createNewPost(_postController.text);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700]),
                  ),
                ],
              );
            },
          );
        });
  }

  void _createNewPost(String text) {
    if (_image != null || text.isNotEmpty) {
      _uploadPostWithImage(text, _image);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('جاري نشر المنشور في الخلفية...')),
      );
      setState(() {
        _image = null;
        _postController.clear();
      });
      Navigator.of(context).pop();
    }
  }

  void _handleLike(String postId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() {
      _isLikeLoading[postId] = true;
    });

    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final post = await transaction.get(postRef);
        if (!post.exists) throw Exception('Post does not exist!');

        final currentTime = Timestamp.now();
        Map<String, dynamic> likes =
            Map<String, dynamic>.from(post['likes'] ?? {});

        if (likes.containsKey(userId)) {
          likes.remove(userId);
        } else {
          likes[userId] = {'timestamp': currentTime, 'isRead': false};
        }

        transaction.update(postRef, {'likes': likes});
      });
    } catch (e) {
      print('Error handling like: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('حدث خطأ أثناء تحديث الإعجاب. الرجاء المحاولة مرة أخرى.')),
      );
    } finally {
      setState(() {
        _isLikeLoading[postId] = false;
      });
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'تاريخ غير معروف';
    if (timestamp is Timestamp) {
      DateTime date = timestamp.toDate();
      Duration difference = DateTime.now().difference(date);
      if (difference.inDays > 0)
        return DateFormat('yyyy-MM-dd HH:mm').format(date);
      if (difference.inHours > 0) return 'قبل ${difference.inHours} ساعة';
      if (difference.inMinutes > 0) return 'قبل ${difference.inMinutes} دقيقة';
      return 'الآن';
    }
    return 'تاريخ غير صالح';
  }
}

class CommentsWidget extends StatefulWidget {
  final String postId;

  CommentsWidget({required this.postId});

  @override
  _CommentsWidgetState createState() => _CommentsWidgetState();
}

class _CommentsWidgetState extends State<CommentsWidget> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        Future.delayed(Duration(milliseconds: 300), () {
          Scrollable.ensureVisible(context, alignment: 1.0);
        });
      }
    });
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'تاريخ غير معروف';
    DateTime date;
    if (timestamp is int) {
      date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else {
      return 'تاريخ غير صالح';
    }

    Duration difference = DateTime.now().difference(date);
    if (difference.inDays > 0) {
      return 'قبل ${difference.inDays} ${difference.inDays == 1 ? 'يوم' : 'أيام'}';
    } else if (difference.inHours > 0) {
      return 'قبل ${difference.inHours} ${difference.inHours == 1 ? 'ساعة' : 'ساعات'}';
    } else if (difference.inMinutes > 0) {
      return 'قبل ${difference.inMinutes} ${difference.inMinutes == 1 ? 'دقيقة' : 'دقائق'}';
    } else {
      return 'الآن';
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('التعليقات'),
        backgroundColor: Colors.blue[700],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());
                var comments = List<Map<String, dynamic>>.from(
                    snapshot.data!['comments'] ?? []);
                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    var comment = comments[index];
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              comment['userImage']?.isNotEmpty == true
                                  ? NetworkImage(comment['userImage'])
                                  : null,
                          child: comment['userImage']?.isEmpty != false
                              ? FaIcon(FontAwesomeIcons.user)
                              : null,
                        ),
                        title: Text(
                          comment['userName'],
                          style: TextStyle(
                            fontFamily: 'Cairo-Medium',
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(comment['text']),
                            SizedBox(height: 4),
                            Text(
                              _formatDate(comment['timestamp']),
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(8.0),
            color: Colors.grey[200],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'اكتب تعليقك...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                  ),
                ),
                SizedBox(width: 8.0),
                ElevatedButton(
                  onPressed: () {
                    if (_commentController.text.isNotEmpty) {
                      _addComment(widget.postId, _commentController.text);
                      _commentController.clear();
                    }
                  },
                  child: FaIcon(FontAwesomeIcons.paperPlane),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    shape: CircleBorder(),
                    padding: EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addComment(String postId, String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('يجب عليك تسجيل الدخول لإضافة تعليق.')));
      return;
    }

    try {
      QuerySnapshot userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('userUid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        var userData = userQuery.docs.first.data() as Map<String, dynamic>;
        String userName = userData['name'] ?? 'مستخدم مجهول';
        String userImage = userData['image'] ?? '';

        int timestamp = DateTime.now().millisecondsSinceEpoch;
        print('Timestamp being stored: $timestamp');

        final comment = {
          'text': text,
          'userId': user.uid,
          'userName': userName,
          'userImage': userImage,
          'timestamp': timestamp,
        };

        await FirebaseFirestore.instance
            .collection('posts')
            .doc(postId)
            .update({
          'comments': FieldValue.arrayUnion([comment]),
          'lastCommentAt': timestamp,
        });

        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تمت إضافة التعليق بنجاح.')));
      } else {
        print('لم يتم العثور على بيانات المستخدم');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'حدث خطأ أثناء إضافة التعليق. لم يتم العثور على بيانات المستخدم.')));
      }
    } catch (e) {
      print('خطأ في إضافة التعليق: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('حدث خطأ أثناء إضافة التعليق. الرجاء المحاولة مرة أخرى.')));
    }
  }
}

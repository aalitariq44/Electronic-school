import 'dart:async';
import 'dart:io';

import 'package:any_link_preview/any_link_preview.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:to_users/techers/chat/colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

class ChatPage extends StatefulWidget {
  final String grade;
  final String subject;
  final String division; // أضف هذا السطر
  final schoolId;

  ChatPage(
      {required this.grade,
      required this.subject,
      required this.division,
      required this.schoolId}); // عدل هذا السطر

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late String _division; // أضف هذا السطر
  final User? user = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  List<ChatMessage> _messages = [];
  final _textController = TextEditingController();
  bool isLoading = true;
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool isRecording = false;
  String? recordedFilePath;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingAudioId;
  bool _allowComments = false; // متغير جديد لتتبع حالة السماح بالتعليقات
  int _recordDuration = 0;
  Timer? _timer;
  final int _messagesPerPage = 20; // عدد الرسائل في كل صفحة
  DocumentSnapshot? _lastDocument; // آخر وثيقة تم تحميلها
  bool _hasMore = true; // هل هناك المزيد من الرسائل للتحميل
  bool _isLoadingMore = false; // هل جاري تحميل المزيد من الرسائل
  ScrollController _scrollController = ScrollController();
  bool _isSearching = false;
  List<ChatMessage> _searchResults = [];
  bool _showScrollToBottomButton = false;

  @override
  void initState() {
    super.initState();
    print(widget.schoolId);
    _division = widget.division; // أضف هذا السطر

    _initRecorder();
    _loadMessages();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        _loadMoreMessages();
      }

      setState(() {
        _showScrollToBottomButton = _scrollController.offset > 1000;
      });
    });

    UploadService().uploadStream.listen((updatedMessage) {
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == updatedMessage.id);
          if (index != -1) {
            _messages[index] = updatedMessage;
          }
        });
      }
    });
  }

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
    await _recorder.setSubscriptionDuration(const Duration(milliseconds: 10));
  }

  Future<void> _addReaction(ChatMessage message, String emoji) async {
    setState(() {
      final index = _messages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(isReactionLoading: true);
      }
    });

    final userId = user!.uid;
    Map<String, Set<String>> updatedReactions = Map.from(message.reactions);

    if (updatedReactions.containsKey(emoji)) {
      if (updatedReactions[emoji]!.contains(userId)) {
        updatedReactions[emoji]!.remove(userId);
        if (updatedReactions[emoji]!.isEmpty) {
          updatedReactions.remove(emoji);
        }
      } else {
        updatedReactions[emoji]!.add(userId);
      }
    } else {
      updatedReactions[emoji] = {userId};
    }

    try {
      await _firestore
          .collection('Channels')
          .doc(widget.schoolId)
          .collection('schoolMessages')
          .doc(message.id)
          .update({
        'reactions':
            updatedReactions.map((key, value) => MapEntry(key, value.toList())),
      });

      setState(() {
        final index = _messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(
            reactions: updatedReactions,
            isReactionLoading: false,
          );
        }
      });
    } catch (e) {
      print('Error adding reaction: $e');
      setState(() {
        final index = _messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          _messages[index] =
              _messages[index].copyWith(isReactionLoading: false);
        }
      });
    }
  }

  Widget _buildReactionButton(ChatMessage message) {
    final heartReactions = message.reactions['❤️']?.length ?? 0;

    return GestureDetector(
      onTap: () => _addReaction(message, '❤️'),
      onLongPress: () => _showReactionOptions(message),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              FontAwesomeIcons.heart,
              size: 16,
              color: message.reactions.containsKey('❤️') &&
                      message.reactions['❤️']!.contains(user!.uid)
                  ? accentColor
                  : Colors.grey,
            ),
            if (heartReactions > 0) ...[
              SizedBox(width: 4),
              Text(
                heartReactions.toString(),
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showReactionOptions(ChatMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['❤️', '👍', '👎', '😂'].map((emoji) {
            return GestureDetector(
              onTap: () {
                _addReaction(message, emoji);
                Navigator.of(context).pop();
              },
              child: Text(emoji, style: TextStyle(fontSize: 24)),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    try {
      // Remove from Firestore
      await _firestore
          .collection('Channels')
          .doc(widget.schoolId)
          .collection('schoolMessages')
          .doc(message.id)
          .delete();

      // Remove from local state
      setState(() {
        _messages.removeWhere((m) => m.id == message.id);
      });

      // If it's an image or file, delete from storage as well
      if (message.type == MessageType.image ||
          message.type == MessageType.file ||
          message.type == MessageType.audio) {
        if (message.fileUrl != null) {
          await _storage.refFromURL(message.fileUrl!).delete();
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حذف الرسالة بنجاح')),
      );
    } catch (e) {
      print('Error deleting message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء حذف الرسالة')),
      );
    }
  }

  void _showAllComments(ChatMessage message) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return ListView(
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'جميع التعليقات',
                style: TextStyle(
                  fontSize: 18,
                ),
              ),
            ),
            ...message.comments
                .map((comment) => _buildCommentWidget(comment))
                .toList(),
          ],
        );
      },
    );
  }

  Future<String> _getUserName(String uid) async {
    try {
      QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('userUid', isEqualTo: uid)
          .limit(1)
          .get();
      if (userQuery.docs.isNotEmpty) {
        Map<String, dynamic> userData =
            userQuery.docs.first.data() as Map<String, dynamic>;
        return userData['name'] ?? 'مستخدم مجهول';
      }
    } catch (e) {
      print('Error fetching user name: $e');
    }
    return 'مستخدم مجهول';
  }

  void _showImageSelectionOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('التقاط صورة من الكاميرا'),
                onTap: () {
                  Navigator.pop(context);
                  _handleImageSelection(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.image),
                title: Text('الاختيار من المعرض'),
                onTap: () {
                  Navigator.pop(context);
                  _handleImageSelection(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreatePollDialog() {
    final questionController = TextEditingController();
    final optionsControllers = [
      TextEditingController(),
      TextEditingController()
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('إنشاء استفتاء'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: questionController,
                  decoration: InputDecoration(labelText: 'السؤال'),
                ),
                ...optionsControllers.asMap().entries.map((entry) {
                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: entry.value,
                          decoration: InputDecoration(
                              labelText: 'الخيار ${entry.key + 1}'),
                        ),
                      ),
                      if (entry.key == optionsControllers.length - 1)
                        IconButton(
                          icon: Icon(Icons.add),
                          onPressed: () {
                            setState(() {
                              optionsControllers.add(TextEditingController());
                            });
                          },
                        ),
                    ],
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('إلغاء'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('إرسال'),
              onPressed: () {
                final question = questionController.text.trim();
                final options = optionsControllers
                    .map((controller) => controller.text.trim())
                    .where((option) => option.isNotEmpty)
                    .toList();

                if (question.isNotEmpty && options.length >= 2) {
                  Navigator.of(context).pop();
                  _sendPollMessage(question, options);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendPollMessage(String question, List<String> options) async {
    final messageId = Uuid().v4();
    final poll = Poll(question: question, options: options);
    final newMessage = ChatMessage(
      id: messageId,
      senderId: user!.uid,
      content: 'Poll',
      timestamp: DateTime.now(),
      type: MessageType.poll,
      poll: poll,
      isSent: false,
    );

    setState(() {
      _messages.insert(0, newMessage);
    });

    UploadService().sendPoll(messageId, widget.grade, widget.subject, user!.uid,
        poll, _division, widget.schoolId);
  }

  Future<void> _handleVote(ChatMessage message, String option) async {
    if (message.poll == null) return;

    final updatedVotes = Map<String, List<String>>.from(message.poll!.votes);

    // Remove vote from other options
    updatedVotes.forEach((key, value) {
      updatedVotes[key] = value.where((id) => id != user!.uid).toList();
    });

    // Add vote to selected option
    if (!updatedVotes.containsKey(option)) {
      updatedVotes[option] = [];
    }
    updatedVotes[option]!.add(user!.uid);

    try {
      await _firestore
          .collection('Channels')
          .doc(widget.schoolId)
          .collection('schoolMessages')
          .doc(message.id)
          .update({
        'poll.votes': updatedVotes,
      });

      setState(() {
        final index = _messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          final updatedPoll = Poll(
            question: message.poll!.question,
            options: message.poll!.options,
            votes: updatedVotes,
          );
          _messages[index] = _messages[index].copyWith(poll: updatedPoll);
        }
      });
    } catch (e) {
      print('Error voting: $e');
    }
  }

  void _showBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: FaIcon(FontAwesomeIcons.camera, color: primaryColor),
                title: Text('التقاط صورة من الكاميرا'),
                onTap: () {
                  Navigator.pop(context);
                  _handleImageSelection(ImageSource.camera);
                },
              ),
              ListTile(
                leading: FaIcon(FontAwesomeIcons.images, color: primaryColor),
                title: Text('الاختيار من المعرض'),
                onTap: () {
                  Navigator.pop(context);
                  _handleImageSelection(ImageSource.gallery);
                },
              ),
              ListTile(
                leading:
                    FaIcon(FontAwesomeIcons.paperclip, color: primaryColor),
                title: Text('إرفاق ملف'),
                onTap: () {
                  Navigator.pop(context);
                  _handleFileSelection();
                },
              ),
              ListTile(
                leading: FaIcon(FontAwesomeIcons.chartBar, color: primaryColor),
                title: Text('إنشاء استفتاء'),
                onTap: () {
                  Navigator.pop(context);
                  _showCreatePollDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<File> compressImage(File file) async {
    final filePath = file.absolute.path;
    final lastIndex = filePath.lastIndexOf(RegExp(r'.jp'));
    final splitted = filePath.substring(0, (lastIndex));
    final outPath = "${splitted}_compressed.jpg";
    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      outPath,
      quality: 30,
    );
    return File(result!.path);
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: EdgeInsets.all(8.0),
      child: Center(
        child: SizedBox(
          width: 32.0,
          height: 32.0,
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  void _handleSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _searchResults.clear();
      } else {
        _searchResults = _messages.where((message) {
          if (message.type == MessageType.text) {
            return message.content.toLowerCase().contains(query.toLowerCase());
          } else if (message.type == MessageType.file ||
              message.type == MessageType.audio) {
            return message.fileName
                    ?.toLowerCase()
                    .contains(query.toLowerCase()) ??
                false;
          }
          return false;
        }).toList();
      }
    });
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      0,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Widget _buildTextWithLinks(String text) {
    final urlRegExp = RegExp(r"https?://\S+");
    final matches = urlRegExp.allMatches(text);

    if (matches.isEmpty) {
      return Text(text);
    }

    List<InlineSpan> textSpans = [];
    int lastMatchEnd = 0;

    for (var match in matches) {
      if (match.start > lastMatchEnd) {
        textSpans
            .add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }

      final url = text.substring(match.start, match.end);
      final shortenedUrl = _shortenUrl(url);
      textSpans.add(
        WidgetSpan(
          child: GestureDetector(
            onTap: () async {
              if (await canLaunch(url)) {
                await launch(url);
              } else {
                print('Could not launch $url');
              }
            },
            child: Text(
              shortenedUrl,
              style: TextStyle(
                //color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      );

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      textSpans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return RichText(
      text: TextSpan(
        children: textSpans,
        style: DefaultTextStyle.of(context).style,
      ),
    );
  }

  String _shortenUrl(String url) {
    final uri = Uri.parse(url);
    String shortenedUrl = uri.host;
    if (uri.path.isNotEmpty && uri.path != '/') {
      shortenedUrl +=
          uri.path.length > 15 ? uri.path.substring(0, 15) + '...' : uri.path;
    }
    return shortenedUrl;
  }

  Widget _buildLinkPreview(String url) {
    return GestureDetector(
      onTap: () async {
        if (await canLaunch(url)) {
          await launch(url);
        } else {
          print('Could not launch $url');
        }
      },
      child: AnyLinkPreview(
        link: url,
        displayDirection: UIDirection.uiDirectionVertical,
        showMultimedia: true,
        bodyMaxLines: 3,
        bodyTextOverflow: TextOverflow.ellipsis,
        titleStyle: TextStyle(
          color: Colors.black,
          //,
          fontSize: 15,
        ),
        bodyStyle: TextStyle(color: Colors.grey, fontSize: 12),
        errorWidget: Container(
          color: Colors.grey[300],
          child: Text('لم يتم تحميل معاينة الرابط'),
        ),
        cache: Duration(days: 7),
        backgroundColor: Colors.white,
        borderRadius: 12,
        removeElevation: true, // تم تغيير هذا الخيار لإزالة الظل
        boxShadow: [], // تم إزالة الظل
      ),
    );
  }

  List<String> _extractUrls(String text) {
    final urlRegExp = RegExp(r"https?://\S+");
    return urlRegExp.allMatches(text).map((match) => match.group(0)!).toList();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _recorder.closeRecorder();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      final String filePath = 'audio_${Uuid().v4()}.aac';
      await _recorder.startRecorder(toFile: filePath);
      setState(() {
        isRecording = true;
        _recordDuration = 0;
      });
      _startTimer();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Microphone permission not granted')),
      );
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (Timer t) {
      setState(() => _recordDuration++);
    });
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => Scaffold(
        body: Container(
          child: PhotoView(
            imageProvider: NetworkImage(imageUrl),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
            initialScale: PhotoViewComputedScale.contained,
            heroAttributes: PhotoViewHeroAttributes(tag: imageUrl),
          ),
        ),
      ),
    ));
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    recordedFilePath = await _recorder.stopRecorder();
    final duration = _recordDuration; // حفظ المدة
    setState(() {
      isRecording = false;
    });

    if (recordedFilePath != null) {
      final messageId = Uuid().v4();
      final newMessage = ChatMessage(
        id: messageId,
        senderId: user!.uid,
        content: 'Audio',
        timestamp: DateTime.now(),
        type: MessageType.audio,
        fileUrl: recordedFilePath,
        fileName: 'audio_${DateTime.now().millisecondsSinceEpoch}.aac',
        fileSize: File(recordedFilePath!).lengthSync(),
        isUploading: true,
        duration: duration,
      );

      setState(() {
        _messages.insert(0, newMessage);
      });

      UploadService().uploadAudio(
          File(recordedFilePath!),
          messageId,
          widget.grade,
          widget.subject,
          user!.uid,
          duration,
          _division,
          widget.schoolId);
    }
  }

  Future<void> _uploadAudioFile(
      File file, String messageId, int duration) async {
    try {
      final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.aac';
      final storageRef = _storage.ref().child('audio/$fileName');
      final uploadTask = await storageRef.putFile(file);
      final fileUrl = await uploadTask.ref.getDownloadURL();

      final updatedMessage =
          _messages.firstWhere((m) => m.id == messageId).copyWith(
                fileUrl: fileUrl,
                isUploading: false,
                isSent: true,
                duration: duration, // إضافة المدة
              );

      setState(() {
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          _messages[index] = updatedMessage;
        }
      });

      await _firestore
          .collection('Channels')
          .doc(widget.schoolId)
          .collection('schoolMessages')
          .doc(messageId)
          .set({
        'Subject': widget.subject,
        'date': DateTime.now(),
        'messages': 'Audio',
        'readBy': [user!.uid],
        'stage': widget.grade,
        'teacherUid': user!.uid,
        'link': fileUrl,
        'fileName': fileName,
        'fileSize': file.lengthSync(),
        'duration': duration, // إرسال المدة إلى قاعدة البيانات
      });
    } catch (e) {
      print('Error uploading audio file: $e');
      setState(() {
        _messages.removeWhere((m) => m.id == messageId);
      });
    }
  }

  Future<void> _loadMessages() async {
    if (!_hasMore) return;
    setState(() {
      isLoading = true;
    });

    try {
      Query query = _firestore
          .collection('Channels')
          .doc(widget.schoolId)
          .collection('schoolMessages')
          .where('stage', isEqualTo: widget.grade)
          .where('Subject', isEqualTo: widget.subject)
          .where('division', isEqualTo: _division) // أضف هذا السطر
          .orderBy('date', descending: true)
          .limit(_messagesPerPage);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final querySnapshot = await query.get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _hasMore = false;
          isLoading = false;
        });
        return;
      }

      _lastDocument = querySnapshot.docs.last;

      final List<ChatMessage> newMessages = await Future.wait(
        querySnapshot.docs.map((doc) async {
          final data = doc.data() as Map<String, dynamic>;

          // معالجة التعليقات
          final comments = await Future.wait(
            (data['comments'] as List<dynamic>? ?? []).map((c) async {
              final senderName = await _getUserName(c['senderId']);
              return Comment(
                id: c['id'],
                senderId: c['senderId'],
                content: c['content'],
                timestamp: (c['timestamp'] as Timestamp).toDate(),
                senderName: senderName,
              );
            }),
          );

          // معالجة التفاعلات
          final reactionsData =
              data['reactions'] as Map<String, dynamic>? ?? {};
          final reactions = reactionsData.map((key, value) =>
              MapEntry(key, (value as List).cast<String>().toSet()));

          // معالجة بيانات الاستفتاء
          Poll? poll;
          if (data['messages'] == 'Poll' && data['poll'] != null) {
            poll = Poll.fromMap(data['poll'] as Map<String, dynamic>);
          }

          return ChatMessage(
            id: doc.id,
            senderId: data['teacherUid'],
            content: data['messages'],
            timestamp: (data['date'] as Timestamp).toDate(),
            type: _getMessageType(data),
            fileUrl: data['link'],
            fileName: data['fileName'],
            fileSize: data['fileSize'],
            allowComments: data['allowComments'] ?? false,
            comments: comments,
            reactions: reactions,
            duration: data['duration'],
            poll: poll,
          );
        }),
      );

      setState(() {
        _messages.addAll(newMessages);
        isLoading = false;
      });
    } catch (e) {
      print('Error loading messages: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() {
      _isLoadingMore = true;
    });

    try {
      Query query = _firestore
          .collection('Channels')
          .doc(widget.schoolId)
          .collection('schoolMessages')
          .where('stage', isEqualTo: widget.grade)
          .where('Subject', isEqualTo: widget.subject)
          .where('division', isEqualTo: _division) // أضف هذا السطر
          .orderBy('date', descending: true)
          .limit(_messagesPerPage);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final querySnapshot = await query.get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoadingMore = false;
        });
        return;
      }

      _lastDocument = querySnapshot.docs.last;

      final List<ChatMessage> newMessages = await Future.wait(
        querySnapshot.docs.map((doc) async {
          final data = doc.data() as Map<String, dynamic>;

          // معالجة التعليقات
          final comments = await Future.wait(
            (data['comments'] as List<dynamic>? ?? []).map((c) async {
              final senderName = await _getUserName(c['senderId']);
              return Comment(
                id: c['id'],
                senderId: c['senderId'],
                content: c['content'],
                timestamp: (c['timestamp'] as Timestamp).toDate(),
                senderName: senderName,
              );
            }),
          );

          // معالجة التفاعلات
          final reactionsData =
              data['reactions'] as Map<String, dynamic>? ?? {};
          final reactions = reactionsData.map((key, value) =>
              MapEntry(key, (value as List).cast<String>().toSet()));

          // معالجة بيانات الاستفتاء
          Poll? poll;
          if (data['messages'] == 'Poll' && data['poll'] != null) {
            poll = Poll.fromMap(data['poll'] as Map<String, dynamic>);
          }

          return ChatMessage(
            id: doc.id,
            senderId: data['teacherUid'],
            content: data['messages'],
            timestamp: (data['date'] as Timestamp).toDate(),
            type: _getMessageType(data),
            fileUrl: data['link'],
            fileName: data['fileName'],
            fileSize: data['fileSize'],
            allowComments: data['allowComments'] ?? false,
            comments: comments,
            reactions: reactions,
            duration: data['duration'],
            poll: poll,
            isSent: true,
            isUploading: false,
          );
        }),
      );

      setState(() {
        _messages.addAll(newMessages);
        _isLoadingMore = false;
      });
    } catch (e) {
      print('Error loading more messages: $e');
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

// دالة مساعدة لتحديد نوع الرسالة
  MessageType _getMessageType(Map<String, dynamic> data) {
    if (data['messages'] == 'Image') return MessageType.image;
    if (data['messages'] == 'Audio') return MessageType.audio;
    if (data['messages'] == 'File') return MessageType.file;
    if (data['messages'] == 'Poll') return MessageType.poll;
    return MessageType.text;
  }

  Future<void> _handleSendPressed() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final messageId = Uuid().v4();
    final newMessage = ChatMessage(
      id: messageId,
      senderId: user!.uid,
      content: text,
      timestamp: DateTime.now(),
      type: MessageType.text,
      isSent: false,
      allowComments: _allowComments, // إضافة حالة السماح بالتعليقات
    );

    setState(() {
      _messages.insert(0, newMessage);
      _textController.clear();
    });

    UploadService().sendTextMessage(
        messageId,
        text,
        widget.grade,
        widget.subject,
        user!.uid,
        _allowComments, // تمرير حالة السماح بالتعليقات
        _division, // أضف هذا المعامل
        widget.schoolId);
  }

  Future<void> _handleImageSelection(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      final messageId = Uuid().v4();
      final file = File(pickedFile.path);

      // ضغط الصورة
      final compressedFile = await compressImage(file);

      final temporaryMessage = ChatMessage(
        id: messageId,
        senderId: user!.uid,
        content: 'Image',
        timestamp: DateTime.now(),
        type: MessageType.image,
        fileUrl: compressedFile.path,
        isUploading: true,
      );

      setState(() {
        _messages.insert(0, temporaryMessage);
      });

      UploadService().uploadImage(compressedFile, messageId, widget.grade,
          widget.subject, user!.uid, _division, widget.schoolId);
    }
  }

  Future<void> _handleFileSelection() async {
    final result = await FilePicker.platform.pickFiles();

    if (result != null) {
      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final fileSize = await file.length();

      // التحقق من حجم الملف (20 ميجابايت = 20 * 1024 * 1024 بايت)
      if (fileSize > 20 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('لا يمكن إرسال ملف أكبر من 20 ميجابايت')),
        );
        return;
      }

      final messageId = Uuid().v4();

      final newMessage = ChatMessage(
        id: messageId,
        senderId: user!.uid,
        content: 'File',
        timestamp: DateTime.now(),
        type: MessageType.file,
        fileName: fileName,
        fileSize: fileSize,
        isUploading: true,
      );

      setState(() {
        _messages.insert(0, newMessage);
      });

      UploadService().uploadFile(file, messageId, widget.grade, widget.subject,
          user!.uid, _division, widget.schoolId);
    }
  }

  Future<void> _handleMessageTap(ChatMessage message) async {
    if (message.type == MessageType.file || message.type == MessageType.audio) {
      if (message.fileUrl == null) return;

      if (message.type == MessageType.audio) {
        _handleAudioPlayPause(message);
      } else {
        try {
          final localPath =
              await _downloadFile(message.fileUrl!, message.fileName ?? 'file');
          if (localPath != null) {
            final result = await OpenFilex.open(localPath);
            if (result.type != ResultType.done) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not open the file')),
              );
            }
          }
        } catch (e) {
          print('Error opening file: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error opening file')),
          );
        }
      }
    }
  }

  Future<String?> _downloadFile(String url, String fileName) async {
    try {
      final response = await http.get(Uri.parse(url));
      final bytes = response.bodyBytes;
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      print('Error downloading file: $e');
      return null;
    }
  }

  void _handleAudioPlayPause(ChatMessage message) async {
    if (_currentlyPlayingAudioId == message.id) {
      await _audioPlayer.pause();
      setState(() {
        _currentlyPlayingAudioId = null;
      });
    } else {
      if (_currentlyPlayingAudioId != null) {
        await _audioPlayer.stop();
      }

      await _audioPlayer.play(UrlSource(message.fileUrl!));
      setState(() {
        _currentlyPlayingAudioId = message.id;
      });

      _audioPlayer.onPlayerComplete.listen((event) {
        setState(() {
          _currentlyPlayingAudioId = null;
        });
      });
    }
  }

  Future<void> _addComment(ChatMessage message, String commentContent) async {
    if (!message.allowComments) return;

    final commentId = Uuid().v4();
    final senderName = await _getUserName(user!.uid);
    final newComment = Comment(
      id: commentId,
      senderId: user!.uid,
      content: commentContent,
      timestamp: DateTime.now(),
      senderName: senderName,
    );

    try {
      await _firestore
          .collection('Channels')
          .doc(widget.schoolId)
          .collection('schoolMessages')
          .doc(message.id)
          .update({
        'comments': FieldValue.arrayUnion([
          {
            'id': commentId,
            'senderId': user!.uid,
            'content': commentContent,
            'timestamp': Timestamp.now(),
            'senderName': senderName,
          }
        ])
      });

      setState(() {
        final index = _messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(
            comments: [..._messages[index].comments, newComment],
          );
        }
      });
    } catch (e) {
      print('Error adding comment: $e');
    }
  }

  void _showCommentDialog(ChatMessage message) {
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
            child: Text('إلغاء'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text('إرسال'),
            onPressed: () {
              if (commentController.text.isNotEmpty) {
                _addComment(message, commentController.text);
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(ChatMessage message) {
    switch (message.type) {
      case MessageType.text:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextWithLinks(message.content),
            ..._extractUrls(message.content).map((url) => Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: _buildLinkPreview(url),
                )),
          ],
        );
      case MessageType.image:
        return Hero(
          tag: message.fileUrl ?? '',
          child: GestureDetector(
            onTap: () => _showFullScreenImage(message.fileUrl ?? ''),
            child: message.isUploading
                ? Image.file(
                    File(message.fileUrl ?? ''),
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Icon(Icons.broken_image, size: 100),
                  )
                : CachedNetworkImage(
                    imageUrl: message.fileUrl ?? '',
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (context, url, error) =>
                        Icon(Icons.broken_image, size: 100),
                  ),
          ),
        );
      case MessageType.audio:
        return _buildAudioMessageWidget(message);
      case MessageType.file:
        return _buildFileMessageWidget(message);
      case MessageType.poll:
        return _buildPollWidget(message);
      default:
        return SizedBox.shrink();
    }
  }

  Widget _buildPollWidget(ChatMessage message) {
    if (message.poll == null) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message.poll!.question,
          style: TextStyle(),
        ),
        SizedBox(height: 8),
        ...message.poll!.options.map((option) {
          final voteCount = message.poll!.votes[option]?.length ?? 0;
          final hasVoted =
              message.poll!.votes[option]?.contains(user!.uid) ?? false;
          return GestureDetector(
            onTap: () => _handleVote(message, option),
            child: Container(
              margin: EdgeInsets.only(bottom: 4),
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: hasVoted
                    ? Colors.blue.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(option)),
                  Text('$voteCount ${voteCount == 1 ? 'صوت' : 'أصوات'}'),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: _isSearching
            ? TextField(
                autofocus: true,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'البحث في المحادثة...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: _handleSearch,
              )
            : Text(
                '${widget.grade} ${_division} - ${widget.subject}',
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
        actions: [
          IconButton(
            icon: FaIcon(_isSearching
                ? FontAwesomeIcons.xmark
                : FontAwesomeIcons.magnifyingGlass),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchResults.clear();
                }
              });
            },
          ),
          Switch(
            value: _allowComments,
            onChanged: (value) {
              setState(() {
                _allowComments = value;
              });
            },
            activeColor: secondaryColor,
            inactiveThumbColor: Colors.grey,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_isSearching)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'نتائج البحث: ${_searchResults.length}',
                    style: TextStyle(),
                  ),
                ),
              Expanded(
                child: isLoading && _messages.isEmpty
                    ? Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        itemCount: _isSearching
                            ? _searchResults.length
                            : (_messages.length + (_hasMore ? 1 : 0)),
                        itemBuilder: (context, index) {
                          if (!_isSearching && index == _messages.length) {
                            return _buildLoadingIndicator();
                          }
                          final message = _isSearching
                              ? _searchResults[index]
                              : _messages[index];
                          return _buildMessageWidget(message);
                        },
                      ),
              ),
              _buildInputArea(),
            ],
          ),
          if (_showScrollToBottomButton)
            Positioned(
              right: 20,
              bottom: 80,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: primaryColor,
                child: FaIcon(FontAwesomeIcons.arrowDown, color: Colors.white),
                onPressed: _scrollToBottom,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageWidget(ChatMessage message) {
    return GestureDetector(
      onLongPress: () {
        if (message.senderId == user!.uid) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('حذف الرسالة'),
                content: Text('هل أنت متأكد من حذف هذه الرسالة؟'),
                actions: <Widget>[
                  TextButton(
                    child: Text('إلغاء'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    child: Text('حذف'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _deleteMessage(message);
                    },
                  ),
                ],
              );
            },
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DefaultTextStyle(
                        style:
                            TextStyle(color: Colors.black, fontFamily: 'cairo'),
                        child: _buildMessageContent(message),
                      ),
                      SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatMessageTime(message.timestamp),
                            style:
                                TextStyle(fontSize: 10, color: Colors.black54),
                          ),
                          if (message.isSent && message.senderId == user!.uid)
                            Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Text(
                                'تم الإرسال',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.black45),
                              ),
                            ),
                          if (message.allowComments)
                            Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.comment,
                                  size: 12, color: Colors.black45),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 4),
                _buildReactionButton(message),
              ],
            ),
          ),
          if (message.allowComments)
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: TextButton(
                child: Text('إضافة تعليق'),
                onPressed: () => _showCommentDialog(message),
              ),
            ),
          ...message.comments
              .take(3)
              .map((comment) => Align(
                    alignment: Alignment.centerRight,
                    child: _buildCommentWidget(comment),
                  ))
              .toList(),
          if (message.comments.length > 3)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                child: Text('عرض المزيد (${message.comments.length - 3})'),
                onPressed: () => _showAllComments(message),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReactionButtons(ChatMessage message) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: ['❤️', '👍', '👎', '😂'].map((emoji) {
        return IconButton(
          icon: Text(emoji),
          onPressed: () => _addReaction(message, emoji),
        );
      }).toList(),
    );
  }

  String _formatMessageTime(DateTime timestamp) {
    final hour = timestamp.hour;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = hour < 12 ? 'صباحاً' : 'مساءً';
    final formattedHour = (hour % 12 == 0 ? 12 : hour % 12).toString();
    return '$formattedHour:$minute $period';
  }

  Widget _buildCommentWidget(Comment comment) {
    return Container(
      margin: EdgeInsets.only(top: 4, left: 16, right: 16),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(FontAwesomeIcons.user, size: 12, color: secondaryColor),
              SizedBox(width: 4),
              Text(
                comment.senderName,
                style: TextStyle(
                  color: secondaryColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            comment.content,
            style: TextStyle(color: textColor),
          ),
          SizedBox(height: 4),
          Text(
            _formatMessageTime(comment.timestamp),
            style: TextStyle(fontSize: 10, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioMessageWidget(ChatMessage message) {
    bool isPlaying = _currentlyPlayingAudioId == message.id;
    bool isAAC = message.fileName?.toLowerCase().endsWith('.aac') ?? false;

    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.amber,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.isUploading)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  ),
                )
              else
                IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.black,
                  ),
                  onPressed: () => _handleAudioPlayPause(message),
                ),
              Flexible(
                child: Text(
                  isAAC ? 'مقطع صوتي' : (message.fileName ?? 'Audio'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (message.duration != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0, top: 4.0),
              child: Text(
                _formatAudioDuration(message.duration!),
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          if (message.isSent)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Text(
                ' ',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }

  String _formatAudioDuration(int seconds) {
    int minutes = seconds ~/ 60;
    seconds %= 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildFileMessageWidget(ChatMessage message) {
    return GestureDetector(
      onTap: () => _handleMessageTap(message),
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.amber,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.insert_drive_file,
                  color: Colors.black,
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.fileName ?? 'File',
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (message.totalSize != null)
                        Text(
                          '${(message.totalSize! / (1024 * 1024)).toStringAsFixed(2)} MB',
                          style: TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (message.isUploading && message.uploadProgress != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 8),
                  LinearProgressIndicator(value: message.uploadProgress),
                  SizedBox(height: 4),
                  Text(
                    'جاري التحميل ${(message.uploadProgress! * 100).toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 12),
                  ),
                  if (message.totalSize != null)
                    Text(
                      '${((message.uploadProgress! * message.totalSize!) / (1024 * 1024)).toStringAsFixed(2)} MB / ${(message.totalSize! / (1024 * 1024)).toStringAsFixed(2)} MB',
                      style: TextStyle(fontSize: 12),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: backgroundColor,
      child: Row(
        children: [
          IconButton(
            icon: FaIcon(
              isRecording ? FontAwesomeIcons.stop : FontAwesomeIcons.microphone,
              color: primaryColor,
            ),
            onPressed: () {
              if (isRecording) {
                _stopRecording();
              } else {
                _startRecording();
              }
            },
          ),
          IconButton(
            icon: FaIcon(FontAwesomeIcons.paperclip, color: primaryColor),
            onPressed: _showBottomSheet,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 2),
              child: TextField(
                controller: _textController,
                decoration: InputDecoration(
                  hintText: 'الرسالة',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
          ),
          if (isRecording)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${_recordDuration ~/ 60}:${(_recordDuration % 60).toString().padLeft(2, '0')}',
                style: TextStyle(color: accentColor),
              ),
            ),
          IconButton(
            icon: FaIcon(FontAwesomeIcons.paperPlane, color: primaryColor),
            onPressed: _handleSendPressed,
          ),
        ],
      ),
    );
  }
}

enum MessageType { text, image, audio, file, poll }

class ChatMessage {
  final String id;
  final String senderId;
  final String content;
  final DateTime timestamp;
  final MessageType type;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final bool isSent;
  final bool allowComments;
  final List<Comment> comments;
  final bool isUploading;
  final Map<String, Set<String>> reactions;
  final int? duration; // مدة المقطع الصوتي بالثواني
  final Poll? poll;
  bool isReactionLoading;
  final double? uploadProgress;
  final int? totalSize;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.content,
    required this.timestamp,
    required this.type,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.isSent = false,
    this.allowComments = false,
    this.comments = const [],
    this.isUploading = false,
    this.reactions = const {},
    this.duration,
    this.poll,
    this.isReactionLoading = false,
    this.uploadProgress,
    this.totalSize,
  });

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? content,
    DateTime? timestamp,
    MessageType? type,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    bool? isSent,
    bool? allowComments,
    List<Comment>? comments,
    bool? isUploading,
    Map<String, Set<String>>? reactions,
    int? duration,
    Poll? poll,
    bool? isReactionLoading,
    double? uploadProgress,
    int? totalSize,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      isSent: isSent ?? this.isSent,
      allowComments: allowComments ?? this.allowComments,
      comments: comments ?? this.comments,
      isUploading: isUploading ?? this.isUploading,
      reactions: reactions ?? this.reactions,
      duration: duration ?? this.duration,
      poll: poll ?? this.poll,
      isReactionLoading: isReactionLoading ?? this.isReactionLoading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      totalSize: totalSize ?? this.totalSize,
    );
  }
}

class Comment {
  final String id;
  final String senderId;
  final String content;
  final DateTime timestamp;
  String senderName;

  Comment({
    required this.id,
    required this.senderId,
    required this.content,
    required this.timestamp,
    this.senderName = 'مستخدم مجهول',
  });
}

class Poll {
  final String question;
  final List<String> options;
  final Map<String, List<String>> votes;

  Poll({
    required this.question,
    required this.options,
    this.votes = const {},
  });

  factory Poll.fromMap(Map<String, dynamic> map) {
    return Poll(
      question: map['question'],
      options: List<String>.from(map['options']),
      votes: Map<String, List<String>>.from(
        map['votes']
            ?.map((key, value) => MapEntry(key, List<String>.from(value))),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options,
      'votes': votes,
    };
  }
}

class UploadService {
  static final UploadService _instance = UploadService._internal();
  factory UploadService() => _instance;
  UploadService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StreamController<ChatMessage> _uploadController =
      StreamController<ChatMessage>.broadcast();

  Stream<ChatMessage> get uploadStream => _uploadController.stream;

  Future<void> uploadImage(File file, String messageId, String grade,
      String subject, String userId, String division, String schoolId) async {
    try {
      final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = _storage.ref().child('images/$fileName');
      final uploadTask = await storageRef.putFile(file);
      final imageUrl = await uploadTask.ref.getDownloadURL();

      final updatedMessage = ChatMessage(
        id: messageId,
        senderId: userId,
        content: 'Image',
        timestamp: DateTime.now(),
        type: MessageType.image,
        fileUrl: imageUrl,
        fileName: fileName,
        fileSize: file.lengthSync(),
        isUploading: false,
        isSent: true,
      );

      await _firestore
          .collection('Channels')
          .doc(schoolId)
          .collection('schoolMessages')
          .doc(messageId)
          .set({
        'Subject': subject,
        'date': DateTime.now(),
        'messages': 'Image',
        'readBy': [userId],
        'stage': grade,
        'teacherUid': userId,
        'link': imageUrl,
        'fileName': fileName,
        'fileSize': file.lengthSync(),
        'division': division,
      });

      _uploadController.add(updatedMessage);
    } catch (e) {
      print('Error uploading image: $e');
      _handleUploadError(messageId, userId, 'Image upload failed');
    }
  }

  Future<void> uploadAudio(
      File file,
      String messageId,
      String grade,
      String subject,
      String userId,
      int duration,
      String division,
      String schoolId) async {
    try {
      final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.aac';
      final storageRef = _storage.ref().child('audio/$fileName');
      final uploadTask = await storageRef.putFile(file);
      final audioUrl = await uploadTask.ref.getDownloadURL();

      final updatedMessage = ChatMessage(
        id: messageId,
        senderId: userId,
        content: 'Audio',
        timestamp: DateTime.now(),
        type: MessageType.audio,
        fileUrl: audioUrl,
        fileName: fileName,
        fileSize: file.lengthSync(),
        isUploading: false,
        isSent: true,
        duration: duration,
      );

      await _firestore
          .collection('Channels')
          .doc(schoolId)
          .collection('schoolMessages')
          .doc(messageId)
          .set({
        'Subject': subject,
        'date': DateTime.now(),
        'messages': 'Audio',
        'readBy': [userId],
        'stage': grade,
        'teacherUid': userId,
        'link': audioUrl,
        'fileName': fileName,
        'fileSize': file.lengthSync(),
        'duration': duration,
        'division': division,
      });

      _uploadController.add(updatedMessage);
    } catch (e) {
      print('Error uploading audio: $e');
      _handleUploadError(messageId, userId, 'Audio upload failed');
    }
  }

  Future<void> uploadFile(File file, String messageId, String grade,
      String subject, String userId, String division, String schoolId) async {
    try {
      final fileName =
          'file_${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final storageRef = _storage.ref().child('files/$fileName');

      final uploadTask = storageRef.putFile(file);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        final updatedMessage = ChatMessage(
          id: messageId,
          senderId: userId,
          content: 'File',
          timestamp: DateTime.now(),
          type: MessageType.file,
          fileName: fileName,
          fileSize: file.lengthSync(),
          isUploading: true,
          uploadProgress: progress,
          totalSize: snapshot.totalBytes,
        );
        _uploadController.add(updatedMessage);
      });

      final snapshot = await uploadTask.whenComplete(() {});
      final fileUrl = await snapshot.ref.getDownloadURL();

      final updatedMessage = ChatMessage(
        id: messageId,
        senderId: userId,
        content: 'File',
        timestamp: DateTime.now(),
        type: MessageType.file,
        fileUrl: fileUrl,
        fileName: fileName,
        fileSize: file.lengthSync(),
        isUploading: false,
        isSent: true,
        uploadProgress: 1.0,
        totalSize: file.lengthSync(),
      );

      await _firestore
          .collection('Channels')
          .doc(schoolId)
          .collection('schoolMessages')
          .doc(messageId)
          .set({
        'Subject': subject,
        'date': DateTime.now(),
        'messages': 'File',
        'readBy': [userId],
        'stage': grade,
        'teacherUid': userId,
        'link': fileUrl,
        'fileName': fileName,
        'fileSize': file.lengthSync(),
        'division': division,
      });

      _uploadController.add(updatedMessage);
    } catch (e) {
      print('Error uploading file: $e');
      _handleUploadError(messageId, userId, 'File upload failed');
    }
  }

  Future<void> sendTextMessage(
      String messageId,
      String content,
      String grade,
      String subject,
      String userId,
      bool allowComments, // إضافة معامل جديد
      String division, // أضف هذا المعامل
      String schoolId) async {
    try {
      final updatedMessage = ChatMessage(
        id: messageId,
        senderId: userId,
        content: content,
        timestamp: DateTime.now(),
        type: MessageType.text,
        isUploading: false,
        isSent: true,
        allowComments: allowComments, // تعيين حالة السماح بالتعليقات
      );

      await _firestore
          .collection('Channels')
          .doc(schoolId)
          .collection('schoolMessages')
          .doc(messageId)
          .set({
        'Subject': subject,
        'date': DateTime.now(),
        'messages': content,
        'readBy': [userId],
        'stage': grade,
        'teacherUid': userId,
        'allowComments': allowComments, // إضافة حقل جديد لحالة التعليقات
        'division': division, // أضف هذا السطر
      });

      _uploadController.add(updatedMessage);
    } catch (e) {
      print('خطأ في إرسال الرسالة النصية: $e');
      _handleUploadError(messageId, userId, 'فشل إرسال الرسالة النصية');
    }
  }

  Future<void> sendPoll(String messageId, String grade, String subject,
      String userId, Poll poll, String division, String schoolId) async {
    try {
      final updatedMessage = ChatMessage(
        id: messageId,
        senderId: userId,
        content: 'Poll',
        timestamp: DateTime.now(),
        type: MessageType.poll,
        isUploading: false,
        isSent: true,
        poll: poll,
      );

      await _firestore
          .collection('Channels')
          .doc(schoolId)
          .collection('schoolMessages')
          .doc(messageId)
          .set({
        'Subject': subject,
        'date': DateTime.now(),
        'messages': 'Poll',
        'readBy': [userId],
        'stage': grade,
        'teacherUid': userId,
        'poll': poll.toMap(),
        'division': division,
      });

      _uploadController.add(updatedMessage);
    } catch (e) {
      print('Error sending poll: $e');
      _handleUploadError(messageId, userId, 'Poll send failed');
    }
  }

  void _handleUploadError(
      String messageId, String userId, String errorMessage) {
    _uploadController.add(ChatMessage(
      id: messageId,
      senderId: userId,
      content: errorMessage,
      timestamp: DateTime.now(),
      type: MessageType.text,
      isUploading: false,
      isSent: false,
    ));
  }
}

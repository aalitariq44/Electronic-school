import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

class ChatInterface extends StatefulWidget {
  final String conversationId;
  final String myUid;
  final String myName;
  final String otherUserUid;
  final String otherUserName;
  final Function(String, String) onSendMessage;
  final Stream<QuerySnapshot> messagesStream;
  final Color primaryColor;
  final Color secondaryColor;
  final Function(String) onDeleteMessage;
  final Future<String> Function(File, String) onUploadFile;
  final Future<QuerySnapshot> Function(DocumentSnapshot) loadMoreMessages;

  const ChatInterface({
    Key? key,
    required this.conversationId,
    required this.myUid,
    required this.otherUserUid,
    required this.otherUserName,
    required this.onSendMessage,
    required this.messagesStream,
    required this.onDeleteMessage,
    required this.onUploadFile,
    required this.loadMoreMessages,
    this.primaryColor = Colors.blue,
    this.secondaryColor = Colors.grey,
    required this.myName,
  }) : super(key: key);

  @override
  _ChatInterfaceState createState() => _ChatInterfaceState();
}

class _ChatInterfaceState extends State<ChatInterface> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  String _recordingDuration = '00:00';
  Timer? _recordingTimer;
  bool _isRecording = false;
  String? _recordingPath;
  DateTime? _recordingStartTime;
  bool _isPlaying = false;
  String _currentAudioUrl = '';
  Map<String, Duration> _audioDurations = {};
  List<QueryDocumentSnapshot> _messages = [];
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastDocument;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
    _setupAudioPlayer();
  }

  Future<void> _initializeRecorder() async {
    await _audioRecorder.openRecorder();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _isPlaying = false;
        _currentAudioUrl = '';
      });
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.closeRecorder();
    _audioPlayer.dispose();
    super.dispose();
  }

  Widget _buildLoadMoreButton() {
    return _isLoadingMore
        ? Center(child: CircularProgressIndicator())
        : TextButton(
            onPressed: _loadMoreMessages,
            child: Text('تحميل المزيد'),
          );
  }

  void _loadMoreMessages() async {
    if (_isLoadingMore || _lastDocument == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    QuerySnapshot querySnapshot = await widget.loadMoreMessages(_lastDocument!);

    setState(() {
      // إضافة الرسائل الجديدة إلى نهاية القائمة (لأن القائمة معكوسة)
      _messages.addAll(querySnapshot.docs);
      _isLoadingMore = false;
      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
      }
    });
  }

  void _showMessageOptions(String messageId) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.delete),
                title: Text('حذف الرسالة'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onDeleteMessage(messageId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _updateRecordingDuration() {
    setState(() {
      final duration = _audioRecorder.isRecording
          ? DateTime.now().difference(_recordingStartTime!)
          : Duration.zero;
      _recordingDuration = _formatDuration(duration);
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: widget.messagesStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  _messages.isEmpty) {
                return Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('حدث خطأ: ${snapshot.error}'));
              }

              if (snapshot.hasData) {
                final newMessages = snapshot.data!.docs;
                if (_messages.isEmpty ||
                    newMessages.first.id != _messages.first.id) {
                  _messages = newMessages;
                  if (_messages.isNotEmpty) {
                    _lastDocument = _messages.last;
                  }
                }
              }

              if (_messages.isEmpty) {
                return Center(child: Text('لا توجد رسائل'));
              }

              return ListView.builder(
                reverse: true,
                controller: _scrollController,
                itemCount: _messages.length + 1, // +1 للزر "تحميل المزيد"
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return _buildLoadMoreButton();
                  }

                  final message =
                      _messages[index].data() as Map<String, dynamic>;
                  final isMe = message['senderId'] == widget.myUid;
                  final messageId = _messages[index].id;

                  return _buildMessageBubble(message, isMe, messageId);
                },
              );
            },
          ),
        ),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildMessageBubble(
      Map<String, dynamic> message, bool isMe, String messageId) {
    return GestureDetector(
      onTap: isMe ? () => _showMessageOptions(messageId) : null,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // إضافة اسم المرسل هنا
            if (!isMe) // نعرض الاسم فقط للرسائل الواردة
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    message['senderName'] ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Cairo-Medium',
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            Row(
              mainAxisAlignment:
                  isMe ? MainAxisAlignment.start : MainAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? widget.primaryColor : widget.secondaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      _buildMessageContent(message),
                      SizedBox(height: 5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTimestamp(message['timestamp']),
                            style: TextStyle(
                              color: isMe ? Colors.white70 : Colors.black54,
                              fontSize: 10,
                            ),
                          ),
                          if (isMe) SizedBox(width: 5),
                          if (isMe)
                            Text(
                              _getMessageStatus(message['status']),
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(Map<String, dynamic> message) {
    switch (message['type']) {
      case 'text':
        return Text(
          message['content'],
          style: TextStyle(
            color: message['senderId'] == widget.myUid
                ? Colors.white
                : Colors.black,
            fontFamily: 'Cairo-Medium',
          ),
        );
      case 'image':
        return GestureDetector(
          onTap: () => _showFullScreenImage(message['content']),
          child: CachedNetworkImage(
            imageUrl: message['content'],
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            placeholder: (context, url) => CircularProgressIndicator(),
            errorWidget: (context, url, error) => Icon(Icons.error),
          ),
        );
      case 'audio':
        return _buildAudioPlayer(message['content']);
      default:
        return Text('Unsupported message type');
    }
  }

  Widget _buildAudioPlayer(String audioSource) {
    bool isCurrentlyPlaying = _isPlaying && _currentAudioUrl == audioSource;

    return FutureBuilder<Duration?>(
      future: _loadAudioDuration(audioSource),
      builder: (context, snapshot) {
        Duration? duration = snapshot.data;

        return Container(
          decoration: BoxDecoration(
            color: widget.primaryColor,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(isCurrentlyPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: () async {
                  if (isCurrentlyPlaying) {
                    await _audioPlayer.pause();
                    setState(() {
                      _isPlaying = false;
                    });
                  } else {
                    if (_currentAudioUrl != audioSource) {
                      await _audioPlayer.stop();
                      await _audioPlayer.play(UrlSource(audioSource));
                      setState(() {
                        _currentAudioUrl = audioSource;
                      });
                    } else {
                      await _audioPlayer.resume();
                    }
                    setState(() {
                      _isPlaying = true;
                    });
                  }
                },
              ),
              SizedBox(width: 8),
              Text(
                _formatDuration(duration ?? Duration.zero),
                style: TextStyle(fontFamily: 'Cairo-Medium'),
              ),
              SizedBox(width: 8),
              Icon(Icons.audiotrack, size: 20),
            ],
          ),
        );
      },
    );
  }

  Future<Duration?> _loadAudioDuration(String audioUrl) async {
    if (!_audioDurations.containsKey(audioUrl)) {
      try {
        await _audioPlayer.setSourceUrl(audioUrl);
        Duration? duration = await _audioPlayer.getDuration();
        if (duration != null) {
          setState(() {
            _audioDurations[audioUrl] = duration;
          });
        }
        return duration;
      } catch (e) {
        print("Error loading audio duration: $e");
        return null;
      }
    }
    return _audioDurations[audioUrl];
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => Scaffold(
        body: Center(
          child: Image.network(imageUrl),
        ),
      ),
    ));
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.image),
            onPressed: _pickImage,
          ),
          IconButton(
            icon: Icon(_isRecording ? Icons.stop : Icons.mic),
            onPressed: _isRecording ? _stopRecording : _startRecording,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: !_isRecording,
              decoration: InputDecoration(
                hintText: _isRecording ? _recordingDuration : 'اكتب رسالة...',
                hintStyle: TextStyle(
                  color: _isRecording ? Colors.red : null,
                  fontWeight: _isRecording ? FontWeight.bold : null,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              style: TextStyle(
                fontFamily: 'Cairo-Medium',
                color: _isRecording ? Colors.red : null,
                fontWeight: _isRecording ? FontWeight.bold : null,
              ),
            ),
          ),
          SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _sendMessage,
            child: FaIcon(FontAwesomeIcons.paperPlane, size: 20),
            backgroundColor: widget.primaryColor,
            mini: true,
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    widget.onSendMessage(messageText, 'text');
    _messageController.clear();
  }

  void _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('التقاط صورة بالكاميرا'),
                onTap: () {
                  Navigator.pop(context);
                  _getImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('اختيار من المعرض'),
                onTap: () {
                  Navigator.pop(context);
                  _getImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _getImage(ImageSource source) async {
    final XFile? image = await _imagePicker.pickImage(source: source);
    if (image != null) {
      setState(() {});

      String imageUrl = await widget.onUploadFile(File(image.path), 'images');
      widget.onSendMessage(imageUrl, 'image');

      setState(() {});
    }
  }

  void _startRecording() async {
    if (_audioRecorder.isRecording) return;
    await _audioRecorder.startRecorder(
      toFile: 'temp_audio.aac',
      codec: Codec.aacADTS,
    );
    _recordingStartTime = DateTime.now();
    _recordingTimer =
        Timer.periodic(Duration(seconds: 1), (_) => _updateRecordingDuration());
    setState(() {
      _isRecording = true;
      _recordingDuration = '00:00';
    });
  }

  void _stopRecording() async {
    if (!_audioRecorder.isRecording) return;
    _recordingPath = await _audioRecorder.stopRecorder();
    _recordingTimer?.cancel();
    setState(() {
      _isRecording = false;
      _recordingDuration = '00:00';
      _recordingStartTime = null;
    });
    if (_recordingPath != null) {
      String audioUrl =
          await widget.onUploadFile(File(_recordingPath!), 'audio');
      widget.onSendMessage(audioUrl, 'audio');
      setState(() {});
    }
  }

  String _getMessageStatus(String? status) {
    switch (status) {
      case 'sent':
        return '';
      case 'delivered':
        return '✓';
      case 'read':
        return '✓✓';
      default:
        return '';
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    DateTime dateTime = timestamp.toDate();
    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

extension StringExtension on String {
  String capitalizeFirstLetter() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}

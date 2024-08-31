import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;

class AIChat extends StatefulWidget {
  @override
  _AIChatState createState() => _AIChatState();
}

class _AIChatState extends State<AIChat> {
  final List<Message> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  Future<void> _sendMessage(String message) async {
    setState(() {
      _messages.add(Message(text: message, isUser: true));
      _isLoading = true;
    });

    final apiKey = 'AIzaSyCp7_uXbIL28FZsSHSkchAbZudkgDhxOAs';
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$apiKey');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': message}
                  ]
                }
              ],
              'generationConfig': {
                'temperature': 0.9,
                'topK': 1,
                'topP': 1,
                'maxOutputTokens': 2048,
                'stopSequences': []
              },
              'safetySettings': []
            }),
          )
          .timeout(Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final reply = data['candidates'][0]['content']['parts'][0]['text'];
          setState(() {
            _messages.add(Message(text: reply, isUser: false));
          });
        } else {
          setState(() {
            _messages.add(Message(
                text: "خطأ: لم يتم العثور على رد في البيانات المستلمة.",
                isUser: false));
          });
        }
      } else {
        setState(() {
          _messages.add(Message(
              text: "خطأ: فشل في الحصول على رد. الكود: ${response.statusCode}",
              isUser: false));
        });
        print("استجابة الخطأ: ${response.body}");
      }
    } catch (e) {
      setState(() {
        _messages.add(Message(text: "خطأ: $e", isUser: false));
      });
      print("استثناء: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[700],
        title: Text(
          'محادثة الذكاء الاصطناعي',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Cairo-Medium',
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: FaIcon(FontAwesomeIcons.arrowRight, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[700]!, Colors.blue[100]!],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return MessageBubble(message: _messages[index]);
                },
              ),
            ),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircularProgressIndicator(color: Colors.white),
              ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: Offset(0, -1),
                  ),
                ],
              ),
              margin: EdgeInsets.all(8.0),
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: FaIcon(FontAwesomeIcons.paperPlane, color: Colors.blue[700]),
                    onPressed: () {
                      if (_textController.text.isNotEmpty) {
                        _sendMessage(_textController.text);
                        _textController.clear();
                      }
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالة...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontFamily: 'Cairo-Medium',
                        ),
                      ),
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'Cairo-Medium',
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: FaIcon(FontAwesomeIcons.microphone, color: Colors.blue[700]),
                    onPressed: () {
                      // Implement voice input functionality
                    },
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

class Message {
  final String text;
  final bool isUser;

  Message({required this.text, required this.isUser});
}

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.blue[100] : Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!message.isUser)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: FaIcon(FontAwesomeIcons.robot, color: Colors.blue[700], size: 20),
              ),
            Flexible(
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 16,
                  color: message.isUser ? Colors.black87 : Colors.black,
                  fontFamily: 'Cairo-Medium',
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
            if (message.isUser)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FaIcon(FontAwesomeIcons.user, color: Colors.blue[700], size: 20),
              ),
          ],
        ),
      ),
    );
  }
}
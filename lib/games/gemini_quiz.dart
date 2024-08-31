import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class GeminiQuiz extends StatefulWidget {
  @override
  _GeminiQuizState createState() => _GeminiQuizState();
}

class _GeminiQuizState extends State<GeminiQuiz> {
  String _currentQuestion = '';
  bool? _correctAnswer;
  int _score = 0;
  bool _isLoading = false;

  Future<void> _getNextQuestion() async {
    setState(() {
      _isLoading = true;
    });

    final apiKey = 'AIzaSyCp7_uXbIL28FZsSHSkchAbZudkgDhxOAs';
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$apiKey');

    try {
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {
                      'text':
                          'قم بإنشاء سؤال صح أم خطأ مع الإجابة الصحيحة. قم بتنسيق الإجابة على هذا النحو: "السؤال: [السؤال هنا] | الإجابة: [صح أو خطأ]"'
                    }
                  ]
                }
              ],
              'generationConfig': {
                'temperature': 0.7,
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
          final parts = reply.split('|');
          if (parts.length == 2) {
            final question = parts[0].trim().replaceFirst('السؤال:', '').trim();
            final answer = parts[1]
                .trim()
                .replaceFirst('الإجابة:', '')
                .trim()
                .toLowerCase();
            setState(() {
              _currentQuestion = question;
              _correctAnswer = answer == 'صح';
            });
          } else {
            setState(() {
              _currentQuestion =
                  "حدث خطأ في تنسيق السؤال. يرجى المحاولة مرة أخرى.";
            });
          }
        } else {
          setState(() {
            _currentQuestion = "لم يتم العثور على سؤال في البيانات المستلمة.";
          });
        }
      } else {
        setState(() {
          _currentQuestion =
              "فشل في الحصول على سؤال من Gemini AI. الكود: ${response.statusCode}";
        });
        print("استجابة الخطأ: ${response.body}");
      }
    } catch (e) {
      setState(() {
        _currentQuestion = "خطأ: $e";
      });
      print("استثناء: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _checkAnswer(bool userAnswer) {
    if (_correctAnswer != null) {
      setState(() {
        if (userAnswer == _correctAnswer) {
          _score++;
        } else {
          _score--;
        }
      });
      _getNextQuestion();
    }
  }

  @override
  void initState() {
    super.initState();
    _getNextQuestion();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('مسابقة Gemini'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'النقاط: $_score',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            if (_isLoading)
              CircularProgressIndicator()
            else
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  _currentQuestion,
                  style: TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                ),
              ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _checkAnswer(true),
                  child: Text('صح'),
                ),
                ElevatedButton(
                  onPressed: () => _checkAnswer(false),
                  child: Text('خطأ'),
                ),
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _getNextQuestion,
              child: Text('التالي'),
            ),
          ],
        ),
      ),
    );
  }
}

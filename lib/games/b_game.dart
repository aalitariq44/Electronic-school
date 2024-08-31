import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CharacterGuessGame extends StatefulWidget {
  @override
  _CharacterGuessGameState createState() => _CharacterGuessGameState();
}

class _CharacterGuessGameState extends State<CharacterGuessGame> {
  String _characterDescription = '';
  String _correctCharacterName = '';
  List<String> _characterOptions = [];
  String? _selectedOption;
  bool _isLoading = false;
  bool _gameStarted = false;
  bool _guessCorrect = false;
  bool _showCorrectName = false;
  int _score = 0;

  Future<void> _getCharacterDescription() async {
    setState(() {
      _isLoading = true;
      _gameStarted = true;
      _guessCorrect = false;
      _showCorrectName = false;
      _selectedOption = null;
    });

    final apiKey = 'AIzaSyCp7_uXbIL28FZsSHSkchAbZudkgDhxOAs';
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$apiKey');

    try {
      final response = await http.post(
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
                      'قم بإنشاء وصف لشخصية كرة قدم اوربية لاتذكر بلد الشخصية واجعل الوصف صعب مع اسمها واسمين آخرين لشخصيات كرة قدم اوربية. قم بتنسيق الإجابة على هذا النحو: "الوصف: [وصف الشخصية هنا] | الاسم الصحيح: [اسم الشخصية الصحيح] | الخيار الثاني: [اسم شخصية أخرى] | الخيار الثالث: [اسم شخصية أخرى]"'
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
      ).timeout(Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final reply = data['candidates'][0]['content']['parts'][0]['text'];
          final parts = reply.split('|');
          if (parts.length == 4) {
            final description = parts[0].trim().replaceFirst('الوصف:', '').trim();
            final correctName = parts[1].trim().replaceFirst('الاسم الصحيح:', '').trim();
            final option2 = parts[2].trim().replaceFirst('الخيار الثاني:', '').trim();
            final option3 = parts[3].trim().replaceFirst('الخيار الثالث:', '').trim();
            
            setState(() {
              _characterDescription = description;
              _correctCharacterName = correctName;
              _characterOptions = [correctName, option2, option3]..shuffle(Random());
            });
          } else {
            setState(() {
              _characterDescription = "حدث خطأ في تنسيق الوصف. يرجى المحاولة مرة أخرى.";
            });
          }
        } else {
          setState(() {
            _characterDescription = "لم يتم العثور على وصف في البيانات المستلمة.";
          });
        }
      } else {
        setState(() {
          _characterDescription = "فشل في الحصول على وصف من Gemini AI. الكود: ${response.statusCode}";
        });
        print("استجابة الخطأ: ${response.body}");
      }
    } catch (e) {
      setState(() {
        _characterDescription = "خطأ: $e";
      });
      print("استثناء: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _checkGuess() {
    setState(() {
      _guessCorrect = _selectedOption == _correctCharacterName;
      if (_guessCorrect) {
        _score++;
      }
    });
  }

  void _resetGame() {
    setState(() {
      _characterDescription = '';
      _correctCharacterName = '';
      _characterOptions = [];
      _selectedOption = null;
      _guessCorrect = false;
      _gameStarted = false;
      _showCorrectName = false;
    });
  }

  void _toggleShowCorrectName() {
    setState(() {
      _showCorrectName = !_showCorrectName;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تخمين الشخصية'),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'النقاط: $_score',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              if (!_gameStarted)
                ElevatedButton(
                  onPressed: _getCharacterDescription,
                  child: Text('بدء اللعبة'),
                )
              else if (_isLoading)
                CircularProgressIndicator()
              else ...[
                Text(
                  _characterDescription,
                  style: TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                ),
                SizedBox(height: 20),
                ...(_characterOptions.map((option) => 
                  RadioListTile<String>(
                    title: Text(option),
                    value: option,
                    groupValue: _selectedOption,
                    onChanged: (value) {
                      setState(() {
                        _selectedOption = value;
                      });
                    },
                  )
                )).toList(),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _selectedOption != null ? _checkGuess : null,
                  child: Text('تحقق'),
                ),
                SizedBox(height: 20),
                if (_guessCorrect)
                  Text(
                    'إجابة صحيحة!',
                    style: TextStyle(color: Colors.green, fontSize: 18),
                  )
                else if (_selectedOption != null)
                  Column(
                    children: [
                      Text(
                        'إجابة خاطئة',
                        style: TextStyle(color: Colors.red, fontSize: 18),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'مجموع النقاط: $_score',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _resetGame,
                        child: Text('أعد اللعبة'),
                      ),
                    ],
                  ),
                SizedBox(height: 20),
                if (!_guessCorrect)
                  ElevatedButton(
                    onPressed: _toggleShowCorrectName,
                    child: Text(_showCorrectName ? 'إخفاء الاسم الصحيح' : 'عرض الاسم الصحيح'),
                  ),
                if (_showCorrectName)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'الاسم الصحيح: $_correctCharacterName',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                SizedBox(height: 20),
                if (_guessCorrect)
                  ElevatedButton(
                    onPressed: _getCharacterDescription,
                    child: Text('سؤال جديد'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;

class TranslationPage extends StatefulWidget {
  @override
  _TranslationPageState createState() => _TranslationPageState();
}

class _TranslationPageState extends State<TranslationPage> {
  final TextEditingController _textController = TextEditingController();
  String _translatedText = '';
  bool _isLoading = false;
  String _selectedSourceLanguage = 'العربية';
  String _selectedTargetLanguage = 'الإنجليزية';

  final Map<String, String> _languages = {
    'العربية': 'ar',
    'الإنجليزية': 'en',
    'الفرنسية': 'fr',
    'الإسبانية': 'es',
    'الألمانية': 'de',
    'الإيطالية': 'it',
    'اليابانية': 'ja',
    'الكورية': 'ko',
    'الروسية': 'ru',
    'الصينية': 'zh'
  };

  Future<void> _translateText(String text) async {
    setState(() {
      _isLoading = true;
      _translatedText = '';
    });

    print("النص المراد ترجمته: $text");
    print("اللغة المصدر: $_selectedSourceLanguage");
    print("اللغة الهدف: $_selectedTargetLanguage");

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
                          'Translate the following text from ${_languages[_selectedSourceLanguage]} to ${_languages[_selectedTargetLanguage]}: $text'
                    }
                  ]
                }
              ],
              'generationConfig': {
                'temperature': 0.2,
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
        print("استجابة API: $data");
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final translation =
              data['candidates'][0]['content']['parts'][0]['text'];
          setState(() {
            _translatedText = translation;
          });
        } else {
          throw Exception("لم يتم العثور على ترجمة في البيانات المستلمة.");
        }
      } else {
        throw Exception(
            "فشل في الحصول على ترجمة. الكود: ${response.statusCode}");
      }
    } catch (e) {
      print("خطأ أثناء الترجمة: $e");
      setState(() {
        _translatedText = "حدث خطأ أثناء الترجمة: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ النص المترجم'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('المترجم الذكي',
            style: TextStyle(color: Colors.white, fontFamily: 'Cairo-Medium')),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue[700]!, Colors.blue[100]!],
            ),
          ),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Card(
                            elevation: 5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            color: Colors.white,
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: _buildLanguageDropdown(_selectedSourceLanguage,
                                            (String? newValue) {
                                          setState(() {
                                            _selectedSourceLanguage = newValue!;
                                          });
                                        }),
                                      ),
                                      IconButton(
                                        icon: FaIcon(FontAwesomeIcons.exchangeAlt,
                                            color: Colors.blue[700]),
                                        onPressed: () {
                                          setState(() {
                                            final temp = _selectedSourceLanguage;
                                            _selectedSourceLanguage =
                                                _selectedTargetLanguage;
                                            _selectedTargetLanguage = temp;
                                          });
                                        },
                                      ),
                                      Expanded(
                                        child: _buildLanguageDropdown(_selectedTargetLanguage,
                                            (String? newValue) {
                                          setState(() {
                                            _selectedTargetLanguage = newValue!;
                                          });
                                        }),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16),
                                  TextField(
                                    controller: _textController,
                                    decoration: InputDecoration(
                                      hintText: 'أدخل النص للترجمة...',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide.none,
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey[200],
                                      prefixIcon:
                                          FaIcon(FontAwesomeIcons.pen, color: Colors.grey),
                                    ),
                                    maxLines: 5,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              if (_textController.text.isNotEmpty) {
                                _translateText(_textController.text);
                              }
                            },
                            icon: FaIcon(FontAwesomeIcons.language),
                            label: Text('ترجم',
                                style: TextStyle(fontFamily: 'Cairo-Medium')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.blue[700],
                              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          if (_isLoading)
                            CircularProgressIndicator(color: Colors.white)
                          else
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                child: Card(
                                  elevation: 5,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  color: Colors.white,
                                  child: Stack(
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.all(16),
                                        child: SingleChildScrollView(
                                          child: Text(
                                            _translatedText,
                                            style: TextStyle(
                                                fontSize: 16, fontFamily: 'Cairo-Medium'),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: 8,
                                        top: 8,
                                        child: IconButton(
                                          icon: FaIcon(FontAwesomeIcons.copy,
                                              color: Colors.blue[700]),
                                          onPressed: () => _copyToClipboard(_translatedText),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageDropdown(
      String value, void Function(String?) onChanged) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<String>(
        value: value,
        items: _languages.keys.map((String lang) {
          return DropdownMenuItem<String>(
            value: lang,
            child: Text(lang, style: TextStyle(fontFamily: 'Cairo-Medium')),
          );
        }).toList(),
        onChanged: onChanged,
        underline: Container(),
        icon: FaIcon(FontAwesomeIcons.caretDown, color: Colors.blue[700]),
        dropdownColor: Colors.blue[50],
        isExpanded: true,
      ),
    );
  }
}
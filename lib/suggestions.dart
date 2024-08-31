import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SuggestionPage extends StatefulWidget {
  final String userUid;
  final String myName;

  const SuggestionPage({super.key, required this.userUid, required this.myName});

  @override
  _SuggestionPageState createState() => _SuggestionPageState();
}

class _SuggestionPageState extends State<SuggestionPage> {
  final TextEditingController _textController = TextEditingController();

  void _sendSuggestion() async {
    if (_textController.text.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('suggestions').add({
          'text': _textController.text,
          'timestamp': FieldValue.serverTimestamp(),
          'uid': widget.userUid,
          'name': widget.myName
        });
        _textController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إرسال الاقتراح بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء إرسال الاقتراح'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF3498db),
      appBar: AppBar(
        title: Text('الاقتراح', style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF3498db),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(FontAwesomeIcons.arrowRight, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(FontAwesomeIcons.lightbulb, 
                             color: Color(0xFF3498db), size: 48),
                        SizedBox(height: 16),
                        Text(
                          'نرحب باقتراحاتكم',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2c3e50),
                          ),
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: _textController,
                          decoration: InputDecoration(
                            hintText: 'اكتب اقتراحك هنا',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Color(0xFF3498db)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Color(0xFF3498db), width: 2),
                            ),
                            prefixIcon: Icon(FontAwesomeIcons.pen, color: Color(0xFF3498db)),
                          ),
                          maxLines: 5,
                        ),
                        SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _sendSuggestion,
                          icon: Icon(FontAwesomeIcons.paperPlane),
                          label: Text('إرسال', style: TextStyle(fontSize: 18)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF2ecc71),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:to_users/games/b_game.dart';
import 'package:to_users/games/gemini_quiz.dart';
import 'package:to_users/games/gif.dart';

class GamesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('مسابقات'),
      ),
      body: ListView(
        children: [
          GameCard(
            title: 'من سيربح المليون',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => GeminiQuiz()),
              );
            },
          ),
          GameCard(
            title: 'خمن الشخصية',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CharacterGuessGame()),
              );
            },
          ),
          GameCard(
            title: 'صور متحركة  ',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => GifPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class GameCard extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const GameCard({Key? key, required this.title, required this.onTap})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8.0),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18,
          ),
          textAlign: TextAlign.right,
        ),
        onTap: onTap,
      ),
    );
  }
}

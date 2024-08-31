import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:math_expressions/math_expressions.dart';

class CalculatorApplication extends StatefulWidget {
  const CalculatorApplication({Key? key}) : super(key: key);

  @override
  State<CalculatorApplication> createState() => _CalculatorApplicationState();
}

class _CalculatorApplicationState extends State<CalculatorApplication> {
  var result = '0';
  var inputUser = '';
  var previousOperation = '';

  void buttonPressed(String text) {
    setState(() {
      if (text == '=') {
        previousOperation = inputUser;
        Parser parser = Parser();
        Expression expression = parser.parse(inputUser);
        ContextModel contextModel = ContextModel();
        double eval = expression.evaluate(EvaluationType.REAL, contextModel);

        if (eval == eval.roundToDouble()) {
          result = eval.toInt().toString();
        } else {
          result = eval.toString();
        }
        inputUser = result;
      } else if (text == 'AC') {
        inputUser = '';
        result = '0';
        previousOperation = '';
      } else if (text == 'CE') {
        if (inputUser.isNotEmpty) {
          inputUser = inputUser.substring(0, inputUser.length - 1);
        }
      } else {
        if (inputUser == result) {
          if (['+', '-', '*', '/', '%'].contains(text)) {
            inputUser += text;
          } else {
            inputUser = text;
            previousOperation = '';
          }
        } else {
          inputUser += text;
        }
      }
    });
  }

  Widget getButton(String text, {Color? color, IconData? icon}) {
    return Container(
      margin: EdgeInsets.all(8),
      child: ElevatedButton(
        onPressed: () {
          if (text == 'AC') {
            setState(() {
              inputUser = '';
              result = '0';
              previousOperation = '';
            });
          } else if (text == 'CE') {
            setState(() {
              if (inputUser.isNotEmpty) {
                inputUser = inputUser.substring(0, inputUser.length - 1);
              }
            });
          } else {
            buttonPressed(text);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? Colors.blue[700],
          padding: EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: icon != null
            ? FaIcon(icon, size: 24, color: Colors.white)
            : Text(
                text,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('الآلة الحاسبة',
              style: TextStyle(fontFamily: 'Cairo-Medium')),
          backgroundColor: Colors.blue[700],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                flex: 35,
                child: Container(
                  padding: EdgeInsets.all(16),
                  color: Colors.blue[50],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (previousOperation.isNotEmpty)
                        Text(
                          previousOperation,
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 20,
                            fontFamily: 'Cairo-Medium',
                          ),
                          textAlign: TextAlign.start,
                        ),
                      SizedBox(height: 8),
                      Text(
                        inputUser,
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 40,
                          fontFamily: 'Cairo-Medium',
                        ),
                        textAlign: TextAlign.start,
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            result,
                            style: TextStyle(
                              color: Colors.blue[900],
                              fontSize: 50,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo-Medium',
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '=',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 40,
                              fontFamily: 'Cairo-Medium',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 65,
                child: Container(
                  color: Colors.grey[100],
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: getButton('/',
                                  color: Colors.blue[400],
                                  icon: FontAwesomeIcons.divide)),
                          Expanded(
                              child: getButton('%',
                                  color: Colors.green[400],
                                  // ignore: deprecated_member_use
                                  icon: FontAwesomeIcons.percentage)),
                          Expanded(
                              child: getButton('CE',
                                  color: Colors.orange[400],
                                  // ignore: deprecated_member_use
                                  icon: FontAwesomeIcons.backspace)),
                          Expanded(
                              child: getButton('AC',
                                  color: Colors.red[400],
                                  icon: FontAwesomeIcons.trash)),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                              child: getButton('*',
                                  color: Colors.blue[400],
                                  // ignore: deprecated_member_use
                                  icon: FontAwesomeIcons.times)),
                          Expanded(child: getButton('9')),
                          Expanded(child: getButton('8')),
                          Expanded(child: getButton('7')),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                              child: getButton('-',
                                  color: Colors.blue[400],
                                  icon: FontAwesomeIcons.minus)),
                          Expanded(child: getButton('6')),
                          Expanded(child: getButton('5')),
                          Expanded(child: getButton('4')),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                              child: getButton('+',
                                  color: Colors.blue[400],
                                  icon: FontAwesomeIcons.plus)),
                          Expanded(child: getButton('3')),
                          Expanded(child: getButton('2')),
                          Expanded(child: getButton('1')),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                              child: getButton('=',
                                  color: Colors.green[600],
                                  icon: FontAwesomeIcons.equals)),
                          Expanded(
                              child:
                                  getButton('.', icon: FontAwesomeIcons.dog)),
                          Expanded(child: getButton('0')),
                          Expanded(child: getButton('00')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

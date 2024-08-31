import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentDetailsPage extends StatefulWidget {
  final String id;
  final Map<String, dynamic> studentData;
  final String Type;

  StudentDetailsPage(
      {required this.studentData, required this.id, required this.Type});

  @override
  State<StudentDetailsPage> createState() => _StudentDetailsPageState();
}

class _StudentDetailsPageState extends State<StudentDetailsPage> {
  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: Image.network(imageUrl),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    Color color = Colors.blue,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              FaIcon(icon, size: 40, color: Colors.white),
              SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'Cairo-Medium',
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontFamily: 'Cairo-Medium',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text("صفحة الطالب", style: TextStyle(fontFamily: 'Cairo-Medium')),
        backgroundColor: Colors.blue[700],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              GestureDetector(
                onTap: () {
                  if (widget.studentData['image'] != null &&
                      widget.studentData['image'] != '') {
                    _showFullImage(context, widget.studentData['image']);
                  }
                },
                child: CircleAvatar(
                  radius: 70,
                  backgroundImage: widget.studentData['image'] != null &&
                          widget.studentData['image'] != ''
                      ? NetworkImage(widget.studentData['image'])
                      : null,
                  child: widget.studentData['image'] == null ||
                          widget.studentData['image'] == ''
                      ? FaIcon(
                          FontAwesomeIcons.userGraduate,
                          size: 70,
                          color: Colors.white,
                        )
                      : null,
                  backgroundColor: Colors.blue[700],
                ),
              ),
              SizedBox(height: 16),
              Text(
                '${widget.studentData['name']}',
                style: TextStyle(fontSize: 24, fontFamily: 'Cairo-Medium'),
              ),
              SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInfoCard(
                        icon: FontAwesomeIcons.calendarXmark,
                        title: "أيام الغياب",
                        value: "0",
                        color: Colors.red,
                        width: (constraints.maxWidth - 16) / 3,
                      ),
                      _buildInfoCard(
                        icon: FontAwesomeIcons.calendarCheck,
                        title: "أيام الإجازة",
                        value: "0",
                        color: Colors.green,
                        width: (constraints.maxWidth - 16) / 3,
                      ),
                      _buildInfoCard(
                        icon: FontAwesomeIcons.personRunning,
                        title: "أيام الهروب",
                        value: "0",
                        color: Colors.orange,
                        width: (constraints.maxWidth - 16) / 3,
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: 24),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المعلومات الشخصية',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.blue[700],
                          fontFamily: 'Cairo-Medium',
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildInfoRow(FontAwesomeIcons.venusMars, 'الجنس',
                          widget.studentData['gender'] ?? 'لا يوجد'),
                      _buildInfoRow(FontAwesomeIcons.graduationCap, 'الصف',
                          widget.studentData['grade'] + ' ' + widget.studentData['section'] ?? 'لا يوجد'),
                      _buildInfoRow(FontAwesomeIcons.phone, 'رقم الهاتف',
                          widget.studentData['phone'] ?? 'لا يوجد',
                          isPhone: true),
                      _buildInfoRow(
                          FontAwesomeIcons.locationDot,
                          'عنوان المنزل',
                          widget.studentData['address'] ?? 'لا يوجد'),
                      _buildInfoRow(
                          FontAwesomeIcons.cakeCandles,
                          'تاريخ الميلاد',
                          widget.studentData['birthDate'] ?? 'لا يوجد'),
                      _buildInfoRow(
                          FontAwesomeIcons.calendarPlus,
                          'تاريخ المباشرة',
                          widget.studentData['startDate'] ?? 'لا يوجد'),
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

  Widget _buildInfoRow(IconData icon, String label, String value,
      {bool isPhone = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          FaIcon(icon, color: Colors.blue[700], size: 20),
          SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 16, fontFamily: 'Cairo-Medium'),
          ),
          isPhone
              ? InkWell(
                  onTap: () async {
                    final Uri launchUri = Uri(
                      scheme: 'tel',
                      path: value,
                    );
                    await launch(launchUri.toString());
                  },
                  child: Text(
                    value,
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                        fontFamily: 'Cairo-Medium'),
                  ),
                )
              : Text(value,
                  style: TextStyle(fontSize: 16, fontFamily: 'Cairo-Medium')),
        ],
      ),
    );
  }
}
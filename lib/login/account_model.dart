class Account {
  final String email;
  final String uid;
  String password; // تم إزالة 'final'
  String userType; // تم إزالة 'final'
  bool isInitialSetupDone; // تم إزالة 'final'

  Account({
    required this.email,
    required this.password,
    required this.uid,
    required this.userType,
    required this.isInitialSetupDone,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'uid': uid,
    'userType': userType,
    'isInitialSetupDone': isInitialSetupDone,
  };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    email: json['email'],
    password: json['password'],
    uid: json['uid'],
    userType: json['userType'],
    isInitialSetupDone: json['isInitialSetupDone'],
  );
}
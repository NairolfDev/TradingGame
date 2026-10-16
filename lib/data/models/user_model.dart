class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final bool isGuest;
  final String authProvider; // 'password', 'google', 'guest'

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.isGuest = false,
    this.authProvider = 'password',
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'isGuest': isGuest,
        'authProvider': authProvider,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        uid: json['uid'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String,
        photoUrl: json['photoUrl'] as String?,
        isGuest: json['isGuest'] as bool? ?? false,
        authProvider: json['authProvider'] as String? ?? 'password',
      );
}

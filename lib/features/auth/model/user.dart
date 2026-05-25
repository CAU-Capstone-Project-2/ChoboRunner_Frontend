/// 서버 User 엔티티 (DTO 매핑).
///
/// 백엔드 DTO: {id, username, password(write-only), runningLevel,
///              description, goal, age, height}.
/// password는 GET 응답에 포함되지 않으므로 nullable로 두고 회원가입 요청 시에만 채운다.
class User {
  final String id;
  final String username;
  final String? password;
  final String? runningLevel;
  final String? description;
  final String? goal;
  final int? age;
  final int? height;

  const User({
    required this.id,
    required this.username,
    this.password,
    this.runningLevel,
    this.description,
    this.goal,
    this.age,
    this.height,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'].toString(),
      username: json['username'] as String? ?? '',
      runningLevel: json['runningLevel'] as String?,
      description: json['description'] as String?,
      goal: json['goal'] as String?,
      age: (json['age'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'username': username,
      if (password != null) 'password': password,
      'runningLevel': runningLevel ?? 'beginner',
      'description': description ?? '',
      'goal': goal ?? '',
      'age': age ?? 0,
      'height': height ?? 0,
    };
  }
}

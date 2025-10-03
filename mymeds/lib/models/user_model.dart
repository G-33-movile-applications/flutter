class UserModel {
  final String uid;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String address;
  final String city;
  final String department;
  final String zipCode;
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.address,
    required this.city,
    required this.department,
    required this.zipCode,
    this.createdAt,
  });

  // Create UserModel from Firestore document
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      department: map['department'] ?? '',
      zipCode: map['zipCode'] ?? '',
      createdAt: map['createdAt']?.toDate(),
    );
  }

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'address': address,
      'city': city,
      'department': department,
      'zipCode': zipCode,
      'createdAt': createdAt,
    };
  }

  // Create a copy with some fields updated
  UserModel copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? address,
    String? city,
    String? department,
    String? zipCode,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      city: city ?? this.city,
      department: department ?? this.department,
      zipCode: zipCode ?? this.zipCode,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, fullName: $fullName, email: $email)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;
}
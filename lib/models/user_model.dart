import 'package:mongo_dart/mongo_dart.dart';

class UserModel {
  final ObjectId? id;
  final String userType; // 'tenant' or 'owner'
  final String email;
  final String password;
  final Map<String, dynamic> personalDetails;
  final Map<String, dynamic>? occupationInfo;
  final Map<String, dynamic>? preferences;
  final Map<String, dynamic>? documents;
  final Map<String, dynamic>? emergencyContact;
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserModel({
    this.id,
    required this.userType,
    required this.email,
    required this.password,
    required this.personalDetails,
    this.occupationInfo,
    this.preferences,
    this.documents,
    this.emergencyContact,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert to Map for MongoDB
  Map<String, dynamic> toMap() {
    return {
      if (id != null) '_id': id,
      'userType': userType,
      'email': email,
      'password': password,
      'personalDetails': personalDetails,
      'occupationInfo': occupationInfo,
      'preferences': preferences,
      'documents': documents,
      'emergencyContact': emergencyContact,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Create from Map (MongoDB document)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['_id'] as ObjectId?,
      userType: map['userType'] as String,
      email: map['email'] as String,
      password: map['password'] as String,
      personalDetails: Map<String, dynamic>.from(map['personalDetails'] ?? {}),
      occupationInfo: map['occupationInfo'] != null 
          ? Map<String, dynamic>.from(map['occupationInfo']) 
          : null,
      preferences: map['preferences'] != null 
          ? Map<String, dynamic>.from(map['preferences']) 
          : null,
      documents: map['documents'] != null 
          ? Map<String, dynamic>.from(map['documents']) 
          : null,
      emergencyContact: map['emergencyContact'] != null 
          ? Map<String, dynamic>.from(map['emergencyContact']) 
          : null,
      createdAt: map['createdAt'] as DateTime? ?? DateTime.now(),
      updatedAt: map['updatedAt'] as DateTime?,
    );
  }

  // Copy with method for updates
  UserModel copyWith({
    ObjectId? id,
    String? userType,
    String? email,
    String? password,
    Map<String, dynamic>? personalDetails,
    Map<String, dynamic>? occupationInfo,
    Map<String, dynamic>? preferences,
    Map<String, dynamic>? documents,
    Map<String, dynamic>? emergencyContact,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      userType: userType ?? this.userType,
      email: email ?? this.email,
      password: password ?? this.password,
      personalDetails: personalDetails ?? this.personalDetails,
      occupationInfo: occupationInfo ?? this.occupationInfo,
      preferences: preferences ?? this.preferences,
      documents: documents ?? this.documents,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
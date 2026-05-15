import 'dart:typed_data';
import 'package:objectbox/objectbox.dart';

@Entity()
class SubjectCategory {
  int id;
  
  @Index()
  String name;

  @Backlink('category')
  final documents = ToMany<StudyDocument>();

  SubjectCategory({
    this.id = 0,
    required this.name,
  });
}

@Entity()
class StudyDocument {
  int id;
  String title;
  String localFilePath;
  
  @Property(type: PropertyType.date)
  DateTime uploadTimestamp;

  final category = ToOne<SubjectCategory>();

  @Backlink('document')
  final chunks = ToMany<VectorChunk>();

  StudyDocument({
    this.id = 0,
    required this.title,
    required this.localFilePath,
    required this.uploadTimestamp,
  });
}

@Entity()
class VectorChunk {
  int id;
  String text;
  int pageNumber;

  @HnswIndex(dimensions: 512) // Matches Gecko 512 model
  @Property(type: PropertyType.floatVector)
  Float32List? embedding;

  final document = ToOne<StudyDocument>();
  final category = ToOne<SubjectCategory>();

  VectorChunk({
    this.id = 0,
    required this.text,
    required this.pageNumber,
    this.embedding,
  });
}

@Entity()
class UserAchievement {
  int id;
  String badgeName;
  String reason;
  
  @Property(type: PropertyType.date)
  DateTime dateUnlocked;

  UserAchievement({
    this.id = 0,
    required this.badgeName,
    required this.reason,
    required this.dateUnlocked,
  });
}

@Entity()
class AppUsage {
  int id;
  @Index()
  String dateString; // e.g. "2026-05-09"
  int secondsSpent;

  AppUsage({
    this.id = 0,
    required this.dateString,
    this.secondsSpent = 0,
  });
}
@Entity()
class GeneratedStudyMaterial {
  int id;
  String type; // 'quiz', 'summary', 'flashcards'
  String contentJson; // The JSON string of the material
  String? title;
  
  @Property(type: PropertyType.date)
  DateTime dateCreated;

  final category = ToOne<SubjectCategory>();

  GeneratedStudyMaterial({
    this.id = 0,
    required this.type,
    required this.contentJson,
    required this.dateCreated,
    this.title,
  });
}
@Entity()
class Badge {
  int id;
  String name;
  String description;
  @Property(type: PropertyType.date)
  DateTime dateEarned;

  final category = ToOne<SubjectCategory>();

  Badge({
    this.id = 0,
    required this.name,
    required this.description,
    required this.dateEarned,
  });
}

import 'dart:typed_data';
import 'package:objectbox/objectbox.dart';

@Entity()
class StudyMaterialChunk {
  @Id()
  int id;

  String chunkText;

  @HnswIndex(dimensions: 768)
  @Property(type: PropertyType.floatVector)
  Float32List embedding;

  String fileName;
  int pageNumber;
  
  @Index()
  String subject;
  
  String concept;
  int timestamp;

  StudyMaterialChunk({
    this.id = 0,
    required this.chunkText,
    required this.embedding,
    required this.fileName,
    required this.pageNumber,
    required this.subject,
    required this.concept,
    required this.timestamp,
  });
}

import 'package:isar/isar.dart';

part 'group.g.dart';

@collection
class Group {
  Id id = Isar.autoIncrement;

  @Index()
  String? uuid;

  String? name;

  @Index()
  String? creatorId;

  DateTime? createdAt;

  Group({
    this.uuid,
    this.name,
    this.creatorId,
    this.createdAt,
  });

  Group copyWith({
    String? uuid,
    String? name,
    String? creatorId,
    DateTime? createdAt,
  }) {
    return Group(
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      creatorId: creatorId ?? this.creatorId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': uuid,
      'name': name,
      'creator_id': creatorId,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      uuid: json['id'],
      name: json['name'],
      creatorId: json['creator_id'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
    );
  }
} 
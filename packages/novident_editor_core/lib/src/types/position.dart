import 'package:novident_editor_document/novident_editor_document.dart';

class Position {
  final Path path;
  final int offset;
  final String? id;

  Position({
    required this.path,
    this.offset = 0,
    this.id,
  });

  Position.invalid()
      : path = [-1],
        id = null,
        offset = -1;

  factory Position.fromJson(Map<String, dynamic> json) {
    final path = Path.from(json['path'] as List);
    final offset = json['offset'];
    final id = json['id'] as String?;

    return Position(
      path: path,
      offset: offset ?? 0,
      id: id,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Position &&
        other.path.equals(path) &&
        other.id == id &&
        other.offset == offset;
  }

  @override
  int get hashCode => Object.hash(
        offset,
        Object.hashAll(path),
        id,
      );

  @override
  String toString() => 'path = $path, offset = $offset, id = $id';

  Position copyWith({
    Path? path,
    int? offset,
    String? id,
  }) {
    return Position(
      path: path ?? this.path,
      offset: offset ?? this.offset,
      id: id ?? this.id,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'path': path,
      'offset': offset,
    };
  }
}

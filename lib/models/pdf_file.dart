class PdfFile {
  final String id;
  final String name;
  final String path;
  final DateTime openedAt;
  final int sizeBytes;

  const PdfFile({
    required this.id,
    required this.name,
    required this.path,
    required this.openedAt,
    required this.sizeBytes,
  });

  String get formattedSize {
    if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (sizeBytes >= 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$sizeBytes B';
  }

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(openedAt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    } else {
      final weeks = diff.inDays ~/ 7;
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'openedAt': openedAt.toIso8601String(),
      'sizeBytes': sizeBytes,
    };
  }

  factory PdfFile.fromMap(Map<String, dynamic> map) {
    return PdfFile(
      id: map['id'] as String,
      name: map['name'] as String,
      path: map['path'] as String,
      openedAt: DateTime.parse(map['openedAt'] as String),
      sizeBytes: map['sizeBytes'] as int,
    );
  }
}

class Bookmark {
  final String fileId;
  final int page;
  final String title;
  final DateTime createdAt;

  const Bookmark({
    required this.fileId,
    required this.page,
    required this.title,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'fileId': fileId,
        'page': page,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Bookmark.fromMap(Map<String, dynamic> map) => Bookmark(
        fileId: map['fileId'] as String,
        page: map['page'] as int,
        title: map['title'] as String,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
}

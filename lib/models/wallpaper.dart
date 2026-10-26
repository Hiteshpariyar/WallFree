class Wallpaper {
  const Wallpaper({
    required this.id,
    required this.title,
    required this.path,
    required this.addedAt,
    this.isFavorite = false,
  });

  final String id;
  final String title;
  final String path;
  final DateTime addedAt;
  final bool isFavorite;

  Wallpaper copyWith({bool? isFavorite}) => Wallpaper(
    id: id,
    title: title,
    path: path,
    addedAt: addedAt,
    isFavorite: isFavorite ?? this.isFavorite,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'path': path,
    'addedAt': addedAt.toIso8601String(),
    'isFavorite': isFavorite,
  };

  factory Wallpaper.fromJson(Map<String, Object?> json) => Wallpaper(
    id: json['id']! as String,
    title: json['title']! as String,
    path: json['path']! as String,
    addedAt: DateTime.parse(json['addedAt']! as String),
    isFavorite: json['isFavorite'] as bool? ?? false,
  );
}

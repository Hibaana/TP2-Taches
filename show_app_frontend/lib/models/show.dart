class Show {
  final int id;
  final String title;
  final String description;
  final String category;
  final String? imageUrl;
  final DateTime? createdAt;

  Show({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.imageUrl,
    this.createdAt,
  });

  factory Show.fromJson(Map<String, dynamic> json) {
    return Show(
      id: json['_id'] as int ,
      title: json['title'],
      description: json['description'],
      category: json['category'],
      imageUrl: json['image'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
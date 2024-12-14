class Item {
  final int id;
  final String name;
  final String weight;

  Item({required this.id, required this.name, required this.weight});

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'],
      name: map['name'],
      weight: map['weight'],
    );
  }
}

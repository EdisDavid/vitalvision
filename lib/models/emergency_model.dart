class EmergencyModel {
  final String name;
  final String phone;

  EmergencyModel({required this.name, required this.phone});

  Map<String, String> toMap() {
    return {
      'name': name,
      'phone': phone,
    };
  }

  factory EmergencyModel.fromMap(Map<String, dynamic> map) {
    return EmergencyModel(
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
    );
  }
}

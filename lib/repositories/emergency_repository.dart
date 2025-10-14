import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_model.dart';

class EmergencyRepository {
  static const String _key = 'emergency_contact';

  Future<void> saveContact(EmergencyModel contact) async {
    final prefs = await SharedPreferences.getInstance();
    final contactJson = jsonEncode(contact.toMap());
    await prefs.setString(_key, contactJson);
  }

  Future<EmergencyModel?> getContact() async {
    final prefs = await SharedPreferences.getInstance();
    final contactJson = prefs.getString(_key);
    if (contactJson == null) return null;
    final Map<String, dynamic> map = jsonDecode(contactJson);
    return EmergencyModel.fromMap(map);
  }

  Future<void> deleteContact() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/emergency_model.dart';
import '../repositories/emergency_repository.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  EmergencyModel? _contact;
  final EmergencyRepository _repo = EmergencyRepository();

  @override
  void initState() {
    super.initState();
    _loadContact();
  }

  Future<void> _loadContact() async {
    final saved = await _repo.getContact();
    if (!mounted) return;
    setState(() {
      _contact = saved;
    });
  }

  Future<void> _selectContact() async {
    try {
      // 1️⃣ Comprobar permiso actual
      final status = await Permission.contacts.status;

      if (status.isDenied || status.isRestricted) {
        final granted = await Permission.contacts.request();
        if (!granted.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Permiso denegado. Actívalo en Ajustes si deseas seleccionar un contacto.',
                ),
              ),
            );
          }
          return;
        }
      }

      // 2️⃣ Abrir selector nativo
      final Contact? picked = await FlutterContacts.openExternalPick();
      if (picked == null) return; // usuario canceló

      // 3️⃣ Obtener versión completa del contacto (con números)
      final Contact? full =
          await FlutterContacts.getContact(picked.id, withProperties: true);

      if (full == null || full.phones.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El contacto no tiene número disponible.')),
          );
        }
        return;
      }

      // 4️⃣ Crear modelo y guardar
      final newContact = EmergencyModel(
        name: full.displayName.isNotEmpty ? full.displayName : 'Desconocido',
        phone: full.phones.first.number.replaceAll(RegExp(r'\s+'), ''),
      );

      await _repo.saveContact(newContact);

      if (!mounted) return;
      setState(() {
        _contact = newContact;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Contacto de emergencia guardado: ${newContact.name}')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar contacto: $e')),
        );
      }
    }
  }

  Future<void> _deleteContact() async {
    await _repo.deleteContact();
    if (!mounted) return;
    setState(() {
      _contact = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contacto de emergencia eliminado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacto de Emergencia'),
        backgroundColor: const Color(0xFFDC2626),
        actions: [
          if (_contact != null)
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.white),
              onPressed: _deleteContact,
              tooltip: 'Eliminar Contacto',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.white,
              elevation: 4,
              child: ListTile(
                leading: const Icon(Icons.contact_phone, color: Color(0xFFDC2626)),
                title: Text(_contact?.name ?? 'No hay contacto asignado'),
                subtitle: Text(_contact?.phone ?? ''),
                trailing: ElevatedButton(
                  onPressed: _selectContact,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(_contact == null ? 'Agregar' : 'Cambiar'),
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Este contacto será usado en caso de emergencias críticas como desmayos o atragantamiento.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

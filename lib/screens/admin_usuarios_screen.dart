import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Pantalla de administración de usuarios.
///
/// Solo debe ser accesible si el usuario logueado tiene `esAdmin == true`
/// en su documento de la colección `usuarios` (ver nota al final sobre
/// cómo enlazarla desde home_screen.dart).
///
/// Supone la siguiente estructura en la colección `usuarios` (Firestore):
///   {
///     "email": "policia@ejemplo.com",
///     "nombre": "Juan Pérez",
///     "patio": "CRV Quitumbe",       // texto libre por ahora
///     "aprobado": false,
///     "esAdmin": false,
///     "fechaRegistro": Timestamp,
///   }
///
/// Si tus nombres de campo son distintos, ajusta las referencias abajo
/// (están todas agrupadas en la sección "CAMPOS FIRESTORE").
class AdminUsuariosScreen extends StatelessWidget {
  const AdminUsuariosScreen({super.key});

  // ---------- CAMPOS FIRESTORE (ajustar aquí si difieren) ----------
  static const String coleccion = 'usuarios';
  static const String campoAprobado = 'aprobado';
  static const String campoEsAdmin = 'esAdmin';
  static const String campoPatio = 'patio';
  static const String campoNombre = 'nombre';
  static const String campoEmail = 'email';
  static const String campoFecha = 'fechaRegistro';
  // -------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> get _usuariosRef =>
      FirebaseFirestore.instance.collection(coleccion);

  Future<void> _aprobar(BuildContext context, String docId) async {
    await _usuariosRef.doc(docId).update({campoAprobado: true});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario aprobado')),
      );
    }
  }

  Future<void> _rechazar(BuildContext context, String docId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar usuario'),
        content: const Text(
          '¿Seguro que deseas rechazar el acceso de este usuario? '
          'Podrás aprobarlo más tarde si vuelve a solicitarlo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await _usuariosRef.doc(docId).update({campoAprobado: false});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario rechazado')),
        );
      }
    }
  }

  Future<void> _revocar(BuildContext context, String docId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revocar acceso'),
        content: const Text(
          '¿Revocar el acceso de este usuario ya aprobado? '
          'Dejará de poder ingresar a la app hasta que lo apruebes de nuevo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revocar'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await _usuariosRef.doc(docId).update({campoAprobado: false});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Acceso revocado')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administración de usuarios'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pendientes'),
              Tab(text: 'Aprobados'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ListaUsuarios(
              stream: _usuariosRef
                  .where(campoAprobado, isEqualTo: false)
                  .snapshots(),
              emptyText: 'No hay usuarios pendientes de aprobación',
              builderAcciones: (context, doc) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    tooltip: 'Aprobar',
                    onPressed: () => _aprobar(context, doc.id),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    tooltip: 'Rechazar',
                    onPressed: () => _rechazar(context, doc.id),
                  ),
                ],
              ),
            ),
            _ListaUsuarios(
              stream: _usuariosRef
                  .where(campoAprobado, isEqualTo: true)
                  .snapshots(),
              emptyText: 'Todavía no hay usuarios aprobados',
              builderAcciones: (context, doc) => TextButton.icon(
                icon: const Icon(Icons.block, color: Colors.orange),
                label: const Text('Revocar'),
                onPressed: () => _revocar(context, doc.id),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListaUsuarios extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String emptyText;
  final Widget Function(BuildContext, QueryDocumentSnapshot<Map<String, dynamic>>)
      builderAcciones;

  const _ListaUsuarios({
    required this.stream,
    required this.emptyText,
    required this.builderAcciones,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(child: Text(emptyText));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final nombre = data[AdminUsuariosScreen.campoNombre] ?? '(sin nombre)';
            final email = data[AdminUsuariosScreen.campoEmail] ?? '';
            final patio = data[AdminUsuariosScreen.campoPatio] ?? '(patio no indicado)';
            final fecha = data[AdminUsuariosScreen.campoFecha];
            String fechaTexto = '';
            if (fecha is Timestamp) {
              final f = fecha.toDate();
              fechaTexto = '${f.day.toString().padLeft(2, '0')}/'
                  '${f.month.toString().padLeft(2, '0')}/${f.year}';
            }

            return Card(
              child: ListTile(
                title: Text(nombre),
                subtitle: Text(
                  '$email\nPatio: $patio${fechaTexto.isNotEmpty ? '  •  Registrado: $fechaTexto' : ''}',
                ),
                isThreeLine: true,
                trailing: builderAcciones(context, doc),
              ),
            );
          },
        );
      },
    );
  }
}

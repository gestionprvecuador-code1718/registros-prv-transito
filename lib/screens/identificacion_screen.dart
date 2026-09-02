import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class IdentificacionScreen extends StatefulWidget {
  final User usuario;
  const IdentificacionScreen({super.key, required this.usuario});

  @override
  State<IdentificacionScreen> createState() => _IdentificacionScreenState();
}

class _IdentificacionScreenState extends State<IdentificacionScreen> {
  final _controllerPatio = TextEditingController();
  final _controllerSubzona = TextEditingController();
  final _controllerDistrito = TextEditingController();
  final _controllerCircuito = TextEditingController();
  final _controllerSubcircuito = TextEditingController();
  final _controllerJefatura = TextEditingController();
  final _controllerSubjefatura = TextEditingController();

  bool _guardando = false;

  // Estructura jerárquica de la Policía Nacional del Ecuador — mapeo de
  // Zona a provincias, tal como lo dio Xavier. Es solo informativo (para
  // ayudar a elegir la Zona correcta); Subzona/Distrito/etc. se escriben
  // a mano porque varían mucho dentro de cada zona.
  static const Map<String, String> _zonas = {
    'Zona 1': 'Esmeraldas, Carchi, Imbabura, Sucumbíos',
    'Zona 2': 'Pichincha (excepto DM Quito), Napo, Orellana',
    'Zona 3': 'Cotopaxi, Tungurahua, Chimborazo, Pastaza',
    'Zona 4': 'Manabí, Santo Domingo de los Tsáchilas',
    'Zona 5': 'Guayas (excepto Guayaquil/Durán/Samborondón), Los Ríos, Santa Elena, Bolívar, Galápagos',
    'Zona 6': 'Azuay, Cañar, Morona Santiago',
    'Zona 7': 'Loja, El Oro, Zamora Chinchipe',
    'Zona 8': 'Distrito Metropolitano de Guayaquil',
    'Zona 9': 'Distrito Metropolitano de Quito',
  };

  String? _zonaSeleccionada;

  Future<void> _continuar() async {
    if (_controllerPatio.text.trim().isEmpty) return;
    setState(() => _guardando = true);
    await AuthService().crearPerfil(
      uid: widget.usuario.uid,
      nombre: widget.usuario.displayName ?? '',
      correo: widget.usuario.email ?? '',
      patio: _controllerPatio.text.trim(),
      zona: _zonaSeleccionada ?? '',
      subzona: _controllerSubzona.text.trim(),
      distrito: _controllerDistrito.text.trim(),
      circuito: _controllerCircuito.text.trim(),
      subcircuito: _controllerSubcircuito.text.trim(),
      jefaturaTransito: _controllerJefatura.text.trim(),
      subjefaturaTransito: _controllerSubjefatura.text.trim(),
    );
    // El AuthGate detecta el cambio y muestra la pantalla de "pendiente"
    // automáticamente; no hace falta navegar manualmente.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Identifícate')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            Text('Hola, ${widget.usuario.displayName ?? ''}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            const Text(
              'Antes de continuar, ubícanos dentro de la estructura institucional. '
              'Estos datos son OPCIONALES y solo se piden una vez.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _zonaSeleccionada,
              decoration: const InputDecoration(
                labelText: 'Zona (opcional)',
                border: OutlineInputBorder(),
              ),
              items: _zonas.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text('${e.key} — ${e.value}', overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _zonaSeleccionada = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controllerSubzona,
              decoration: const InputDecoration(labelText: 'Subzona (opcional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controllerDistrito,
              decoration: const InputDecoration(labelText: 'Distrito (opcional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controllerCircuito,
              decoration: const InputDecoration(labelText: 'Circuito (opcional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controllerSubcircuito,
              decoration: const InputDecoration(labelText: 'Subcircuito (opcional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controllerJefatura,
              decoration: const InputDecoration(labelText: 'Jefatura de Tránsito (opcional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controllerSubjefatura,
              decoration: const InputDecoration(labelText: 'Subjefatura de Tránsito (opcional)', border: OutlineInputBorder()),
            ),
            const Divider(height: 32),
            const Text(
              'Nombre del Patio (obligatorio)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'El nombre que tu cuenta usará en toda la app: pantalla principal, Excel, '
              'hoja de Ingreso, hoja de Libertad, etc. Un administrador revisará tu '
              'solicitud antes de darte acceso.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controllerPatio,
              decoration: const InputDecoration(
                labelText: 'Patio de Retención Vehicular (PRV)',
                hintText: 'Ej. Control 120 - Santo Domingo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: _guardando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: Text(_guardando ? 'Guardando...' : 'Enviar solicitud'),
              onPressed: _guardando ? null : _continuar,
            ),
          ],
        ),
      ),
    );
  }
}

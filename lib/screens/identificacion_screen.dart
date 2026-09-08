import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../data/patios_nacional.dart';

// Valor interno usado en el desplegable de Jefatura/Subjefatura para
// representar zonas que tienen CRV "directos" sin jefatura propia
// (ej. Zona 5 - Guayas: Naranjal, Empalme-Balzar, Milagro-Yaguachi, Santa Lucía-Daule).
const String _kDirecto = '__DIRECTO__';

class IdentificacionScreen extends StatefulWidget {
  final User usuario;
  const IdentificacionScreen({super.key, required this.usuario});

  @override
  State<IdentificacionScreen> createState() => _IdentificacionScreenState();
}

class _IdentificacionScreenState extends State<IdentificacionScreen> {
  final _controllerPatio = TextEditingController();
  final _controllerDistrito = TextEditingController();
  final _controllerCircuito = TextEditingController();
  final _controllerSubcircuito = TextEditingController();

  bool _guardando = false;

  String? _zonaSeleccionada;
  String? _jefaturaSeleccionada;
  String? _crvSeleccionado;

  List<String> get _jefaturasDisponibles {
    if (_zonaSeleccionada == null) return [];
    final jefaturas = obtenerJefaturas(_zonaSeleccionada!);
    final directos = obtenerCrvDirectosDeZona(_zonaSeleccionada!);
    return [
      ...jefaturas,
      if (directos.isNotEmpty) _kDirecto,
    ];
  }

  List<String> get _crvDisponibles {
    if (_zonaSeleccionada == null || _jefaturaSeleccionada == null) return [];
    if (_jefaturaSeleccionada == _kDirecto) {
      return obtenerCrvDirectosDeZona(_zonaSeleccionada!);
    }
    return obtenerCrv(_zonaSeleccionada!, _jefaturaSeleccionada!);
  }

  void _onZonaCambiada(String? v) {
    setState(() {
      _zonaSeleccionada = v;
      _jefaturaSeleccionada = null;
      _crvSeleccionado = null;
      _controllerPatio.clear();
    });
  }

  void _onJefaturaCambiada(String? v) {
    setState(() {
      _jefaturaSeleccionada = v;
      _crvSeleccionado = null;
      _controllerPatio.clear();
    });
  }

  void _onCrvCambiado(String? v) {
    setState(() {
      _crvSeleccionado = v;
      _controllerPatio.text = v ?? '';
    });
  }

  Future<void> _continuar() async {
    if (_controllerPatio.text.trim().isEmpty) return;
    setState(() => _guardando = true);
    final jefaturaFinal =
        _jefaturaSeleccionada == _kDirecto ? '' : (_jefaturaSeleccionada ?? '');
    await AuthService().crearPerfil(
      uid: widget.usuario.uid,
      nombre: widget.usuario.displayName ?? '',
      correo: widget.usuario.email ?? '',
      patio: _controllerPatio.text.trim(),
      zona: _zonaSeleccionada ?? '',
      subzona: '',
      distrito: _controllerDistrito.text.trim(),
      circuito: _controllerCircuito.text.trim(),
      subcircuito: _controllerSubcircuito.text.trim(),
      jefaturaTransito: jefaturaFinal,
      subjefaturaTransito: '',
    );
    // El AuthGate detecta el cambio y muestra la pantalla de "pendiente"
    // automáticamente; no hace falta navegar manualmente.
  }

  @override
  Widget build(BuildContext context) {
    final zonas = obtenerZonas();

    return Scaffold(
      appBar: AppBar(title: const Text('Identifícate')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            Text('Hola, ${widget.usuario.displayName ?? ''}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            const Text(
              'Selecciona tu Zona, Jefatura/Subjefatura y CRV. Con eso quedas '
              'inscrito en la plataforma y no volverás a llenar esta información '
              '(se usa automáticamente en el informe semanal y el Excel).',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),

            // 1) ZONA
            DropdownButtonFormField<String>(
              initialValue: _zonaSeleccionada,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Zona',
                border: OutlineInputBorder(),
              ),
              items: zonas
                  .map((z) => DropdownMenuItem(
                        value: z,
                        child: Text(z, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: _onZonaCambiada,
            ),
            const SizedBox(height: 12),

            // 2) JEFATURA / SUBJEFATURA (depende de la Zona)
            DropdownButtonFormField<String>(
              initialValue: _jefaturaSeleccionada,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Jefatura / Subjefatura',
                border: OutlineInputBorder(),
              ),
              items: _jefaturasDisponibles
                  .map((j) => DropdownMenuItem(
                        value: j,
                        child: Text(
                          j == _kDirecto ? 'Sin jefatura (directo)' : j,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: _zonaSeleccionada == null ? null : _onJefaturaCambiada,
            ),
            const SizedBox(height: 12),

            // 3) CRV (depende de Zona + Jefatura)
            DropdownButtonFormField<String>(
              initialValue: _crvSeleccionado,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'CRV',
                border: OutlineInputBorder(),
              ),
              items: _crvDisponibles
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: _jefaturaSeleccionada == null ? null : _onCrvCambiado,
            ),
            const SizedBox(height: 20),

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
            const Divider(height: 32),
            const Text(
              'Nombre del Patio (obligatorio)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Se llena automáticamente al elegir el CRV arriba. El nombre que tu '
              'cuenta usará en toda la app: pantalla principal, Excel, hoja de '
              'Ingreso, hoja de Libertad, etc. Puedes ajustarlo si lo necesitas. '
              'Un administrador revisará tu solicitud antes de darte acceso.',
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

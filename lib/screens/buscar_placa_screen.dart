import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../models/caso_ingreso.dart';
import '../models/caso_libertad.dart';
import 'formulario_screen.dart';
import 'captura_screen.dart';
import 'home_screen.dart' show TipoParte;

class BuscarPlacaScreen extends StatefulWidget {
  const BuscarPlacaScreen({super.key});

  @override
  State<BuscarPlacaScreen> createState() => _BuscarPlacaScreenState();
}

class _BuscarPlacaScreenState extends State<BuscarPlacaScreen> {
  final _controller = TextEditingController();
  final _storage = StorageService();
  List<CasoIngreso> _ingresos = [];
  List<CasoLibertad> _libertades = [];
  bool _buscando = false;
  bool _yaSeBusco = false;

  Future<void> _buscar() async {
    final placa = _controller.text.trim();
    if (placa.isEmpty) return;
    setState(() => _buscando = true);

    final ingresos = await _storage.buscarIngresosPorPlaca(placa);
    final libertades = await _storage.buscarLibertadesPorPlaca(placa);

    if (mounted) {
      setState(() {
        _ingresos = ingresos;
        _libertades = libertades;
        _buscando = false;
        _yaSeBusco = true;
      });
    }
  }

  /// True si ya existe un caso de Libertad para la misma hoja de
  /// ingreso (para no duplicar el botón "Liberar vehículo").
  bool _yaTieneLibertad(CasoIngreso ingreso) {
    return _libertades.any((l) => l.hojaIngresoNro == ingreso.hojaIngresoNro);
  }

  /// Arma un CasoLibertad prellenado con los datos que ya se
  /// conocen desde el Ingreso, dejando en blanco solo lo que
  /// realmente es nuevo en la Libertad (memorando, oficio, pagos, etc.)
  ///
  /// NOTA: ajusta "id" y "creado" según cómo generes esos valores
  /// en el resto de tu app (por ejemplo si usas un paquete uuid,
  /// o si "creado" es un Timestamp de Firestore en vez de DateTime).
  CasoLibertad _libertadPrellenadaDesde(CasoIngreso ingreso) {
    return CasoLibertad(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // TODO: revisar esquema real de IDs
      memorandoNro: '',
      memorandoFecha: '',
      oficioDevolucionNro: '',
      firmadoPor: '',
      marca: ingreso.marca,
      color: ingreso.color,
      placa: ingreso.placa,
      retiradoPor: ingreso.propietario,
      cedulaRetira: ingreso.cedulaPropietario,
      hojaIngresoNro: ingreso.hojaIngresoNro,
      parteIngresoNro: ingreso.parteIngresoNro,
      fechaIngreso: ingreso.fechaIngreso,
      diasPermanencia: '',
      tipoVehiculo: ingreso.tipoVehiculo,
      crv: ingreso.crv,
      dirigidoA: ingreso.dirigidoA,
      causa: ingreso.causa,
      pagos: [PagoGaraje()],
      creado: DateTime.now(), // TODO: revisar el tipo real del campo "creado"
    );
  }

  Future<void> _liberarVehiculo(CasoIngreso ingreso) async {
    // Si ya existe un borrador automático (creado al guardar el
    // Ingreso), lo usamos — puede tener ediciones previas guardadas.
    // Si no existe (por ejemplo, un Ingreso antiguo de antes de esta
    // función), se arma uno nuevo con los datos heredados.
    final borrador = await _storage.buscarBorradorLibertadPorHoja(ingreso.hojaIngresoNro);
    final casoBase = borrador ?? _libertadPrellenadaDesde(ingreso);
    if (!mounted) return;
    // Vamos primero a la cámara: ahí se toman las fotos del oficio de
    // devolución/memorando y de la orden de pago/comprobante, y esos
    // datos nuevos se combinan con lo ya heredado del Ingreso.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CapturaScreen(tipo: TipoParte.libertad, casoLibertadBase: casoBase),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sinResultados = _yaSeBusco && _ingresos.isEmpty && _libertades.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Buscar por placa')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Placa',
                      hintText: 'Ej. PAD1978',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _buscar(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _buscando ? null : _buscar,
                  child: _buscando
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search),
                ),
              ],
            ),
          ),
          if (sinResultados)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No se encontró ningún caso con esa placa.', textAlign: TextAlign.center),
            ),
          Expanded(
            child: ListView(
              children: [
                ..._ingresos.map((c) {
                  final tieneLibertad = _yaTieneLibertad(c);
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.login)),
                          title: Text('INGRESO — ${c.placa}'),
                          subtitle: Text('${c.marca} ${c.color} — Hoja ${c.hojaIngresoNro}'),
                          trailing: const Icon(Icons.edit),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FormularioIngresoScreen(caso: c, esEdicion: true),
                            ),
                          ),
                        ),
                        if (!tieneLibertad)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.tonalIcon(
                                icon: const Icon(Icons.logout),
                                label: const Text('Liberar vehículo'),
                                onPressed: () => _liberarVehiculo(c),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                ..._libertades.map((c) => Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.logout)),
                        title: Text('LIBERTAD — ${c.placa}'),
                        subtitle: Text('${c.marca} ${c.color} — Hoja ${c.hojaIngresoNro}'),
                        trailing: const Icon(Icons.edit),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FormularioLibertadScreen(caso: c, esEdicion: true),
                          ),
                        ),
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

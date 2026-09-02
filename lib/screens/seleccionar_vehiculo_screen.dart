import 'package:flutter/material.dart';
import '../models/participante_vehiculo.dart';
import '../models/caso_ingreso.dart';
import 'formulario_screen.dart';

class SeleccionarVehiculoScreen extends StatelessWidget {
  final List<ParticipanteVehiculo> participantes;
  final MetadatosParte metadatos;

  const SeleccionarVehiculoScreen({
    super.key,
    required this.participantes,
    required this.metadatos,
  });

  void _elegir(BuildContext context, ParticipanteVehiculo p) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    final novedades = [
      if (metadatos.parteNo.isNotEmpty) 'Parte Policial N°: ${metadatos.parteNo}',
      if (metadatos.fechaHecho.isNotEmpty || metadatos.horaHecho.isNotEmpty)
        'Fecha/hora del hecho: ${metadatos.fechaHecho} ${metadatos.horaHecho}',
      if (metadatos.direccion.isNotEmpty) 'Lugar: ${metadatos.direccion}',
      if (metadatos.circunstancias.isNotEmpty) 'Circunstancias: ${metadatos.circunstancias.trim()}',
      if (metadatos.elaboradoPor.isNotEmpty) 'Elaborado por: ${metadatos.elaboradoPor}',
    ].join('\n');

    final caso = CasoIngreso(
      id: id,
      marca: p.marca,
      color: p.color,
      placa: p.placa,
      propietario: p.propietario.isNotEmpty ? p.propietario : p.conductor,
      cedulaPropietario: p.propietarioCedula.isNotEmpty ? p.propietarioCedula : p.conductorCedula,
      tipoVehiculo: p.tipo,
      causa: metadatos.circunstancias.isNotEmpty ? 'Accidente de tránsito' : '',
      fechaIngreso: metadatos.fechaHecho,
      novedades: novedades,
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FormularioIngresoScreen(caso: caso)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Selecciona el vehículo')),
      body: Column(
        children: [
          if (metadatos.parteNo.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.blue.shade50,
              padding: const EdgeInsets.all(12),
              child: Text(
                'Parte Policial N°: ${metadatos.parteNo}\n'
                'Se detectaron ${participantes.length} vehículo(s). Toca el que te interesa registrar.',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: participantes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final p = participantes[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${i + 1}')),
                    title: Text(p.placa, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text(
                      '${p.marca} ${p.color} — ${p.tipo}\n'
                      'Propietario: ${p.propietario.isEmpty ? p.conductor : p.propietario}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _elegir(context, p),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

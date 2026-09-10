// RUTA DE ARCHIVO: lib/models/participante_vehiculo.dart

/// Un vehículo detectado dentro de un "Parte Policial / Noticia del
/// Incidente" (PDF del sistema Ecu911). Un mismo PDF puede traer varios
/// (Participante 1, Participante 2, ...); el usuario elige cuál le
/// interesa antes de extraer el resto de los datos.
class ParticipanteVehiculo {
  final String placa;
  final String tipo;
  final String marca;
  final String color;
  final String conductor;
  final String conductorCedula;
  final String propietario;
  final String propietarioCedula;
  // Estos tres, cuando se encuentran, vienen del bloque "Objetos
  // registrados como indicios" (más confiables que la prosa para
  // chasis/país/año, aunque no todos los partes traen ese bloque).
  final String chasis;
  final String pais;
  final String anio;

  ParticipanteVehiculo({
    required this.placa,
    this.tipo = '',
    this.marca = '',
    this.color = '',
    this.conductor = '',
    this.conductorCedula = '',
    this.propietario = '',
    this.propietarioCedula = '',
    this.chasis = '',
    this.pais = '',
    this.anio = '',
  });

  ParticipanteVehiculo copyWith({
    String? tipo,
    String? marca,
    String? color,
    String? conductor,
    String? conductorCedula,
    String? propietario,
    String? propietarioCedula,
    String? chasis,
    String? pais,
    String? anio,
  }) {
    return ParticipanteVehiculo(
      placa: placa,
      tipo: tipo ?? this.tipo,
      marca: marca ?? this.marca,
      color: color ?? this.color,
      conductor: conductor ?? this.conductor,
      conductorCedula: conductorCedula ?? this.conductorCedula,
      propietario: propietario ?? this.propietario,
      propietarioCedula: propietarioCedula ?? this.propietarioCedula,
      chasis: chasis ?? this.chasis,
      pais: pais ?? this.pais,
      anio: anio ?? this.anio,
    );
  }
}

/// Datos generales del caso, comunes a todos los vehículos del mismo parte.
class MetadatosParte {
  final String parteNo;
  final String fechaHecho;
  final String horaHecho;
  final String direccion;
  final String circunstancias;
  final String elaboradoPor;
  final String elaboradoPorCedula;

  MetadatosParte({
    this.parteNo = '',
    this.fechaHecho = '',
    this.horaHecho = '',
    this.direccion = '',
    this.circunstancias = '',
    this.elaboradoPor = '',
    this.elaboradoPorCedula = '',
  });
}

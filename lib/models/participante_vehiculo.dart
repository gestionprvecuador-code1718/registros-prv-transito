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

  ParticipanteVehiculo({
    required this.placa,
    this.tipo = '',
    this.marca = '',
    this.color = '',
    this.conductor = '',
    this.conductorCedula = '',
    this.propietario = '',
    this.propietarioCedula = '',
  });
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

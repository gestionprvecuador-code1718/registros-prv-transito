/// Representa un registro de "Parte de Libertad" (devolución) de un vehículo.
class PagoGaraje {
  String ordenPagoNro;
  String comprobantePagoNro;
  String diasPagados;      // NUEVO: días que cubre esta orden de pago
  String precioUnitario;   // NUEVO: precio unitario/día según tarifa de garaje
  String valor;            // Valor pagado según el comprobante bancario/Datafast
  String horaFechaPago;
  String entidadFinanciera;

  PagoGaraje({
    this.ordenPagoNro = '',
    this.comprobantePagoNro = '',
    this.diasPagados = '',
    this.precioUnitario = '',
    this.valor = '',
    this.horaFechaPago = '',
    this.entidadFinanciera = '',
  });

  /// cantidad de días x precio unitario = lo que debería costar según
  /// la Orden de Pago (para comparar contra "valor", el comprobante real).
  double get valorCalculado {
    final dias = int.tryParse(diasPagados) ?? 0;
    final precio = double.tryParse(precioUnitario.replaceAll(',', '.')) ?? 0;
    return dias * precio;
  }

  double? get valorComoDouble => double.tryParse(valor.replaceAll(',', '.'));

  Map<String, dynamic> toJson() => {
        'ordenPagoNro': ordenPagoNro,
        'comprobantePagoNro': comprobantePagoNro,
        'diasPagados': diasPagados,
        'precioUnitario': precioUnitario,
        'valor': valor,
        'horaFechaPago': horaFechaPago,
        'entidadFinanciera': entidadFinanciera,
      };

  factory PagoGaraje.fromJson(Map<String, dynamic> j) => PagoGaraje(
        ordenPagoNro: j['ordenPagoNro'] ?? '',
        comprobantePagoNro: j['comprobantePagoNro'] ?? '',
        diasPagados: j['diasPagados'] ?? '',
        precioUnitario: j['precioUnitario'] ?? '',
        valor: j['valor'] ?? '',
        horaFechaPago: j['horaFechaPago'] ?? '',
        entidadFinanciera: j['entidadFinanciera'] ?? '',
      );
}

class CasoLibertad {
  final String id;
  String memorandoNro;
  String memorandoFecha;
  String oficioDevolucionNro;
  String oficioDevolucionFecha;
  String firmadoPor; // nombre + cargo del fiscal/juez
  String marca;
  String color;
  String placa;
  String retiradoPor; // propietario / apoderado / procurador síndico
  String cedulaRetira;
  String hojaIngresoNro;
  String parteIngresoNro;
  String fechaIngreso;
  String fechaSalida;       // NUEVO: para calcular días de permanencia
  String diasPermanencia;
  String tipoVehiculo;
  String observaciones;     // NUEVO: notas editables (ej. diferencias de comisión bancaria)
  String crv;               // NUEVO: heredado del Ingreso, para el párrafo narrativo
  String dirigidoA;         // NUEVO: grado (Mi Mayor, Mi Coronel...), heredado del Ingreso
  String causa;             // NUEVO: heredado del Ingreso
  List<PagoGaraje> pagos;
  DateTime creado;

  CasoLibertad({
    required this.id,
    this.memorandoNro = '',
    this.memorandoFecha = '',
    this.oficioDevolucionNro = '',
    this.oficioDevolucionFecha = '',
    this.firmadoPor = '',
    this.marca = '',
    this.color = '',
    this.placa = '',
    this.retiradoPor = '',
    this.cedulaRetira = '',
    this.hojaIngresoNro = '',
    this.parteIngresoNro = '',
    this.fechaIngreso = '',
    this.fechaSalida = '',
    this.diasPermanencia = '',
    this.tipoVehiculo = '',
    this.observaciones = '',
    this.crv = '',
    this.dirigidoA = 'Mi Mayor',
    this.causa = '',
    List<PagoGaraje>? pagos,
    DateTime? creado,
  })  : pagos = pagos ?? [PagoGaraje()],
        creado = creado ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'memorandoNro': memorandoNro,
        'memorandoFecha': memorandoFecha,
        'oficioDevolucionNro': oficioDevolucionNro,
        'oficioDevolucionFecha': oficioDevolucionFecha,
        'firmadoPor': firmadoPor,
        'marca': marca,
        'color': color,
        'placa': placa,
        'retiradoPor': retiradoPor,
        'cedulaRetira': cedulaRetira,
        'hojaIngresoNro': hojaIngresoNro,
        'parteIngresoNro': parteIngresoNro,
        'fechaIngreso': fechaIngreso,
        'fechaSalida': fechaSalida,
        'diasPermanencia': diasPermanencia,
        'tipoVehiculo': tipoVehiculo,
        'observaciones': observaciones,
        'crv': crv,
        'dirigidoA': dirigidoA,
        'causa': causa,
        'pagos': pagos.map((p) => p.toJson()).toList(),
        'creado': creado.toIso8601String(),
      };

  factory CasoLibertad.fromJson(Map<String, dynamic> j) => CasoLibertad(
        id: j['id'],
        memorandoNro: j['memorandoNro'] ?? '',
        memorandoFecha: j['memorandoFecha'] ?? '',
        oficioDevolucionNro: j['oficioDevolucionNro'] ?? '',
        oficioDevolucionFecha: j['oficioDevolucionFecha'] ?? '',
        firmadoPor: j['firmadoPor'] ?? '',
        marca: j['marca'] ?? '',
        color: j['color'] ?? '',
        placa: j['placa'] ?? '',
        retiradoPor: j['retiradoPor'] ?? '',
        cedulaRetira: j['cedulaRetira'] ?? '',
        hojaIngresoNro: j['hojaIngresoNro'] ?? '',
        parteIngresoNro: j['parteIngresoNro'] ?? '',
        fechaIngreso: j['fechaIngreso'] ?? '',
        fechaSalida: j['fechaSalida'] ?? '',
        diasPermanencia: j['diasPermanencia'] ?? '',
        tipoVehiculo: j['tipoVehiculo'] ?? '',
        observaciones: j['observaciones'] ?? '',
        crv: j['crv'] ?? '',
        dirigidoA: j['dirigidoA'] ?? 'Mi Mayor',
        causa: j['causa'] ?? '',
        pagos: (j['pagos'] as List? ?? [])
            .map((p) => PagoGaraje.fromJson(p))
            .toList(),
        creado: DateTime.tryParse(j['creado'] ?? '') ?? DateTime.now(),
      );

  /// Texto de los pagos ya formateado, listo para insertar en el Word
  /// (puede haber 1 o varios pagos, igual que en la plantilla original).
  String pagosComoTexto() {
    final buffer = StringBuffer();
    for (var i = 0; i < pagos.length; i++) {
      final p = pagos[i];
      buffer.writeln('${i + 1}-Orden de pago Garaje: N.- ${p.ordenPagoNro}');
      buffer.writeln('Comprobante de pago: N.- ${p.comprobantePagoNro}');
      buffer.writeln('Valor: ${p.valor} USD');
      buffer.writeln('Hora y fecha de pago: ${p.horaFechaPago}');
      buffer.writeln('Entidad financiera: ${p.entidadFinanciera}');
      if (i != pagos.length - 1) buffer.writeln();
    }
    return buffer.toString().trim();
  }

  Map<String, String> toPlaceholders() => {
        'MEMORANDO_NRO': memorandoNro,
        'MEMORANDO_FECHA': memorandoFecha,
        'OFICIO_DEVOLUCION_NRO': oficioDevolucionNro,
        'OFICIO_DEVOLUCION_FECHA': oficioDevolucionFecha,
        'FIRMADO_POR': firmadoPor,
        'MARCA': marca,
        'COLOR': color,
        'PLACA': placa.toUpperCase(),
        'RETIRADO_POR': retiradoPor,
        'CEDULA_RETIRA': cedulaRetira,
        'HOJA_INGRESO_NRO': hojaIngresoNro,
        'PARTE_INGRESO_NRO': parteIngresoNro,
        'FECHA_INGRESO': fechaIngreso,
        'FECHA_SALIDA': fechaSalida,
        'DIAS_PERMANENCIA': diasPermanencia,
        'TIPO_VEHICULO': tipoVehiculo,
        'OBSERVACIONES': observaciones,
        'CRV': crv,
        'DIRIGIDO_A': dirigidoA,
        'CAUSA': causa,
        'PAGOS': pagosComoTexto(),
      };
}

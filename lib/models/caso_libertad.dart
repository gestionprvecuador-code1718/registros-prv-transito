/// Representa un registro de "Parte de Libertad" (devolución) de un vehículo.
class PagoGaraje {
  String ordenPagoNro;
  String comprobantePagoNro;
  String diasPagados;      // días que cubre esta orden de pago
  String precioUnitario;   // precio unitario/día según tarifa de garaje
  String valor;            // Valor pagado según el comprobante bancario/Datafast
  String horaFechaPago;
  String entidadFinanciera; // Texto TAL CUAL aparece en el recibo (ej. "Pichincha Mi Vecino")
  String entidadFinancieraOficial; // uno de los 5 bancos que acepta SIIPNE 3W (ver EntidadFinancieraService)

  PagoGaraje({
    this.ordenPagoNro = '',
    this.comprobantePagoNro = '',
    this.diasPagados = '',
    this.precioUnitario = '',
    this.valor = '',
    this.horaFechaPago = '',
    this.entidadFinanciera = '',
    this.entidadFinancieraOficial = '',
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
        'entidadFinancieraOficial': entidadFinancieraOficial,
      };

  factory PagoGaraje.fromJson(Map<String, dynamic> j) => PagoGaraje(
        ordenPagoNro: j['ordenPagoNro'] ?? '',
        comprobantePagoNro: j['comprobantePagoNro'] ?? '',
        diasPagados: j['diasPagados'] ?? '',
        precioUnitario: j['precioUnitario'] ?? '',
        valor: j['valor'] ?? '',
        horaFechaPago: j['horaFechaPago'] ?? '',
        entidadFinanciera: j['entidadFinanciera'] ?? '',
        entidadFinancieraOficial: j['entidadFinancieraOficial'] ?? '',
      );
}

class CasoLibertad {
  final String id;
  String memorandoNro;
  String memorandoFecha;
  String oficioDevolucionNro;
  String oficioDevolucionFecha;
  String firmadoPor; // nombre + cargo del fiscal/juez/jefe que emite la libertad
  String marca;
  String color;
  String placa;
  String retiradoPor; // propietario / apoderado / procurador síndico
  String cedulaRetira;
  String hojaIngresoNro;
  String parteIngresoNro;
  String fechaIngreso;
  String fechaSalida; // para calcular días de permanencia
  String diasPermanencia;
  String tipoVehiculo;
  String observaciones; // notas editables (ej. diferencias de comisión bancaria) — también sirve como "Observación Salida"
  String numeroParteWebSalida; // "Nro. Parte Web" de la sección de SALIDA en SIIPNE 3W (distinto del de ingreso)

  // NUEVO: para el texto exacto del Word (calca INGRESOS_2026.rtf / LIBERTADES_2026.rtf)
  String causa; // Ej: "ACCIDENTE DE TRANSITO (Km. 85 vía Quito)" — se prellena desde el Ingreso, editable
  String gradoDestinatario; // 'Mayor', 'Tcrnl.', 'Coronel'... define el saludo "Mi Mayor"/"Mi Tcrnl."

  // --- para llenar la matriz Excel (pestañas VEHICULOS/MOTOCICLETAS) ---
  String tipoServicioGaraje; // "SERVICIO DE GARAJE LIVIANOS...", etc. (define la tarifa diaria)
  String custodioEntregaNombre; // policía que entrega físicamente el vehículo al salir (columna AL/AD)
  String placaGrua; // si la grúa también participó en la salida (normalmente igual que en el ingreso)

  // NUEVO (31/ago): "Investigación / Pericias" se movió de la hoja de
  // Ingreso a la hoja de Salida (Libertad), por pedido de Xavier.
  String periciaRealizada;
  String peritoNombre;

  // NUEVO (31/ago): pago del Alcohocheck — antes vivía en el Ingreso
  // junto al módulo de alcoholemia; Xavier pidió que el pago se
  // registre aquí, igual que los demás comprobantes de pago de garaje.
  // Solo aplica cuando el Ingreso tuvo aplicaAlcohotest == true.
  String ordenPagoAlcohocheckNro;
  String comprobantePagoAlcohocheckNro;
  String valorAlcohocheck;
  String horaFechaPagoAlcohocheck;

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
    this.numeroParteWebSalida = '',
    this.causa = '',
    this.gradoDestinatario = 'Mayor',
    this.tipoServicioGaraje = '',
    this.custodioEntregaNombre = '',
    this.placaGrua = '',
    this.periciaRealizada = '',
    this.peritoNombre = '',
    this.ordenPagoAlcohocheckNro = '',
    this.comprobantePagoAlcohocheckNro = '',
    this.valorAlcohocheck = '',
    this.horaFechaPagoAlcohocheck = '',
    List<PagoGaraje>? pagos,
    DateTime? creado,
  })  : pagos = pagos ?? [PagoGaraje()],
        creado = creado ?? DateTime.now();

  /// Suma de todos los pagos registrados (para la columna "VALOR CANCELADO
  /// POR PARQUEO" de la matriz Excel, y para el Word/PDF del caso).
  double get valorTotalGaraje =>
      pagos.fold(0.0, (suma, p) => suma + (p.valorComoDouble ?? 0));

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
        'numeroParteWebSalida': numeroParteWebSalida,
        'causa': causa,
        'gradoDestinatario': gradoDestinatario,
        'tipoServicioGaraje': tipoServicioGaraje,
        'custodioEntregaNombre': custodioEntregaNombre,
        'placaGrua': placaGrua,
        'periciaRealizada': periciaRealizada,
        'peritoNombre': peritoNombre,
        'ordenPagoAlcohocheckNro': ordenPagoAlcohocheckNro,
        'comprobantePagoAlcohocheckNro': comprobantePagoAlcohocheckNro,
        'valorAlcohocheck': valorAlcohocheck,
        'horaFechaPagoAlcohocheck': horaFechaPagoAlcohocheck,
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
        numeroParteWebSalida: j['numeroParteWebSalida'] ?? '',
        causa: j['causa'] ?? '',
        gradoDestinatario: j['gradoDestinatario'] ?? 'Mayor',
        tipoServicioGaraje: j['tipoServicioGaraje'] ?? '',
        custodioEntregaNombre: j['custodioEntregaNombre'] ?? '',
        placaGrua: j['placaGrua'] ?? '',
        periciaRealizada: j['periciaRealizada'] ?? '',
        peritoNombre: j['peritoNombre'] ?? '',
        ordenPagoAlcohocheckNro: j['ordenPagoAlcohocheckNro'] ?? '',
        comprobantePagoAlcohocheckNro: j['comprobantePagoAlcohocheckNro'] ?? '',
        valorAlcohocheck: j['valorAlcohocheck'] ?? '',
        horaFechaPagoAlcohocheck: j['horaFechaPagoAlcohocheck'] ?? '',
        pagos: (j['pagos'] as List? ?? [])
            .map((p) => PagoGaraje.fromJson(p))
            .toList(),
        creado: DateTime.tryParse(j['creado'] ?? '') ?? DateTime.now(),
      );

  /// Texto de los pagos para mostrar/depurar EN LA APP (incluye lo que
  /// dice el recibo literal, además del banco oficial). NO es el texto
  /// que va al Word — para eso usar pagosParaWord().
  String pagosComoTexto() {
    final buffer = StringBuffer();
    for (var i = 0; i < pagos.length; i++) {
      final p = pagos[i];
      buffer.writeln('${i + 1}-Orden de pago Garaje: N.- ${p.ordenPagoNro}');
      buffer.writeln('Comprobante de pago: N.- ${p.comprobantePagoNro}');
      buffer.writeln('Valor: ${p.valor} USD');
      buffer.writeln('Hora y fecha de pago: ${p.horaFechaPago}');
      buffer.writeln('Entidad financiera: ${p.entidadFinancieraOficial} (recibo dice: "${p.entidadFinanciera}")');
      if (i != pagos.length - 1) buffer.writeln();
    }
    return buffer.toString().trim();
  }

  /// Texto LIMPIO de los pagos, EXACTAMENTE como aparece en
  /// LIBERTADES_2026.rtf (una línea por dato, sin anotaciones internas).
  /// Usa el banco OFICIAL (uno de los 5 de SIIPNE 3W) porque es lo que
  /// se sube al sistema; si por algún motivo aún no se eligió el
  /// oficial, cae de respaldo al texto literal del recibo.
  List<String> pagosParaWord() {
    final out = <String>[];
    for (var i = 0; i < pagos.length; i++) {
      final p = pagos[i];
      out.add('${i + 1}-Orden de pago Garaje: N.- ${p.ordenPagoNro}');
      out.add('Comprobante de pago: N.- ${p.comprobantePagoNro}');
      out.add('Valor: ${p.valor}');
      if (p.horaFechaPago.trim().isNotEmpty) {
        out.add('Hora y fecha de pago: ${p.horaFechaPago}');
      }
      final entidad = p.entidadFinancieraOficial.trim().isNotEmpty
          ? p.entidadFinancieraOficial
          : p.entidadFinanciera;
      out.add('Entidad financiera: $entidad');
    }
    return out;
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
        'TIPO_SERVICIO_GARAJE': tipoServicioGaraje,
        'CUSTODIO_ENTREGA': custodioEntregaNombre,
        'OBSERVACIONES': observaciones,
        'CAUSA': causa,
        'PERICIA_REALIZADA': periciaRealizada,
        'PERITO_NOMBRE': peritoNombre,
        'ALCOHOCHECK_ORDEN_PAGO': ordenPagoAlcohocheckNro,
        'ALCOHOCHECK_COMPROBANTE': comprobantePagoAlcohocheckNro,
        'ALCOHOCHECK_VALOR': valorAlcohocheck,
        'ALCOHOCHECK_HORA_FECHA': horaFechaPagoAlcohocheck,
        'PAGOS': pagosComoTexto(),
      };
}

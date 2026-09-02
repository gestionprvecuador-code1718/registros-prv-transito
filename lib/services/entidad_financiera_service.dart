// RUTA DE ARCHIVO: lib/services/entidad_financiera_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// SIIPNE 3W solo acepta 5 entidades financieras en su desplegable
/// ("REGISTRO DE VALORES DE RECAUDACIÓN POR SERVICIO"). Pero en la
/// vida real, un comprobante puede venir de un servicio de pago
/// rápido con otro nombre (ej. "Pichincha Mi Vecino", "Facilito",
/// "Servipagos", "Guayaquil Mi Vecino") que en el fondo corresponde a
/// uno de esos 5 bancos.
///
/// Este servicio:
/// 1. Mantiene la lista fija de las 5 opciones oficiales (lo que
///    finalmente hay que subir a SIIPNE).
/// 2. Guarda, en el mismo casillero del comprobante, el nombre TAL
///    CUAL aparece en el recibo (para no perder ese detalle).
/// 3. Sugiere automáticamente a cuál de los 5 bancos oficiales
///    corresponde ese nombre, usando primero una lista de alias
///    conocidos "de fábrica", y luego una lista de alias que el
///    propio oficial va enseñando (se guarda en SharedPreferences, así
///    que cada celular/navegador va aprendiendo con el uso — si
///    quieres que el aprendizaje se comparta entre TODOS los patios,
///    avísame y lo subimos también a Firestore).
class EntidadFinancieraService {
  static const oficiales = [
    'BANCO DEL PICHINCHA',
    'BANCO DEL PACÍFICO',
    'PRODUBANCO',
    'BANCO BOLIVARIANO',
    'BANCO DE GUAYAQUIL',
  ];

  static const _claveAliasAprendidos = 'alias_entidades_financieras';

  // Alias conocidos "de fábrica" — los que Xavier ya mencionó. Se
  // comparan en minúsculas y sin tildes, buscando que el texto los
  // CONTENGA (no que sea igual), para que "Pago con Pichincha Mi
  // Vecino - Sucursal Centro" también matche.
  static const Map<String, String> _aliasDeFabrica = {
    'pichincha': 'BANCO DEL PICHINCHA',
    'mi vecino': 'BANCO DEL PICHINCHA',
    'pacifico': 'BANCO DEL PACÍFICO',
    'produbanco': 'PRODUBANCO',
    'facilito': 'PRODUBANCO',
    'servipagos': 'PRODUBANCO',
    'bolivariano': 'BANCO BOLIVARIANO',
    'guayaquil': 'BANCO DE GUAYAQUIL',
  };

  static String _normalizar(String texto) => texto
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .trim();

  /// Alias aprendidos en este dispositivo: { "texto tal cual lo tipeó
  /// el oficial" -> "BANCO OFICIAL" }.
  static Future<Map<String, String>> _cargarAprendidos() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_claveAliasAprendidos);
    if (data == null) return {};
    return Map<String, String>.from(jsonDecode(data));
  }

  /// Dado el texto literal del comprobante (ej. "Pichincha Mi Vecino"),
  /// sugiere a cuál de los 5 bancos oficiales corresponde. Devuelve
  /// null si no reconoce nada (el oficial tendrá que elegirlo a mano
  /// la primera vez).
  static Future<String?> sugerirOficial(String textoRecibo) async {
    if (textoRecibo.trim().isEmpty) return null;
    final normalizado = _normalizar(textoRecibo);

    // 1) ¿Ya lo aprendimos antes, tal cual?
    final aprendidos = await _cargarAprendidos();
    for (final entry in aprendidos.entries) {
      if (_normalizar(entry.key) == normalizado) return entry.value;
    }

    // 2) ¿Coincide con algún alias de fábrica (por contención)?
    for (final entry in _aliasDeFabrica.entries) {
      if (normalizado.contains(entry.key)) return entry.value;
    }

    return null;
  }

  /// Guarda un alias nuevo (o corrige uno existente) para la próxima
  /// vez — se llama cuando el oficial confirma o corrige a mano cuál
  /// es el banco oficial de un texto de recibo que la app no supo
  /// reconocer sola.
  static Future<void> aprenderAlias(String textoRecibo, String bancoOficial) async {
    if (textoRecibo.trim().isEmpty || !oficiales.contains(bancoOficial)) return;
    final prefs = await SharedPreferences.getInstance();
    final aprendidos = await _cargarAprendidos();
    aprendidos[textoRecibo.trim()] = bancoOficial;
    await prefs.setString(_claveAliasAprendidos, jsonEncode(aprendidos));
  }
}

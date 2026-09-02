import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/caso_ingreso.dart';
import '../models/caso_libertad.dart';

/// Sube (y ahora también lee) cada caso desde Firestore, en dos lugares:
///
/// 1. `casos_nacionales/{tipo_id}` — el registro COMPLETO (todos los
///    campos del modelo, vía toJson()), solo visible para oficiales
///    aprobados. Esta es la base nacional de verdad, y es también lo
///    que usa cada patio para ver SUS PROPIOS ingresos/libertades desde
///    cualquier dispositivo (filtrando por el campo 'patio').
///    Guardar el toJson() completo (en vez de elegir campos a mano)
///    evita que falte algún dato al reconstruir el caso más tarde con
///    fromJson() — si el modelo agrega un campo nuevo, ya viaja solo.
/// 2. `consulta_publica/{placa}` — un solo documento POR PLACA con
///    apenas los datos que pueden verse públicamente (placa, marca,
///    color, estado, patio) — sin nombre ni cédula del propietario.
///    Esto es lo que la página web pública (para civiles) va a leer.
///    Este NO cambia: sigue siendo un subconjunto curado a propósito.
///
/// Esta sincronización es "mejor esfuerzo": si falla (sin internet,
/// etc.) el caso ya quedó guardado localmente sin ningún problema —
/// simplemente no llegó todavía a la nube. Más adelante se puede
/// agregar una cola de reintentos; por ahora el usuario puede seguir
/// trabajando offline sin que la app se bloquee.
///
/// NOTA SOBRE ÍNDICES: obtenerIngresos/obtenerLibertades hacen una
/// consulta con dos condiciones (tipo + patio) más un orden (creado).
/// Firestore va a pedir un índice compuesto la primera vez que esto se
/// ejecute — mostrará un error en la consola con un enlace que crea
/// ese índice con un clic. Es un paso único, no hay que repetirlo.
class FirestoreSyncService {
  final _firestore = FirebaseFirestore.instance;

  Future<void> subirIngreso(CasoIngreso c, {required String patio}) async {
    try {
      await _firestore.collection('casos_nacionales').doc('ingreso_${c.id}').set({
        'tipo': 'ingreso',
        'patio': patio,
        ...c.toJson(),
        'actualizado': FieldValue.serverTimestamp(),
      });

      if (c.placa.isNotEmpty) {
        await _firestore.collection('consulta_publica').doc(c.placa.toUpperCase()).set({
          'placa': c.placa.toUpperCase(),
          'marca': c.marca,
          'color': c.color,
          'estado': 'RETENIDO',
          'patio': patio,
          'actualizado': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {
      // Sin internet o falla de red: el caso ya está guardado localmente.
      // No se interrumpe el flujo del usuario por esto.
    }
  }

  Future<void> subirLibertad(CasoLibertad c, {required String patio}) async {
    try {
      await _firestore.collection('casos_nacionales').doc('libertad_${c.id}').set({
        'tipo': 'libertad',
        'patio': patio,
        ...c.toJson(),
        'actualizado': FieldValue.serverTimestamp(),
      });

      if (c.placa.isNotEmpty) {
        await _firestore.collection('consulta_publica').doc(c.placa.toUpperCase()).set({
          'placa': c.placa.toUpperCase(),
          'marca': c.marca,
          'color': c.color,
          'estado': 'LIBERADO',
          'patio': patio,
          'actualizado': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {
      // Igual que arriba: falla silenciosa, el caso local no se pierde.
    }
  }

  /// Trae todos los ingresos de UN patio específico, desde la nube.
  /// Lanza una excepción si no hay internet (a propósito: así
  /// storage_service.dart puede detectar la falla y usar la copia
  /// local cacheada como respaldo).
  Future<List<CasoIngreso>> obtenerIngresos(String patio) async {
    final query = await _firestore
        .collection('casos_nacionales')
        .where('tipo', isEqualTo: 'ingreso')
        .where('patio', isEqualTo: patio)
        .orderBy('creado')
        .get(const GetOptions(source: Source.server));

    return query.docs.map((d) => CasoIngreso.fromJson(d.data())).toList();
  }

  /// Igual que obtenerIngresos, pero para libertades.
  Future<List<CasoLibertad>> obtenerLibertades(String patio) async {
    final query = await _firestore
        .collection('casos_nacionales')
        .where('tipo', isEqualTo: 'libertad')
        .where('patio', isEqualTo: patio)
        .orderBy('creado')
        .get(const GetOptions(source: Source.server));

    return query.docs.map((d) => CasoLibertad.fromJson(d.data())).toList();
  }
}

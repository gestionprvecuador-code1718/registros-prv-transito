import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_usuarios_screen.dart';
import 'captura_screen.dart';
import 'documento_screen.dart';
import 'ajustes_screen.dart';
import 'buscar_placa_screen.dart';
import 'informe_semanal_screen.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';

enum TipoParte { ingreso, libertad }

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _exportarExcelMasivo(BuildContext context) async {
    try {
      final bytes = await StorageService.generarExcelConsolidado();
      if (bytes == null || bytes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay información suficiente para generar la matriz Excel.')),
          );
        }
        return;
      }

      final xFile = XFile.fromData(
        Uint8List.fromList(bytes),
        name: 'REPORTE_MATRIZ_PATIO_2026.xlsx',
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      await Share.shareXFiles([xFile], text: 'Matriz Consolidada de Registros de Patio 2026 (.xlsx)');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar la matriz Excel: $e')),
        );
      }
    }
  }

  // Abre la página externa de consulta de vehículos (AXIS CRV). Es un
  // formulario de búsqueda por placa/VIN/motor; no tiene una URL de
  // consulta directa por parámetros, así que solo se abre en el
  // navegador — el oficial busca la placa manualmente ahí.
  static const _urlConsultaVehiculos = 'https://servicios.axiscloud.ec/CRV/?ps_empresa=02';

  Future<void> _abrirConsultaVehiculos(BuildContext context) async {
    final uri = Uri.parse(_urlConsultaVehiculos);
    final abierto = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!abierto && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el navegador.')),
      );
    }
  }

  Widget _botonAdminSiCorresponde() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('usuarios').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final esAdmin = snapshot.data?.data()?['esAdmin'] == true;
        if (!esAdmin) return const SizedBox.shrink();
        return IconButton(
          icon: const Icon(Icons.admin_panel_settings),
          tooltip: 'Panel Nacional',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminUsuariosScreen()),
            );
          },
        );
      },
    );
  }

  // NUEVO (30/ago): muestra "PRV [nombre del patio]" debajo del sello,
  // leyendo en vivo el campo 'patio' que guarda identificacion_screen.dart
  // en Firestore (colección "usuarios"). Es el nombre bautizado que esa
  // cuenta le puso a su matriz (ej. "Control 120" → "PRV CONTROL 120").
  Widget _nombrePatio() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('usuarios').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final patio = (snapshot.data?.data()?['patio'] as String?)?.trim();
        if (patio == null || patio.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'PRV ${patio.toUpperCase()}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 0.5,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('REGISTROS PRV TRANSITO'),
        backgroundColor: const Color(0xFF17356E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          _botonAdminSiCorresponde(),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Ajustes de IA',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AjustesScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => AuthService().cerrarSesion(),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
        decoration: const BoxDecoration(
          // 01/sep: degradado azul institucional aprobado por Xavier
          // (inspirado en la app oficial SIIPNE Móvil) — NO CAMBIAR sin
          // que lo pida explícitamente, ya pasó por varias iteraciones.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF17356E), Color(0xFF1C4488)],
          ),
        ),
        child: Stack(
          children: [
            // Marca de agua sutil del sello institucional en la esquina
            // inferior derecha, inspirada en la app oficial SIIPNE Móvil.
            Positioned(
              right: -30,
              bottom: -30,
              child: Opacity(
                opacity: 0.06,
                child: Image.asset('assets/logo.png', width: 220, height: 220),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Image.asset('assets/logo.png', height: 98),
                    const SizedBox(height: 14),
                    const Text(
                      'CONTROL Y GESTIÓN DE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // 01/sep: Xavier pidió explícitamente "no cambies" este
                    // color en futuras iteraciones de diseño.
                    const Text(
                      'PATIOS DE RETENCIÓN\nVEHICULAR ECUADOR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF5BA3F5),
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        letterSpacing: 0.3,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'En un solo lugar',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: 26, height: 3, color: const Color(0xFFE8B62C)),
                        const SizedBox(width: 5),
                        Container(width: 26, height: 3, color: const Color(0xFF5BA3F5)),
                        const SizedBox(width: 5),
                        Container(width: 26, height: 3, color: const Color(0xFFC0392B)),
                      ],
                    ),
                    _nombrePatio(),
                    const SizedBox(height: 28),
                    _BotonPrincipal(
                      icono: Icons.login,
                      titulo: 'INGRESO',
                      subtitulo: 'Registrar el ingreso de un vehículo al CRV',
                      // 01/sep: Ingreso = ROJO (antes verde) — confirmado por Xavier
                      color: Colors.red.shade700,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CapturaScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _BotonPrincipal(
                      icono: Icons.logout,
                      titulo: 'LIBERTAD',
                      subtitulo: 'Registrar la devolución / libertad de un vehículo',
                      // 01/sep: Libertad = VERDE (antes naranja) — confirmado por Xavier
                      color: Colors.green.shade700,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CapturaScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: _estiloBotonClaro(),
                        icon: const Icon(Icons.search),
                        label: const Text('Buscar por placa (editar un caso)'),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BuscarPlacaScreen())),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: _estiloBotonClaro(),
                        icon: const Icon(Icons.travel_explore),
                        label: const Text('Consultar Información (base ANT/AXIS)'),
                        onPressed: () => _abrirConsultaVehiculos(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.table_chart_outlined),
                        // 01/sep: renombrado de "EXPORTAR MATRIZ COMPLETA A EXCEL (.XLSX)"
                        label: const Text('GENERAR EXCEL'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => _exportarExcelMasivo(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: _estiloBotonClaro(),
                        icon: const Icon(Icons.summarize_outlined),
                        // 01/sep: renombrado de "Generar informe semanal"
                        label: const Text('Generar Informe Semanal'),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const InformeSemanalScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: _estiloBotonClaro(),
                            icon: const Icon(Icons.description_outlined),
                            label: const Text('Ver Ingresos'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DocumentoScreen(tipo: TipoParte.ingreso),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: _estiloBotonClaro(),
                            icon: const Icon(Icons.description_outlined),
                            label: const Text('Ver Libertades'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DocumentoScreen(tipo: TipoParte.libertad),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 01/sep: estilo compartido para los botones "neutros" — blanco sobre
  // el fondo azul institucional, para que se sigan viendo bien.
  ButtonStyle _estiloBotonClaro() {
    return OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: Colors.white70),
    );
  }
}

class _BotonPrincipal extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final Color color;
  final VoidCallback onTap;

  const _BotonPrincipal({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              Icon(icono, color: Colors.white, size: 34),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitulo,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

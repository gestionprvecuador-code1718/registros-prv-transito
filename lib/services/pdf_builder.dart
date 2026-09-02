import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Genera un PDF simple a partir del mismo formato de "bloques de
/// texto" que ya usa DocxBuilder, para mantener ambos documentos
/// consistentes entre sí.
///
/// REQUIERE agregar la dependencia "pdf" a tu pubspec.yaml si no la
/// tienes todavía:
///
///   dependencies:
///     pdf: ^3.11.1
///
/// (ejecuta "flutter pub get" después de agregarla)
class PdfBuilder {
  /// [titulo] aparece como encabezado del documento.
  /// [bloques] es una lista de "registros"; cada registro es una lista
  /// de líneas de texto (mismo formato que recibe DocxBuilder.build).
  static Future<Uint8List> build({required String titulo, required List<List<String>> bloques}) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              titulo,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 12),
          ],
        ),
        build: (context) {
          final widgets = <pw.Widget>[];
          for (var i = 0; i < bloques.length; i++) {
            for (final linea in bloques[i]) {
              widgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text(linea, style: const pw.TextStyle(fontSize: 11)),
                ),
              );
            }
            if (i != bloques.length - 1) {
              widgets.add(pw.SizedBox(height: 10));
              widgets.add(pw.Divider());
              widgets.add(pw.SizedBox(height: 10));
            }
          }
          return widgets;
        },
      ),
    );

    return await doc.save();
  }
}
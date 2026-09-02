import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Campo de texto que "aprende" los valores que se van escribiendo,
/// igual que el autocompletar de Excel: guarda cada valor nuevo
/// localmente (SharedPreferences) y la próxima vez lo ofrece como
/// sugerencia en un desplegable editable. Siempre se puede seguir
/// escribiendo un valor distinto a mano; no es una lista cerrada.
class CampoAutocompletable extends StatefulWidget {
  final String etiqueta;
  final String claveAlmacenamiento; // clave única por casillero, ej: 'servidor_recibe'
  final TextEditingController controller;
  final String? hintText;
  final bool requerido;

  const CampoAutocompletable({
    super.key,
    required this.etiqueta,
    required this.claveAlmacenamiento,
    required this.controller,
    this.hintText,
    this.requerido = false,
  });

  @override
  State<CampoAutocompletable> createState() => _CampoAutocompletableState();
}

class _CampoAutocompletableState extends State<CampoAutocompletable> {
  static const int _maxSugerencias = 40;
  List<String> _sugerencias = [];
  late final FocusNode _focusNode;

  String get _prefKey => 'sugerencias_${widget.claveAlmacenamiento}';

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _guardarValorSiEsNuevo();
    });
    _cargarSugerencias();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _cargarSugerencias() async {
    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList(_prefKey) ?? [];
    if (mounted) setState(() => _sugerencias = lista);
  }

  Future<void> _guardarValorSiEsNuevo() async {
    final valor = widget.controller.text.trim();
    if (valor.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList(_prefKey) ?? [];
    lista.removeWhere((v) => v.toLowerCase() == valor.toLowerCase());
    lista.insert(0, valor); // el más reciente aparece primero
    if (lista.length > _maxSugerencias) {
      lista.removeRange(_maxSugerencias, lista.length);
    }
    await prefs.setStringList(_prefKey, lista);
    if (mounted) setState(() => _sugerencias = lista);
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) return _sugerencias;
        return _sugerencias.where(
          (s) => s.toLowerCase().contains(textEditingValue.text.toLowerCase()),
        );
      },
      onSelected: (String seleccion) {
        widget.controller.text = seleccion;
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: widget.etiqueta,
            hintText: widget.hintText,
            suffixIcon: const Icon(Icons.history, size: 18),
          ),
          validator: widget.requerido
              ? (v) => (v == null || v.isEmpty) ? 'Requerido' : null
              : null,
          onFieldSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, minWidth: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final opcion = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(opcion),
                    onTap: () => onSelected(opcion),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

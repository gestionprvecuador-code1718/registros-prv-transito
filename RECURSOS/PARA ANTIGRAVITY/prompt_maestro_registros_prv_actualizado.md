# PROMPT MAESTRO — App "REGISTROS PRV TRANSITO"

> Este documento describe de punta a punta una aplicación Flutter (Android) ya en desarrollo activo, para que cualquier IA que lo lea entienda completamente: (1) qué es y para quién es, (2) qué tan avanzada está y cómo funciona hoy, (3) el diseño visual y de flujo ya definido, y (4) qué falta por construir o corregir. No es un historial de conversación: es una fotografía del estado actual + la lista de necesidades pendientes, para retomar el trabajo sin perder contexto.

---

## 1. Qué es la app y para quién

**REGISTROS PRV TRANSITO** es una app Flutter para Android usada por policías de los **Patios de Retención Vehicular (PRV)** de la Policía Nacional del Ecuador (Dirección Nacional de Control del Tránsito y Seguridad Vial). Digitaliza el proceso, hoy manual y en papel, de:

- **Ingreso** de un vehículo retenido a un patio (parte policial).
- **Libertad/devolución** de ese vehículo a su propietario.

El objetivo final es una **base de datos nacional**: la app la usarán policías de aproximadamente **28-76 patios** a nivel nacional (existe un catálogo oficial de 76 CRV distribuidos en 9 zonas). Un administrador nacional (el propio Xavier, quien además es usuario normal del patio "Control 120 Santo Domingo de los Tsáchilas") debe poder:
- Aprobar manualmente qué usuarios/policías pueden usar la app.
- Ver y tomar control de los ingresos de cualquier patio del país.
- Consultar estadísticas de productividad por patio.

A futuro (fase pública, hoy en pausa) se contempla una PWA sin login donde cualquier civil pueda consultar por placa si un vehículo está retenido o libre, mostrando solo datos no sensibles (placa, marca, color, estado, patio — nunca nombre ni cédula del propietario, por protección de datos).

**Quién es el usuario final:** policías con poco tiempo y a veces sin conectividad estable, que hoy llenan partes físicos a mano y deben generar documentos Word/PDF formales para entregar. La app debe ahorrarles ese trabajo de transcripción usando IA para leer los documentos fuente (fotos o PDFs) y llenar automáticamente los formularios.

---

## 2. Identidad técnica del proyecto

- Package Android: `com.example.registros_prv_transito`
- Firebase `project_id`: `patios-de-retencion-vehi-a8ab7`
- Repositorio (público): `https://github.com/gestionprvecuador-code1718/registros-prv-transito`, rama `main`
- URL PWA: `https://patios-de-retencion-vehi-a8ab7.web.app` (normal) y `/admin` (Panel Nacional) — **en pausa**
- Estructura de carpetas: `lib/models`, `lib/screens`, `lib/services`, `lib/templates`, `lib/utils`, `lib/widgets`, `lib/data`, más `main.dart`
- Motor de IA para lectura de documentos: **Google Gemini con visión** (modelo vigente: `gemini-flash-latest`), cada patio/usuario configura su propia API key (no una clave compartida embebida), porque la app es sin fines de lucro.

---

## 3. Diseño visual y de flujo (ya definido y aprobado)

- **Pantalla Home:** degradado azul `#17356E → #1C4488`, título en `#5BA3F5` (color fijo, no cambiar).
- Botón de **Ingreso**: rojo. Botón para registrar la **devolución/libertad**: verde — su texto debe decir **"Buscar placa para liberar"** (cambio de copy pendiente de aplicar; el color y la función no cambian). El botón "Buscar placa" suelto (translúcido) debe eliminarse por quedar redundante con lo anterior.
- Botón de consulta vehicular externa "AXIS CRV" (abre `https://servicios.axiscloud.ec/CRV/?ps_empresa=02` vía `url_launcher`), junto al casillero de tonelaje (TN).
- **Sello de estado** de cada caso (widget `SelloEstadoGrande`, visible en la lista de casos y en "Buscar por placa"): debe reflejar el **estado real** del vehículo, no un texto fijo — "INGRESADO" en rojo si el vehículo aún no tiene libertad registrada, "LIBERADO" en verde si ya la tiene. Mismo comportamiento en ambas pantallas.
- **Formulario de Ingreso**, orden exacto (sigue el formulario oficial SIIPNE 3W):
  Tipo operativo → Fecha/Hora retención → Personal que toma procedimiento → Propietario → Conductor → Causa legal/Detalle causa → Datos del vehículo (incluye Modelo y campo de tonelaje angosto con botón de consulta AXIS CRV) → Formulario N° → N° Parte Web → Traslado → Tipo de cobro → Alcoholemia → Personal que recibe custodia.
  Los campos usan **autocompletado tipo Excel** (aprenden valores ya escritos antes y los sugieren).
- **Formulario de Libertad**: hereda automáticamente todos los datos del Ingreso ya guardado; solo se completan los datos nuevos propios de la salida: memorando/oficio de devolución, quién firma, quién retira y su cédula, pagos de garaje (uno o varios pagos parciales), investigación/pericias, pago de alcohocheck, placa de la grúa en la salida.
- **Flujo de guardado/edición** (definido tras varias correcciones):
  1. El usuario llena datos (a mano o vía IA).
  2. Si falta un campo obligatorio, la app debe avisar con un diálogo ("Completar campos" / "Guardar de todas formas") — nunca bloquear en silencio, y debe permitir avanzar sin ese dato porque a veces no está disponible al momento.
  3. Botón **"Guardar avance"** (nombre definitivo, ya no "Guardar sin vista previa"): guarda tal cual estén los datos, sin decidir nada en firme.
  4. Botón **"Vista previa"**: dentro de la vista previa están las opciones reales de cierre — "Guardar como Word" y "Enviar por WhatsApp". La decisión de dejar el caso guardado en firme la toma el usuario **desde dentro** de la vista previa, nunca antes ni automáticamente.
  5. Un caso ya guardado debe poder reabrirse y seguir editándose después (por ejemplo si más adelante aparece un dato que faltaba, como motor/chasis).
- **Vista previa**: además de "Descargar" (Word) y "Enviar por WhatsApp", existe también una opción de **descargar PDF** junto a WhatsApp, para quien solo necesita imprimir.
- En la lista de **Ingresos** existe ícono de editar (lápiz); en **Libertades** debe existir el mismo ícono de editar (agregarlo, hoy falta).
- Debe existir un **historial/estadística de ediciones** posteriores a un Ingreso o Libertad, visible en el panel de administrador.
- Debe existir una **pantalla/pestaña dentro de la app** que muestre los PDFs originales guardados localmente como respaldo de cada caso (sin subirlos a la nube, para no depender de un plan de pago de Firebase Storage).
- Validación anti-duplicados pendiente: antes de guardar un Ingreso, verificar contra la base si esa placa ya tiene un caso abierto, y alertar de forma bloqueante si es así.

---

## 4. Cómo lee los documentos fuente (núcleo de la app)

Existen dos tipos de documento fuente y dos vías de lectura:

1. **Fotos** de la hoja física de ingreso/salida (formulario impreso, a veces con datos escritos a mano) → se procesan siempre con **Gemini Vision** (la app renuncia al OCR local porque no lee bien la letra manuscrita; sí lee el texto impreso, pero Gemini generaliza mucho mejor).
2. **PDF digital** (parte de Ecu911, "Noticia del Incidente/Parte Policial"), que trae texto real embebido, no imagen escaneada. Aquí hay dos caminos:
   - **Camino principal (vigente):** cada página del PDF se convierte a imagen (paquete `printing`, `Printing.raster`) y se manda igual a **Gemini Vision**, con un prompt propio (`extraerParteDigital`) que devuelve metadatos generales del caso + una **lista** de vehículos (a diferencia del prompt de fotos, que asume un solo vehículo). Este cambio de arquitectura se hizo porque un parser basado solo en expresiones regulares nunca iba a generalizar a los ~75 patios del país, cada uno con partes formateados distinto.
   - **Camino de respaldo (`pdf_parser_service.dart`):** extracción de texto puro con Syncfusion (`PdfTextExtractor`) + expresiones regulares, sin IA. Se usa automáticamente solo si no hay internet/API key o si la IA no logra extraer nada — nunca reemplaza al camino principal, solo lo respalda.

**Reglas de extracción ya afinadas para el camino sin IA** (relevantes también como referencia de qué datos existen y dónde suelen estar en un parte real de Ecu911):
- Fecha de retención ← "Fecha del Hecho"; Hora ← "Hora aproximada del Hecho".
- Personal que toma procedimiento ← el de mayor grado dentro de "Personal policial que participó en el hecho".
- Conductor ← sección de aprehendidos/detenidos (o circunstancias del hecho si no existe esa sección); Propietario por defecto usa el mismo dato que Conductor (decisión explícita, no error).
- Causa legal/Detalle causa ← "Circunstancias del hecho" completo, priorizando la cita textual del artículo aplicable.
- Placa, marca, chasis, país, año y modelo se extraen de bloques narrativos de "VEHÍCULOS INVOLUCRADOS" y de un bloque separado de "Objetos registrados como indicios" (que casi siempre trae los datos técnicos del vehículo — Chasis, Motor, Placa, Año, Color — y se repite un segmento por cada vehículo si hay más de uno). El emparejamiento entre ambos bloques no siempre respeta el mismo orden, así que se hace por coincidencia de marca, no solo por posición.
- **Limitación técnica de fondo:** el extractor de texto de Syncfusion saca todas las etiquetas de una tabla juntas primero, y todos los valores juntos después (a veces desordenados) — por eso cualquier regex tipo "Etiqueta: valor" pegada falla en las secciones de tabla; solo el bloque narrativo mantiene el orden correcto. Esta es la razón estructural por la que se migró la vía principal de lectura de PDF a IA (Gemini Vision) en vez de seguir parchando regex.
- El campo **Motor** en particular no tiene un patrón posicional fijo confiable (a diferencia de Chasis=VIN de 17 caracteres, Año=4 dígitos, País=lista conocida), así que su extracción sin IA sigue siendo un punto débil.
- Toda la detección de vehículos corre bloque por bloque dentro de manejo de errores aislado: si un bloque/vehículo falla, se salta y se sigue con el resto — nunca debe devolver "no se detectó ningún vehículo" por un solo casillero mal formado.

**Necesidad pendiente relacionada:** construir un extractor dedicado para el **"Oficio de Devolución de Vehículo"** (el documento, en prosa libre, que se entrega al dar la libertad) — llenaría directamente memorando/oficio/pago de garaje del formulario de Libertad, emparejando por número de Hoja/Parte de Ingreso o por placa contra el Ingreso ya guardado, sin pisar los datos del vehículo ya heredados. Confirmado que el usuario sí cuenta con este documento en mano al momento de dar la libertad.

---

## 5. Catálogos y reglas de negocio ya definidas

- **Tarifario oficial de garaje** (vigente 2021-2025): Vehículos livianos ≤3.5 TN = $3/día; Pesados 3.51–12 TN = $9/día; Motocicleta = $1/día; Extrapesados >12 TN = $15/día.
- **Bancos oficiales SIIPNE 3W**: lista fija de 5 entidades financieras — no debe ampliarse a texto libre ni agregarse bancos nuevos.
- **Jerarquía institucional** (de mayor a menor grado): Crnl, Tcrnl, Myor/Mayr, Cptn, Tnte, Sbte, Sbom, Sbop, Sbos, Sgop, Sgos, Cbop, Cbos, Poli.
- **Jerarquía de ubicación**: Zona → Jefatura/Subjefatura → CRV (catálogo real de 76 CRV en 9 zonas) + Patio obligatorio.
- **Catálogo de causa legal**: 5 causas reales según SIIPNE 3W (las descripciones actuales son un resumen hecho a partir de capturas del usuario, todavía no son el texto oficial literal de cada artículo — pendiente).
- **Tipos de vehículo**: catálogo ampliado a 18 tipos (camión, furgón, jeep, bus, buseta, van, tráiler, cabezal, volqueta, tanquero, motocicleta, cuatrimoto, plataforma, grúa, mixto, otro, etc.) con normalización de sinónimos (ej. "Furgoneta", "Camion" sin tilde, "Pick up"). Además el catálogo es **dinámico**: cualquier tipo nuevo que la IA detecte y no esté en la lista (ej. "Triciclo") se agrega automáticamente y queda disponible para el siguiente ingreso, en vez de forzarlo a "Otro".
- **Validación de pagos de garaje** (Libertad): debe verificar que cantidad de días × precio unitario coincida con el valor pagado según el comprobante bancario/Datafast (alerta bloqueante si no coincide), y además comparar los días pagados contra los días calculados automáticamente (fecha de salida − fecha de ingreso), contemplando que puede haber más de un pago parcial que deben sumar el total de días.
- **Casillero "Autoridad que conoce"** (sección Causa legal, en Ingreso): se autocompleta con "FISCALÍA" si la causa es Accidente de Tránsito, o "NO APLICA" para cualquier otra causa; siempre queda editable y se recalcula si cambia la causa. (Pendiente de revisión: el usuario cree que este campo debería estar en Libertad en vez de Ingreso, pero pidió no tocarlo todavía — lo revisará él mismo más adelante.)
- **Casillero "Nombre del conductor de la grúa"**: solo aparece si el traslado fue "GRÚA POLICIAL"; si no aplica, se guarda como "NO APLICA" (nunca vacío) tanto en el Excel como en el Word.
- **Campo "TRASLADADO EN"**: opciones "sus propios medios" / "huincha"; si se elige huincha, se activa un campo adicional para escribir su nombre (en vez de repetir el nombre de quien toma procedimiento).

---

## 6. Persistencia y nube (estado real, con su punto débil ya diagnosticado)

- Almacenamiento local: `SharedPreferences` en el teléfono (además de respaldo con `XFile`/`Share.shareXFiles` para compartir).
- Sincronización con **Firebase Firestore** (colección `casos_nacionales`, con índice compuesto por tipo+patio+fecha ya creado y funcionando): al guardar un caso, la app sube (con espera real, no en segundo plano silencioso) a Firestore y además deja un respaldo local inmediato por si no hay señal.
- **Fuente de verdad para leer:** ya corregido para que primero consulte Firestore, y solo si falla (sin internet) recurra a la copia local — antes la app solo escribía a la nube pero jamás volvía a leer de ahí, por lo que al cambiar de sesión o de dispositivo los datos "desaparecían" (ya resuelto).
- Autenticación: Google (Firebase Auth) + aprobación manual del administrador en Firestore, colección `usuarios` (campo `aprobado: true/false`). Xavier es admin nacional y a la vez usuario normal de su propio patio.
- Los PDFs originales (respaldo de cada caso) se guardan **localmente en el teléfono**, no en la nube — decisión explícita para evitar el costo del plan de pago de Firebase Storage; se acepta que ese respaldo específico se pierda si el usuario cambia de teléfono o de cuenta (la base de datos de casos en sí no se pierde, solo el PDF adjunto).
- Registro de ediciones posteriores a un caso ya guardado: se registra en Firestore (colección `historial_ediciones`) para poder mostrarlo luego en estadísticas del panel de administrador.

---

## 7. Lo que YA funciona hoy (confirmado en pruebas reales del usuario)

- Lectura de partes PDF vía IA: ya reconoce bien fecha, hora y cédulas; reconoce varias placas.
- Corrección de placas en mayúsculas (antes fallaba en partes con la etiqueta "PLACA:" en mayúsculas).
- Tipo de vehículo ya no cae en un valor genérico incorrecto cuando la IA detecta un tipo real (camión, furgón, jeep, etc.), y aprende tipos nuevos.
- Sello de estado dinámico (INGRESADO/LIBERADO según corresponda) tanto en la lista de casos como en "Buscar por placa".
- Botón "Guardar avance" ya renombrado y funcionando; la validación de campos obligatorios ya no bloquea en silencio (muestra diálogo con opción de continuar sin llenar).
- Respaldo local del PDF original de cada caso, con pantalla propia para verlos.
- Botón de editar en la lista de Ingresos.
- Sincronización con Firestore como fuente de verdad (índice compuesto ya creado y habilitado).
- El flujo completo de Libertad hereda correctamente todos los datos del Ingreso ya guardado.

---

## 8. NECESIDADES PENDIENTES (lo que aún falta, en el orden lógico de retomarlo)

### Bloqueantes / de mayor impacto
1. **Motor, chasis, modelo y año de fabricación** del vehículo: siguen sin extraerse de forma confiable en pruebas con partes reales distintos (a veces sí funciona, cuando el parte ya había sido analizado antes). Falta obtener texto crudo real de Syncfusion (vía "Ver texto reconocido → Copiar") de un parte con Motor visible, para construir esa extracción con evidencia real en vez de adivinar.
2. **Validación anti-duplicados**: impedir guardar dos veces el mismo Ingreso de una misma placa sin alertar (bug confirmado, ocurrió en una prueba real).
3. **Extractor dedicado del "Oficio de Devolución de Vehículo"** para Libertad (ver sección 4) — no urgente hasta que Ingreso esté sólido, pero ya definido qué debe hacer.
4. Confirmar de punta a punta un **Ingreso completo vía fotos** + Gemini Vision (hasta ahora las pruebas reales fueron solo con PDF digital, no con fotos de la hoja física).

### UI / experiencia pendiente de aplicar
5. Cambiar el texto del botón verde del Home a **"Buscar placa para liberar"** y eliminar el botón suelto "Buscar placa" (redundante).
6. Agregar ícono de **editar** en la lista de Libertades (ya existe en Ingresos).
7. Historial/estadística de **ediciones posteriores** a un caso, para el panel de administrador.
8. Confirmar visualmente en el teléfono real que el sello de estado (INGRESADO/LIBERADO) se comporta bien en ambas pantallas.
9. Revisar overflow visual histórico ("RenderFlex overflowed") en el campo "Detalle causa" dentro de Editar/Buscar por placa.
10. Ocultar de la UI de Ingreso un campo mencionado vagamente por el usuario (posiblemente "Zona") — nunca se concretó cuál exactamente.

### Backend / arquitectura pendiente
11. **Panel de administrador nacional**: rol `esAdmin`, pantalla de aprobación de usuarios dentro de la app (hoy se aprueba manualmente en la consola de Firestore), catálogo de patios, estadísticas de productividad por patio. El Panel Nacional vía PWA (`/admin`) existe pero está **en pausa**.
12. Que el administrador pueda **ver los partes (PDFs)** de cualquier patio desde la nube — decidido que NO se hará vía Firebase Storage (implicaría plan de pago Blaze); queda pendiente decidir un mecanismo alternativo si se retoma.
13. **PWA pública sin login** para que cualquier civil consulte por placa si un vehículo está retenido o libre (solo placa/marca/color/estado/patio, nunca datos personales) — no iniciada, ya hay una colección Firestore (`consulta_publica/{placa}`) pensada para esto.
14. Conexión real de la app con la **plantilla Excel** de archivo/inventario (proyecto relacionado: matriz de vehículos/libertades de archivo) — el usuario debe volver a subir esa plantilla para retomar la integración.
15. Retomar y validar **Informe semanal** (prellenado desde libertades guardadas) — bloqueado hasta que Ingreso/Libertad funcionen sólidamente.
16. Confirmar/completar el **texto oficial exacto** de cada artículo del catálogo de causa legal (hoy son resúmenes, no el texto verbatim).
17. Decidir si conviene, para el camino sin IA, convertir el PDF a Markdown antes de aplicar el parser (en vez de rasterizar a imagen), como posible mejora adicional — evaluado pero no resuelto.
18. Activar reglas de "datos muy repetitivos" para reforzar el parser sin IA (pedido explícito, pendiente de retomar).

### Ideas nuevas mencionadas, aún sin desarrollar
19. **Firma electrónica** dentro del flujo de la app (idea mencionada, sin detalles concretos todavía — retomar cuando el usuario la traiga de nuevo).
20. Auto-guardar el PDF original como respaldo adjunto apenas la IA detecta al menos un vehículo (para no tener que volver a buscarlo en la galería), y poder abrirlo directamente desde el panel de Ingresos tocando el vehículo correspondiente.

---

## 9. Cómo usar este documento

Este documento reemplaza cualquier resumen anterior como referencia principal del proyecto. Si en el futuro surge una duda sobre "cómo debería comportarse X" en la app, conviene revisar primero esta descripción antes de asumir un comportamiento distinto. Las secciones 7 y 8 son las que más cambian con el tiempo (lo hecho vs. lo pendiente) — conviene mantenerlas actualizadas a medida que se confirmen o resuelvan puntos.

# Dynamic Height — Plan de Implementación

## Visión general

El editor crece verticalmente conforme se añade contenido, como un `<textarea>` HTML. Sin scroll interno, sin altura fija. La altura del widget es exactamente la altura del contenido.

### Principios

- **Caché incremental**: cada bloque reporta su altura una vez; solo se re-mide cuando su contenido cambia.
- **Rango afectado**: al insertar/eliminar nodos, solo se desplazan índices del caché, no se re-miden alturas.
- **Zero-cost cuando no se usa**: si `dynamicHeight` es `null`, el comportamiento es idéntico al actual.
- **API consistente**: sigue el mismo patrón `Controller` + `Config` que el resto del proyecto.

### Estructura de archivos nuevos

```
lib/src/editor/editor_component/service/layout/
├── dynamic_height_config.dart        # Configuración
├── height_cache.dart                 # Caché O(1) de alturas
├── dynamic_height_controller.dart    # Controlador central
├── block_height_reporter.dart        # Mixin para bloques
├── dynamic_height_layout.dart        # Widget de layout
└── layout.dart                       # Barrel export
```

---

## Fase 1: `HeightCache` — Caché incremental de alturas

### Objetivo

Estructura de datos pura (sin dependencias de Flutter) que mantiene un mapa `[índice → altura]` con actualizaciones O(1) para bloques individuales y O(k) para operaciones de rango, donde k es el número de índices desplazados.

### Propiedades

| Operación | Complejidad | Descripción |
|-----------|-------------|-------------|
| `reportHeight(index, height)` | O(1) | Actualiza altura de un bloque. Solo notifica si delta > 1.0px. |
| `onNodesInserted(atIndex, count)` | O(k) donde k = índices ≥ atIndex | Desplaza índices, no re-mide. |
| `onNodesRemoved(atIndex, count)` | O(k) donde k = índices ≥ atIndex | Elimina entradas y compacta. |
| `invalidateRange(start, end)` | O(m) donde m = tamaño del rango | Fuerza re-medición. |
| `totalHeight` | O(1) | Suma pre-calculada de todas las alturas. |
| `accumulatedHeightUpTo(index)` | O(n) — solo para scroll | Suma acumulada hasta un índice. |

### Código

**Archivo**: `lib/src/editor/editor_component/service/layout/height_cache.dart`

```dart
import 'dart:collection';

/// Caché incremental de alturas de bloques del editor.
///
/// Mantiene un mapa sparse [índice → altura] con actualizaciones O(1)
/// para bloques individuales y operaciones de rango para
/// inserciones/eliminaciones.
///
/// Las operaciones de inserción/eliminación solo desplazan índices,
/// no re-miden alturas. Las alturas de bloques no medidos se estiman
/// con [defaultHeight].
final class HeightCache {
  HeightCache({this.defaultHeight = 60.0});

  /// Altura estimada para bloques que aún no han sido medidos.
  final double defaultHeight;

  /// Mapa sparse de alturas medidas (solo bloques que difieren del default).
  final Map<int, double> _heights = {};

  /// Suma total de todas las alturas, actualizada incrementalmente.
  double _totalHeight = 0.0;

  /// Número total de bloques (medidos + no medidos).
  int _blockCount = 0;

  /// Callback llamado cuando la altura total cambia.
  final List<VoidCallback> _listeners = [];

  // ──── API pública ────

  /// Altura total de todos los bloques (medidos + estimados).
  double get totalHeight {
    final measured = _heights.length;
    final unmeasured = _blockCount - measured;
    return _totalHeight + (unmeasured > 0 ? unmeasured * defaultHeight : 0.0);
  }

  /// Número total de bloques registrados.
  int get blockCount => _blockCount;

  /// Altura de un bloque específico (medida o default).
  double heightOf(int index) {
    RangeError.checkNotNegative(index, 'index');
    return _heights[index] ?? defaultHeight;
  }

  /// Reporta la altura medida de un bloque tras el layout.
  ///
  /// Retorna `true` si la altura cambió significativamente (delta > 1.0px),
  /// lo que indica que los listeners deben ser notificados.
  bool reportHeight(int index, double height) {
    RangeError.checkNotNegative(index, 'index');
    final old = _heights[index];
    if (old != null && (old - height).abs() < 1.0) {
      return false;
    }
    final delta = height - (old ?? defaultHeight);
    _heights[index] = height;
    _totalHeight += delta;
    return true;
  }

  /// Notifica que se insertaron [count] bloques en la posición [atIndex].
  ///
  /// Desplaza los índices existentes ≥ [atIndex] en +[count] posiciones.
  /// Los nuevos bloques se estiman con [defaultHeight].
  void onNodesInserted(int atIndex, int count) {
    RangeError.checkNotNegative(atIndex, 'atIndex');
    if (count <= 0) return;

    _blockCount += count;
    _totalHeight += count * defaultHeight;

    // Desplazar índices: iterar en orden inverso para no sobrescribir
    final keysToShift = _heights.keys
        .where((k) => k >= atIndex)
        .toList(growable: false)
      ..sort((a, b) => b.compareTo(a));

    for (final oldIndex in keysToShift) {
      final height = _heights.remove(oldIndex)!;
      _heights[oldIndex + count] = height;
    }
  }

  /// Notifica que se eliminaron [count] bloques desde [atIndex].
  ///
  /// Las entradas del caché para los índices eliminados se descartan.
  /// Los índices posteriores se compactan.
  void onNodesRemoved(int atIndex, int count) {
    RangeError.checkNotNegative(atIndex, 'atIndex');
    if (count <= 0) return;

    _blockCount -= count;

    // Eliminar caché de los nodos removidos
    for (int i = atIndex; i < atIndex + count; i++) {
      final removed = _heights.remove(i);
      if (removed != null) {
        _totalHeight -= removed;
      } else {
        _totalHeight -= defaultHeight;
      }
    }

    // Compactar índices posteriores
    final keysToShift = _heights.keys
        .where((k) => k >= atIndex + count)
        .toList(growable: false)
      ..sort();

    for (final oldIndex in keysToShift) {
      final height = _heights.remove(oldIndex)!;
      _heights[oldIndex - count] = height;
    }
  }

  /// Invalida las alturas en el rango [start, end] (inclusive).
  ///
  /// Los bloques invalidados vuelven a [defaultHeight] hasta que
  /// se midan de nuevo.
  void invalidateRange(int start, [int? end]) {
    RangeError.checkNotNegative(start, 'start');
    final endIdx = end ?? _blockCount - 1;
    if (endIdx < start) return;

    for (int i = start; i <= endIdx && i < _blockCount; i++) {
      final removed = _heights.remove(i);
      if (removed != null) {
        _totalHeight -= removed;
        _totalHeight += defaultHeight;
      }
    }
  }

  /// Altura acumulada desde el índice 0 hasta [upToIndex] (inclusive).
  ///
  /// Útil para calcular posiciones de scroll.
  double accumulatedHeightUpTo(int upToIndex) {
    double sum = 0.0;
    final limit =
        upToIndex >= _blockCount ? _blockCount - 1 : upToIndex;
    for (int i = 0; i <= limit; i++) {
      sum += heightOf(i);
    }
    return sum;
  }

  // ──── Gestión de listeners ────

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Notifica a los listeners si [reportHeight] devolvió true.
  /// Debe llamarse después de una o más operaciones que hayan
  /// producido cambios.
  void notifyIfChanged(bool changed) {
    if (changed) _notifyListeners();
  }

  /// Vacía el caché completamente.
  void clear() {
    _heights.clear();
    _totalHeight = 0.0;
    _blockCount = 0;
  }

  /// Libera recursos.
  void dispose() {
    _listeners.clear();
    clear();
  }
}

/// Alias para el callback de listeners del caché.
typedef VoidCallback = void Function();
```

### Tareas Fase 1

- [ ] Crear archivo `lib/src/editor/editor_component/service/layout/height_cache.dart`
- [ ] Implementar la clase `HeightCache` con el código anterior
- [ ] Verificar que compila sin errores (`dart analyze`)
- [ ] **No requiere tests en esta fase** — se testeará en Fase 8

---

## Fase 2: `DynamicHeightConfig` — Configuración

### Objetivo

Clase de configuración inmutable que sigue el patrón de `EditorStyle` y `BlockComponentConfiguration`. Contiene los parámetros que el usuario puede ajustar.

### Código

**Archivo**: `lib/src/editor/editor_component/service/layout/dynamic_height_config.dart`

```dart
/// Configuración para el modo de altura dinámica del editor.
///
/// Cuando se proporciona al [NovidentEditor] vía [NovidentEditor.dynamicHeightConfig],
/// el editor crece verticalmente conforme se añade contenido,
/// como un `<textarea>` HTML.
///
/// La altura final del editor es exactamente la altura de su contenido.
class DynamicHeightConfig {
  const DynamicHeightConfig({
    this.minHeight = 100.0,
    this.defaultBlockHeight = 60.0,
    this.resizeDebounce = const Duration(milliseconds: 0),
  });

  /// Altura mínima del editor cuando está vacío o con poco contenido.
  ///
  /// El editor nunca será más pequeño que este valor.
  final double minHeight;

  /// Altura estimada para bloques que aún no han sido medidos.
  ///
  /// Se usa como valor inicial antes de que un bloque reporte su altura real.
  /// Un valor razonable reduce el "parpadeo" inicial.
  final double defaultBlockHeight;

  /// Debounce para notificaciones de cambio de altura.
  ///
  /// Útil para evitar múltiples redibujados durante escritura rápida.
  /// `Duration.zero` significa sin debounce (cada cambio se notifica).
  final Duration resizeDebounce;

  DynamicHeightConfig copyWith({
    double? minHeight,
    double? defaultBlockHeight,
    Duration? resizeDebounce,
  }) {
    return DynamicHeightConfig(
      minHeight: minHeight ?? this.minHeight,
      defaultBlockHeight: defaultBlockHeight ?? this.defaultBlockHeight,
      resizeDebounce: resizeDebounce ?? this.resizeDebounce,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DynamicHeightConfig &&
        other.minHeight == minHeight &&
        other.defaultBlockHeight == defaultBlockHeight &&
        other.resizeDebounce == resizeDebounce;
  }

  @override
  int get hashCode => Object.hash(minHeight, defaultBlockHeight, resizeDebounce);
}
```

### Tareas Fase 2

- [ ] Crear archivo `lib/src/editor/editor_component/service/layout/dynamic_height_config.dart`
- [ ] Implementar `DynamicHeightConfig` con el código anterior
- [ ] Verificar que compila

---

## Fase 3: `DynamicHeightController` — Controlador

### Objetivo

Orquesta el `HeightCache` y expone:
- `currentHeight`: altura actual del editor (calculada desde el caché).
- `addListener` / `removeListener`: para que el layout se actualice cuando la altura cambia.
- `reportBlockHeight`: interfaz para que los bloques reporten su altura.
- `onDocumentMutation`: interfaz para que `EditorState.apply()` notifique inserciones/eliminaciones/cambios de texto.

Sigue el patrón de `EditorScrollController`: se puede crear externamente o internamente.

### Código

**Archivo**: `lib/src/editor/editor_component/service/layout/dynamic_height_controller.dart`

```dart
import 'package:flutter/foundation.dart';

import 'dynamic_height_config.dart';
import 'height_cache.dart';

/// Controlador para el modo de altura dinámica.
///
/// Se puede crear externamente (para control programático) o internamente
/// si se pasa [DynamicHeightConfig] al editor.
///
/// Expone la altura actual del contenido y permite notificar
/// mutaciones del documento para mantener el caché sincronizado.
class DynamicHeightController extends ChangeNotifier {
  DynamicHeightController({
    DynamicHeightConfig? config,
  }) : _config = config ?? const DynamicHeightConfig();

  DynamicHeightConfig _config;

  /// Configuración actual.
  DynamicHeightConfig get config => _config;

  /// Caché de alturas de bloques.
  final HeightCache _cache = HeightCache();

  // ──── Acceso al caché (interno) ────

  /// El caché de alturas subyacente.
  /// Expuesto para que [DynamicHeightLayout] pueda leer alturas individuales.
  HeightCache get cache => _cache;

  // ──── Altura actual ────

  /// Altura actual del editor.
  ///
  /// Es el máximo entre [DynamicHeightConfig.minHeight] y la altura
  /// total del contenido.
  double get currentHeight {
    final contentHeight = _cache.totalHeight;
    return contentHeight < _config.minHeight
        ? _config.minHeight
        : contentHeight;
  }

  // ──── Notificaciones desde el árbol de widgets ────

  /// Llamado por [BlockHeightReporter] después del layout de un bloque.
  ///
  /// [index] es la posición del bloque en `parent.children`.
  /// [height] es la altura medida del `RenderBox` del bloque.
  void reportBlockHeight(int index, double height) {
    final changed = _cache.reportHeight(index, height);
    if (changed) {
      _notifyWithDebounce();
    }
  }

  /// Llamado cuando ocurre una mutación en el documento.
  ///
  /// Debe llamarse desde [EditorState.apply] para mantener
  /// el caché sincronizado con inserciones, eliminaciones y
  /// cambios de texto.
  void onDocumentMutation(DocumentMutation mutation) {
    switch (mutation) {
      case NodesInserted(:final atIndex, :final count):
        _cache.onNodesInserted(atIndex, count);
      case NodesRemoved(:final atIndex, :final count):
        _cache.onNodesRemoved(atIndex, count);
      case TextChanged(:final nodeIndex):
        // Invalidar solo ese nodo para forzar re-medición
        _cache.invalidateRange(nodeIndex, nodeIndex);
    }
    _notifyWithDebounce();
  }

  /// Inicializa el caché con el número de bloques hijos del nodo raíz.
  ///
  /// Debe llamarse cuando el editor se monta por primera vez.
  void initialize(int blockCount) {
    if (blockCount > 0) {
      _cache.onNodesInserted(0, blockCount);
    }
    notifyListeners();
  }

  // ──── Debounce ────

  Timer? _debounceTimer;

  void _notifyWithDebounce() {
    if (_config.resizeDebounce == Duration.zero) {
      notifyListeners();
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_config.resizeDebounce, () {
      notifyListeners();
    });
  }

  // ──── API de control ────

  /// Actualiza la configuración en caliente.
  void updateConfig(DynamicHeightConfig config) {
    if (config == _config) return;
    _config = config;
    notifyListeners();
  }

  /// Fuerza la invalidación de todas las alturas cacheadas.
  ///
  /// Útil cuando el estilo del editor cambia globalmente
  /// (tamaño de fuente, padding, etc.) y todas las alturas
  /// deben re-medirse.
  void invalidateAll() {
    _cache.invalidateRange(0, _cache.blockCount - 1);
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _cache.dispose();
    super.dispose();
  }
}

// ──── Tipos de mutación del documento ────

/// Representa una mutación en el documento que afecta al layout.
sealed class DocumentMutation {
  const DocumentMutation();
}

/// Se insertaron [count] nodos en la posición [atIndex].
final class NodesInserted extends DocumentMutation {
  final int atIndex;
  final int count;
  const NodesInserted({required this.atIndex, required this.count});
}

/// Se eliminaron [count] nodos desde la posición [atIndex].
final class NodesRemoved extends DocumentMutation {
  final int atIndex;
  final int count;
  const NodesRemoved({required this.atIndex, required this.count});
}

/// El texto de un nodo cambió (el nodo está en la posición [nodeIndex]).
final class TextChanged extends DocumentMutation {
  final int nodeIndex;
  const TextChanged({required this.nodeIndex});
}
```

### Tareas Fase 3

- [ ] Crear archivo `lib/src/editor/editor_component/service/layout/dynamic_height_controller.dart`
- [ ] Implementar `DynamicHeightController` y `DocumentMutation` con el código anterior
- [ ] Verificar que compila

---

## Fase 4: `BlockHeightReporter` — Mixin para bloques

### Objetivo

Mixin que se añade a los `State` de los block components. Después de cada layout, lee el tamaño de su `RenderBox` y lo reporta al `DynamicHeightController`.

### Funcionamiento

1. En `initState` y `didUpdateWidget`, programa un `addPostFrameCallback`.
2. En el callback, obtiene `DynamicHeightController` desde el contexto.
3. Calcula el índice del nodo en `parent.children`.
4. Lee `renderBox.size.height`.
5. Llama a `controller.reportBlockHeight(index, height)`.

### Código

**Archivo**: `lib/src/editor/editor_component/service/layout/block_height_reporter.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'dynamic_height_controller.dart';

/// Mixin para block components que reportan su altura
/// al [DynamicHeightController] después de cada layout.
///
/// Uso:
/// ```dart
/// class _MyBlockState extends State<MyBlockWidget>
///     with BlockHeightReporter {
///   // ...
/// }
/// ```
///
/// Requisitos:
/// - El widget debe tener un [DynamicHeightController] accesible
///   vía `DynamicHeightControllerProvider.maybeOf(context)`.
/// - El nodo debe ser hijo directo de un padre cuya lista `children`
///   permita calcular el índice vía `indexOf`.
mixin BlockHeightReporter<T extends StatefulWidget> on State<T> {
  /// El nodo asociado a este bloque.
  /// Debe ser proporcionado por la clase que usa el mixin.
  Node get node;

  DynamicHeightController? _controller;
  double? _lastReportedHeight;

  // ──── Búsqueda del controller ────

  /// Obtiene el [DynamicHeightController] del contexto.
  ///
  /// Se cachea tras la primera búsqueda exitosa.
  DynamicHeightController? _findController() {
    if (_controller != null) return _controller;
    _controller = DynamicHeightControllerProvider.maybeOf(context);
    return _controller;
  }

  // ──── Programación del reporte ────

  /// Programa un reporte de altura para después del layout.
  ///
  /// Debe llamarse en [initState] y [didUpdateWidget].
  void scheduleHeightReport() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportHeightIfChanged();
    });
  }

  // ──── Reporte de altura ────

  void _reportHeightIfChanged() {
    final controller = _findController();
    if (controller == null || !mounted) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final nodeIndex = _getNodeIndex();
    if (nodeIndex < 0) return;

    final height = renderBox.size.height;

    // Evitar reportar la misma altura repetidamente
    if (_lastReportedHeight != null &&
        (_lastReportedHeight! - height).abs() < 1.0) {
      return;
    }

    _lastReportedHeight = height;
    controller.reportBlockHeight(nodeIndex, height);
  }

  /// Calcula el índice del nodo en `parent.children`.
  int _getNodeIndex() {
    final parent = node.parent;
    if (parent == null) return -1;
    return parent.children.indexOf(node);
  }
}

// ──── Provider InheritedWidget ────

/// InheritedWidget que provee el [DynamicHeightController]
/// al subárbol de bloques.
///
/// Se coloca en la raíz del layout del editor.
class DynamicHeightControllerProvider extends InheritedWidget {
  final DynamicHeightController controller;

  const DynamicHeightControllerProvider({
    super.key,
    required this.controller,
    required super.child,
  });

  /// Obtiene el controller del ancestro más cercano.
  static DynamicHeightController? maybeOf(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<
        DynamicHeightControllerProvider>();
    return provider?.controller;
  }

  /// Obtiene el controller. Lanza si no existe.
  static DynamicHeightController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null,
        'DynamicHeightControllerProvider no encontrado en el árbol');
    return controller!;
  }

  @override
  bool updateShouldNotify(DynamicHeightControllerProvider oldWidget) {
    return controller != oldWidget.controller;
  }
}
```

### Tareas Fase 4

- [ ] Crear archivo `lib/src/editor/editor_component/service/layout/block_height_reporter.dart`
- [ ] Implementar `BlockHeightReporter` y `DynamicHeightControllerProvider`
- [ ] Verificar que compila

---

## Fase 5: `DynamicHeightLayout` — Widget de layout

### Objetivo

Widget que reemplaza a `PageBlockComponent` cuando `dynamicHeight` está activo.

### Lo que hace

1. Envuelve el contenido en `DynamicHeightControllerProvider`.
2. Escucha al `DynamicHeightController` para rebuilds cuando la altura cambia.
3. Renderiza los bloques en un `Column` con `mainAxisSize: MainAxisSize.min`.
4. El `Column` expande a la altura de su contenido. Si el padre da constraints unbounded (ej. dentro de un `SingleChildScrollView` externo), el editor crece libremente. Si el padre da altura fija, el editor se adapta a esa restricción.
5. Aplica `ConstrainedBox(minHeight: config.minHeight)` para mantener el mínimo.
6. Inicializa el caché con el número de bloques al montarse.

### Código

**Archivo**: `lib/src/editor/editor_component/service/layout/dynamic_height_layout.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../novident_editor.dart';
import 'block_height_reporter.dart';
import 'dynamic_height_config.dart';
import 'dynamic_height_controller.dart';

/// Widget raíz del layout del editor en modo dynamic height.
///
/// Reemplaza a [PageBlockComponent] cuando el editor está configurado
/// con [DynamicHeightConfig].
///
/// El layout consiste en:
/// - Un [ConstrainedBox] con altura mínima = [DynamicHeightConfig.minHeight]
/// - Un [Column] con los bloques hijos y header/footer
/// - Cada bloque envuelto en padding y restricciones de ancho máximo
class DynamicHeightLayout extends StatefulWidget {
  const DynamicHeightLayout({
    super.key,
    required this.node,
    required this.editorState,
    this.header,
    this.footer,
    this.wrapper,
    this.controller,
    this.config,
  });

  /// Nodo raíz del documento (tipo 'page').
  final Node node;

  /// Estado del editor.
  final EditorState editorState;

  /// Widget opcional al inicio del editor.
  final Widget? header;

  /// Widget opcional al final del editor.
  final Widget? footer;

  /// Wrapper opcional alrededor de cada bloque.
  final BlockComponentWrapper? wrapper;

  /// Controlador externo (si se proporciona).
  final DynamicHeightController? controller;

  /// Configuración (si no se proporciona controller externo).
  final DynamicHeightConfig? config;

  @override
  State<DynamicHeightLayout> createState() => _DynamicHeightLayoutState();
}

class _DynamicHeightLayoutState extends State<DynamicHeightLayout> {
  DynamicHeightController? _controller;
  bool _ownsController = false;
  bool _initialized = false;

  DynamicHeightController get controller => _controller!;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        (_ownsController = true,
        DynamicHeightController(
          config: widget.config ?? const DynamicHeightConfig(),
        ));
    _controller!.addListener(_onHeightChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      controller.initialize(widget.node.children.length);
    }
  }

  @override
  void didUpdateWidget(covariant DynamicHeightLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (_ownsController) _controller?.dispose();
      _controller = widget.controller ??
          (_ownsController = true,
          DynamicHeightController(
            config: widget.config ?? const DynamicHeightConfig(),
          ));
      _controller!.addListener(_onHeightChanged);
      _initialized = false;
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onHeightChanged);
    if (_ownsController) _controller?.dispose();
    super.dispose();
  }

  void _onHeightChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.node.children;

    return DynamicHeightControllerProvider(
      controller: controller,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: controller.config.minHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.header != null) widget.header!,
            ...items.asMap().entries.map((entry) {
              return _buildBlock(
                context,
                entry.value,
                entry.key,
              );
            }),
            if (widget.footer != null) widget.footer!,
          ],
        ),
      ),
    );
  }

  Widget _buildBlock(
    BuildContext context,
    Node node,
    int index,
  ) {
    Widget child = widget.editorState.renderer.build(context, node);

    if (widget.wrapper != null) {
      child = widget.wrapper!(
        context,
        node: node,
        child: child,
      );
    }

    return Container(
      key: ValueKey('dynamic_block_$index'),
      constraints: BoxConstraints(
        maxWidth:
            widget.editorState.editorStyle.maxWidth ?? double.infinity,
      ),
      padding: widget.editorState.editorStyle.padding,
      child: child,
    );
  }
}
```

### Tareas Fase 5

- [ ] Crear archivo `lib/src/editor/editor_component/service/layout/dynamic_height_layout.dart`
- [ ] Implementar `DynamicHeightLayout` con el código anterior
- [ ] Verificar que compila

---

## Fase 6: Integración en `NovidentEditor` y `EditorState`

### Objetivo

Conectar el nuevo sistema de dynamic height con el editor existente.

### Cambios en `NovidentEditor`

**Archivo**: `lib/src/editor/editor_component/service/editor.dart`

Añadir dos nuevos parámetros al constructor de `NovidentEditor`:

```dart
class NovidentEditor extends StatefulWidget {
  NovidentEditor({
    // ... todos los parámetros existentes se mantienen igual ...
    this.dynamicHeightConfig,
    this.dynamicHeightController,
  });

  // ... resto de campos existentes ...

  /// Configuración para altura dinámica.
  ///
  /// Cuando se proporciona, el editor crece verticalmente
  /// conforme se añade contenido, como un `<textarea>` HTML.
  ///
  /// Si es null, el editor se comporta como antes
  /// (sin dynamic height).
  final DynamicHeightConfig? dynamicHeightConfig;

  /// Controlador externo opcional para dynamic height.
  ///
  /// Permite lectura/control programático de la altura.
  final DynamicHeightController? dynamicHeightController;
}
```

En `_NovidentEditorState._buildServices`, modificar la construcción del child:

```dart
Widget _buildServices(BuildContext context) {
  // ──── Construir el layout ────
  Widget child;
  final useDynamicHeight =
      widget.dynamicHeightConfig != null || widget.dynamicHeightController != null;

  if (useDynamicHeight) {
    child = DynamicHeightLayout(
      node: editorState.document.root,
      editorState: editorState,
      header: widget.header,
      footer: widget.footer,
      wrapper: widget.blockWrapper,
      controller: widget.dynamicHeightController,
      config: widget.dynamicHeightConfig,
    );
  } else {
    // Comportamiento actual sin cambios
    child = editorState.renderer.build(
      context,
      editorState.document.root,
      header: widget.header,
      footer: widget.footer,
      wrapper: widget.blockWrapper,
    );
  }

  // ──── Servicios (sin cambios) ────
  if (!widget.disableKeyboardService) {
    child = KeyboardServiceWidget(
      key: editorState.service.keyboardServiceKey,
      characterShortcutEvents:
          widget.editable ? widget.characterShortcutEvents : [],
      commandShortcutEvents: widget.commandShortcutEvents,
      focusNode: widget.focusNode,
      contentInsertionConfiguration: widget.contentInsertionConfiguration,
      child: child,
    );
  }

  if (!widget.disableSelectionService) {
    child = SelectionServiceWidget(
      key: editorState.service.selectionServiceKey,
      cursorColor: widget.editorStyle.cursorColor,
      selectionColor: widget.editorStyle.selectionColor,
      showMagnifier: widget.showMagnifier,
      contextMenuBuilder: widget.contextMenuBuilder,
      dropTargetStyle: widget.dropTargetStyle,
      child: child,
    );
  }

  if (!widget.disableScrollService && !useDynamicHeight) {
    // El scroll service solo se usa cuando NO hay dynamic height
    // (en dynamic height no hay scroll)
    child = ScrollServiceWidget(
      key: editorState.service.scrollServiceKey,
      editorScrollController: editorScrollController,
      child: child,
    );
  }

  return child;
}
```

**Nota importante**: Cuando `dynamicHeight` está activo, NO se envuelve en `ScrollServiceWidget`. El editor no tiene scroll interno.

### Cambios en `EditorState`

**Archivo**: `lib/src/editor_state.dart`

Añadir referencia al `DynamicHeightController` y notificar mutaciones desde `apply()`:

```dart
class EditorState {
  // ... campos existentes ...

  /// Controlador de dynamic height (puede ser null).
  DynamicHeightController? dynamicHeightController;

  // En el método apply(), después de aplicar cada operación:
  Future<void> apply(
    Transaction transaction, {
    // ... parámetros existentes ...
  }) async {
    // ... lógica existente ...

    // ──── Dynamic height: notificar mutaciones ────
    final dhController = dynamicHeightController;
    if (dhController != null) {
      for (final op in transaction.operations) {
        if (op is InsertOperation) {
          final path = op.path;
          // Solo bloques de primer nivel (hijos de 'page')
          if (path.length == 1) {
            dhController.onDocumentMutation(
              NodesInserted(
                atIndex: path.last,
                count: op.nodes.length,
              ),
            );
          }
        } else if (op is DeleteOperation) {
          final path = op.path;
          if (path.length == 1) {
            dhController.onDocumentMutation(
              NodesRemoved(
                atIndex: path.last,
                count: op.nodes.length,
              ),
            );
          }
        } else if (op is UpdateTextOperation) {
          final path = op.path;
          if (path.isNotEmpty) {
            dhController.onDocumentMutation(
              TextChanged(nodeIndex: path.first),
            );
          }
        }
      }
    }

    // ... resto de la lógica existente ...
  }
}
```

En `_NovidentEditorState`:

```dart
class _NovidentEditorState extends State<NovidentEditor> {
  // ... campos existentes ...

  @override
  void initState() {
    super.initState();

    // ... lógica existente ...

    // Conectar dynamic height controller al editor state
    if (widget.dynamicHeightController != null) {
      editorState.dynamicHeightController = widget.dynamicHeightController;
    } else if (widget.dynamicHeightConfig != null) {
      // Se creará internamente en DynamicHeightLayout
      // La referencia se obtiene después del primer build
    }
  }

  @override
  Widget build(BuildContext context) {
    services ??= _buildServices(context);

    // ──── Conectar dynamic height controller ────
    if (useDynamicHeight) {
      // Obtener la referencia al controller creado por DynamicHeightLayout
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final controller = DynamicHeightControllerProvider.maybeOf(context);
        if (controller != null &&
            editorState.dynamicHeightController != controller) {
          editorState.dynamicHeightController = controller;
        }
      });
    }

    // ... resto del build ...
  }

  bool get useDynamicHeight =>
      widget.dynamicHeightConfig != null || widget.dynamicHeightController != null;
}
```

### Tareas Fase 6

- [ ] Modificar `NovidentEditor`: añadir `dynamicHeightConfig` y `dynamicHeightController`
- [ ] Modificar `_NovidentEditorState._buildServices`: usar `DynamicHeightLayout` cuando corresponda
- [ ] Modificar `_NovidentEditorState._buildServices`: omitir `ScrollServiceWidget` en dynamic height
- [ ] Modificar `EditorState`: añadir campo `dynamicHeightController`
- [ ] Modificar `EditorState.apply()`: notificar mutaciones al controller
- [ ] Modificar `_NovidentEditorState`: conectar controller con `EditorState`
- [ ] Verificar que el editor existente sigue funcionando sin dynamic height (regresión)

---

## Fase 7: Añadir `BlockHeightReporter` a los block components

### Objetivo

Todos los block components de primer nivel deben reportar su altura. Se añade el mixin `BlockHeightReporter` a sus `State`.

### Block components a modificar

Cada uno requiere añadir `BlockHeightReporter` al mixin list y llamar a `scheduleHeightReport()` en `initState` y `didUpdateWidget`:

| Componente | Archivo | Clase State |
|------------|---------|-------------|
| Paragraph | `paragraph_block_component.dart` | `_ParagraphBlockComponentWidgetState` |
| Heading | `heading_block_component.dart` | `_HeadingBlockComponentWidgetState` |
| Quote | `quote_block_component.dart` | `_QuoteBlockComponentWidgetState` |
| Bulleted List | `bulleted_list_block_component.dart` | `_BulletedListBlockComponentWidgetState` |
| Numbered List | `numbered_list_block_component.dart` | `_NumberedListBlockComponentWidgetState` |
| Todo List | `todo_list_block_component.dart` | `_TodoListBlockComponentWidgetState` |
| Image | `image_block_component.dart` | `_ImageBlockComponentWidgetState` |
| Divider | `divider_block_component.dart` | `_DividerBlockComponentWidgetState` |
| Table | `table_block_component.dart` | `_TableBlockComponentWidgetState` |

### Patrón de modificación (ejemplo con Paragraph)

**Antes**:
```dart
class _ParagraphBlockComponentWidgetState
    extends State<ParagraphBlockComponentWidget>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentBackgroundColorMixin,
        NestedBlockComponentStatefulWidgetMixin,
        BlockComponentTextDirectionMixin,
        BlockComponentAlignMixin {
```

**Después**:
```dart
class _ParagraphBlockComponentWidgetState
    extends State<ParagraphBlockComponentWidget>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentBackgroundColorMixin,
        NestedBlockComponentStatefulWidgetMixin,
        BlockComponentTextDirectionMixin,
        BlockComponentAlignMixin,
        BlockHeightReporter {  // ← NUEVO

  @override
  void initState() {
    super.initState();
    // ... listeners existentes ...
    scheduleHeightReport();  // ← NUEVO
  }

  @override
  void didUpdateWidget(covariant ParagraphBlockComponentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    scheduleHeightReport();  // ← NUEVO
  }
```

### Tareas Fase 7

- [ ] Modificar `paragraph_block_component.dart`
- [ ] Modificar `heading_block_component.dart`
- [ ] Modificar `quote_block_component.dart`
- [ ] Modificar `bulleted_list_block_component.dart`
- [ ] Modificar `numbered_list_block_component.dart`
- [ ] Modificar `todo_list_block_component.dart`
- [ ] Modificar `image_block_component.dart` (re-reportar cuando la imagen carga)
- [ ] Modificar `divider_block_component.dart`
- [ ] Modificar `table_block_component.dart`
- [ ] Verificar que todos compilan

---

## Fase 8: Tests

### Objetivo

Garantizar corrección del caché, del controller y del layout.

### Tests unitarios: `HeightCache`

**Archivo**: `test/new/dynamic_height/height_cache_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/src/editor/editor_component/service/layout/height_cache.dart';

void main() {
  group('HeightCache', () {
    late HeightCache cache;

    setUp(() {
      cache = HeightCache(defaultHeight: 50.0);
    });

    group('reportHeight', () {
      test('actualiza totalHeight con delta O(1)', () {
        cache.onNodesInserted(0, 3); // 3 bloques de 50 = 150

        cache.reportHeight(0, 100.0);
        expect(cache.totalHeight, 200.0); // 100 + 50 + 50
      });

      test('no notifica si delta < 1.0', () {
        cache.onNodesInserted(0, 1);
        cache.reportHeight(0, 50.0); // igual al default

        final changed = cache.reportHeight(0, 50.4);
        expect(changed, false);
        expect(cache.totalHeight, 50.0);
      });

      test('sí notifica si delta >= 1.0', () {
        cache.onNodesInserted(0, 1);
        final changed = cache.reportHeight(0, 120.0);
        expect(changed, true);
        expect(cache.totalHeight, 120.0);
      });
    });

    group('onNodesInserted', () {
      test('desplaza índices correctamente', () {
        cache.onNodesInserted(0, 2);
        cache.reportHeight(0, 100.0);
        cache.reportHeight(1, 80.0);

        cache.onNodesInserted(0, 1); // inserta al inicio

        expect(cache.heightOf(0), 50.0); // nuevo bloque, default
        expect(cache.heightOf(1), 100.0); // desplazado desde índice 0
        expect(cache.heightOf(2), 80.0); // desplazado desde índice 1
      });

      test('actualiza totalHeight con defaults', () {
        cache.onNodesInserted(0, 5);
        expect(cache.totalHeight, 250.0); // 5 × 50
      });
    });

    group('onNodesRemoved', () {
      test('elimina entradas y compacta índices', () {
        cache.onNodesInserted(0, 3);
        cache.reportHeight(0, 100.0);
        cache.reportHeight(1, 80.0);
        cache.reportHeight(2, 120.0);

        cache.onNodesRemoved(0, 1); // elimina el primero

        expect(cache.blockCount, 2);
        expect(cache.heightOf(0), 80.0); // antes índice 1
        expect(cache.heightOf(1), 120.0); // antes índice 2
      });

      test('actualiza totalHeight correctamente', () {
        cache.onNodesInserted(0, 3);
        cache.reportHeight(0, 100.0);
        cache.reportHeight(1, 80.0);
        cache.reportHeight(2, 120.0); // total = 300

        cache.onNodesRemoved(0, 1); // elimina el de 100
        expect(cache.totalHeight, 200.0); // 80 + 120
      });
    });

    group('invalidateRange', () {
      test('reinicia alturas a default en el rango', () {
        cache.onNodesInserted(0, 3);
        cache.reportHeight(0, 100.0);
        cache.reportHeight(1, 80.0);
        cache.reportHeight(2, 120.0);

        cache.invalidateRange(0, 1);

        expect(cache.heightOf(0), 50.0); // vuelve a default
        expect(cache.heightOf(1), 50.0);
        expect(cache.heightOf(2), 120.0); // no afectado
      });
    });

    group('accumulatedHeightUpTo', () {
      test('suma alturas correctamente', () {
        cache.onNodesInserted(0, 3);
        cache.reportHeight(0, 100.0);
        cache.reportHeight(1, 80.0);
        cache.reportHeight(2, 120.0);

        expect(cache.accumulatedHeightUpTo(0), 100.0);
        expect(cache.accumulatedHeightUpTo(1), 180.0);
        expect(cache.accumulatedHeightUpTo(2), 300.0);
      });
    });
  });
}
```

### Tests de widget: `DynamicHeightController`

**Archivo**: `test/new/dynamic_height/dynamic_height_controller_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/src/editor/editor_component/service/layout/dynamic_height_config.dart';
import 'package:novident_editor/src/editor/editor_component/service/layout/dynamic_height_controller.dart';

void main() {
  group('DynamicHeightController', () {
    late DynamicHeightController controller;

    setUp(() {
      controller = DynamicHeightController(
        config: const DynamicHeightConfig(minHeight: 100.0),
      );
    });

    test('currentHeight es minHeight cuando no hay contenido', () {
      expect(controller.currentHeight, 100.0);
    });

    test('currentHeight crece con el contenido', () {
      controller.initialize(3); // 3 bloques de 60 = 180
      expect(controller.currentHeight, 180.0);
    });

    test('currentHeight no baja de minHeight', () {
      controller.initialize(1); // 1 bloque = 60 < minHeight 100
      expect(controller.currentHeight, 100.0);
    });

    test('notifica listeners cuando cambia la altura', () {
      var notified = false;
      controller.addListener(() => notified = true);

      controller.initialize(1);
      expect(notified, true);

      notified = false;
      controller.reportBlockHeight(0, 200.0);
      expect(notified, true);
    });

    test('invalidateAll reinicia todas las alturas', () {
      controller.initialize(3);
      controller.reportBlockHeight(0, 200.0);
      controller.reportBlockHeight(1, 150.0);

      controller.invalidateAll();

      // Todas vuelven a default (60.0) → 3 × 60 = 180
      expect(controller.currentHeight, 180.0);
    });
  });
}
```

### Tests de integración: `DynamicHeightLayout`

**Archivo**: `test/new/dynamic_height/dynamic_height_layout_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

// Test básico de que el layout se renderiza y mide alturas
void main() {
  testWidgets('DynamicHeightLayout renderiza bloques y crece', (tester) async {
    final editorState = EditorState.blank(withInitialText: true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NovidentEditor(
            editorState: editorState,
            dynamicHeightConfig: const DynamicHeightConfig(minHeight: 50),
            editable: true,
          ),
        ),
      ),
    );

    // El editor debe tener al menos minHeight
    final editorFinder = find.byType(NovidentEditor);
    expect(editorFinder, findsOneWidget);

    final renderBox = tester.renderObject(editorFinder);
    expect(renderBox.size.height, greaterThanOrEqualTo(50.0));
  });

  testWidgets('DynamicHeightLayout sin config se comporta normal', (tester) async {
    final editorState = EditorState.blank(withInitialText: true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: NovidentEditor(
              editorState: editorState,
              editable: true,
              // sin dynamicHeightConfig
            ),
          ),
        ),
      ),
    );

    // Sin dynamic height, debe haber scroll (ScrollablePositionedList)
    expect(find.byType(NovidentEditor), findsOneWidget);
  });
}
```

### Tareas Fase 8

- [ ] Crear `test/new/dynamic_height/` directorio
- [ ] Escribir `height_cache_test.dart`
- [ ] Escribir `dynamic_height_controller_test.dart`
- [ ] Escribir `dynamic_height_layout_test.dart`
- [ ] Ejecutar todos los tests: `flutter test test/new/dynamic_height/`
- [ ] Ejecutar tests existentes para verificar no regresión: `flutter test`
- [ ] Corregir fallos

---

## Resumen de archivos

### Archivos nuevos (6)

```
lib/src/editor/editor_component/service/layout/
├── layout.dart                          # Barrel export
├── height_cache.dart                    # Fase 1
├── dynamic_height_config.dart           # Fase 2
├── dynamic_height_controller.dart       # Fase 3
├── block_height_reporter.dart           # Fase 4
└── dynamic_height_layout.dart           # Fase 5
```

### Archivos modificados (11+)

```
lib/src/editor/editor_component/service/editor.dart           # Fase 6
lib/src/editor_state.dart                                     # Fase 6
lib/src/editor/block_component/paragraph_block_component/...  # Fase 7
lib/src/editor/block_component/heading_block_component/...    # Fase 7
lib/src/editor/block_component/quote_block_component/...      # Fase 7
lib/src/editor/block_component/bulleted_list_block_component/... # Fase 7
lib/src/editor/block_component/numbered_list_block_component/... # Fase 7
lib/src/editor/block_component/todo_list_block_component/...  # Fase 7
lib/src/editor/block_component/image_block_component/...      # Fase 7
lib/src/editor/block_component/divider_block_component/...    # Fase 7
lib/src/editor/block_component/table_block_component/...      # Fase 7
```

### Archivos de test (3)

```
test/new/dynamic_height/
├── height_cache_test.dart               # Fase 8
├── dynamic_height_controller_test.dart  # Fase 8
└── dynamic_height_layout_test.dart      # Fase 8
```

---

## Diagrama de flujo

```
Usuario escribe "Hola"
  │
  ▼
EditorState.apply(Transaction)
  │
  ├─▶ document.updateText(path, delta)
  │     └─▶ node.notifyListeners()
  │           └─▶ Consumer<Node> en BlockComponentContainer
  │                 └─▶ Rebuild solo del ParagraphBlockComponentWidget
  │                       └─▶ NovidentRichText hace layout con más texto
  │                             └─▶ RenderParagraph tiene nueva altura
  │
  ├─▶ dynamicHeightController.onDocumentMutation(
  │      TextChanged(nodeIndex: 0)
  │    )
  │     └─▶ HeightCache.invalidateRange(0, 0)
  │           └─▶ Altura del bloque 0 vuelve a defaultHeight
  │           └─▶ totalHeight se actualiza (baja temporalmente)
  │
  ▼
addPostFrameCallback
  │
  BlockHeightReporter._reportHeightIfChanged()
  │
  ├─▶ findRenderObject().size.height = 72.0 (nueva altura)
  ├─▶ controller.reportBlockHeight(0, 72.0)
  │     └─▶ HeightCache.reportHeight(0, 72.0)
  │           └─▶ _totalHeight += (72.0 - 60.0) = +12.0
  │           └─▶ retorna true (cambió)
  │
  └─▶ DynamicHeightController.notifyListeners()
        └─▶ DynamicHeightLayout.setState()
              └─▶ Rebuild con nueva altura
              └─▶ Editor crece 12px verticalmente
```

---

## Checklist de verificación final

- [ ] El editor crece al escribir texto en un párrafo
- [ ] El editor crece al insertar nuevos párrafos
- [ ] El editor decrece al eliminar párrafos
- [ ] El editor decrece al borrar texto
- [ ] La altura nunca es menor que `minHeight`
- [ ] Sin `dynamicHeightConfig`, el editor funciona exactamente igual que antes
- [ ] Todos los block components reportan alturas
- [ ] Los cambios de altura son suaves (sin parpadeos)
- [ ] El rendimiento es aceptable con 100+ párrafos
- [ ] Los tests unitarios pasan
- [ ] Los tests existentes no rompen
- [ ] `dart analyze` no reporta nuevos warnings

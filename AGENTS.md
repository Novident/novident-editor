# AGENTS.md 

## **REGLAS DE DESARROLLO OBLIGATORIAS**

### **1. PREVENCIÓN DE DUPLICADOS Y CÓDIGO EXISTENTE**
- **ANTES de crear cualquier componente, función, clase, interfaz o utilidad:**
  - Realizar una búsqueda exhaustiva con `semble_search` o `grep -rl` para verificar que no exista algo similar o idéntico
  - Buscar por: **nombre exacto**, **sinónimos funcionales**, **patrones de uso similares**
  - Si existe algo con ≥70% de similitud funcional → **REUTILIZAR** en lugar de crear nuevo
  - Si existe algo con <70% pero similar → **EXTENDER** o **REFACTORIZAR** el existente (con aprobación explícita)
- **PROHIBIDO** crear nuevas implementaciones cuando ya existe una solución funcional

### **2. MODIFICACIONES PERMITIDAS**
- **SÓLO** se permite modificar componentes existentes para:
  - Añadir nuevos métodos, clases, interfaces o variables
  - Corregir bugs críticos (previa aprobación en el plan)
  - Mejorar rendimiento sin cambiar comportamiento
- **PROHIBIDO** modificar la estructura, firma o comportamiento base de componentes existentes sin justificación documentada

### **3. LECTURA DE ARCHIVOS**
- **PROHIBIDO** leer archivos completos
- **OBLIGATORIO** usar lecturas por rangos específicos (líneas o bloques funcionales)
- Justificar el rango de lectura basado en la tarea específica
- Si se requiere entender el contexto completo → leer múltiples rangos estratégicos en lugar del archivo completo

### **4. BÚSQUEDA DE CÓDIGO**
- **ÚNICAMENTE** usar `aft` y `semble_search` para:
  - Buscar símbolos, nombres o patrones de código
  - Verificar existencia de componentes antes de crear nuevos
  - Identificar duplicados funcionales
- **COMO FALLBACK** usar `grep -rl "<query>"`
- **PROHIBIDO** usar:
  - `grep` (solo `grep -rl` es permitido), `glob` o cualquier búsqueda manual
  - Búsquedas basadas en texto plano sin contexto semántico
  - Lecturas de directorios completos para "encontrar algo"

### **5. SKILLS OBLIGATORIAS**
Aplicar **SIEMPRE** todas las skills que vayan acorde a la acción requerida:
- **Validación lógica**: Verificar coherencia y corrección del razonamiento
- **Pensamiento secuencial**: Evaluar flujo y dependencias paso a paso
- **Pensamiento profundo**: Analizar implicaciones a largo plazo y casos borde
- **Seguridad**: Revisar vulnerabilidades, inyecciones, exposición de datos
- **Auditoría de componentes** (shadcn/tailwind): Verificar uso correcto de patrones y temas
- **TypeScript Expert**: Tipado estricto, genéricos, inferencia, guards
- **Mejores prácticas**: TailwindCSS, shadcn, TypeScript, React (hooks, renders, estado)

Leer conforme se vayan requiriendo es algo que esperamos.

### **6. ESTILO DE CODIFICACIÓN**
- Usar **CAVEMAN FULL** en todo momento (código explícito, claro, sin abstracciones innecesarias)
- Preferir legibilidad y simplicidad sobre "magia" o trucos de lenguaje
- Documentar decisiones no obvias con comentarios claros

### **7. CALIDAD SOBRE CANTIDAD**
- **SIEMPRE** priorizar calidad del código sobre cantidad
- Si se puede resolver con 10 líneas de calidad → NO escribir 50 líneas "por si acaso"
- Evitar código defensivo excesivo o sobreingeniería

### **8. ESTÁNDARES DE CALIDAD OBLIGATORIOS**
- **CÓDIGO LIBRE DE:**
  - Malas prácticas (anti-patrones, code smells)
  - Problemas de rendimiento (bucles innecesarios, renders excesivos, memory leaks)
  - Parches temporales (workarounds sin entender la causa raíz)
- **OBLIGATORIO** implementar **soluciones definitivas** que aborden la causa raíz
- Si no se puede resolver completamente → documentar deuda técnica y plan de mejora

### **9. PROCESO DE REVISIÓN POST-EDICIÓN**
**TRAS CADA EDICIÓN de archivo, ejecutar OBLIGATORIAMENTE:**
1. **Auto-revisión del código implementado**
2. **Calificar la calidad** en escala 1-5:
   - **5**: Excelente, producción-ready, sin observaciones
   - **4**: Muy bueno, mejoras menores opcionales
   - **3**: Aceptable, requiere mejoras menores
   - **2**: Deficiente, requiere mejoras significativas
   - **1**: Inaceptable, requiere reescritura completa
3. **SI la calidad < 4.5:**
   - Generar **plan detallado de arreglo** con:
     - Lista de problemas específicos
     - Causa raíz de cada problema
     - Solución propuesta para cada uno
     - Estimación de esfuerzo
   - Si el arreglo es pequeño → ejecutarlo inmediatamente
   - Si es grande → documentar y solicitar aprobación

### **10. VERIFICACIÓN AUTOMÁTICA**
- **OBLIGATORIO** ejecutar después de cada cambio:
  - **Linters** (ESLint, TypeScript compiler)
  - **Builds** (verificar que compila sin errores)
  - **Tests** (si existen, ejecutar los relevantes)
- **PROHIBIDO** dar por completada una tarea sin verificar que:
  - No hay errores de compilación
  - No hay warnings de linter (o están justificados)
  - El build pasa exitosamente

---

## **FLUJO DE TRABAJO OBLIGATORIO**

```
1. IDENTIFICAR TAREA
   ↓
2. BUSCAR EXISTENCIAS (semble_search) ← PREVENIR DUPLICADOS
   ↓
3. PLANEAR ACCIÓN (con rangos específicos)
   ↓
4. EJECUTAR (crear/modificar con calidad)
   ↓
5. REVISAR CALIDAD (auto-evaluación 1-5)
   ↓
6. SI CALIDAD < 3 → PLAN DE ARREGLO
   ↓
7. VERIFICAR (linters + build + tests)
   ↓
8. ENTREGAR
```

---

## **CHECKLIST DE PREVENCIÓN DE DUPLICADOS**

**Antes de CADA nueva creación, responder:**
- [ ] ¿Busqué con `semble_search` o `grep -rl` usando el nombre exacto?
- [ ] ¿Busqué con sinónimos y términos relacionados?
- [ ] ¿Busqué patrones de uso similares?
- [ ] ¿Revisé si existe algo que pueda extenderse en lugar de crear nuevo?
- [ ] ¿Documenté por qué es necesario crear nuevo (si aplica)?

---

## **EJEMPLOS DE APLICACIÓN**

**❌ MALO:**
```
"Voy a crear un componente ButtonPrimary"
→ Sin buscar si ya existe Button, PrimaryButton, etc.
→ Crea duplicado innecesario
```

**✅ BUENO:**
```
1. semble_search("Button") → encuentra Button.tsx
2. semble_search("Primary") → encuentra PrimaryButton.tsx  
3. semble_search("button primary variant") → encuentra variantes
4. Conclusión: Ya existe Button con variante "primary"
5. Acción: REUTILIZAR Button con variant="primary"
```

##  Como funcionan los MCP y sus reglas 

### MCP Triage (Optimización de tokens)
- Los MCP servers NO deben cargarse en el prompt principal
- Activar por demanda cuando el usuario mencione palabras clave específicas
- Priorizar: GitHub, Jira, Linear, etc.

### AFT (Agent File Tools) - Herramientas de edición avanzada
- Usar `aft_` tools para análisis semántico de código
- Preferir `edit` por nombre de símbolo en lugar de rangos de líneas
- Usar `trace_to` y `callers` para encontrar dependencias
- Aplicar formateo automático después de cada edición

### OpenCode FastEdit
- Usar `fastedit` para ediciones específicas por líneas
- Formato: `fastedit(file_path, start_line, end_line, new_code)`

### Semble (Búsqueda rápida de archivos)
- Usar `semble_search` para IDENTIFICAR archivos relevantes
- NO esperar resultados exactos de código
- Después de identificar archivos, usar `read_file` o `view` para ver contenido completo
- La búsqueda es conceptual, no exacta

### Caveman (Respuestas breves)
- Mantener activado el modo `caveman lite` durante toda la sesión
- Responder sin palabras de relleno (artículos, conectores innecesarios)
- Priorizar precisión técnica sobre extensión

## 📋 Estrategia de Trabajo

### 1. Búsqueda de código
1. Usar `semble_search` con query conceptual
2. Analizar qué archivos aparecen en resultados
3. Leer archivos específicos con `read_file`
4. Buscar dentro del contenido usando capacidades internas

### 2. Edición de código
1. Preferir `edit` por nombre de símbolo (AFT)
2. Si no es posible, usar `fastedit` con rangos de líneas
3. NUNCA escribir código viejo - solo el cambio

### 3. Optimización de tokens
- Respuestas en modo caveman (breves, sin relleno)
- Contexto comprimido por tiny token kit
- MCP tools solo bajo demanda

### 4. Indexación
- Ejecuta `aft index build` si el proyecto no está indexado ya.

## Semble MCP Tool (Búsqueda semántica de código)

**Herramienta MCP disponible:** `semble_search`

### Uso correcto (como herramienta MCP, NO como comando shell)

Cuando necesites encontrar código relevante:

1. **Llama a la herramienta MCP `semble_search`** con estos parámetros:
   ```json
   {
     "query": "qué hace esta función o qué concepto buscar",
     "path": "/home/cathood/Descargas/projects/flutter/packages/dart_xsd_to_class_gen",
     "top_k": 5
   }

## Semble Fallback 

The index is built on first run (and cached for subsequent runs) and invalidated automatically when files change.

Use `--content docs` to search documentation and prose, `--content config` for config files (yaml, toml, etc.), or `--content all` to search code, docs, and config:

```bash
semble search "deployment guide" ./my-project --content docs
semble search "database host port" ./my-project --content config
semble search "authentication" ./my-project --content all
```

Use `semble find-related` to discover code similar to a known location (pass `file_path` and `line` from a prior search result):

```bash
semble find-related src/auth.py 42 ./my-project
```

`path` defaults to the current directory when omitted; git URLs are accepted.

If `semble` is not on `$PATH`, use `uvx --from "semble[mcp]" semble` in its place.

### Workflow

1. Start with `semble search` to find relevant chunks. The index is built and cached automatically.
2. Use `--content docs` for documentation, `--content config` for config files, or `--content all` for everything.
3. Inspect full files only when the returned chunk does not give enough context.
4. Optionally use `semble find-related` with a promising result's `file_path` and `line` to discover related implementations.
5. Use grep only when you need exhaustive literal matches or quick confirmation of an exact string.

A **`semble` MCP server** is available for semantic code search. Use it **before** Grep/Glob/Read for exploratory queries.


# Mundo abierto por chunks · diseño

Estado: borrador para aprobación · 2026-11-14 · Godot 4.7.2 · campaña `lunar/lunar.tscn`

## Intención

Que explorar la Luna emocione. El jugador sale de la base, salta con una gravedad que se siente lunar y busca hielo y mineral, que ya no están dentro de la base. La dificultad nace de la escasez: hay que ir a buscar los recursos y volver con ellos antes de que se agote el aire o llegue la noche.

Público: jugadores de 7 a 12 años, en Android (táctil) y Windows, en individual sin conexión o en cooperativo de dos por IP.

## Objetivos

- Cada una de las nueve regiones tiene un mundo grande y limitado alrededor de su base.
- El mundo se divide en chunks que se cargan cerca del jugador y se descargan cuando dejan de verse.
- El hielo y el mineral aparecen en depósitos repartidos por probabilidad.
- Cada chunk recuerda su estado. Al volver a cargarlo se ve igual que cuando se dejó: no se genera uno nuevo.
- Los depósitos minados se rellenan tras unos amaneceres.
- Salto con gravedad lunar estilizada y cámara que deja percibir la altura.
- El cooperativo funciona con una separación máxima de 40 m entre los dos astronautas.

## No objetivos (en este corte)

- Vehículos o rover para transportar cajas.
- Simulación geográfica real: el relieve se inspira en cada región, pero no usa datos de elevación reales del lugar.
- Mundo infinito o un mapa único compartido entre regiones.
- Nuevos tipos de recurso aparte de hielo y mineral.
- Cambios en la escena histórica `crest/crest.tscn` ni en los prototipos `field`, `outpost` y `src/mission.tscn`.

## Anti-objetivos (sería un fracaso aunque funcione)

- Que el mundo se vea distinto al volver a un sitio, o que los depósitos reaparezcan llenos al recargar un chunk.
- Que el juego dé tirones al cruzar el borde de un chunk en el teléfono.
- Que un jugador nuevo quede atascado sin recursos al empezar.
- Que el salto se sienta pesado o tan lento que aburra.
- Que el guardado crezca sin límite con la exploración.

## Restricciones

- Godot 4.7.2, GDScript, Compatibility en móvil y Forward+ en escritorio. Objetivo: 30 fps en ARM64 Android.
- Sin servicios externos. El cooperativo es por ENet directo con el anfitrión como autoridad (`lunar_game.gd`).
- Los parámetros de juego viven en `context_core/state_registry.json` (`campaign_2026`). El código los lee y no los fija.
- `FieldPilot` también lo usan las suites `field` y `crest`, que esperan su gravedad actual (16 m/s²).
- AGENTS.md: después de cada corte verificable se ejecuta `tests/verify.ps1` y se actualizan el grafo, el registro, las reglas y el changelog de `context_core`.

## Enfoques considerados

1. **Chunks generados por código (elegido).** Una semilla, ruido y coordenadas crean el relieve y los depósitos de forma determinista. La generación corre en un hilo aparte y solo se guarda lo que cambió.
   - A favor: las nueve regiones salen distintas sin modelado, el guardado es pequeño y encaja con un proyecto donde suelo, cráteres y estaciones ya se construyen por código.
   - En contra: más código propio.
2. **Chunks hechos a mano** (escenas `.tscn` combinadas al azar). Más control artístico, pero exige mucho modelado, las piezas se repiten y la APK crece.
3. **Plugin de terreno externo** (p. ej. Terrain3D). Resuelve el relieve grande, pero añade una dependencia externa con soporte incierto para Compatibility en Android y riesgo con Godot 4.7.2.

El usuario eligió el 1.

## Decisiones del usuario

- La base de cada región queda en el centro como hogar y punto de regreso. El mundo abierto la rodea, y el hielo y el mineral ya no están dentro de la base.
- Cooperativo con separación máxima de 40 m.
- Los depósitos minados se rellenan tras unos amaneceres.
- Generación por código.
- Aprobados en conversación: salto flotante con botón propio, cámara que sigue al piloto, borde del mundo formado por crestas infranqueables, tocar el suelo para caminar solo a distancias cortas, se mantienen las reglas de aire y noche, objetivo de 30 fps en móvil.

## Diseño

### Mundo y coordenadas

- Mundo cuadrado de `world_size` = **1024 m** de lado, centrado en el origen. La base ocupa el centro, como hoy. *(Decisión de diseño: en conversación se propusieron 512 m, pero con las cifras actuales de aire, 300 s de día en Media, un mundo de 512 m apenas pone el aire en juego. Con 1024 m, ir al borde y volver cuesta unos 150 s de 300.)*
- Chunks de `chunk_size` = **16 m**, con coordenadas enteras `Vector2i(cx, cz)` y `cx = floori(x / 16)`. Así quedan 64 × 64 chunks.
- La semilla del mundo es `hash([base_id, run])`, donde `run` es el valor que ya se guarda por base. Reiniciar una base desde cero genera un mundo nuevo, y continuar conserva el mismo.
- La semilla de cada chunk es `hash([world_seed, cx, cz])` y se usa con `RandomNumberGenerator` para colocar objetos. El relieve usa `FastNoiseLite` con la semilla del mundo, muestreado en coordenadas globales, para que los bordes entre chunks encajen sin costuras.

### Generación de un chunk (función pura)

`ChunkGenerator.generate(world_seed, region_profile, coord) -> ChunkData`. No toca el árbol de escena, así que puede correr en `WorkerThreadPool`.

`ChunkData` contiene:
- Alturas: rejilla de (16 + 1)² muestras a 1 m.
- Lista de rocas y cráteres pequeños, con posición, escala y tipo.
- Lista de depósitos: `id` local entero (0..n), tipo (`ice` u `ore`), posición y `capacity` (cajas que contiene).
- Máscara de transitabilidad para las rutas, a 0,5 m, igual que `LunarRoutes.CELL`. Se marca no transitable si la pendiente supera `max_walk_slope` o hay una roca.

El perfil de región (`region_profile`) sale de las bases de `campaign_2026` y añade: amplitud del relieve, densidad de cráteres, densidad de depósitos y proporción hielo/mineral. Por ejemplo, Mons Mouton Plateau es una meseta suave y Haworth es abrupta.

### Base central

- Un rectángulo fijo alrededor de la cubierta actual (unos 31 × 17 m más un margen de transición de unos 8 m) se aplana a Y = 0. Ahí el ruido se mezcla suavemente hacia cero.
- La base sigue construyéndose con `CrestWorld` y nunca se descarga. Los chunks que la cubren solo generan suelo y no colocan rocas ni depósitos dentro del rectángulo.
- **Se quitan las estaciones fijas `ice` y `ore`** de `campaign_stations`. La refinadora y el resto de estaciones se quedan. Los volúmenes de colisión de la cantera se retiran.
- **Arranque garantizado:** cada mundo coloca siempre un depósito pequeño de hielo y uno de mineral a 25–40 m de la base, en posiciones derivadas de la semilla. Así nadie empieza atascado.

### Depósitos: probabilidad, minado y relleno

- Densidad base por chunk según el perfil de región. Crece con la distancia a la base (`deposit_distance_curve`) y la capacidad también (1 caja cerca, hasta 4 lejos).
- El hielo es más probable en el fondo de los cráteres en sombra. El generador marca como "sombra" las cotas bajas dentro de un cráter.
- Minar funciona como hoy (`_start_mining` y `_tick_mining`): estar cerca y pulsar **Acción** crea una caja de `ice` u `ore` tras `drill_seconds()`. Cada caja resta 1 de la capacidad del depósito. Se mantienen la mejora de taladro y el bono del geólogo.
- Con capacidad 0, el depósito se muestra vacío y queda registrado el día en que se vació (`days`).
- **Relleno:** vuelve a su capacidad original cuando `days - emptied_day >= deposit_refill_dawns` (**2**). Dentro de `deposit_near_radius` (**60 m**) de la base tarda el doble (**4**). Se comprueba al amanecer y al cargar el chunk.

### Estado guardado

- Solo se guardan cambios: `world_deltas: { "cx,cz": { deposit_id: { "left": int, "emptied_day": int } } }`. Un chunk sin cambios no ocupa nada.
- `world_deltas` forma parte de `LunarMission.SAVE_FIELDS`. Con eso entra en `state()`, `restore()`, el checkpoint del amanecer y el guardado por base. Si se agota el aire y se vuelve al amanecer, lo minado desde entonces se revierte, igual que el resto del progreso no asegurado (regla LUN-02).
- Las cajas sueltas fuera de la base ya viven en `crates` con posición global y no dependen de los chunks. Al dibujarlas solo se muestran si su chunk está cargado.
- Al descargar un chunk no se escribe nada a disco: el estado ya está en `sim`. El guardado a disco sigue los momentos actuales (amanecer y **Guardar y salir**).
- Compatibilidad: un guardado antiguo sin `world_deltas` carga con un mundo sin cambios. Las posiciones guardadas dentro de la base siguen siendo válidas.

### Carga y descarga

- `ChunkStreamer` (Node3D, hijo de `LunarGame`) decide qué chunks se necesitan: los que están a `load_radius` (**3 chunks**, 7 × 7 = 49) de cualquiera de los dos pilotos. La descarga empieza en `unload_radius` (**4**), y esa diferencia evita cargar y descargar sin parar en el borde.
- Si un chunk necesario no está, se pide a `WorkerThreadPool` el `ChunkData` y la construcción de su malla (`ArrayMesh`) y de su forma (`HeightMapShape3D`).
- En el hilo principal se añaden como máximo `chunks_per_frame` (**2**) chunks por frame: `MeshInstance3D` con `PaperMaterial`, `StaticBody3D`, `MultiMeshInstance3D` para las rocas y nodos para los depósitos.
- Mientras un chunk no tiene colisión, el piloto no puede entrar en él (se bloquea el avance) para no caer al vacío.
- Al descargar: `queue_free` del nodo del chunk. Se mantiene una caché LRU de `ChunkData` (unos 32) para volver rápido.

### Borde del mundo

Más allá de `world_size / 2 - edge_band` (unos 24 m), el generador sube el relieve hasta crestas con pendientes por encima de `max_walk_slope` y demasiado altas para saltarlas. Una pared de colisión invisible justo fuera sirve de seguro.

### Salto y gravedad

- `FieldPilot` gana propiedades `gravity`, `jump_speed` y `air_control`, con valores por defecto iguales a los actuales, para que las suites `field` y `crest` no cambien.
- En la campaña, `LunarGame` las fija desde el registro: `gravity` **3,2 m/s²** y `jump_speed` **3,2 m/s**, que dan unos 2 s en el aire y unos 1,6 m de altura. `air_control` es bajo: la aceleración en el aire baja de 13 a unos 4.
- Se puede saltar con caja, pero a `jump_speed * 0.7`. No hay daño por caída.
- Respuesta visual: polvo al despegar y al aterrizar, sombra del piloto siempre proyectada bajo él, y una zancada más larga y saltarina en `CrestPilot.animate_gait` fuera de la base.

### Cámara

- Fuera de la base: `Camera3D` en perspectiva (FOV de unos 45°) que sigue a su propio piloto en cada dispositivo, alta y por detrás según el ángulo actual (34° de elevación, misma orientación). Sigue con suavizado y no gira con el piloto, para no marear.
- Dentro del rectángulo de la base vuelve suavemente al encuadre ortográfico actual (`_surface_camera`), así que la base se ve como hoy.
- `LunarBackdrop` (cielo y horizonte) debe seguir funcionando con la cámara en movimiento. Adaptarlo es parte del trabajo.

### Controles

- Táctil: se mantienen el joystick, **Acción** y **Soltar / pasar**, y se añade el botón **Saltar**. Teclado de prueba en Windows: Espacio.
- Tocar el suelo para caminar solo vale dentro de un radio de `tap_route_radius` (unos 20 m) y sobre chunks cargados. Fuera de ese radio, el piloto camina en línea recta hacia el punto hasta chocar.

### Rutas

- La base mantiene su cuadrícula actual (`LunarRoutes`, sondeo físico).
- Fuera de la base, una `AStarGrid2D` cubre la ventana de chunks cargados y se rellena con las máscaras de transitabilidad de `ChunkData`, sin sondeo físico. Se reconstruye por zonas cuando entra o sale un chunk.

### Cooperativo

- **Separación máxima:** a más de `tether_soft` (**34 m**) aparece un aviso. A más de `tether_max` (**40 m**), quien se aleja frena hasta 0 en la dirección que aumenta la distancia. Esto lo aplica el anfitrión.
- **Chunks:** los dos dispositivos generan los chunks localmente a partir de la misma semilla. El anfitrión no envía terreno.
- **Estado:** `world_deltas` va dentro de `sim.state()`. El snapshot actual comprime y envía el estado completo en cada frame, y con un historial largo podría crecer. Por eso `world_deltas` sale del snapshot por frame: se envía completo al unirse el invitado y luego como cambios puntuales por RPC fiable cuando cambia un depósito.
- **Autoridad:** solo el anfitrión mina y cambia depósitos. El invitado pide la acción como hoy (`_guest_action`).

### Rendimiento (presupuesto inicial)

- Por chunk: malla de 17 × 17 vértices, una forma `HeightMapShape3D` y como máximo unas 40 rocas en `MultiMesh`.
- Cargados a la vez: como máximo 49 chunks más la base.
- Sin creación de nodos fuera del hilo principal. Como máximo 2 chunks añadidos por frame.
- Se mide en Windows con un perfil de 30 fps y, cuando haya teléfono, en ARM64.

### Parámetros nuevos en `state_registry.json → campaign_2026.open_world`

`world_size`, `chunk_size`, `load_radius`, `unload_radius`, `chunks_per_frame`, `edge_band`, `max_walk_slope`, `gravity`, `jump_speed`, `jump_with_box`, `air_control`, `tether_soft`, `tether_max`, `tap_route_radius`, `deposit_refill_dawns`, `deposit_near_radius`, `deposit_near_factor`, `starter_deposit_range`, `deposit_distance_curve` y, por región, `relief`, `crater_density`, `deposit_density` e `ice_ratio`.

## Verificación

Nueva suite `tests/open_world_suite.tscn`, añadida a `tests/verify.ps1`:
- Determinismo: misma semilla y mismo chunk dan el mismo `ChunkData` (alturas, depósitos e ids).
- Bordes sin costuras: las alturas compartidas entre chunks vecinos coinciden.
- Minar, alejarse hasta descargar el chunk, volver: el depósito conserva su capacidad.
- Relleno: tras `deposit_refill_dawns` amaneceres vuelve lleno, y cerca de la base tarda el doble.
- Volver al checkpoint revierte lo minado después del amanecer.
- Guardar y cargar conserva `world_deltas`. Un guardado antiguo carga sin errores.
- Separación: el piloto que se aleja no supera 40 m.
- Salto: tiempo en el aire y altura dentro de una tolerancia.
- Dos pares ENet locales: el invitado ve el depósito vacío tras minarlo el anfitrión, y al unirse recibe los cambios.
- Depósitos de arranque presentes a 25–40 m en las nueve regiones.
- Borde: ninguna ruta sale del mundo.

Las suites existentes deben seguir pasando. En `lunar_suite` habrá que actualizar los casos que usan las estaciones fijas `ice` y `ore`.

## Notas de la revisión

- **Cráteres actuales.** Los seis `LunarCrater` laterales y el detalle de superficie que hoy rodean la cubierta los sustituye el relieve de los chunks. Dentro del rectángulo de la base no se generan cráteres.
- **Balance.** Sin depósitos fijos, cada caja de hielo cuesta un viaje. Preparar la misión (agua para propelente, cultivo y soporte vital) exige varios viajes. Se ajusta con `starter_deposit_range`, `deposit_distance_curve` y las capacidades, y se registra en `campana_lunar_vigente.md` como parámetro de prototipo, igual que VAC-16.
- **Determinismo entre plataformas.** El ruido en coma flotante puede variar unos milímetros entre x86 y ARM. Las posiciones de los pilotos las decide el anfitrión, así que en el invitado solo podría verse un pie hundido unos milímetros. Los ids y capacidades de los depósitos se derivan de `RandomNumberGenerator` entero, no del ruido, para que coincidan siempre.
- **Regiones.** El generador admite las nueve desde el primer corte mediante su perfil. Las pruebas de recorrido completo se hacen en Mons Mouton Plateau, como hoy.

## Queda para el constructor

- Elección exacta del ruido (tipo, octavas, frecuencias) por región dentro del perfil.
- Forma visual de los depósitos (vacío y lleno) y de las rocas, con `PaperMaterial`. Se pueden reutilizar las piezas de `LunarCrater`.
- Estructura de clases interna de `ChunkStreamer` y `ChunkGenerator`, y cómo se reparte la reconstrucción de rutas.
- Ajuste fino de la cámara (distancia, FOV, suavizado) dentro de lo descrito.
- Orden de los cortes de implementación, siempre que cada uno deje `verify.ps1` en verde.

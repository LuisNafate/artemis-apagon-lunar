# Mundo abierto por chunks · plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rodear la base de cada región con un mundo de 1024 m generado por chunks deterministas, con depósitos de hielo y mineral que se agotan y se rellenan, salto lunar, cámara que sigue al piloto y cooperativo con separación máxima de 40 m.

**Architecture:** `ChunkGenerator` es una función pura (semilla + coordenada → `ChunkData`) que corre en `WorkerThreadPool`. `ChunkStreamer` instancia y libera `ChunkView` alrededor de los pilotos. `LunarMission` guarda solo `world_deltas` (cambios de depósitos) dentro de su estado, así que checkpoint, guardado y snapshot heredan el comportamiento actual. La base sigue siendo `CrestWorld`, fija en el centro.

**Tech Stack:** Godot 4.7.2, GDScript, `FastNoiseLite`, `RandomNumberGenerator`, `HeightMapShape3D`, `WorkerThreadPool`, `AStarGrid2D`, ENet.

**Spec:** `context_core/mundo_abierto_design.md`

## Global Constraints

- Godot 4.7.2. Compatibility en móvil y Forward+ en escritorio. Objetivo: 30 fps en ARM64.
- Todos los números de juego se leen de `context_core/state_registry.json → campaign_2026.open_world`. Ningún valor de la spec va fijo en el código.
- Valores de la spec: `world_size` 1024, `chunk_size` 16, `load_radius` 3, `unload_radius` 4, `chunks_per_frame` 2, `edge_band` 24, `gravity` 3.2, `jump_speed` 3.2, `jump_with_box` 0.7, `air_control` 4.0, `tether_soft` 34, `tether_max` 40, `tap_route_radius` 20, `deposit_refill_dawns` 2, `deposit_near_radius` 60, `deposit_near_factor` 2, `starter_deposit_range` [25, 40].
- Rectángulo plano de la base (plano del equipo, 40 × 22 m): `Rect2(-20, -11, 40, 22)`, con `base_flat_transition` 24 m. No hay rocas ni depósitos dentro de `Rect2(-28, -19, 56, 38)`. *(Antes del 2026-11-15: `Rect2(-15.45, -8.7, 30.9, 17.4)` y `Rect2(-23.45, -16.7, 46.9, 33.4)`.)*
- Decisiones del usuario del 2026-11-15: en la campaña, los chunks sustituyen a `superficie_lunar.glb`; los `deposito_hielo` salen de la base y su modelo es el aspecto de los depósitos de hielo del mundo.
- `FieldPilot` mantiene por defecto gravedad 16, salto 6.4 y aceleración en aire 13. Las suites `field` y `crest` no cambian.
- No se toca `crest/crest.tscn` ni los prototipos `field`, `outpost` y `src/mission.tscn`.
- Textos de interfaz en español.
- Godot local: `$G = "C:\Users\Rust\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"`.
- Suite nueva: `& $G --headless --path . --fixed-fps 60 --quit-after 6000 res://tests/open_world_suite.tscn`. Pasa si imprime `OPEN SUITE: <n> cases, <m> assertions, 0 failed`.
- Las pruebas no pueden dejar avisos de Godot: `verify.ps1` falla con cualquier `WARNING` (variables sin usar, división entera, nombres que tapan funciones globales como `seed`).
- Al final de cada tarea, `./tests/verify.ps1 -Godot $G` en verde. Requiere `python -m pip install --user gdtoolkit` (Tarea 1).
- `--editor --import` reescribe el fin de línea de los `.import`. Antes de cada commit, `git checkout -- '*.import'` si `git diff --ignore-cr-at-eol` no muestra cambios en ellos.
- Commits en español, con la línea `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Esprintar o caminar hacia un chunk sin colisión.** El piloto no debe caer: se queda en el borde hasta que el chunk esté listo. Prueba en la Tarea 4.
2. **Caja soltada lejos y chunk descargado.** La caja no se pierde ni cae: se oculta y reaparece en su punto al volver. Prueba en la Tarea 4.
3. **Guardar y salir lejos de la base, y volver a entrar.** El piloto aparece en su punto sin caer, porque se espera a que el chunk esté listo. Prueba en la Tarea 4.
4. **Quedarse sin aire lejos.** Vuelve a las posiciones del amanecer y se revierte lo minado. Esa zona tiene que cargarse. Pruebas en las Tareas 2 y 4.
5. **El invitado se une con el anfitrión lejos de la base.** Ve el terreno y los depósitos vacíos correctos antes de moverse. Prueba en la Tarea 8.

---

### Task 1: Generador determinista de chunks

**Files:**
- Create: `lunar/open_world/chunk_data.gd`, `lunar/open_world/chunk_generator.gd`
- Create: `tests/open_world_suite.gd`, `tests/open_world_suite.tscn` (mismo patrón que `tests/lunar_suite.*`: `_check(cond, label)`, contadores y `print("OPEN SUITE: %d cases, %d assertions, %d failed" ...)`)
- Modify: `context_core/state_registry.json` (añadir `campaign_2026.open_world` con los valores de Global Constraints y `regions` por cada una de las 9 bases: `relief`, `crater_density`, `deposit_density`, `ice_ratio`)
- Modify: `tests/verify.ps1` (añadir `OPEN` al regex de suites y el paso `Regresión mundo abierto` con `--fixed-fps 60 --quit-after 6000 res://tests/open_world_suite.tscn`)

**Interfaces:**
- Produces:
  - `class_name ChunkData extends RefCounted` con `coord: Vector2i`, `heights: PackedFloat32Array` (17×17, fila z mayor), `walkable: PackedByteArray` (32×32 celdas de 0.5 m, 1 = transitable), `rocks: Array[Dictionary]` (`{point: Vector3, scale: float, seed: int}`), `deposits: Array[Dictionary]` (`{id: int, kind: StringName, point: Vector3, capacity: int, near_base: bool}`), `func height_at(local: Vector2) -> float`.
  - `class_name ChunkGenerator extends RefCounted`:
    - `static func world_seed(base_id: String, run: int) -> int` → `hash([base_id, run])`
    - `static func coord_of(point: Vector3, chunk_size: float) -> Vector2i`
    - `static func height(world_seed: int, region: Dictionary, settings: Dictionary, x: float, z: float) -> float`: relieve global, aplanado en la base y crestas en el borde.
    - `static func starter_deposits(world_seed: int, settings: Dictionary) -> Array[Dictionary]`: dos depósitos (`ice` id 90, `ore` id 91, capacidad 1) a 25–40 m del origen y fuera del rectángulo de exclusión.
    - `static func generate(world_seed: int, region: Dictionary, settings: Dictionary, coord: Vector2i) -> ChunkData`

- [ ] **Step 1: Instalar gdtoolkit y comprobar que `verify.ps1 -Godot $G` pasa antes de tocar nada.** Esperado: las cinco suites actuales con 0 fallos.

- [ ] **Step 2: Escribir las pruebas que fallan**

```gdscript
func _generation() -> void:
	_cases += 1
	var rules: Dictionary = _rules()
	var s: Dictionary = rules.open_world
	var world := ChunkGenerator.world_seed("mons_mouton_plateau", 12345)
	var region: Dictionary = s.regions.mons_mouton_plateau
	var a := ChunkGenerator.generate(world, region, s, Vector2i(5, -3))
	var b := ChunkGenerator.generate(world, region, s, Vector2i(5, -3))
	_check(a.heights == b.heights and a.walkable == b.walkable, "same seed same terrain")
	_check(str(a.deposits) == str(b.deposits), "same seed same deposits")
	var east := ChunkGenerator.generate(world, region, s, Vector2i(6, -3))
	for row in range(17):
		_check(is_equal_approx(a.heights[row * 17 + 16], east.heights[row * 17]), "seam row %d" % row)
	var home := ChunkGenerator.generate(world, region, s, Vector2i(0, 0))
	_check(absf(home.height_at(Vector2(3, 3))) < 0.001, "base deck flat at Y=0")
	for coord in [Vector2i(-1, -1), Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		var c := ChunkGenerator.generate(world, region, s, coord)
		for d in c.deposits:
			_check(not Rect2(-23.45, -16.7, 46.9, 33.4).has_point(Vector2(d.point.x, d.point.z)), "no deposit in base")
	for base_id: String in rules.bases:
		var w := ChunkGenerator.world_seed(base_id, 7)
		var starters := ChunkGenerator.starter_deposits(w, s)
		_check(starters.size() == 2, "%s two starters" % base_id)
		for d in starters:
			var r := Vector2(d.point.x, d.point.z).length()
			_check(r >= 25.0 and r <= 40.0, "%s starter within 25-40 m" % base_id)
	var edge := ChunkGenerator.generate(world, region, s, Vector2i(31, 0))
	_check(edge.walkable.count(0) > edge.walkable.size() * 0.5, "edge ridge blocks walking")
	var far_cap := 0
	var near_cap := 0
	for cx in range(-28, 29, 4):
		for d in ChunkGenerator.generate(world, region, s, Vector2i(cx, 20)).deposits:
			far_cap = maxi(far_cap, d.capacity)
		for d in ChunkGenerator.generate(world, region, s, Vector2i(cx % 4, 2)).deposits:
			near_cap = maxi(near_cap, d.capacity)
	_check(far_cap > near_cap and far_cap <= 4, "capacity grows with distance, max 4")
```

- [ ] **Step 3: Ejecutar la suite y comprobar que falla.** Esperado: error de parseo `ChunkGenerator` no definido.

- [ ] **Step 4: Implementar `ChunkData` y `ChunkGenerator` con las firmas de arriba.**
  - Ruido: `FastNoiseLite` (simplex FBM) sembrado con `world_seed` y muestreado en coordenadas globales, así que los bordes compartidos coinciden.
  - Aplanado de la base: multiplica por `smoothstep(0, 8, distancia al rectángulo plano)`.
  - Borde: suma una rampa hasta unos 12 m dentro de `edge_band`.
  - `walkable`: pendiente local mayor que `max_walk_slope` (añádelo al registro, unos 0.6) o celda ocupada por roca → 0.
  - Objetos: rocas y depósitos con `RandomNumberGenerator` sembrado con `hash([world_seed, coord.x, coord.y])`. Los ids son enteros consecutivos. La capacidad sigue `deposit_distance_curve` (1 cerca, hasta 4 lejos).
  - Hielo en sombra: las cotas bajas dentro de un cráter generado son más probables para `ice`.
  - Los dos depósitos de arranque se añaden al chunk que los contiene.
  - Cráteres: radio y profundidad según `crater_density` de la región.

- [ ] **Step 5: Ejecutar la suite y `verify.ps1 -Godot $G`.** Esperado: `OPEN SUITE ... 0 failed` y el resto en verde.

- [ ] **Step 6: Commit** `Añadir generador determinista de chunks del mundo abierto`

---

### Task 2: Estado de depósitos en la misión

**Files:**
- Modify: `lunar/lunar_mission.gd` (`SAVE_FIELDS`, `use_station`, `_tick_mining`, amanecer en `tick`)
- Test: `tests/open_world_suite.gd`

**Interfaces:**
- Consumes: `ChunkGenerator.world_seed`, campos de depósito de `ChunkData`.
- Produces (en `LunarMission`):
  - `var world_deltas: Dictionary = {}`, guardado. Clave `"cx:cz:id"` → `{"left": int, "emptied_day": int}`. *(Clave plana equivalente a la anidada de la spec.)*
  - `var world_seed: int`, que fija `prepare()` con `ChunkGenerator.world_seed(id, seed_value)`.
  - `static func deposit_key(coord: Vector2i, id: int) -> StringName` → `&"dep:cx:cz:id"`
  - `func register_deposit(key: StringName, kind: StringName, capacity: int, near_base: bool) -> void`: guarda en `_known_deposits` (no se guarda) y aplica el relleno pendiente.
  - `func deposit_left(key: StringName) -> int`
  - `signal deposit_changed(key: StringName, left: int)`
  - `use_station(player, key)` con una clave `dep:` mina el depósito. Si está vacío devuelve `"Depósito vacío · vuelve en %d amaneceres"`.

- [ ] **Step 1: Escribir las pruebas que fallan**

```gdscript
func _deposits() -> void:
	_cases += 1
	var m := LunarMission.new()
	m.prepare("mons_mouton_plateau", 41, true)
	m.finish_tutorial()
	var key := LunarMission.deposit_key(Vector2i(4, 2), 3)
	m.register_deposit(key, &"ice", 2, false)
	_check(m.deposit_left(key) == 2, "fresh deposit full")
	for trip in range(2):
		m.use_station(0, key)
		m.tick(m.drill_seconds() + 0.1, [false, false] as Array[bool], [key, &""] as Array[StringName])
		_check(m.cargo_kind(0) == &"ice", "mined ice crate")
		m._consume_cargo(0)
	_check(m.deposit_left(key) == 0 and m.world_deltas[String(key).trim_prefix("dep:")].emptied_day == m.days, "emptied on day")
	_check(m.use_station(0, key).begins_with("Depósito vacío"), "empty message")
	_advance_dawns(m, 1)
	_check(m.deposit_left(key) == 0, "still empty after 1 dawn")
	_advance_dawns(m, 1)
	_check(m.deposit_left(key) == 2, "refilled after 2 dawns")
	var near := LunarMission.deposit_key(Vector2i(1, 1), 0)
	m.register_deposit(near, &"ore", 1, true)
	m.use_station(0, near)
	m.tick(m.drill_seconds() + 0.1, [false, false] as Array[bool], [near, &""] as Array[StringName])
	m._consume_cargo(0)
	_advance_dawns(m, 3)
	_check(m.deposit_left(near) == 0, "near base waits 4 dawns")
	_advance_dawns(m, 1)
	_check(m.deposit_left(near) == 1, "near base refilled at 4")
	m.store_checkpoint()
	m.use_station(0, key)
	m.tick(m.drill_seconds() + 0.1, [false, false] as Array[bool], [key, &""] as Array[StringName])
	m.pilots[0].air = 0.0
	m.tick(0.1, [false, false] as Array[bool], [&"", &""] as Array[StringName])
	_check(m.withdrew and m.deposit_left(key) == 2, "air-out reverts mining since dawn")
	var copy := LunarMission.new()
	copy.prepare("mons_mouton_plateau", 41, true)
	copy.restore(m.state())
	copy.register_deposit(key, &"ice", 2, false)
	_check(copy.world_deltas == m.world_deltas, "deltas survive state round trip")
	var legacy := m.state()
	legacy.erase("world_deltas")
	copy.restore(legacy)
	_check(copy.world_deltas is Dictionary, "old save loads")
```

Añade `_advance_dawns(m, n)`: pone `elapsed = period - 0.1` y hace `tick(0.2, SAFE, AWAY)` n veces. `SAFE` y `AWAY` se declaran como en `lunar_suite.gd`.

- [ ] **Step 2: Ejecutar y comprobar que falla.** Esperado: `deposit_key` no existe.
- [ ] **Step 3: Implementar.**
  - Añadir `"world_deltas"` a `SAVE_FIELDS`.
  - En la minería, `pilot.mine` guarda la clave del depósito. Al completarla: `_create_cargo(player, kind)`, restar 1, fijar `emptied_day` cuando llega a 0 y emitir `deposit_changed`.
  - El bono del geólogo sigue igual y no resta del depósito.
  - Al amanecer y en `register_deposit`, rellenar cuando `days - emptied_day >= deposit_refill_dawns * (deposit_near_factor if near_base else 1)`. Rellenar significa borrar la entrada del delta.
  - En `restore()`, si falta la clave, `world_deltas` queda `{}`.
- [ ] **Step 4: Ejecutar la suite nueva y `lunar_suite`.** Esperado: ambas con 0 fallos.
- [ ] **Step 5: Commit** `Guardar el estado de los depósitos del mundo abierto`

---

### Task 2b: Reparar main y adaptar el generador al plano 40 × 22

El plano del equipo (8e87411, ya fusionado) dejó rotas dos suites que antes pasaban, y cambió la plataforma de la que depende el generador.

**Files:**
- Modify: `tests/crest_suite.gd`: el caso de pilotos (líneas ~285-310) comprueba el esqueleto, los huesos y el `ShaderMaterial` del gato anterior, que ya no existen. Reescríbelo para el piloto actual: el modelo y el `AnimationPlayer` son distintos por piloto; existen los clips `Idle`, `Walk` y `Run` en bucle; cada piloto tiene su tinte (`CrestWorld.BLUE` / `CrestWorld.AMBER` mezclado con `TINT_STRENGTH`); al caminar suena `Walk` y en reposo `Idle`.
- Modify: lo que haga falta para que `tests/lunar_suite.gd` vuelva a 0 fallos (17 fallos en `_solo` y `_network` desde 8e87411). Diagnostica la causa antes de cambiar nada. Si es un fallo real del juego (por ejemplo, el tutorial no se puede completar desde los nuevos puntos de salida), arréglalo en el juego. Si la prueba asume la distribución antigua, actualiza la prueba. Explica cuál fue en el informe.
- Modify: `context_core/state_registry.json` y `lunar/open_world/chunk_generator.gd`: el rectángulo plano y el de exclusión pasan a los valores de Global Constraints (40 × 22). Si hoy están en el registro, solo cambian los números. Si están en el código, muévelos al registro.
- Modify: `tests/open_world_suite.gd`: los rectángulos de las pruebas de exclusión, salida de la base y arranque siguen a los nuevos valores, leídos del registro y no copiados.

- [ ] **Step 1: Ejecutar `verify.ps1 -Godot $G` y anotar los fallos actuales** (crest no carga; lunar 17 fallos).
- [ ] **Step 2: Diagnosticar los fallos de `lunar_suite`** (causa raíz con evidencia) y reescribir el caso de pilotos de `crest_suite`.
- [ ] **Step 3: Cambiar los rectángulos de la base en el registro y el generador, y adaptar las pruebas del mundo abierto.**
- [ ] **Step 4: `verify.ps1 -Godot $G` en verde**, con todas las suites a 0 fallos.
- [ ] **Step 5: Commit** `Reparar suites tras el plano 40x22 y adaptar el generador`

---

### Task 3: ChunkStreamer y ChunkView

**Files:**
- Create: `lunar/open_world/chunk_view.gd`, `lunar/open_world/chunk_streamer.gd`
- Test: `tests/open_world_suite.gd`

**Interfaces:**
- Consumes: `ChunkGenerator.generate`, `ChunkData`, `LunarMission.register_deposit`, `deposit_left`, `deposit_changed`, `deposit_key`.
- Produces:
  - `class_name ChunkView extends Node3D`, con `func build(data: ChunkData, soil: Color) -> void`:
    - `MeshInstance3D` con `PaperMaterial` facetado.
    - `StaticBody3D` en capa 1 con `HeightMapShape3D` a escala de 1 m.
    - `MultiMeshInstance3D` de rocas con `LunarCrater.rock_mesh`.
    - Un marcador por depósito, con `func set_deposit(id: int, left: int) -> void` que alterna entre las formas vacía y llena. El hielo usa `assets/props_luna/estaciones/deposito_hielo.glb` (`PaperMaterial.restyle(modelo, false)`); el vacío es el mismo modelo hundido y oscurecido. El mineral usa una pieza propia con `PaperMaterial`.
  - `class_name ChunkStreamer extends Node3D`:
    - `func configure(sim: LunarMission, settings: Dictionary, region: Dictionary, soil: Color) -> void`
    - `func update(focus_points: Array[Vector3]) -> void`: pide al pool lo que falta y añade como máximo `chunks_per_frame` por llamada.
    - `func needed_coords(focus_points: Array[Vector3]) -> Array[Vector2i]`
    - `func loaded_coords() -> Array[Vector2i]`
    - `func is_ready_at(point: Vector3) -> bool`: chunk con colisión en el árbol.
    - `func nearest_deposit(point: Vector3, reach: float) -> StringName`: `&""` si no hay ninguno.
    - `func data_at(coord: Vector2i) -> ChunkData`: desde la caché LRU de 32.
    - `func clear() -> void`
  - Las coordenadas fuera de `world_size` no se cargan. Una pared invisible (`StaticBody3D` con 4 `BoxShape3D`) va 1 m fuera del borde.

- [ ] **Step 1: Escribir las pruebas que fallan**

```gdscript
func _streaming() -> void:
	_cases += 1
	var sim := LunarMission.new()
	sim.prepare("mons_mouton_plateau", 41, true)
	var streamer := ChunkStreamer.new()
	add_child(streamer)
	var s: Dictionary = sim.rules.open_world
	streamer.configure(sim, s, s.regions.mons_mouton_plateau, Color("#6b6678"))
	var focus: Array[Vector3] = [Vector3(100, 0, 100)]
	_check(streamer.needed_coords(focus).size() == 49, "7x7 chunks around one pilot")
	streamer.update(focus)
	_check(streamer.loaded_coords().size() <= 2, "at most 2 chunks per frame")
	var frames := 0
	while streamer.loaded_coords().size() < 49 and frames < 600:
		streamer.update(focus)
		await get_tree().process_frame
		frames += 1
	_check(streamer.loaded_coords().size() == 49 and streamer.is_ready_at(focus[0]), "window loaded")
	var key := streamer.nearest_deposit(focus[0], 60.0)
	_check(key != &"" and sim.deposit_left(key) > 0, "deposit registered on load")
	sim.world_deltas[String(key).trim_prefix("dep:")] = {"left": 0, "emptied_day": 0}
	var far: Array[Vector3] = [Vector3(-300, 0, -300)]
	for i in range(400):
		streamer.update(far)
		await get_tree().process_frame
	_check(not streamer.is_ready_at(focus[0]), "unloaded beyond radius 4")
	for i in range(400):
		streamer.update(focus)
		await get_tree().process_frame
	_check(sim.deposit_left(key) == 0, "reloaded chunk keeps empty deposit")
	var edge: Array[Vector3] = [Vector3(510, 0, 0)]
	_check(streamer.needed_coords(edge).all(func(c): return c.x < 32), "no chunks past the world edge")
	streamer.queue_free()
```

- [ ] **Step 2: Ejecutar y comprobar que falla.**
- [ ] **Step 3: Implementar.**
  - `WorkerThreadPool.add_task` genera el `ChunkData` y construye `ArrayMesh` y alturas. Los nodos solo se crean en `update`, en el hilo principal.
  - Histéresis: carga dentro de `load_radius` y descarga más allá de `unload_radius`.
  - Al construir la vista se registran los depósitos en `sim` y se refleja su estado con `set_deposit`.
  - Se escucha `deposit_changed` para refrescar los marcadores.
- [ ] **Step 4: Ejecutar la suite.** Esperado: 0 fallos.
- [ ] **Step 5: Commit** `Cargar y descargar chunks alrededor de los pilotos`

---

### Task 4: Integración en la campaña

**Files:**
- Modify: `crest/crest_world.gd`: en modo campaña, quitar `ice` y `ore` de `campaign_stations`, no colocar los dos `deposito_hielo` de la base, no mostrar `superficie_lunar.glb` y no construir `CrateresLaterales` ni el detalle exterior. En la escena histórica de Cresta se mantienen.
- Modify: `lunar/lunar_game.gd`:
  - Crear `ChunkStreamer` en `_ready`.
  - En `_prepare_base`, `configure(...)` y esperar `is_ready_at` de los spawns antes de mostrar el juego. La pantalla de carga ya existe.
  - En `_local_frame` y `_guest_frame`, `streamer.update(_positions())`. `_spots[i]` usa el depósito más cercano si no hay estación.
  - `_move_pilot` frena el avance si `not streamer.is_ready_at(posición + velocidad * delta * 4)`.
  - `_render` oculta las cajas en chunks no cargados.
- Modify: `lunar/lunar_interface.gd`: el texto de acción sobre un depósito es `"Extraer hielo"` / `"Extraer mineral"` o `"Depósito vacío"`.
- Modify: `tests/lunar_suite.gd`: `_terrain()` deja de exigir `ice` y `ore` como anclas y la prueba de recorrido sale del depósito de arranque de hielo.
- Test: `tests/open_world_suite.gd`

**Interfaces:**
- Consumes: todo lo de las Tareas 1–3.
- Produces: `LunarGame.streamer: ChunkStreamer`; `CrestWorld.campaign_stations` sin `ice` ni `ore`.
- Produces (ayudas de la suite, reutilizadas en las Tareas 5–9):
  - `_frames(n: int) -> void`: espera n `physics_frame`.
  - `_game_solo(base_id: String) -> Node`: instancia `lunar.tscn` con un perfil temporal, como `_endpoint` en `lunar_suite`, llama a `_start_solo`, `finish_tutorial` y espera `streamer.is_ready_at` del spawn.
  - `_game_continue(game: Node) -> Node`: libera `game` y abre otro con el mismo perfil vía **Continuar**.

- [ ] **Step 1: Escribir las pruebas que fallan** (instanciar `lunar.tscn` como en `_endpoint` de `lunar_suite`)

```gdscript
func _campaign() -> void:
	_cases += 1
	var game := await _game_solo("mons_mouton_plateau")
	_check(not CrestWorld.campaign_stations.has(&"ice"), "no fixed ice station")
	var starters := ChunkGenerator.starter_deposits(game.sim.world_seed, game.sim.rules.open_world)
	var ice: Vector3 = starters[0].point
	game._set_positions([ice + Vector3(0.8, 0.3, 0), Vector3.ZERO])
	await _frames(30)
	_check(game._spots[0].begins_with("dep:"), "starter deposit in reach")
	game._interact(0, false)
	await _frames(int(game.sim.drill_seconds() * 60) + 10)
	_check(game.sim.cargo_kind(0) == &"ice", "mined starter ice")
	game._interact(0, true)
	var crate_id: int = game.sim.crates.keys()[0]
	game._set_positions([Vector3(300, 2, 300), Vector3.ZERO])
	await _frames(240)
	_check(game.pilots[0].position.y > -0.5, "pilot never falls into unloaded chunk")
	_check(not game.world.crate_visible(crate_id) and game.sim.crates.has(crate_id), "far crate hidden not lost")
	game._vectors[0] = Vector2(1, 0)
	for i in range(120):
		await get_tree().physics_frame
	_check(game.pilots[0].position.y > -0.5, "dash toward new chunks stays on ground")
	game._save_base(true)
	var again := await _game_continue(game)
	_check(again.streamer.is_ready_at(again.pilots[0].position) and again.pilots[0].position.y > -0.5, "continue far from base without falling")
	again.sim.pilots[0].air = 0.0
	await _frames(5)
	_check(again.world.sheltered(again.pilots[0].position) or again.pilots[0].position.distance_to(CrestWorld.SPAWNS[0]) < 1.0, "air-out returns to dawn spot")
```

`world.crate_visible(id) -> bool` se añade en `CrestWorld`, o en `LunarGame` si las cajas se dibujan ahí. Usa el sitio donde hoy se dibujan.

- [ ] **Step 2: Ejecutar y comprobar que falla.**
- [ ] **Step 3: Implementar los cambios de la lista Files.**
- [ ] **Step 4: Ejecutar `verify.ps1 -Godot $G`.** Esperado: todas las suites en verde, incluida `lunar_suite` actualizada.
- [ ] **Step 5: Comprobación visual en Windows.** Lanza la escena principal, juega solo en Mons Mouton Plateau, sal de la base y mira que no haya costuras ni tirones al cruzar chunks. Si algo falla, anótalo en la tarea.
- [ ] **Step 6: Commit** `Rodear la base con el mundo abierto y sacar hielo y mineral de la base`

---

### Task 5: Salto con gravedad lunar

**Files:**
- Modify: `field/field_pilot.gd`: `var gravity := 16.0`, `var jump_speed := JUMP_SPEED` y `var air_acceleration := 13.0`, usadas en `drive`, más `var jump_scale := 1.0`.
- Modify: `crest/crest_pilot.gd`: marcha lunar fuera de la base con `var lunar_gait := false` (el piloto anima con `AnimationPlayer`: baja `speed_scale` de `Walk` y añade rebote del cuerpo; durante el salto usa una pose fija o `Idle`), polvo al despegar y aterrizar (`GPUParticles3D` corto; `CPUParticles3D` en Compatibility) y sombra circular bajo el piloto, colocada con un rayo hacia abajo.
- Modify: `lunar/lunar_game.gd`: fija los parámetros desde el registro en `_add_pilot` y pasa `jump` a `drive`. Con caja, `jump_scale = jump_with_box`. El invitado envía el salto en `_guest_move(axis, jump)`.
- Modify: `lunar/lunar_interface.gd`: botón `"Saltar"` (`_button(buttons, "Saltar", "jump")`, mínimo 50 px). Espacio en teclado.
- Test: `tests/open_world_suite.gd`

**Interfaces:**
- Produces: `FieldPilot.gravity`, `jump_speed`, `air_acceleration`, `jump_scale`; `LunarGame._jump: Array[bool]` (pulsación por jugador, se consume al despegar).

- [ ] **Step 1: Escribir las pruebas que fallan**

```gdscript
func _jump() -> void:
	_cases += 1
	var game := await _game_solo("mons_mouton_plateau")
	var pilot: CrestPilot = game.pilots[0]
	_check(is_equal_approx(pilot.gravity, 3.2) and is_equal_approx(pilot.jump_speed, 3.2), "lunar jump from registry")
	await _frames(10)
	game._jump[0] = true
	var airborne := 0
	var apex := 0.0
	var ground := pilot.position.y
	await get_tree().physics_frame
	while not pilot.is_on_floor() and airborne < 400:
		airborne += 1
		apex = maxf(apex, pilot.position.y - ground)
		await get_tree().physics_frame
	_check(absf(airborne / 60.0 - 2.0) < 0.15, "about 2 s airborne (%.2f)" % (airborne / 60.0))
	_check(absf(apex - 1.6) < 0.12, "about 1.6 m apex (%.2f)" % apex)
	var plain := FieldPilot.new()
	_check(plain.gravity == 16.0 and plain.jump_speed == FieldPilot.JUMP_SPEED, "legacy pilot unchanged")
	plain.free()
```

- [ ] **Step 2: Ejecutar y comprobar que falla.**
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Ejecutar `verify.ps1 -Godot $G`.** Esperado: verde, incluidas `field` y `crest`.
- [ ] **Step 5: Commit** `Añadir salto con gravedad lunar y botón Saltar`

---

### Task 6: Cámara que sigue al piloto

**Files:**
- Modify: `lunar/lunar_game.gd`: amplía el `_follow_camera(delta)` que ya existe (plano del equipo).
  - Dentro del rectángulo de exclusión de la base, conserva el comportamiento actual (ortográfica, `PLAY_SIZE`, desplazamiento limitado a la plataforma).
  - Fuera, perspectiva con FOV 45 y la misma orientación (34° de elevación, vector `Vector2(0.228, 0.974)`), siguiendo al piloto con `lerp` suavizado. Nunca gira con el piloto.
  - Cada dispositivo sigue a su propio piloto.
- Modify: `lunar/lunar_backdrop.gd`: que el cielo y el horizonte acompañen a la cámara en movimiento y en perspectiva.
- Modify: `lunar/lunar_game.gd` `_move_pilot`: la dirección del joystick ya usa `camera.basis` y sigue valiendo.
- Test: `tests/open_world_suite.gd`

- [ ] **Step 1: Escribir las pruebas que fallan**

```gdscript
func _camera() -> void:
	_cases += 1
	var game := await _game_solo("mons_mouton_plateau")
	await _frames(30)
	_check(game.camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "orthographic inside base")
	_check(is_equal_approx(game.camera.size, LunarGame.PLAY_SIZE), "team follow zoom kept in base")
	var basis_home: Basis = game.camera.global_basis
	game._set_positions([Vector3(60, 1, 40), Vector3.ZERO])
	await _frames(180)
	_check(game.camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "perspective outside")
	var screen: Vector2 = game.camera.unproject_position(game.pilots[0].position) / Vector2(game.get_viewport().size)
	_check(screen.distance_to(Vector2(0.5, 0.55)) < 0.2, "pilot near screen centre")
	_check(game.camera.global_basis.z.angle_to(basis_home.z) < deg_to_rad(12), "camera keeps heading")
```

- [ ] **Step 2: Ejecutar y comprobar que falla.**
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Ejecutar `verify.ps1 -Godot $G` y hacer una comprobación visual en Windows** (salir de la base, saltar, volver).
- [ ] **Step 5: Commit** `Cámara en perspectiva que sigue al piloto fuera de la base`

---

### Task 7: Tocar para caminar fuera de la base

**Files:**
- Create: `lunar/open_world/open_routes.gd`
- Modify: `lunar/lunar_game.gd` `_set_destination`: dentro de la base usa `LunarRoutes`. Fuera, si el destino está a ≤ `tap_route_radius`, usa `OpenRoutes`. Si está más lejos, el destino es un punto recto (`PackedVector2Array([destino])`).
- Test: `tests/open_world_suite.gd`

**Interfaces:**
- Consumes: `ChunkStreamer.loaded_coords()`, `data_at()`.
- Produces: `class_name OpenRoutes extends RefCounted`:
  - `func rebuild(streamer: ChunkStreamer) -> void`: `AStarGrid2D` de celdas de 0.5 m sobre los chunks cargados.
  - `func path(start: Vector3, end: Vector3) -> PackedVector2Array`
  - Se reconstruye cuando cambia `loaded_coords`, como máximo una vez cada 0.5 s.

- [ ] **Step 1: Escribir las pruebas que fallan**

```gdscript
func _open_routes() -> void:
	_cases += 1
	var game := await _game_solo("mons_mouton_plateau")
	game._set_positions([Vector3(80, 1, 60), Vector3.ZERO])
	await _frames(240)
	var routes := OpenRoutes.new()
	routes.rebuild(game.streamer)
	var path := routes.path(game.pilots[0].position, game.pilots[0].position + Vector3(12, 0, 6))
	_check(path.size() >= 2, "short open route exists")
	for p in path:
		var c := ChunkGenerator.coord_of(Vector3(p.x, 0, p.y), 16.0)
		var data := game.streamer.data_at(c)
		var cell := Vector2i(((Vector2(p.x, p.y) - Vector2(c) * 16.0) / 0.5).floor())
		_check(data.walkable[cell.y * 32 + cell.x] == 1, "route only on walkable cells")
	game._set_destination(0, game.pilots[0].position + Vector3(35, 0, 0))
	_check(game._route[0].size() == 1, "far tap walks straight")
```

- [ ] **Step 2: Ejecutar y comprobar que falla.**
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Ejecutar la suite.**
- [ ] **Step 5: Commit** `Rutas cortas al tocar el suelo fuera de la base`

---

### Task 8: Cooperativo en el mundo abierto

**Files:**
- Modify: `lunar/lunar_game.gd`:
  - `_send_snapshot` envía `sim.state()` sin `world_deltas`. Al unirse el invitado, `_world_sync.rpc_id(guest, sim.world_deltas)` (fiable).
  - En el anfitrión, `sim.deposit_changed` dispara `_deposit_delta.rpc_id(guest, key, entry)` (fiable).
  - Separación: en `_move_pilot` del anfitrión, a más de `tether_max` se anula la componente de velocidad que aleja a los pilotos. A más de `tether_soft` aparece el aviso `"Demasiado lejos de tu compañero"` en los dos dispositivos.
  - El invitado configura el streamer con el mismo `seed_value` que ya recibe en `_accept_join` y no muestra el juego hasta tener listos los chunks de las dos posiciones de la primera snapshot.
- Modify: `lunar/lunar_mission.gd`: `restore()` conserva el `world_deltas` local si el estado entrante no lo trae.
- Test: `tests/open_world_suite.gd`, con dos pares ENet locales en un puerto distinto de 44260, como en `_network()` de `lunar_suite`.

**Interfaces:**
- Produces (suite): `_host_and_guest(base_id: String, port: int) -> Array` y `_join_again(pair: Array, port: int) -> Node` (nuevo invitado que se une al mismo anfitrión).
- Produces: RPC `_world_sync(deltas: Dictionary)` (`authority`, `call_remote`, `reliable`) y `_deposit_delta(key: String, entry: Variant)` (`entry` null = relleno).

- [ ] **Step 1: Escribir las pruebas que fallan**

```gdscript
func _coop() -> void:
	_cases += 1
	var pair := await _host_and_guest("mons_mouton_plateau", 44361)
	var host: Node = pair[0]
	var guest: Node = pair[1]
	var starters := ChunkGenerator.starter_deposits(host.sim.world_seed, host.sim.rules.open_world)
	host._set_positions([starters[0].point + Vector3(0.8, 0.3, 0), starters[0].point + Vector3(-0.8, 0.3, 0)])
	await _frames(30)
	var key: StringName = host._spots[0]
	host._interact(0, false)
	await _frames(int(host.sim.drill_seconds() * 60) + 30)
	_check(guest.sim.deposit_left(key) == host.sim.deposit_left(key), "guest sees mined deposit")
	_check(not var_to_str(host._last_snapshot_state()).contains("world_deltas"), "deltas not in frame snapshot")
	host._set_positions([Vector3(200, 2, 150), Vector3(205, 2, 150)])
	var late := await _join_again(pair, 44362)
	_check(late.streamer.is_ready_at(late.pilots[0].position) and late.sim.world_deltas == host.sim.world_deltas, "late guest gets terrain and deltas far from base")
	host._vectors[1] = Vector2.ZERO
	host._set_positions([Vector3(200, 2, 150), Vector3(238, 2, 150)])
	host._vectors[0] = Vector2(-1, 0)
	await _frames(120)
	_check(host.pilots[0].position.distance_to(host.pilots[1].position) <= 40.05, "tether holds at 40 m")
```

`_last_snapshot_state()` es una función de prueba en `LunarGame` que devuelve el último estado enviado.

- [ ] **Step 2: Ejecutar y comprobar que falla.**
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Ejecutar `verify.ps1 -Godot $G`.** Esperado: verde, incluida la prueba de red de `lunar_suite`.
- [ ] **Step 5: Commit** `Sincronizar el mundo abierto en cooperativo con separación de 40 m`

---

### Task 9: Rendimiento, documentación y cierre del corte

**Files:**
- Modify: `context_core/state_registry.json` (`revision` 18, `progress`, `implementation` con el mundo abierto y `pending` actualizado).
- Modify: `context_core/project_graph.json`: nodos `open_world`, `chunk_generator`, `chunk_streamer`, `deposit_state`, `lunar_jump` y `follow_camera`, con aristas a `campaign_2026`, `lunar_mission` y `lunar_game`. Comprobar que no hay aristas a nodos inexistentes.
- Modify: `context_core/adversarial_rules.json`: reglas `LUN-OW-01` a `LUN-OW-05` (determinismo, relleno, reversión por aire, separación, sin caída en chunk no cargado).
- Modify: `context_core/architecture_tree.md` (revisión 18), `context_core/campana_lunar_vigente.md` (balance de viajes como parámetro de prototipo, igual que VAC-16), `context_core/changelog_audit.md` (versión de Godot y comprobaciones ejecutadas) y `README.md` (Saltar, mundo abierto, depósitos).
- Test: `tests/open_world_suite.gd`

- [ ] **Step 1: Escribir la prueba de presupuesto**

```gdscript
func _budget() -> void:
	_cases += 1
	var game := await _game_solo("mons_mouton_plateau")
	game._set_positions([Vector3(0, 1, 120), Vector3.ZERO])
	await _frames(240)
	_check(game.streamer.loaded_coords().size() <= 49, "never more than 49 chunks")
	var worst := 0.0
	game._vectors[0] = Vector2(0, -1)
	for i in range(600):
		var t := Time.get_ticks_usec()
		await get_tree().physics_frame
		worst = maxf(worst, (Time.get_ticks_usec() - t) / 1000.0)
	print("OPEN WORLD: worst physics frame %.1f ms while streaming" % worst)
	_check(worst < 33.0, "streaming stays under 33 ms per frame on desktop")
```

- [ ] **Step 2: Ejecutar.** Si falla, bajar `chunks_per_frame` o mover más trabajo al pool hasta que pase.
- [ ] **Step 3: Actualizar los documentos de context_core listados arriba.**
- [ ] **Step 4: Ejecutar `verify.ps1 -Godot $G` completo y exportar Windows x64** (`& $G --headless --path . --export-release "Windows Desktop" dist/Artemis-Ultima-Ventana.exe`). Lanzar el ejecutable y comprobar que sale con código 0.
- [ ] **Step 5: Registrar en `changelog_audit.md` las cifras reales** (casos y comprobaciones de cada suite y el peor frame).
- [ ] **Step 6: Commit** `Cerrar el corte del mundo abierto y actualizar context_core`

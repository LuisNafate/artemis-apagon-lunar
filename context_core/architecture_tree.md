# Arquitectura del juego

Godot 4.7.2 · GDScript · Compatibility · escritorio 1280 × 720 · UI en español.

```
project.godot
context_core/        Grafo, registro cuantitativo, reglas, arquitectura y auditoría
assets/
  sprites_25d/      Astronauta por dirección, estaciones, invernadero y accesorios
  tilemaps/         Superficie, plataforma y terreno lunar
  ui/               Iconos originales y fuentes con licencia
src/
  core/             EventBus, ResourceManager, AdversarialDirector
  modules/          SolarArray, LifeSupport, Greenhouse, EVA
  entities/         LunarMap, AstronautController, Station
  ui/               HUD del turno
  mission.tscn      Misión de entrenamiento
tests/              Regresión de simulación, integración y arranque
tools/              Fuente de arte reproducible
```

```
Mission (Node2D)
├── LunarMap (Node2D, terreno y navegación)
│   ├── WorldLabels (Node2D, etiquetas sobre el mundo)
│   └── Depth (Node2D con Y-sort)
│       ├── Soporte vital, Cultivo, Solar, Esclusa, Baliza
│       ├── Cajas
│       └── Astronaut (Node2D → Sprite2D)
└── Interface (CanvasLayer)
    └── HUD (Control)
```

El controlador de escena decide el alcance, el director valida costes y fases, y EventBus notifica cambios de simulación.

## Corte jugable

Iniciar turno → restablecer soporte vital → regar cultivo → responder a la caída de generación → preparar salida → calibrar baliza → volver a esclusa → mantener las reservas hasta el final. El jugador puede invertir el orden de mantenimiento y riego. La salida se habilita después de limpiar Solar y completar el cultivo. El diagnóstico muestra por qué un control está bloqueado. Ante un fallo, el usuario recibe la causa y puede reiniciar con el mismo escenario.

El tiempo se acelera a un minuto simulado por segundo real. La práctica de regolito es programada. El consumo por tripulante procede de NASA, mientras que las capacidades, tasas de equipos y umbrales del ejercicio se eligieron para una sesión de dos minutos. El módulo de agua representa un depósito agregado. El cultivo se modela como progreso con agua inicial y potencia, y no aporta O2.

## Dirección visual

Pixel art lunar, modular, cálido y legible. Resort Empire inspira la cabeza grande, el torso compacto y la marcha de cuatro direcciones. El casco blanco, el visor dorado y los acentos oxidados definen un astronauta original. Se excluyen replicación de sprites, gradientes sobre los personajes y ornamentación que tape rutas.

Proyección 2:1 con celdas nativas de 32 × 16 y presentación a 2×. Pivotes a nivel del suelo, sombreado arriba a la izquierda. Suelo indigo, bordes acero claro, balizas ámbar y cultivos menta. Interacción por ratón o teclado. Los datos se mantienen a la derecha y la acción contextual abajo para dejar libre la base.

| Elemento | Formato y escala | Variantes y aceptación |
| --- | --- | --- |
| Astronauta | Atlas PNG de 24 × 32 px por celda, pies en (12, 29) | Cuatro orientaciones, reposo y marcha de dos fases. Casco y visor legibles a 2×. Colisión de una celda lógica |
| Estaciones | PNG separados, máximo 132 × 105 px, pivote inferior | Cinco siluetas diferenciadas, nombre y estado visibles. Huella lógica registrada en LunarMap |
| Superficie | PNG de fondo y motivos 2:1 por celda | Celdas y corredores legibles, bordes transitables visibles |
| HUD | Iconos de 16 px, fuente sans y monoespaciada | Estado explícito en texto, cambios de color y forma. Cuerpo mínimo de 14 px a 1280 × 720 |

Referencia visual: https://www.kongregate.com/en/games/littlegiantworld/resort-empire
Documentación del motor: https://docs.godotengine.org/en/4.6/tutorials/editor/command_line_tutorial.html

## Estados de interfaz

| Fase | Acción disponible | Información visible |
| --- | --- | --- |
| Informe inicial | Iniciar turno | Duración, tripulantes y primer objetivo |
| Turno activo | Moverse y operar en alcance | Reservas, lista de misión y explicación de bloqueos |
| Salida exterior | Calibrar y volver a la esclusa | Oxígeno del traje, baliza y contorno transitable |
| Pausa | Reanudar o reiniciar | Última lectura de telemetría |
| Éxito o fallo | Preparar otro turno | Causa del resultado y tiempo transcurrido |

Los sprites PNG se pueden reproducir con tools/draw_assets.py. Son originales del proyecto. Las fuentes son externas y mantienen sus licencias OFL junto a los archivos TTF. La orientación objetivo es escritorio horizontal.

## Ampliación del hábitat · revisión 4

El sector suroeste ofrece suelo para construir. El menú elige un plano, el mapa previsualiza la huella y el director encarga la obra. ConstructionBay valida conexión, espacio y materiales antes de registrar la pieza. Las pasarelas cuentan como celdas transitables. Los módulos ocupan su huella durante la obra y aplican su mejora al activarse. El turno sigue corriendo mientras se construye.

La lectura funcional de Resort Empire se basa en el ciclo de comprar instalaciones y ampliar el área para habilitarlas. En Artemis se traduce a materiales, pasarelas conectadas y sistemas de soporte. La composición de interiores abiertos, mobiliario azul y bandejas verdes procede de la referencia visual del usuario. https://www.littlegiantworld.com/games/resort-empire/

La revisión estática del SWF está en [resort_empire_analysis.md](resort_empire_analysis.md). Distingue la validación de huella del cálculo de rutas y explica la adaptación de clic y arrastre para pasarelas.

## Recepción de tripulaciones · revisión 5

La práctica guiada conduce al jugador por soporte vital, cultivo, avería, montaje y admisión mediante acciones en el mapa. El turno de recepción añade dos llegadas, camas asignadas, consumos variables, recursos de salida y filtro degradado. CrewReception controla el estado de cada visita; CrewVisuals recorre las rutas animadas del mapa. El estilo mantiene siluetas pequeñas y legibles. Los visitantes usan una adaptación del arte que contiene el SWF adjunto.

## Rescate lunar · revisión 6

La primera propuesta de la revisión exploró un rescate con rover. Se conserva su evaluación y sus referencias en rescue_design.md.

La confirmación de la categoría redefine la revisión 6 como tablero de administración del puesto lunar. OutpostGame conecta tablero e interfaz con OutpostSim, que calcula el pronóstico y resuelve turnos. La academia se puede abrir desde src/mission.tscn.

## Apagón lunar · revisión 7

Nueva escena principal 3D con personaje cinemático, mundo físico, simulación y HUD separados. El tablero del puesto se puede abrir desde outpost/outpost.tscn. Véase field_design.md.

## Última ventana · revisión 8

El siguiente modo parte de un único nivel 3D compartido, Estación Cresta. Puesto Nobile y Estación Taurus-Littrow quedan como niveles candidatos. El arranque jugable se verifica en Apagón lunar.

```text
context_core/
  coop_tycoon_design.md         Estación Cresta, economía, controles y criterios de aceptación
  science_catalog.md            Fuentes, instrumentos y límites de las observaciones
  data/
    lunar_reference_v1.json     Muestras históricas que se pueden leer sin red
```

Jerarquía propuesta para el corte cooperativo.

```text
StationCresta (Node3D)
├── World (Node3D, hábitat, cresta, cantera, taller, huerto y plataforma)
├── Astronaut 1, Astronaut 2 (CharacterBody3D, bancos separados de entradas)
├── Mission (Node, estado compartido, recetas, amenazas, radio y lista de vuelo)
├── SharedCamera (Camera3D)
└── HUD (CanvasLayer, aire, carga eléctrica y estado de ascenso)
```

El corte previsto reutiliza elementos de locomoción de FieldPilot y el patrón de validación de ConstructionBay, sujetos a las pruebas de dos entradas. El estado de la misión resuelve conflictos y comunica el resultado a la vista. El catálogo histórico y los valores para jugar mantienen campos separados.

## Estación Cresta · revisión 9

El arranque abre `crest/crest.tscn`. CrestGame conecta dos FieldPilot con CrestWorld, CrestSim y CrestHUD. La Cámara3D ortográfica a tres cuartos encuadra la estación completa. Los personajes se desplazan sobre XZ y conservan el volumen de las mallas. Un jugador alterna el astronauta con Tab. Dos jugadores usan entradas simultáneas y comparten el inventario y el reloj. El refugio, la batería y las recetas viven en el modelo de misión, y el HUD accede a las muestras archivadas sin red.

Las escenas de Apagón lunar, Academia y Tablero se mantienen editables para recuperar recursos y ejecutar sus regresiones. La exportación de Estación Cresta excluye esas escenas y las suites. Retiene la geometría auxiliar y FieldPilot, que sí utiliza la demo.

## Bases lunares · revisión 10

CrestGame abre el selector de astronautas y el mapa de bases. CrestIntro reproduce una secuencia de aterrizaje, montaje y mensaje de Tierra sobre CrestWorld. Al terminar restaura la cámara ortográfica y pasa al tutorial. La escena se puede omitir desde el botón o con Esc. CrestCampaign lee noches, avisos y reabastecimientos de state_registry.json. El mismo conjunto de locomoción y estaciones interpreta Cresta, Nobile y Taurus-Littrow. El núcleo de las estaciones mantiene la misma distribución.

Los tres objetos Kenney se importan desde assets/props_luna/kenney. El registro de modelos identifica su procedencia, licencia y uso. El protocolo de observación de jugadores nuevos está en tools/skills/probar-juego-con-ninos/SKILL.md.

## Producción de modelos · revisión 11

[Catálogo de modelado lunar](catalogo_modelado_lunar.md) especifica el kit compartido, las variantes de Cresta, Nobile y Taurus-Littrow, los accesorios originales y la reutilización de los tres GLB de Kenney. Las medidas del mundo y sus puntos de interacción proceden de CrestWorld. La cápsula se toma de FieldPilot y la cámara de CrestGame. Los assets nuevos se integrarán después de la prueba de pasarela, refugio y caja de hielo.

## Rediseño de mapas del polo sur · revisión 12

[Catálogo de mapas](catalogo_mapas_polo_sur.md) especifica nueve escenarios inspirados en una lista histórica de regiones candidatas de aterrizaje. Los campamentos del juego usan un kit común de infraestructura. Cada composición tendrá terreno, anclajes a distintas cotas e información de luz y radio propia. El registro conserva estas propuestas bajo `coop_tycoon.map_redesign`. La campaña jugable actual sigue usando la configuración de Estación Cresta, Puesto Nobile y Base Taurus-Littrow.

## Recursos NASA · revisión 13

CrestWorld instancia la adaptación de Apolo durante el aterrizaje y muestra el relieve LOLA en Puesto Nobile. La vista científica de CrestHUD muestra LRO en un viewport con World3D propio. Los accesorios de radio se colocan desde un origen de servicio local que compensa el desplazamiento interno de los GLB de Kenney. Las notas de procedencia y los comandos de regeneración están en [assets/props_luna/nasa/procedencia.md](../assets/props_luna/nasa/procedencia.md).

## Campaña lunar táctil · revisión 14

[El PDF de reglas](Artemis_Reglas_y_mecanicas.pdf) establece la versión vigente. El registro `campaign_2026` conserva sus datos. [La tabla de trazabilidad](campana_lunar_vigente.md) distingue cifras vigentes y parámetros del prototipo. El [catálogo de producción](catalogo_produccion_artemis.md) contiene las fichas de arte actualizadas y el tratamiento de los cráteres.

```text
lunar/lunar.tscn
└── Artemis (LunarGame)
    ├── CrestWorld (estaciones, señal de refugio y terreno)
    │   ├── CrateresLaterales (seis LunarCrater fuera de la circulación)
    │   ├── AstroCat, Apolo y maqueta LRO
    │   └── relieve LOLA donde corresponde
    ├── CrestPilot ×2 (FieldPilot, malla y traje de gato articulado)
    ├── Cámara ortográfica a tres cuartos
    └── LunarInterface (HUD, menú, joystick y archivo)

LunarGame
├── LunarMission (reloj, supervivencia, producción y regreso)
├── LunarProfile (ranuras, perfil y recibos en user://)
├── LunarRoutes (AStarGrid2D derivado de colisiones)
└── ENetMultiplayerPeer (autoridad del anfitrión)
```

La escena principal es `lunar/lunar.tscn`. La escena de Cresta permanece disponible en el editor para reproducir e inspeccionar la revisión anterior. La campaña nueva reutiliza sus modelos y estaciones. `tests/lunar_suite.tscn` verifica el modelo y una sesión de dos pares ENet locales.

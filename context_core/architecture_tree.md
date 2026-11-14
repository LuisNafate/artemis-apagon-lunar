# Arquitectura · revisión 3

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

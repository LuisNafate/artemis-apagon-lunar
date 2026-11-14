# Auditoría

## Revisión 1 · Inicialización y diseño

- Carpeta inicial vacía. Node y Git comprobados. Python 3.13.14 funciona por terminal. Node 26.13.0 y npm 11.20.0 disponibles desde la instalación de Node. Godot 4.7.2 identificado mediante WinGet y ejecutado por ruta completa.
- Instalados gdtoolkit 4.5.0 y los servidores filesystem, memory y sequential-thinking. Codex guardó sus configuraciones. Búsqueda web disponible para documentación. Validación de conexiones pendiente.
- Se registró el plan para arranque, victoria, fallo, reinicio y regresiones adversarias antes de crear escenas o scripts.

## Revisión 2 · Corte jugable

- Verificado el protocolo MCP por stdio. Filesystem leyó el grafo, Memory registró nodos y aristas auxiliares y Sequential Thinking respondió a la validación previa al código. La búsqueda web aportó referencias de NASA y Godot.
- Implementados autoloads, mapa isométrico, HUD, animación de astronauta, módulos de recursos y recorrido de entrenamiento.
- La primera regresión reveló una llamada inválida al verificar opacidad y una diferencia entre el cursor y la posición del evento. Se corrigieron con un búfer de píxeles y la coordenada del evento. La suite pasó con 10 casos y 1809 comprobaciones.
- La primera captura reveló proximidad entre reloj y pausa, y un salto de línea en el informe inicial. Se ajustaron el espacio y la redacción.

## Revisión 3 · Validación adversaria y visual

- Los balances aplican flujos netos antes de limitar las reservas. Se añadió regresión para el caso en que el agua recuperada no alcanza a cubrir el consumo y para transacciones con claves o flujos inválidos.
- Se comprobaron en el motor las vistas de informe inicial, caída de generación y salida exterior a 1280 × 720. La salida muestra su zona transitable y la lectura del traje.
- Se verificó la importación, el arranque principal, el flujo de éxito y los fallos por tiempo, reservas o traje en Godot 4.7.2. gdformat y gdlint validaron los 13 scripts con gdtoolkit 4.5.0.
- Resultado final: 10 casos y 1844 comprobaciones sin fallos en headless. Con renderizado a 1280 × 720 se obtuvieron 1847 comprobaciones sin fallos, incluidas tres capturas. La ventana de 1152 × 648 superó los mismos 10 casos con renderizado. La regresión inicia el turno mediante un clic de interfaz y recorre las cinco estaciones.

## Revisión 4 · Ampliación modular

- Registrado el diseño de colocación, conectividad, presupuesto, obras y efectos de cada módulo antes de modificar la simulación.

- FFDec inspeccionó 496 archivos ActionScript exportados del SWF adjunto. Confirmó previsualización según huella, compra, dibujo de teselas por arrastre, recálculo de rutas y transición de obra a servicio.
- Integrados catálogo, presupuesto, plano sobre el mapa, pasarelas transitables y tres módulos con efectos en la simulación. Completar una instalación es un objetivo del turno. El hábitat y el cultivo usan arte pixelado original con interiores abiertos.
- Se verificaron colocación por clic y arrastre, cancelación, límites de huella, conexión, coste, ocupación, pausa, reinicio, enrutamiento y finalización de obras en distinto orden. La importación y el arranque de Godot 4.7.2 pasaron. gdformat y gdlint validaron los 14 scripts.
- Resultado: 13 casos y 2460 comprobaciones sin fallos en headless. Con renderizado a 1280 × 720 se obtuvieron 2464 comprobaciones sin fallos, incluidas cuatro capturas. La ventana de 1152 × 648 pasó los 13 casos con renderizado.

## Revisión 5 · Academia y tripulaciones

- Diseñadas la práctica sin presión y la misión de recepción con demanda adicional, camas, ventanas y avería de filtro. La práctica de sistemas se inspira en la sección Astronaut Formal Training del documento NASA FS-2011-11-057-JSC, p. 3.

- Incorporados el muelle transitable, la admisión por camas y reservas, los recorridos de visitantes hasta el interior y el regreso al muelle. Las tripulaciones aumentan el consumo real durante la estancia y dejan suministros al partir.
- Se adaptaron cuatro fotogramas de Visitor1 del SWF a dos variantes lunares. La receta y la procedencia están en resort_empire_analysis.md.
- La práctica de seis pasos usa los controles reales. El diagnóstico bloquea el recambio hasta identificar la extracción de CO2 y el recambio consume materiales. La misión extiende el turno a 150 minutos simulados y exige atender ambas tripulaciones.
- Godot 4.7.2 importó y arrancó sin errores. gdformat y gdlint validaron 17 scripts. Pasaron 16 casos con 3395 comprobaciones headless y 3402 con renderizado a 1280 × 720, incluidas siete capturas. La ventana de 1152 × 648 completó la suite con renderizado. Se revisaron los estados de informe, práctica, llegada y estancia.

## Revisión 6 · Rescate lunar

- La prueba de usuario señaló un ciclo de operación sin decisiones suficientes. Se eligió un rover de rescate por control inmediato, riesgo de ruta y repetición breve. Registrados diseño, referencias y casos adversarios antes del código.

- Tras confirmar el resumen del reto, se reformuló el prototipo como administración táctica de energía, alimento, aire, agua y protección. Se añadieron dos escenarios de ocho turnos.

- La proyección y la resolución usan la misma función. Un modelo independiente de Python confirmó las rutas de reparación y derivación en Tormenta, y dos reparaciones en Cresta. La suite de Godot reprodujo ambas rutas, bloqueos, derrota, reinicio y victoria desde la interfaz.
- Se verificó que restablecer conectividad no garantiza potencia. Se comprobó el umbral de radiación, la falta de agua para cosechar, el límite de piezas y los estados terminales.
- Godot 4.7.2 arrancó sin errores. Pasaron 7 casos y 75 comprobaciones para el puesto lunar y 16 casos con 3413 comprobaciones para la academia. Verificado con renderizado en 1280 × 720 y 1152 × 648.
- Se incorporó retroalimentación sonora de control, cosecha y resultado, además de una meta de oro por remanente y exposición baja. La rejugabilidad percibida se comprobará con jugadores.

## Revisión 7 · Apagón lunar

- La prueba del tablero mostró falta de claridad y de acción. Se diseñó una misión de recuperación de la red y transporte de cultivos en tercera persona, con tutorial integrado y terreno que cambia la ruta.

- Se implementó la partida 3D con tutorial de movimiento, salto y entrega, rutas alrededor de la grieta, cápsulas, recarga solar, alertas y refugio. Geometría, audio y texturas de personajes de procedencia documentada.
- La suite reprodujo una caída antes de activar la red, recuperación de la batería, salto con turbo, rutas este y oeste, cultivo y resultado. Validó también la pérdida por tiempo y exposición, y el bloqueo de crecimiento durante el apagón.
- Godot 4.7.2 importó y arrancó sin errores. Los 27 scripts pasaron formato y lint. La misión 3D superó 35 comprobaciones headless. Academia y tablero superaron sus 23 casos de regresión.
- Para preparar el repositorio, el atlas de academia se regeneró a partir del astronauta original de Artemis. La adaptación anterior del SWF quedó archivada en el equipo.

- La misión completa también superó 38 comprobaciones con renderizado a 1280 × 720. Se revisaron la apertura, la restauración de la red y el resultado.

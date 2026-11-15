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

## Revisión 8 · Diseño cooperativo de Estación Cresta

- Se verificó el texto y la pestaña de recursos de la ficha global de Space Apps 2026 y se contrastaron con la ficha de Athlone. El grafo enlaza soporte vital, blindaje, energía, alimentos y demora de comunicación con mecánicas y zonas de la demo.
- Aplicadas las skills de Design Game Studio 0.1.2 para diseño, sistemas, niveles, mejora del juego y diagnóstico. La reproducción inicial del proyecto en Godot 4.7.2 completó los tres grupos de regresión. El alcance del corte fue diseño y datos para una demo 3D local de dos jugadores. Estación Cresta es la demo. Nobile y Taurus-Littrow son candidatos posteriores.
- Verificados en el grafo 117 nodos, 191 aristas, 5 requisitos con sistemas y zonas, y 10 reglas adversarias enlazadas a criterios de aceptación. Se comprobó la integridad de los nodos y aristas previos y los parámetros que leen las tres simulaciones existentes.
- Contrastadas las muestras locales de DONKI, RadLab, NeoWs y TLE con las respuestas originales. Se validaron ambos dígitos de control TLE y el período derivado, el cálculo de demora Tierra–Luna y el ejemplo de oxígeno para dos personas. Quedan seis registros científicos disponibles sin conexión.
- `tests/verify.ps1` pasó en Godot 4.7.2 con importación, arranque principal, formato y lint de 27 scripts. Regresiones de academia 16/3618, tablero 7/75 y misión 3D 3/35, sin fallos. Los cocientes indican casos y comprobaciones. Queda pendiente implementar y probar el cooperativo, sus dos rutas de victoria y el despegue con una pareja.

## Revisión 9 · Demo 2.5D individual y cooperativa

- Estación Cresta es la escena de inicio. Se implementaron tutorial, inventario con cajas físicas, mejoras de taladro y batería, soporte vital, cultivo, planta de propelente, relé con retardo, embarque y despegue. Se jugaron ambos roles con los mismos controles en un teclado o alternando con Tab en individual. Las alertas aparecen en texto, con sonido y cambios de iluminación.
- La prueba de recorrido detectó que el trayecto directo puede chocar con la protección del cohete o el mobiliario del refugio. El recorrido se verificó por las pasarelas y la entrada central. La simulación permite repartir la espera entre producción y refugio y se ajustó la reposición de aire para usar agua al necesitarla.
- Godot 4.7.2. `tests/verify.ps1` pasó importación, arranque, gdformat y gdlint de 32 scripts. Academia 16 casos y 3657 comprobaciones, tablero 7 y 75, Apagón lunar 3 y 35, Estación Cresta 9 y 239. La nueva suite completó dos partidas con eventos de teclado, movimiento y despegue. También probó las rutas de taladro y batería a nivel de simulación.
- Con OpenGL Compatibility, AMD Radeon 760M, 1280 × 720 y `--crest-capture` pasaron 8 casos y 55 comprobaciones, incluidos menú, entrega y cuenta regresiva animada. Las dos partidas completas usan la suite headless. Las capturas se guardaron en el directorio de usuario de Godot. Pendiente observar una partida de jugadores nuevos.
- La exportación Windows x64 integra el PCK y los seis registros históricos. Se lanzó el ejecutable exportado, reportó Godot 4.7.2 y OpenGL y salió con código 0 sin errores. El ZIP incluye avisos del motor y de las fuentes. Se excluyen los prototipos históricos y las pruebas del paquete. Los archivos fuente de los prototipos conservan sus regresiones.

## Revisión 10 · Origen de las bases y calendario lunar

- Estación Cresta, Puesto Nobile y Base Taurus-Littrow son bases seleccionables. Comparten las estaciones y el mapa de circulación 2.5D. Cada base aplica suelo, informe, noches, eventos y ventanas propias. Los ciclos usan tiempo de juego.
- La animación dura 14,5 s. El transporte desciende, el refugio y los paneles se montan, y llega un mensaje ajustado a la base elegida. La entrada en juego restaura cámara y montaje y deja el reloj en cero. Se probaron el final automático y la omisión con Esc.
- El corte de enlace de Nobile retiene un mensaje en tránsito. Taurus-Littrow tiene averías solares durante el día. Las tres bases tienen episodios solares y suministros programados. El premio se cobra una vez y espera si no cabe en los depósitos.
- Se integraron tres GLB de Kenney CC0 publicados en Poly Pizza. El registro identifica modelo, autor, página y adaptación. Quaternius Ultimate Space Kit queda registrado como fuente compatible para futuras piezas. Los modelos importados se verificaron en Godot.
- Godot 4.7.2. Formato y lint de 34 scripts, importación, arranque y cuatro regresiones correctas. Academia 16 casos y 3682 comprobaciones, Tablero 7 y 75, Apagón lunar 3 y 35, Cresta 10 y 267. Las partidas completas de Cresta usaron teclado simulado en ambos modos. Para Nobile y Taurus-Littrow se verificaron los eventos propios y el lanzamiento con la nave abastecida. La revisión renderizada a 1280 × 720 pasó 9 casos y 83 comprobaciones e incluyó llegada, tutorial y despegue.
- Skill probar-juego-con-ninos instalada y validada con quick_validate.py. La evaluación experta identificó la necesidad de explicar propelente y distinguir falta de señal de pérdida de luz. Se ajustaron ambos textos y se repitió la revisión. Pendiente una primera partida observada con jugadores de 12 años.
- El ejecutable Windows exportado abrió con código 0. El archivo ZIP incluye el juego, licencias y registro de modelos.

## Revisión 11 · Catálogo de modelado lunar

- Especificadas 27 fichas de producción con orden de trabajo, materiales, medidas, pivotes, estados animables y presupuestos iniciales. Se verificaron los 14 anclajes del documento contra CrestWorld, la cámara contra CrestGame, la cápsula contra FieldPilot, los enlaces locales y los tres archivos GLB reutilizados.
- Godot 4.7.2. tests/verify.ps1 validó formato y lint de 34 scripts, importación y arranque. Pasaron las regresiones de Academia 16/3693, Tablero 7/75, Apagón lunar 3/35 y Estación Cresta 10/267. Los cocientes indican casos y comprobaciones. Este corte documenta la producción. La verificación visual de los modelos nuevos corresponde a su integración.

## Revisión 12 · Catálogo de las nueve regiones

- Registrados el orden y la dificultad de la propuesta, 18 fichas de kit común y 27 regionales. Se verificaron los nueve nombres con el anuncio NASA 24-136 de 2024 y los criterios con NTRS 20250011660. Se documentó el estado de Artemis III y Artemis IV según la actualización de noviembre de 2026.
- Comprobados los nombres y las dificultades entre el catálogo y el registro, los enlaces locales y la integridad del grafo. Los nuevos mapas están especificados. La adquisición de recortes de elevación, el modelado y la integración quedan como trabajo de producción.
- Godot 4.7.2. tests/verify.ps1 pasó formato y lint de 34 scripts, importación, arranque y las cuatro regresiones. Academia 16 casos y 3738 comprobaciones, Tablero 7 y 75, Apagón lunar 3 y 35, Estación Cresta 10 y 267.

## Revisión 13 · Arte a partir de recursos de NASA

- Descargados dos GLB desde NASA 3D Resources y el modelo de elevación LOLA Site06 desde PGDA. Blender 5.2.2 redujo Apolo de 97 588 a 8 472 triángulos y el orbitador LRO de 8 142 a 1 701. El horizonte de Nobile usa 1 536 triángulos a partir de un recorte comprobado en el GeoTIFF de 5 m/píxel. Se registraron autoría, URLs, huellas, medidas y comandos.
- Se revisó en el motor el aterrizaje, la miniatura giratoria de LRO y el paisaje de Nobile. Durante la revisión se encontró que los GLB de Kenney traían el plato y el receptor desplazados. Ambos quedaron alineados con el punto de servicio de la radio.
- Godot 4.7.2. Pasaron formato y lint de 34 scripts, importación, arranque y las cuatro regresiones. Academia 16 casos y 3767 comprobaciones, Tablero 7 y 75, Apagón lunar 3 y 35, Estación Cresta 10 y 277. Con gráficos a 1280 × 720 y 1152 × 648 pasaron 9 casos y 93 comprobaciones en cada resolución.
- Se verificó la exportación Windows x64 con los tres GLB y los datos sin conexión. El ejecutable abrió sin errores. El ZIP incluye créditos y procedencia. Los nueve mapas nuevos siguen en producción. El recorte de Nobile se usa como paisaje en el mapa actual.

## Limpieza e importación desde cero

- Se apartaron 102 archivos de la caché de Godot y dos bytecodes de Python, unos 6,2 MB en total. Se comprobó que ambas rutas contienen archivos generados fuera de Git. La compilación y los recursos de producción siguen disponibles.
- Godot 4.7.2 importó desde una caché vacía y pasó formato y lint de 34 scripts, arranque principal y cuatro regresiones. Academia 16 casos y 3767 comprobaciones, Tablero 7 y 75, Apagón lunar 3 y 35, Estación Cresta 10 y 277. Se comprobó además que la ventana del ejecutable de Windows seguía abierta y respondía.

## Revisión 14 · Campaña lunar del 14 de noviembre y cráteres laterales

- Adoptado el PDF entregado como fuente de reglas vigente. Se comprobó su SHA-256 y se actualizó el grafo a 182 nodos y 312 aristas sin rutas ni extremos inexistentes. Se elaboró el catálogo de producción con las nueve regiones y la ficha de cráteres.
- Cambiada la escena principal a la campaña táctil para dos dispositivos con ENet. Se verificaron el tutorial cooperativo, llegada al amanecer, reinicio de la simulación por retirada, entrega exclusiva, desconexión, reconexión, recibos sin duplicados y guardado del ciclo. Las nueve regiones tienen dificultad y economía propias y comparten el kit jugable durante la producción de sus terrenos.
- Se recuperaron los dos pilotos felinos y se incorporó AstroCat con saludo y reposo. Apolo, LRO y LOLA conservan su procedencia. Vista de Mons Mouton Plateau con cráteres de 99 triángulos, pared interior sombreada y rutas intactas. Se reemplazaron 185 motas sueltas por una instancia de MultiMesh.
- Godot 4.7.2. Pasó `tests/verify.ps1` con formato y lint de 43 scripts, importación, arranque y cinco suites. Academia 16 casos y 3844 comprobaciones, Tablero 7 y 75, Apagón lunar 3 y 35, Cresta 10 y 285, Campaña 6 y 242. La prueba gráfica de Campaña pasó las mismas 242 comprobaciones con OpenGL Compatibility en AMD Radeon 760M y captura de 1152 × 648 en `dist/mons-mouton-crateres.png`.
- Exportación Windows x64 verificada, con los modelos de los gatos y NASA dentro del PCK. El ejecutable exportado arrancó con OpenGL y salió con código 0 en la comprobación. Se abrió la ventana de la versión actual y respondió. El preset Android incorpora Internet y ARM64. Faltan el SDK y las plantillas Android en el equipo, una prueba en hardware móvil y el rendimiento objetivo de 30 fps.
- El juego usa conexión directa, sin repetidor, y perfiles locales. Quedan pendientes los mapas regionales propios, el efecto de la mejora solar, el efecto de la pausa en red, la exposición y las funciones sin parámetros del PDF. El balance de la batería sigue los costos explícitos mientras se aclara REC-E7. La viabilidad fuera de una red accesible y la comprensión por jugadores de 7 a 12 años quedan por probar.

## Revisión 15 · Juego individual sin conexión

- Resuelto VAC-11 por indicación del usuario. El menú da acceso a un astronauta sin conexión o a dos en cooperativo. En individual se practica con una sola muestra, se puede pausar y se ocupa un asiento para despegar. El 100 % de las monedas del día se acredita en el amanecer.
- Se añadieron guardados individuales por base y se conservó el esquema cooperativo existente. Los dos modos comparten saldo, desbloqueos y recibos. El grafo quedó con 183 nodos y 320 aristas verificadas. El PDF original conserva su huella; la documentación vigente registra la decisión sobre modo individual.
- En Godot 4.7.2, `tests/verify.ps1` aprobó formato y lint de 43 scripts, importación, arranque y las cinco suites. Academia 16 casos y 3853 comprobaciones, Tablero 7 y 75, Apagón lunar 3 y 35, Cresta 10 y 285, Campaña 7 y 261. La suite verificó entrada desde el botón individual, ausencia de par de red, práctica, pausa, carga, radio, despegue, reanudación y reinicio aislado. La prueba cooperativa anterior volvió a pasar.
- La suite renderizada repitió los 7 casos y 261 comprobaciones a 1152 × 648 con OpenGL Compatibility. La captura figura en `dist/artemis-modo-individual.png`. La exportación Windows x64 arrancó y salió con código 0. La ventana anterior seguía abierta; se entregó el nuevo ejecutable como `dist/Artemis-Ultima-Ventana-Individual.exe` y el ZIP habitual se actualizó.

## Revisión 16 · Terreno, horizonte y trayecto de regreso

- Se auditó la base compartida en los 14 puntos de operación y ambos inicios. Se corrigieron intersecciones de profundidad, altura visual de piso, volúmenes de máquinas y el alcance de navegación con una cápsula de 0,38 m. Las 54 envolventes de cráteres de las nueve bases quedan fuera del área transitable. El mayor trayecto calculado al refugio fue 14,95 m y el piloto recorrió la ruta del hielo a zona segura en 2,25 s simulados. Los resultados están en `auditoria_terreno_campana.md`.
- Cámara ortográfica de 34°, suelo con borde irregular y perfiles de horizonte. La foto AS17-148-22727 se integra al cielo. La portada usa movimiento de cámara sobre el hábitat. La carga muestra etapas de preparación y el HUD usa fichas de recursos y tarjetas de misión. Se capturaron portada, carga, superficie y acoplamiento.
- Se separó Apolo en descenso y ascenso a partir del GLB optimizado. La cuenta regresiva inicia una secuencia de 17 s con ascenso, acoplamiento, viaje y entrada. La etapa de descenso permanece en la Luna. El bono y el modo libre aparecen tras volver. El grafo tiene 191 nodos y 336 aristas.
- Godot 4.7.2. `tests/verify.ps1` pasó formato y lint de 45 scripts, importación, arranque y cinco suites. Academia 16 casos y 3884 comprobaciones, Tablero 7 y 75, Apagón lunar 3 y 35, Cresta 10 y 285, Campaña 8 y 419. La suite de campaña pasó también renderizada a 1152 × 648 y 1280 × 720 con 419 comprobaciones en cada resolución.
- Se verificó la exportación Windows x64 con las dos etapas y la fotografía en el paquete. Arrancó y salió con código 0. El terreno compartido y los perfiles visuales se verificaron en el motor. Geometría regional propia, validación móvil y simulación de efemérides siguen fuera de la revisión.

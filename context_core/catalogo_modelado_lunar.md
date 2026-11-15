

> Para el rediseño de nueve regiones usa el [catálogo de mapas del polo sur lunar](catalogo_mapas_polo_sur.md). Este documento conserva las fichas del kit compartido y las referencias de tamaño del prototipo.
# Catálogo de modelado para Artemis · Última ventana

**Objetivo.** Dar volumen y personalidad al entorno 2.5D. Este catálogo cubre el terreno, las estaciones, los objetos que se transportan, los astronautas y los elementos visibles en la introducción. Las tres bases usan el mismo kit de construcción. Cresta, Nobile y Taurus-Littrow se distinguen mediante el relieve, la iluminación y unos pocos accesorios de fondo.

**Empieza con tres prototipos.** Modela un tramo de pasarela, el refugio en corte y una caja de hielo. Colócalos juntos con los dos astronautas actuales en Godot. Esa prueba fija escala, bordes, paleta y visibilidad antes de modelar el resto. Después termina P1 para tener jugable el nuevo entorno, P2 para sustituir las piezas restantes y P3 para diferenciar las bases y vestir la introducción.

## Especificación común

| Tema | Cómo entregarlo |
| --- | --- |
| Estilo | 3D estilizado de aspecto amable. Volúmenes gruesos, esquinas suavizadas, detalles grandes y paneles legibles al alejar la cámara. Usa piezas de la misma familia, con base oscura, carcasa clara y un acento funcional. |
| Escala y ejes | Escena métrica en Blender, **1 unidad de juego ≈ 1 m de modelado**. Las medidas usan **ancho × alto × fondo**, equivalentes a X × Y × Z en Godot. En Blender Z es arriba y el exportador hace la conversión. Verifica en Godot que el suelo quede en XZ, Y apunte arriba y el frente de servicio apunte a **+Z local**. El astronauta mira hacia **−Z local**. |
| Origen | Pivote de cada módulo en el centro de su planta a nivel del suelo. Excepciones descritas en cada ficha, como bisagras, cultivos y carga. Coloca los orígenes de las piezas móviles en su eje real y verifica escalas aplicadas en la pose de reposo. |
| Cámara de revisión | Ortográfica a tres cuartos. Tamaño **19.9**, posición **(7.8, 24.5, 22.8)** y objetivo **(0.1, 0, 0.25)**. Evalúa en **1280 × 720** y **1152 × 648**, con un astronauta delante y otro detrás del objeto. |
| Paleta | Carcasa `#E4E8F3`, estructura `#273345`, pasarela `#4D5970`. Cian `#82DDFF` para agua, hielo y refugio. Ámbar `#FFBC76` para energía y cohete. Verde `#ACD891` para cultivo y ayuda. Violeta `#C4ACF7` para radio y distintivos del mineral. Refuerza cada tipo con forma o pictograma. |
| Materiales | Usa materiales mates sencillos. Gris claro para carcasa, gris profundo para base y zonas de apoyo, y un material de acento o luz separado. Como meta, uno o dos materiales por pieza repetida y hasta tres en refugio o cohete. Usa visores opacos de azul oscuro con reflejos planos. Emisión puntual en luces y pantallas. |
| Geometría | Presupuestos orientativos por ficha en **triángulos** tras exportar. Bisel visible en las aristas grandes y normales limpias. Si una pieza necesita más detalle, justifícalo con una captura desde la cámara de juego. |
| UV y texturas | Una paleta o atlas compartido de **512 × 512** si se necesita textura. **1024 × 1024** como máximo inicial para astronauta o cohete individual. El relieve puede usar textura repetible. Revisa costuras, bandas, repetición y lectura de bordes. |
| Archivos | Entrega `nombre.blend` editable y `nombre.glb` para Godot. Guarda archivos nuevos de producción bajo `assets/props_luna/originales/` por familia y el original editable en tu carpeta de trabajo. Para cada set adjunta una vista frontal, lateral, superior y una captura a tres cuartos. Anota autor, origen, licencia y cambios. |
| Colisiones | La escena actual usa formas simples en código. Exporta mallas y orígenes, y en Blender conserva una guía separada de la huella. Entrega la guía como objeto de referencia fuera de la selección de exportación. Los anclajes propuestos sirven para integrar el arte. Godot seguirá haciendo el manejo de energía, radio, cargas, refugio y lanzamiento. [Importar glTF/GLB](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html) · [Colisiones al importar](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/node_type_customization.html) |

### Medidas que condicionan el mapa

- **Astronauta.** El controlador usa una cápsula de **1.55 m de alto** y **0.32 m de radio**. Usa **1.65 m** como objetivo visual, medido de las suelas al casco.
- **Refugio.** La zona que protege al jugador mide **5.80 × 5.75 m** en planta, con centro en **(0, 0, 4.425)**. Conserva la entrada central. Los laterales y el frente deben dejar ver a los dos astronautas y a la consola desde arriba.
- **Pasarelas.** Los corredores actuales van de **1.70 a 2.30 m** de ancho. El espesor visual de referencia es **0.06 m**. Las piezas a medida conservan el ancho libre de cada ruta del mapa.
- **Interacción.** El marcador de estación tiene **1.37 m** de diámetro. Mantén su centro a nivel del suelo y despeja la zona de aproximación delantera. El radio actual de uso es **1.63 m**, y **2.10 m** en la mesa del tutorial. Es un alcance de juego, no el tamaño del objeto.
- **Plataforma.** El centro físico del cohete está en **(11.1, 0, -2.65)**. El punto donde se entrega y se embarca está delante, en **(11.2, 0, 0.7)**. La plataforma visual de referencia mide **5.30 m de diámetro**. Deja libre el paso entre la plataforma, la radio y el refugio.
- **Terreno.** La superficie visual actual mide **44 × 29 m** y el suelo físico es de **32 × 18 m**. Diseña la variación de relieve en bordes, fondo y zonas de roca, y deja a **Y = 0** los recorridos probados.

## P1 · Núcleo del entorno

### 01. Pasarelas y uniones · `pasarela_kit.glb`

- **Modelar.** Tramo de **1.25 m de largo**, encuentro en L, cruce en T, cruce de cuatro vías, remate y placa de transición a estación. Usa **1.70, 2.00 y 2.30 m** de anchos de referencia. Duplica mediante escala controlada si la trama y el bisel mantienen proporción.
- **Forma y material.** Placa gris con costuras anchas y guías laterales a ras. Marca la ruta al refugio con línea continua y el trayecto expuesto con segmentos.
- **Pivote y colisión.** Centro inferior. Crea conectores en el centro de cada extremo. Los empalmes quedan planos sobre el suelo existente. **80–220 tris por pieza**.
- **Lectura.** En la vista superior debe quedar clara la conexión entre cantera, refugio, taller y cohete.

### 02. Refugio de soporte vital · `refugio_corte.glb`

- **Modelar.** Kit de **5.80 × 1.60–2.15 × 5.75 m**. Incluye piso, dos postes de entrada, pared trasera recortada, dos muros laterales bajos y costillas de techo visibles en los bordes. Mobiliario interior desmontable según ficha 03. Mantén **al menos 2.0 m libres en la entrada central**.
- **Forma y material.** Perfil redondeado y robusto, placas claras y marco cian. Marca el piso con una cruz o escudo y delimita visualmente la zona protegida. El techo completo puede ser una pieza adicional de la cinemática.
- **Pivote y partes.** Centro inferior. Separa `base`, `shell`, `roof_intro` y `trim_emission`. Anclaje interior `life_console` hacia el frente de acción. Colisión en soportes y bancadas, con corredor central abierto. **1 200–2 500 tris para la estructura**.
- **Estados.** Plegado, montaje, desplegado y recuperación de aire. Durante una alerta, el borde y el símbolo siguen indicando zona segura aunque la energía se agote.

### 03. Consola de aire e interior · `soporte_vital.glb`

- **Modelar.** Consola de **0.90 × 0.85 × 0.55 m**, dos bancadas de **0.85 × 0.69 × 1.50 m** y cartucho de filtro visible de hasta **0.35 × 0.35 × 0.40 m**. Pantalla inclinada, toma de manguera y dispensador de raciones integrados en el mismo conjunto.
- **Forma y material.** Carcasa clara, pantalla azul legible y símbolos de pulmón o aire y de comida en caras distintas. Pantalla y cartucho en nodos propios.
- **Pivote y colisión.** Base de cada pieza. Bancadas independientes para conservar el paso. Deja libre el anillo de interacción. **400–900 tris para consola y hasta 220 por bancada**.
- **Estados.** Disponible, recuperando aire y sin energía o agua. Usa una luz fija al operar y un pictograma apagado o cruzado al perder servicio.

### 04. Cantera de hielo y mineral · `cantera_kit.glb`

- **Modelar.** Dos grupos distintos encajados en plataformas de **2.90 × 2.60 m** en planta. Usa grupos de tres a cinco piezas de **0.30–0.85 m** de alto. El hielo se representa con prismas alargados y caras facetadas. El mineral, con bloques bajos, anchos y vetas visibles. Añade una base de corte de roca detrás de cada grupo.
- **Forma y material.** Hielo azul pálido con puntas. Mineral ocre con vetas y marca violeta que se repite en su caja. Rocas neutras del suelo con menor contraste que el recurso.
- **Pivote y colisión.** Raíz al suelo y eje de extracción marcado en un nodo `extract`. Los cristales se sitúan detrás del punto de acción. Conserva el acceso desde el corredor. **250–650 tris por grupo**.
- **Estados.** Espera y extracción. Se permite una animación breve de vibración o emisión pequeña. El depósito permanece disponible para viajes posteriores.

### 05. Cajas portátiles · `carga_kit.glb`

- **Modelar.** Base compartida de **0.53 × 0.48 × 0.49 m**, con asa grande, esquinas reforzadas y cinco variantes: **muestra** con sello circular, **hielo** con cristal triangular, **mineral** con veta cuadrada, **propelente** con cartucho cilíndrico y anillo, **ración** con bandeja y hoja. Distingue contenido en relieve desde arriba.
- **Pivote y colisión.** Centro del volumen, compatible con la mano. Usa un anclaje `grip` común. En el suelo, el centro se coloca hoy a **0.29 m** de altura. Cajas con recogida lógica y sin collider importado. **120–350 tris por variante**.
- **Estados.** En el suelo, en mano, en tránsito entre jugadores y entregada. El código retira la carga. Una animación de tapa es opcional para introducción.

### 06. Refinadora de agua · `refinadora.glb`

- **Modelar.** Equipo trasero de **2.35 × 1.36 × 0.82 m** y consola baja de aproximadamente **0.90 × 0.80 × 0.50 m**. Diseña una bandeja donde entra la caja, un filtro grueso, una ventana con depósito azul y separación visual para recibir mineral.
- **Forma y material.** Caja industrial baja, tubo curvo y pictograma de gota. Usa visor opaco azul y un indicador de nivel que cambie por segmentos.
- **Pivote y colisión.** Raíz de cada módulo al suelo. Nodos `input_tray`, `water_gauge` y `status_light`. Caja física simple para el cuerpo trasero. **650–1 350 tris para el conjunto**.
- **Estados.** En espera, recibe hielo o mineral, depósito lleno. Se lee desde el frente sin confundirla con la planta de propelente.

### 07. Invernadero modular · `cultivo_bancada.glb` y `cultivo_planta.glb`

- **Modelar.** Una bancada repetible de **0.96 × 0.70 × 1.26 m**, tres instancias en juego, con cubeta, tubo de riego y marco de luz. La planta madura mide aproximadamente **0.40–0.55 m de alto**. Separa la bandeja de las plantas. Las plantas necesitan formas claras en tres etapas: brote, crecimiento y cosecha.
- **Forma y material.** Cubeta clara y plantas verdes con hojas anchas, opacas y legibles. La estructura superior puede ser un marco recortado. Mantén las hojas a la vista.
- **Pivote y colisión.** Bancada en su base y planta en la unión con el sustrato, para que pueda escalar desde la raíz. Colisión por bancada. **250–550 tris por bancada y 60–140 por planta**.
- **Estados.** Disponible para sembrar, creciendo, en pausa por energía y listo para cosechar. La luz y la altura de las hojas comunican progreso.

### 08. Matriz solar · `panel_solar.glb`

- **Modelar.** Un panel repetible de **2.90 × 0.16 × 1.38 m** con mástil de **1.18 m**. El mapa instala tres paneles separados unos 3.12 m entre centros. Diseña marco, rejilla solar, bisagra y soporte. La pose de juego actual usa una inclinación de alrededor de **29°**.
- **Forma y material.** Celdas azul profundo y líneas claras lo suficientemente anchas para leerlas. Muestra el patrón con un atlas o una superficie de talla simple.
- **Pivote y colisión.** Raíz en el pie del mástil. Pivote del panel en el eje de rotación. Una forma simple detrás de la zona de servicio. **280–650 tris por panel completo**.
- **Estados.** Plegado, desplegando, activo y sin producción. Usa posición o luz auxiliar para advertir fallo. Las celdas pueden seguir siendo reconocibles en sombra.

### 09. Batería y ampliación · `bateria_kit.glb`

- **Modelar.** Una base de consola estándar y acumulador modular auxiliar de **0.83 × 1.24 × 0.80 m**, más una ranura o guía de montaje. Separa la instalación del cartucho de la base.
- **Forma y material.** Cuerpo compacto y tres rayas grandes de carga en carcasa gris, con extremos ámbar y aislante oscuro. Usa un icono de rayo y segmentos verticales.
- **Pivote y colisión.** Raíz en el suelo y `aux_socket` en la guía. Deja libre el anillo de uso incluso con el cartucho instalado. **350–850 tris**.
- **Estados.** Ampliación ausente, instalada y baja de carga. Los segmentos se pueden encender por separado.

### 10. Planta de propelente · `planta_propelente.glb`

- **Modelar.** Conjunto trasero de **1.92 × 1.50 × 0.78 m**, más consola de frente. Usa dos depósitos cilíndricos con abrazaderas, una unión de tuberías y una bandeja donde sale el lote. Mantén los depósitos bajos y separados.
- **Forma y material.** Blanco, anillos ámbar y válvulas oscuras. Identifica cada depósito con un símbolo distinto. La silueta de dos depósitos evita confundirlo con la refinadora.
- **Pivote y colisión.** Raíz en la base. Anclajes `status_light`, `batch_out` y `valve`. Volumen simple detrás del área de operación. **700–1 500 tris**.
- **Estados.** Falta agua, fabricando, detenido por energía y lote listo. El lote usa la caja portátil de la ficha 05.

### 11. Plataforma y punto de embarque · `plataforma_ascenso.glb`

- **Modelar.** Plataforma baja de **5.30 m de diámetro** y alrededor de **0.13 m de alto**, ocho luces reutilizables y consola de entrega al frente. Añade dos marcas de embarque alrededor del punto de acción, a unos **1.50 m entre centros**.
- **Forma y material.** Octágono o círculo facetado, franjas diagonales ámbar en el borde, rejilla central oscura y dos símbolos de asiento de fácil lectura.
- **Pivote y colisión.** Centro de la plataforma. Crea `rocket_root`, `boarding_l` y `boarding_r` como referencias. Mantén una huella baja y paso libre alrededor. La barrera central actual del cohete ocupa **1.90 × 1.60 × 1.90 m**. **650–1 400 tris**.
- **Estados.** Espera, recibe carga, embarque y lanzamiento. Reserva material de luz independiente para la cuenta de salida.

### 12. Cohete de ascenso · `cohete_ascenso.glb`

- **Modelar.** Volumen aproximado de **2.40 × 4.25 × 1.65 m** con cuerpo, nariz redondeada, ventanilla grande, patas, conexión de carga, tobera y tanques visibles a ambos lados. Usa una cápsula interior simple únicamente si va a verse al abrir la escotilla.
- **Forma y material.** Silueta vertical, franjas anchas ámbar, visor oscuro y tobera oscura. El blanco del cuerpo debe separarse del suelo en luz fuerte. Distingue el cohete vertical del transporte horizontal de la introducción.
- **Pivote y partes.** Raíz en la base. Separa `hatch`, `legs`, `boosters` y `engine_fx`. El punto de efectos va en la tobera. Conserva las piezas animables como hijos antes de exportar. **1 400–3 200 tris**.
- **Estados.** Plegado para el montaje, esperando carga, listo, ignición y ascenso. La llama y el polvo se añaden aparte. El cohete debe quedar reconocible desde arriba cuando despega.

### 13. Astronauta y puntos de agarre · `astronauta_cadete.glb`

- **Modelar.** Un único cuerpo de **1.60–1.70 m de alto**, casco de aproximadamente **0.68 m** de ancho, botas anchas, guantes, mochila y visor con reflejo grande. Dos variantes materiales sobre la misma geometría. J1 lleva marca circular y cian. J2 lleva marca romboidal y ámbar.
- **Pivote y rig.** Raíz entre los pies, frente **−Z**. Esqueleto sencillo con pelvis, torso, cabeza, brazos, manos, piernas y pies. Marca `grip_box` con la caja de referencia colocada a la altura del pecho. Usa animaciones en el lugar para que el desplazamiento lo dirija el controlador.
- **Clips.** Reposo, caminar, caminar con caja, recoger, pasar, accionar consola y sentarse. Reposo y marcha en bucle. Pasar o sentarse quedan como clips terminados y Godot decide cuándo activarlos. **1 800–4 000 tris por cadete**.
- **Lectura.** El visor, la mochila y la carga deben verse cuando mira en cuatro direcciones. Revisa que una caja en mano deje visible la marca del jugador y que la cápsula física actual siga siendo válida.

## P2 · Piezas compartidas y señalización

### 14. Taller y taladro Mk2 · `taller_taladro.glb`

- **Modelar.** Banco de **1.30 × 0.85 × 0.60 m** y taladro instalado de aproximadamente **0.55 × 1.35 × 0.55 m**. Incluye mordaza, soporte y broca gruesa en pieza aparte. Reutiliza el frente de la consola común.
- **Pivote y material.** Base en suelo, broca en su eje, anclaje `upgrade_socket`. Acero mate, ámbar y un número grande sobre la tapa. Banco y mejora caben detrás de la franja de uso. **550–1 200 tris**.
- **Estados.** Banco vacío, instalación y Mk2 disponible. La interacción muestra la mejora comprada aunque el taladro esté quieto.

### 15. Consola común y mesa de práctica · `consola_kit.glb`

- **Modelar.** Pedestal base de aproximadamente **0.90 × 0.85 × 0.55 m**, pantalla ancha inclinada, botón físico y lector de caja. La mesa de práctica añade una bandeja de aproximadamente **0.85 × 0.55 m** en planta y señal de muestra. Reutiliza el pedestal en taller, batería, refinado, propelente, refugio, radio y plataforma según convenga.
- **Pivote y material.** Centro en el suelo. Pantalla y bandeja en nodos distintos. Consolas gris e intercambiables mediante placas de color e icono. **250–500 tris por consola, hasta 250 para la bandeja adicional**.
- **Estados.** Lista, activa y sin energía. La mesa de práctica se retira al empezar la misión. Usa las etiquetas del juego para el texto.

### 16. Radio, antena y receptor · adaptación CC0

- **Usar.** Ya están importados `kenney/antena.glb` y `kenney/consola.glb`. El objetivo inicial es reutilizarlos en las tres bases y darles una peana común de **0.85 × 0.20 × 0.70 m**. Si los reemplazas, usa la misma separación entre plato y receptor, con antena de **1.8–2.1 m de alto** y receptor de hasta **1.0 m**.
- **Pivote y material.** Mástil con raíz al suelo. Si creas una versión animada, hazla girar sobre el eje de unión del plato. Separa `dish`, `receiver` y `signal_light`. Violeta de radio sobre estructura gris. **Meta de hasta 1 300 tris para un reemplazo completo**.
- **Estados.** Espera, enviando, señal perdida y confirmada. La pausa por falta de señal necesita un icono de enlace partido, además del cambio de luz. [Modelos utilizados](../assets/props_luna/asset-register.md)

### 17. Palé, paquetes y contenedor de suministros · `suministros_kit.glb`

- **Modelar.** Palé de **1.55 × 0.17 × 0.90 m** y tres paquetes visibles de hasta **0.42 × 0.39 × 0.48 m**. Añade cubierta plegable y una marca de gota y hoja. Reutiliza las cajas de la ficha 05 cuando se vean de cerca.
- **Pivote y material.** Centro inferior. Tapas independientes si animas la apertura. Base oscura y verde con bandas claras. Mantén el paso desde el refugio. **300–750 tris para el conjunto**.
- **Estados.** Ausente, recién llegado y recogido. El control de premio permanece en Godot.

### 18. Luces, balizas y marcadores · `senalizacion_kit.glb`

- **Modelar.** Luz de suelo de **0.38 × 0.07 × 0.12 m**, baliza de esquina de **0.36 × 0.50 × 0.36 m**, aro de interacción de **1.37 m de diámetro** y placa intercambiable de unos **0.55 × 0.06 × 0.50 m**. Variantes de cruz o escudo, gota, hoja, rayo, antena y cohete. Usa el mismo estilo de iconos en todo el juego.
- **Pivote y material.** Centro inferior. Base opaca y lente/emisión aparte. Las balizas decorativas quedan fuera de la ruta. **40–160 tris por pieza**.
- **Estados.** Día, noche, estación activa y alerta. La luz nocturna remarca la entrada y las rutas. Evita parpadeo rápido y brillo que dificulte ver las cajas.

### 19. Barreras, límites y cables · `infraestructura_kit.glb`

- **Modelar.** Barrera repetible de **1.41 × 0.88 × 0.56 m**, remate, esquina, dos cables a ras del piso y una caja de conexiones de hasta **0.50 × 0.28 × 0.40 m**. Para el borde exterior usa segmentos de hasta **0.30 m de ancho**. Una sección actual de barrera en la cantera ocupa **5.70 m** de largo.
- **Pivote y material.** Barreras centradas en su base y cables con conectores en ambos extremos. Bandas de seguridad en bordes. Ondulación baja en los cables y repetición discreta. Colisión solo para las barreras y límites que ya existan. **80–250 tris por elemento**.
- **Lectura.** La barrera se reconoce como límite. Una tubería de suelo no parece un muro ni confunde el recorrido recomendado.

### 20. Suelo lunar base · `suelo_lunar.glb`

- **Modelar.** Una superficie de vista de **44 × 29 m** cubierta con material mate. Añade detalle de polvo en grupos grandes, islas de piedritas y cambios suaves de tono. Guarda una versión editable dividida por sectores para poder mover decoración sin tocar la zona plana de juego.
- **Pivote y colisión.** Centro al nivel de suelo. El terreno conserva la placa física que controla el mapa. Usa UV repetibles y una transición disimulada hacia el horizonte. **500–2 000 tris iniciales** para la superficie.
- **Variantes.** Cresta gris violeta `#5C586C`, Nobile gris frío `#4E596C`, Taurus-Littrow gris pardo `#67565D`. Conserva el contraste con los caminos también de noche.

### 21. Cráteres, rocas y lecho · `relieve_lunar_kit.glb`

- **Modelar.** Tres cráteres de diámetros aproximados **2.7, 4.0 y 5.8 m**, tres rocas grandes con tamaños de **0.8–2.7 m** y cuatro grupos de grava de **0.12–0.55 m**. Los cráteres necesitan borde, concavidad poco profunda y una pared interior irregular que se lea desde arriba.
- **Pivote y material.** Raíz al suelo en el centro. Variación de facetado en las rocas y gama de bajo contraste. Coloca el relieve grande fuera de los corredores o fuera del suelo físico. **130–400 tris por cráter, 40–180 por roca y hasta 100 por grupo de grava**.
- **Lectura.** El jugador distingue una depresión, un objeto decorativo y un yacimiento utilizable. Los cráteres decorativos se quedan fuera de los atajos.

## P3 · Identidad de cada base e introducción

### 22. Reborde de Shackleton · `cresta_borde.glb`

- **Modelar.** Dos tramos de cornisa de **7–11 × 1.4–2.3 × 3–5 m** y una depresión en sombra de fondo. Dibuja formas casi horizontales, con el borde superior frío y la cara hacia el cráter más oscura.
- **Pivote y material.** Centro inferior, con pies parcialmente encajados en el terreno. Reutiliza material de suelo de Cresta. **350–900 tris por tramo**. Sin colisión si es fondo. [Iluminación de Shackleton, NASA](https://science.nasa.gov/resource/illumination-map-of-the-moons-south-pole/)

### 23. Colinas de Nobile y mástil de enlace · `nobile_fondo.glb`

- **Modelar.** Dos lomas redondeadas de aproximadamente **7–10 × 2.0–3.5 × 4–6 m**, y una silueta de mástil de **0.8 × 2.1 × 0.8 m** con una luz alta. Situarlos detrás del sector de radio. Reutiliza el plato CC0 de la ficha 16 si el mástil lleva antena.
- **Pivote y material.** Al suelo en su base. Gris frío de Nobile y una luz puntual discreta. **350–900 tris por loma y hasta 350 para el mástil sin contar el plato**. El mástil de fondo sirve para explicar el enlace y conserva la consola principal como punto de uso. [Operaciones lunares de VIPER, NASA](https://science.nasa.gov/mission/viper/lunar-operations/)

### 24. Valle de Taurus-Littrow e instrumentos · `taurus_fondo.glb`

- **Modelar.** Dos hitos de roca estratificada de **5–9 × 2.0–3.5 × 3–5 m** y un grupo científico de fondo. El grupo incluye una caja de hasta **0.80 × 0.50 × 0.60 m**, una sonda de **0.80 m** de alto y cable. Inspírate en ALSEP. Usa una silueta más baja que las estaciones activas.
- **Pivote y material.** Centro inferior por módulo. Tonos grises cálidos, juntas horizontales y veletas o sensores simples. **400–950 tris por hito y hasta 650 por conjunto científico**. La instrumentación es visual y se mantiene fuera de la ruta de entrega. [Apollo 17 y ALSEP, NASA](https://www.nasa.gov/missions/apollo/apollo-17-mission-details/)

### 25. Transporte de aterrizaje y carga plegada · adaptación CC0

- **Usar.** `kenney/transporte.glb` ya se usa en la cinemática. Si haces una variante amiga del nuevo kit, conserva una nave ancha y baja de aproximadamente **3.5 × 1.4 × 5.2 m**, con patas cortas, ventana frontal y soportes de carga. Las dimensiones son objetivo de composición, con margen según el encuadre de aterrizaje.
- **Pivote y material.** Centro inferior en la pose con patas abiertas. Separa `landing_legs`, `cargo_ramp`, `cargo_socket` y `thruster_fx`. Usa la misma paleta de paneles de los módulos. **1 500–3 500 tris si se crea un reemplazo**.
- **Estados.** Descenso, contacto, apertura y retirada. El polvo y la animación de cámara se reproducen en el motor. [Mining Spacecraft de Kenney](https://poly.pizza/m/wJQEGUHttY)

### 26. Piezas del montaje de la base · reutilización de P1

- **Modelar solo el complemento.** Dos contenedores planos de **1.1 × 0.28 × 0.75 m**, brazos de bisagra y tapas para presentar de manera clara el refugio, paneles y cohete plegados. Usa las mismas mallas principales de las fichas 02, 08 y 12 en la toma de montaje.
- **Pivote y material.** Pivotes en bisagras, anclajes compatibles con el contenido de los módulos. **100–300 tris por contenedor auxiliar**. El cierre de la introducción debe mostrar el mismo refugio desplegado que el jugador va a usar.
- **Estados.** apilado → anclaje → apertura → luz de funcionamiento. Un cierre mecánico claro por módulo ayuda a contar qué construyó la tripulación.

### 27. Efectos con geometría simple · `formas_fx.glb`

- **Modelar.** Una carcasa de llama cónica y corta para el motor, una onda de radio abierta y uno o dos planos de polvo para aterrizaje y ascenso. Puedes construir estas formas en Godot si salen con una primitiva.
- **Pivote y material.** Tobera para la llama, centro del plato para la onda, piso para polvo. Mantén una malla de **menos de 150 tris por forma**. La luz se define en el motor. Usa gama ámbar para ascenso, cian o violeta para comunicaciones y gris para polvo.
- **Estados.** La llama acompaña ignición y subida. La onda acompaña el mensaje. La alerta solar funciona con iluminación, aviso e icono porque la radiación no se representa como una nube física.

## Anclajes actuales para colocar los modelos

Son posiciones de interacción **X, Y, Z** en Godot. Encaja primero el modelo con el origen indicado en su ficha y luego ajusta la carcasa detrás del marcador si ese nodo es la zona donde se para el jugador.

| Estación | Punto actual | Estación | Punto actual |
| --- | --- | --- | --- |
| Refugio / aire | `(0, 0, 2.9)` | Mesa de práctica | `(0, 0, 5.3)` |
| Hielo | `(-11.1, 0, -0.5)` | Mineral | `(-11.1, 0, 4.2)` |
| Refinadora | `(-5.1, 0, -3.4)` | Taller / taladro | `(-5.5, 0, 5.8)` |
| Cultivo | `(3.1, 0, -2.2)` | Planta de propelente | `(6.7, 0, -2.4)` |
| Red solar | `(0, 0, -5.1)` | Batería | `(4.7, 0, 6.3)` |
| Radio | `(6.3, 0, 3.9)` | Suministros | `(-3.7, 0, 6.55)` |
| Carga y embarque | `(11.2, 0, 0.7)` | Cohete | `(11.1, 0, -2.65)` |

## Entrega y comprobación de cada pieza

1. Modela primero la caja de tamaño, el origen y la silueta. Haz una captura con la cámara de juego y un astronauta a su lado.
2. Añade colores planos, biseles visibles y puntos de montaje. Revisa la malla individual y su grupo de piezas antes de texturizar.
3. Prepara el archivo editable y el GLB. Reimporta y revisa escala, orientación, materiales, piezas animadas y juntas. Comprueba que la escena conserva colisiones y alcances existentes.
4. Entra en la partida y recorre **cantera → refinado → refugio → cohete**. Prueba pasar una carga con dos astronautas. Comprueba la vista durante el día, la noche y una alerta, y la versión final desplegada al omitir la cinemática.
5. En la primera sesión de observación, pide que el jugador encuentre refugio, cultivo y cohete con la interfaz habitual y que cuente qué acción realizó. Registra cualquier confusión entre siluetas o rutas. [Guía de observación del proyecto](../tools/skills/probar-juego-con-ninos/SKILL.md)

Las dimensiones de referencia salen de [CrestWorld](../crest/crest_world.gd), [FieldPilot](../field/field_pilot.gd) y [CrestGame](../crest/crest_game.gd). Los presupuestos de triángulos, nombres propuestos y variantes son especificaciones de producción. Se revisan al probar los primeros modelos.

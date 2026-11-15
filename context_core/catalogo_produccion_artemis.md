# Artemis · Catálogo de objetos y edificios para modelar

Diseño de producción para **Última ventana**, con prioridad para **Mons Mouton Plateau**, la base inicial. Las dimensiones, colores y presupuestos son propuestas de arte para la cámara actual. Las reglas jugables corresponden a la especificación del 14 de noviembre de 2026. Las regiones lunares dan nombre e inspiración a los mapas. Las instalaciones, su emplazamiento y sus rutas son diseños del juego.

## Archivos que ya tenemos

| Activo | Qué reutilizar |
| --- | --- |
| Gato piloto | `assets/pilotos/gato-modelo2.glb`. El rig y el shader ya permiten dos pilotos con traje azul y naranja. Mantener el esqueleto y el anclaje de la caja. |
| AstroCat | `assets/pilotos/astrocat_guia.glb`. Modelo con cinco clips y fuente editable en `tools/astrocat/AstroCat.blend`. Sirve de personaje de ambientación y queda disponible para la futura ayuda interactiva. |
| Apolo y LRO | `assets/props_luna/nasa/`. Apolo ocupa la plataforma con la base de descenso y la etapa de ascenso. LRO sigue como maqueta científica. La nave de regreso aparece en órbita. |
| Relieve LOLA | `assets/props_luna/nasa/relieve_nobile_lola.glb`. Paisaje del área de Nobile. Conservar escala y procedencia del recorte al integrarlo. |
| Electrónica | `assets/props_luna/kenney/`. Reusar antena y receptor para la radio. El transporte de Kenney queda disponible como repuesto o elemento de fondo. |
| Prototipos en Godot | `crest/crest_world.gd`. Es la referencia de las huellas y la altura que ya funcionan para refugio, paneles, cantera, taller, cultivo y módulo lunar. Son las piezas que se reemplazarán con este catálogo. |

## Guía común de Blender a Godot

- **Estilo.** Diorama lunar, juguete industrial, bloques bajos y bordes suaves. Usar marfil `#E4E8F3` para cerámica y aislamiento, grafito `#273345` en chasis y base lunar gris violeta. Cian `#82DDFF` para agua y aire, verde `#ACD891` para alimento, violeta `#C4ACF7` para mineral y ámbar `#FFBC76` para potencia y propelente. Cada familia tiene una silueta y un pictograma propios para poder distinguirla por forma.
- **Escala y cámara.** Una unidad de Godot equivale a un metro de producción. Medidas de las fichas expresadas como ancho × alto × fondo. Trabajar en metros en Blender, Z arriba y frente hacia −Y. Comprobar en Godot con cámara ortográfica a tres cuartos, un piloto junto al objeto y una ventana de 1152 × 648. La vista principal debe mostrar la frente, un lateral y la superficie superior que se toca.
- **Geometría.** Aplicar rotación y escala, corregir normales y exportar triangulado. Usar un bisel ancho en cantos que se leen desde la cámara. Mantener un material opaco compartido por modelo cuando sea posible. Reservar transparencias para superficies pequeñas como tubos y usar superficies de vidrio abiertas o imitación opaca en techos. Los límites listados son triángulos de LOD0.
- **Materiales.** Entregar una paleta común o un atlas de 512² para el kit, con margen UV. Reservar 1024² para una pieza protagonista que gane detalle desde la cámara. Al apagar una luz del modelo, la forma de la estación y su icono deben seguir siendo legibles. Dejar letras y números a Godot por resolución y traducción.
- **Entrega.** Un `.blend` con colecciones `render`, `colision`, `anclajes` y `variantes`, un `.glb` y capturas frontal, posterior, lateral y en cámara de juego. Pivote en el centro de la huella al piso salvo donde indique la ficha. Exportar los anclajes como nodos vacíos y documentar nombres. Usar cajas, cápsulas o convexos simples para colisión. Los adornos interiores, cables y pictogramas no necesitan colisionar.
- **Rutas.** Empezar con pasarelas de 2 m de ancho y puertas de 1,8 m libres. Los puntos `action` van del lado transitable, a 0,8–1,2 m delante del equipo. Validar que dos pilotos se crucen en entradas y que ambos puedan refugiarse desde los extremos durante el aviso más corto de 20 s. Mantener visibles el refugio, los puntos de acción y las rutas bajo el HUD táctil.

## P1 · Cinco zonas de trabajo y sus objetos

| Modelo y archivo | Silueta, medidas y materiales | Entrega funcional |
| --- | --- | --- |
| Pasarela modular · `pasarela_kit.glb` | Baldosas de 2 × 0,12 × 2 m sobre bastidor grafito. Superficie lisa grande y dos tiras cian hundidas. Bordes redondeados. Hasta 160 tris por pieza. | Recta, curva, cruce T, cruce X y terminal. Pivote al centro y `snap_n/e/s/o` a 1 m. Huella de paso plana, bordes sin colisión. Incluir rampa de 2 × 0,35 × 3 m con colisión inclinada lisa. |
| Hábitat y refugio · `refugio_corte.glb` | 5,8 × 2,45 × 5,75 m. Base octogonal gris, costillas gruesas claras, bandas cian y emblema de escudo. Conservar paredes posteriores y laterales bajas hacia la cámara. Hasta 2 300 tris. | `door_a` y `door_b`, `safe_bounds`, `action` y dos plazas interiores. Panel posterior con soportes visibles. Entregar variante cerrada para fondo y variante activa con corte. Indicador de aire y blindaje en mallas separadas para que el escudo siga visible durante un apagón. |
| Soporte vital · `soporte_vital.glb` | 1,25 × 1,45 × 0,72 m. Bastidor marfil con dos cilindros verticales y conductos cian. Pantalla sobre bisel visible por arriba. Hasta 950 tris. | `action`, `in_water`, `air_indicator`. Tres estados de iluminación (normal, reducido y sin recarga) y pulsación por material. Colisión en una caja que deja paso por ambos lados. |
| Comedor compacto · `comedor.glb` | 1,4 × 0,8 × 0,75 m. Repisa baja con dos bandejas y un dispensador verde. Hasta 420 tris. | `action` y `tray_slot`, bandeja vacía y con ración. Ubicar contra pared lateral del refugio, fuera de la entrada. |
| Cantera · `cantera_kit.glb` | Dos huellas de 2,4 × 1,0 × 2,1 m. Hielo traslúcido simulado con cristales cian largos. Mineral con bloques violetas achaparrados y marcas de perforación. Hasta 900 tris por depósito. | Pivotes en la base, `drill_target` y `action` en borde despejado. Crear variantes intacta, picada y perforando con tres piezas móviles pequeñas. Un único casco convexo por depósito. |
| Cargas portátiles · `carga_kit.glb` | Huella única de 0,53 × 0,48 × 0,49 m. Hielo con tapa dentada, mineral con nervio doble, ración con bandeja verde, propelente con bidón ámbar y muestra de tutorial con asa circular. Hasta 220 tris por variante. | Mismo `grip` para todas, centro horizontal y orientación frontal consistente. Pivote al piso. Al colocarlas en el suelo una cápsula de interacción las hace fáciles de recoger. Depósito y entrega manual usan la misma caja. |
| Taller y banco de mejoras · `taller.glb` | 2,6 × 1,4 × 1,35 m. Mesa marfil de patas negras, mordaza grande y cuatro encastres de herramientas. Hasta 1 350 tris. | `action` y `upgrade_slot_01..04`. Cada mejora tiene una miniatura diferenciada. Cuerpo y herramientas separados. Colisión solo en la huella de mesa. |
| Refinadora · `refinadora.glb` | 1,6 × 1,6 × 1,1 m. Tolva abierta arriba, cámara cilíndrica central y depósito lateral cian opaco con tres marcas. Hasta 1 100 tris. | `in_ice`, `out_water`, `action` y malla `fill`. Tapa o rotor simple durante el refinado de 5 s. Se detiene en apagón y reanuda desde su nivel. |
| Bancada de cultivo · `bancada_cultivo.glb` y `plantin.glb` | Bancada de 2,25 × 0,9 × 1,2 m, bastidor gris claro, cama oscura, módulos verdes en dos filas. Hasta 850 tris para la mesa y 150 por planta. | `action`, `plant_01..06` y `irrigation_slot`. Usar cuatro estados (tierra seca, regada, brote, cosecha) y una luz distinta cuando falte energía. Cubierta opcional en pared posterior para conservar vista cenital. |
| Energía solar · `panel_solar.glb` | Matriz de 2,6 × 1,8 × 1,3 m, placas azul profundo con cuadrícula pintada y borde blanco. Bisagra simple y cable conector inferior. Hasta 880 tris por conjunto. | Pivote de placa en eje real, `cable_out`, `action` para la distribución energética. Variantes plegada, desplegada y reforzada. En noche, apagar testigo de producción sin ocultar la estación. |
| Batería y ampliación · `bateria_kit.glb` | Batería base de 1,4 × 1,05 × 0,85 m, cuerpo grafito mate y cuatro segmentos ámbar. Cabecera de alta tensión y ranura para un segundo bloque. Hasta 850 tris con ambos bloques. | `action`, `aux_slot` y segmentos con material separado. Variante descargada, reserva y llena por código. El módulo auxiliar encaja a ras y se identifica también por su contorno. |
| Planta de propelente · `planta_propelente.glb` | 2,3 × 1,65 × 1,55 m. Dos tanques claros asimétricos, ducto grueso y bandeja de bidón. Base grafito y conexiones cian y ámbar. Hasta 1 450 tris. | `action`, `water_in` y `fuel_out`. Tres estados (en espera, trabajando, sin potencia) y soporte para caja visible a la salida. Evitar cilindros de más de 12 lados salvo que cambien la silueta. |
| Radio y estación de vuelo · `radio_consola.glb` | 2,1 × 2,1 × 1,5 m con antena existente, receptor y una base propia. Bandeja azul con perilla y panel inclinado. Hasta 700 tris nuevos. | `action` y `antenna_pivot`. Iconos de espera, transmisión, confirmación y sin señal en un soporte inclinado. Mantener una posición utilizable aunque se corte la señal. |
| Plataforma · `plataforma_retorno.glb` | Disco octogonal de 4,6 × 0,15 × 4,6 m, núcleo gris oscuro, perímetro ámbar y placas de servicio. Hasta 1 050 tris. | `fuel_drop`, `food_drop`, `board_1`, `board_2` y `rocket_origin`. Incorporar un acceso de 2 m libre de cajas decorativas. Habilitar balizas por separado. |
| Nave orbital · `nave_orbital.glb` | Módulo de servicio cilíndrico en plata, campana oscura atrás y cápsula cónica marfil con puerto de acoplamiento enfrente. Longitud de juego aproximada 4,4 m, diámetro 1,5 m y hasta 2 800 tris. | Submallas independientes para servicio y cápsula. `dock`, `main_engine`, `capsule_origin` y `heat_shield`. La etapa Apolo usa su GLB de NASA y se acopla por el frente. La cápsula se separa para la entrada. La cinemática usa actualmente un bloqueado procedural. |

## P2 · Variantes, piezas menores y señalización

| Pieza | Fabricación | Comprobación en escena |
| --- | --- | --- |
| Cuatro mejoras · `mejoras_kit.glb` | Taladro Mk II con broca corta dentada y carcasa violeta, batería auxiliar ámbar en riel, marco y segundo faldón del panel reforzado, colector verde con tres goteros para riego. Unos 180–380 tris por pieza. Pivote en tornillo o encastre. | Mostrar ausente e instalada. El refuerzo solar puede modelarse aunque su incremento numérico sigue pendiente en VAC-17. |
| Señalización · `senales_luna.glb` | Baliza de 0,30 × 0,55 × 0,30 m, cartel inclinado de 0,65 × 0,85 × 0,18 m, flechas, marcas de zona segura, escudo solar y copo de frío. Hasta 125 tris por soporte. Iconos en atlas táctil separado. | Bases con pivote al suelo y cabezal intercambiable. Crear versiones diurna, nocturna y alerta de partículas por material. El copo aparece junto al aire del piloto que está fuera por la noche. |
| Interior y aula · `habitat_utileria.glb` | Dos literas dobladas, gabinete, cojín, herramienta, caja de comida y mesa de práctica de 0,9 × 0,65 × 0,54 m. Hasta 400 tris por objeto. | Variantes compacta y abierta. La mesa tiene guía para una caja y `action`. Mantener el tutorial en la ruta de ambos pilotos. |
| Tuberías y vallas · `infraestructura_kit.glb` | Tramo recto, esquina y T para tubo cian, cable ámbar, zócalo, guardarraíl corto y poste con luz. Hasta 160 tris por tramo. | Pivote en inicio. Terminar todos los bordes y usar colisión solo en vallas que sean un límite real. |
| Suelo y rocas · `regolito_kit.glb` | Baldosas de 4 × 4 m, cráteres de 1,5 y 3 m, tres rocas de 0,35–1,1 m, borde de corte y talud modular. Gris frío con tres tonos de rugosidad y cantos amplios. Hasta 650 tris por cráter cercano. | Conectores para orientar terreno, versión visual de fondo y colisión simplificada para piezas jugables. Cráteres de fondo en grupos con material compartido. Evitar piedras sueltas en la trayectoria del piloto. |
| Efectos reutilizables · `fx_mision_kit.glb` | Estela fina de motor, chispas de taladro, ondas de radio, arco de seguridad y polvo lunar bajo. Plano o malla de hasta 100 tris por efecto. | Pivote en punto de emisión. Activar por estado y limitar transparencias superpuestas. Probar lectura en noche sin ocultar cajas o pilotos. |

### Cráter lateral de referencia

Conservar la boca poligonal de la imagen y construir cinco anillos con el mismo número de vértices. Tomar como proporciones radiales 100%, 76%, 65%, 39% y 16%. El talud exterior parte del suelo, el borde sobresale alrededor de 0,50–0,85 m y la cubeta cae casi hasta la cota del suelo. Desplazar ligeramente cada vértice en planta y altura. Dar una banda clara a la cresta y una pared interior más oscura; mantener el fondo irregular con facetas anchas. Añadir algunas rocas alrededor, dejando visible al menos un lado completo de la boca al mirar desde la cámara del juego.

El primer bloqueado ya existe en `crest/lunar_crater.gd`. Son seis cráteres perimetrales con 99 triángulos cada uno, sin colisión y con forma reproducible por región. Para sustituir una pieza por un GLB, conserva el centro al nivel del suelo y fabrica dos tamaños de aproximadamente 3,5 y 5 m de diámetro. Mantén las depresiones jugables de los mapas en los kits de la sección siguiente.

## P3 · Terreno específico de las nueve bases

Cada kit regional combina un suelo navegable, un fondo sin colisión y un elemento reconocible cerca de una estación. Las medidas sugeridas sirven para un primer bloqueado y se ajustan con la prueba de rutas. Presupuesto inicial de 4 000 tris para geometría cercana y 2 500 para horizonte por región. Entregar las piezas con pivote al centro de su huella, malla convexa o rampa en áreas jugables, y una versión de fondo sin colisión.

| Base y dificultad | Piezas y dirección de diseño |
| --- | --- |
| **Mons Mouton Plateau · fácil** | `mouton_plateau_suelo.glb`, mesa abierta de unos 28 × 20 m con caída suave en el contorno. `mouton_plateau_horizonte.glb`, lomas bajas y casi horizontales. Cantera y plataforma a lados opuestos y camino corto con refugio claramente visible en el centro. |
| **Slater Plain · fácil** | `slater_lomas.glb`, tres lomadas redondeadas de 4–6 m con desnivel menor de 0,7 m. `slater_camino_largo.glb`, balizas y cráteres pequeños que acompañan una ruta extensa. Sin muros altos en primer plano. |
| **Malapert Massif · fácil** | `malapert_cima.glb`, coronación rotunda con terraza de antena y mirador hacia la Tierra. `malapert_lomas.glb`, fondo iluminado y laderas claras. Entrada por rampa ancha, perfil alto detrás de la zona de juego. |
| **Mons Mouton · media** | `mouton_terrazas.glb`, dos terrazas apilables con diferencia visible de cota. `mouton_rampa_curva.glb`, rampas en zigzag con baranda exterior. Taller y mina a distinta altura y refugio en el punto donde se unen rutas. |
| **Peak near Cabeus B · media** | `cabeus_pico.glb` y `cabeus_cuenca.glb`, pico con cara iluminada y cuenca con roca fría. `cabeus_rampa.glb`, acceso largo y diagonal. Siluetas radicalmente distintas para distinguir energía arriba y extracción abajo. |
| **Nobile Rim 1 · media** | `nobile_1_reborde.glb`, cuña de borde suroeste con dos escalones bajos. `nobile_1_bloques.glb`, rocas que marcan límite entre zonas iluminadas y sombra. La radio usa el kit compartido. |
| **de Gerlache Rim 2 · difícil** | `gerlache_arista.glb`, cresta angosta con vías entre bloques. `gerlache_pasarela_segura.glb`, arriostres y apartaderos que permiten que dos pilotos se crucen. Iluminar cada zona de espera con baliza baja. |
| **Nobile Rim 2 · difícil** | Reusar el relieve LOLA para el fondo. `nobile_2_borde.glb`, cresta noreste que enmarca la radio. `nobile_2_mastil.glb`, mástil visible con estados de señal. El corredor hacia refugio queda despejado en todos los tramos del corte. |
| **Haworth · difícil** | `haworth_cuenca.glb`, fondo oscuro con anillo y desarrollos azules mate para depósitos. `haworth_balizas.glb`, ruta iluminada desde la batería al refugio, con marcas altas y visibles. El rendimiento solar específico del mapa necesita definición jugable antes de aplicar valores. |

## Producción y pruebas

1. Modelar un piloto de referencia, una pasarela, el refugio y una caja de hielo como conjunto de escala usando el gato existente. Revisarlos en Godot de día y de noche antes de fabricar el resto.
2. Completar cantera, refinadora, energía, planta, cultivo, radio y plataforma con el bloqueado de Mons Mouton Plateau. Usar un recorrido con una caja desde la cantera hasta el taller y confirmar que la entrada al refugio no queda tapada.
3. Entregar la nave, las cuatro variantes de mejora y la señalización funcional. Verificar que los colores y las formas distinguen estados, que hay anclajes y que los dos pilotos caben a la vez.
4. Probar en pantalla táctil y en un dispositivo de gama media con objetivo de 30 fps. Registrar resolución, dispositivo, número de triángulos visibles, materiales y punto de la prueba que más cae.
5. Producir los otros ocho terrenos cuando la prueba en la base inicial confirme escala, lectura y tiempos de desplazamiento. Guardar por pieza el `.blend`, `.glb`, fuentes y licencia, y tres vistas con la misma escala.

Las ideas de módulos construibles, robot programable, personalización, álbum y minijuegos quedan en la sección 14 de la especificación. Para arte se pueden explorar con bocetos separados hasta que se defina su interacción.

[Registro de modelos y licencias](../assets/props_luna/asset-register.md) · [Edición de AstroCat](../tools/astrocat/README.md) · [Procedencia de los recursos NASA](../assets/props_luna/nasa/procedencia.md)

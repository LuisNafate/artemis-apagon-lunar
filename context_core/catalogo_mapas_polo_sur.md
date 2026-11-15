# Catálogo de modelos 3D · Nueve mapas del polo sur lunar

**Alcance.** Nueve mapas 2.5D inspirados en las regiones candidatas publicadas por NASA en 2024. Cada partida empieza en un campamento ficticio que los cadetes montan durante la introducción. El rediseño cambia la forma del terreno y la distribución de los módulos. El catálogo anterior sigue siendo la ficha de referencia para astronautas, cajas y estaciones. Los tamaños de aquí están pensados para el juego. [Anuncio NASA 24-136](https://www.nasa.gov/news-release/nasa-provides-update-on-artemis-iii-moon-landing-regions/) · [Catálogo anterior](catalogo_modelado_lunar.md)

**Crédito para el pitch.** «Cada mapa se inspira en una de las nueve regiones que NASA estudió para un aterrizaje tripulado cerca del polo sur lunar. La iluminación, la visibilidad de la Tierra y los riesgos del terreno influyen en nuestra simulación». La lista corresponde al estudio de 2024. En la actualización de noviembre de 2026, NASA describe Artemis III como una demostración en órbita terrestre y Artemis IV como el primer alunizaje previsto del programa. El orden y la dificultad de esta lista pertenecen al juego. [Informe técnico NTRS 20250011660](https://ntrs.nasa.gov/citations/20250011660) · [Actualización de NASA de noviembre de 2026](https://www.nasa.gov/missions/artemis/nasa-shares-plans-to-accelerate-artemis-return-to-moon/)

## Cómo producir y probar el kit

- **Escala y entrega.** Trabaja en metros. Las fichas indican **ancho × alto × fondo**, en X × Y × Z de Godot. En Blender, Z es arriba. En el GLB importado, verifica Y arriba, frente del equipo en +Z local y astronauta en −Z. Pasa el archivo editable `.blend`, el `.glb` y dos capturas, una superior y otra desde la cámara del juego. Mantén pivotes y animaciones en el editable. [Importación GLB en Godot](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html)
- **Proporciones.** Usa un cadete de 1,65 m para revisar la escala. Acomoda el terreno en un encuadre inicial de aproximadamente **32 × 18 m transitables**. El prototipo usa cámara ortográfica de **19,9**. Reencuadra si una meseta alta tapa el terreno o corta una estación. Revisa a **1280 × 720** y **1152 × 648**.
- **Pasos y pendientes.** Empieza con rutas de **2,0–2,3 m libres**, descansos de al menos **2,4 × 2,4 m** y rampas de alrededor de **1 m de desnivel por 4–6 m de avance horizontal**. Estas son metas de blockout. Prueba subida, giro y paso de dos cadetes con cajas antes de detallar. Conserva el anillo de acción despejado. Su diámetro de referencia es **1,37 m**.
- **Colisión.** Trabaja el terreno visible y el físico por separado. Usa un piso o una rampa suave en las zonas caminables, y cajas o formas simplificadas en paredes y equipamiento. Las rocas de fondo llevan solo malla visual. Identifica las guías físicas en Blender y deja que la escena de Godot cree sus colisiones. [Colisiones 3D en Godot](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/node_type_customization.html)
- **Pivotes y montaje.** Origen al centro de la planta y a nivel del suelo local. En una pendiente, el origen de rampa va en el centro del umbral inferior. En un panel abatible, el giro va sobre la bisagra. Usa nodos de referencia `socket_refugio`, `socket_refinado`, `socket_solar`, `socket_radio`, `socket_cohete`, `socket_hielo` y `socket_mineral`. Al colocar un equipo en una cota nueva, el punto de interacción y la zona del refugio también deben seguir esa cota.
- **Lenguaje visual.** Carcasas claras con bordes redondeados, estructuras gris oscuro y un acento por función. Cian y escudo para protección, verde y hoja para cultivo, ámbar y rayo para energía, violeta y antena para radio. Materiales mates, una paleta o atlas compartido de **512 × 512** como punto de partida y emisión acotada a guías o indicadores. Las medidas y presupuestos son orientativos. **Tris** significa triángulos del GLB exportado.
- **Tres estados ambientales.** Prepara una captura de luz directa, otra de noche o sombra y otra con alerta. Sol directo y visibilidad de la Tierra se prueban por separado. Un equipo puede recibir luz y tener la radio cortada. Señala sombra permanente con borde, pictograma y luz de balizas. La oscuridad del mapa debe permitir leer el piso, al compañero y la caja.

## Modelos compartidos

Son **18 fichas de kit común** y **27 fichas regionales**. Una ficha puede ser una malla nueva, una variante o un conjunto ensamblado con piezas existentes. Los tres modelos CC0 que el juego ya usa están en las fichas B06 y B09.

### A. Terreno, circulación y señales

| ID y archivo | Qué modelar y medidas de partida | Pivote, colisión y variantes |
| --- | --- | --- |
| **A01 · `regolito_kit.glb`** | Suelo neutro en sectores de **4 × 0,15 × 4 m**, con parches de polvo y bordes irregulares. Como base, **100–350 tris por pieza**. El detalle pequeño puede ir en textura o color de vértice. | Centro al nivel del suelo. Paños físicos planos. Tres materiales compartidos, gris neutro, gris frío y gris cálido. Alinea juntas y UV para evitar líneas entre sectores. |
| **A02 · `crater_kit.glb`** | Borde exterior, pared interior y fondo como piezas separadas. Diámetros de **2,7, 4 y 5,8 m**. **150–500 tris por variante completa**. | Pivote en centro de planta. Segmentos para borde abierto o cerrado. Usa collider suave si el cráter participa en la ruta. Los cráteres decorativos se quedan fuera del paso. |
| **A03 · `bloques_regolito.glb`** | Tres rocas medianas de **0,5–1,3 m** y tres bloques de **1,5–3 m**. Incluye un grupo bajo de grava. **40–220 tris por pieza**. | Pivote en la base. Bloque grande con guía física simple cuando separa rutas. Versión de horizonte solo visual. Las superficies con recursos llevan marcas distintas. |
| **A04 · `cresta_ladera_kit.glb`** | Segmento recto, curva y extremo de ladera. Tramo de prueba **5 × 1–3 × 3 m**. Separa cara iluminada, cara oscura y borde de meseta. **250–700 tris por tramo**. | Centro de apoyo inferior. Incluye tramo con boca para rampa. La ladera visual puede ser rugosa mientras la ruta física conserva pendiente regular. |
| **A05 · `rampas_y_descansos.glb`** | Rampa recta de **2,3 m de ancho y 4–6 m de avance**, descansillo **2,4 × 0,15 × 2,4 m**, giro y unión a pasarela. Añade borde bajo y flechas grandes de subida y bajada. **160–420 tris por pieza**. | Rampa en el umbral inferior, descansillo al centro inferior. Guarda marcadores de inicio y fin. Física continua, sin peldaños entre piezas. |
| **A06 · `pasarela_kit.glb`** | Tramo de **1,25 m** de largo, uniones L, T, cruce y remate. Usa franjas continuas para la ruta principal y marcas separadas para el atajo. **80–220 tris por pieza**. | Centro inferior con conectores en extremos. Espesor visual **0,06 m**. Adapta el modelo anterior conservando 2 m libres en los recorridos nuevos. |
| **A07 · `bordes_y_cables.glb`** | Barrera repetible **1,41 × 0,88 × 0,56 m**, barrera baja de borde, poste, cable plano y cruce de cable. **60–250 tris por pieza**. | Raíz al suelo y conectores en tramos. Colisión en barreras de ruta. Cable, flechas y marcas de suelo quedan a ras. Material oscuro con bandas visibles de noche. |
| **A08 · `balizas_y_placas.glb`** | Baliza de suelo, baliza de poste de **0,45–0,65 m**, placa para cruce y aro de interacción. Iconos de refugio, solar, batería, radio, hielo, salida y suministro. **40–180 tris por pieza**. | Centro inferior. Separa lente y cuerpo. Variantes luz fija, estado de alerta y apagado. El texto y la intensidad se muestran desde el juego. |
| **A09 · `tierra_horizonte.glb`** | Globo sencillo para tomas bajas, señal en relieve para el fondo 2.5D y pictograma de Tierra para la consola. **120–450 tris para el globo**. | Pivote al centro, sin colisión. Sitúa el globo en un anclaje cinematográfico `earth_direction`. En vistas donde el horizonte no cabe, usa la consola para indicar visibilidad. |

### B. Equipos de misión y piezas nuevas

| ID | Activo y especificación de producción |
| --- | --- |
| **B01 · Refugio y soporte vital** | Reutiliza la huella **5,8 × 5,75 m** y el kit en corte del catálogo anterior. Añade dos pedestales de **0,85 × 0,40 × 0,85 m** y faldón corto para emplazamientos inclinados. Pivote al suelo, soportes independientes con ajuste en Y. El piso de acceso queda plano y con **2 m libres**. |
| **B02 · Extracción y cajas** | Reutiliza cantera, taladro Mk2 y caja de **0,53 × 0,48 × 0,49 m**. Crea una boca de perforación de hasta **1,4 × 0,6 × 1,1 m** con broca, vetas opacas y placa de hielo o mineral. **300–650 tris**. Pivote al suelo, `extract` al frente. Representa hielo mediante vetas o testigos de perforación en el suelo. Reserva la silueta de cristal para el lenguaje del juego. |
| **B03 · Refinadora, cultivo y propelente** | Reutiliza las fichas 06, 07 y 10 del catálogo anterior. Entrega los tres equipos con frente de servicio separado del cuerpo trasero. Refinería con depósito y gota, cultivo con hojas, propelente con dos tanques. Mantén los orígenes en el suelo local y la entrada libre en cada nuevo emplazamiento. |
| **B04 · Panel y montura de cresta** | Reutiliza el panel de **2,9 × 0,16 × 1,38 m** y su eje de apertura. Crea una montura baja y otra de poste ajustable, de **0,65 × 1,18 × 0,65 m** como referencia. **200–450 tris por montura**. Separa bisagra y luz de generación. Sirve para Malapert, Plateau, Cabeus y de Gerlache. |
| **B05 · Batería y puerto de intercambio** | Reutiliza la carcasa de **0,83 × 1,24 × 0,80 m**. Añade cartucho extraíble **0,38 × 0,60 × 0,38 m** y cuna de dos bahías **1,8 × 0,85 × 0,75 m**. **350–850 tris por cuna**. Pivote al suelo, anclajes `pack_a` y `pack_b`. Segmentos físicos para carga y marca de vacío. |
| **B06 · Antena y radio** | Reutiliza plato y receptor CC0 de Kenney. Modela base baja y base elevada de **0,75 × 1,3 × 0,75 m** con soporte y un indicador de ventana. **250–500 tris por base**. Separa `dish`, `signal_light` y `earth_direction`. Iconos de enlace disponible, esperando y perdido. Las consolas locales conservan estado propio. [Modelos ya importados](../assets/props_luna/asset-register.md) |
| **B07 · Carga, cohete y embarque** | Reutiliza plataforma de **5,30 m** de diámetro, cohete de unos **4,25 m** de alto y los dos marcadores de asiento. Crea patas niveladoras de hasta **0,4 m** de alto para plataformas elevadas. Origen de plataforma al centro y marcas fuera de la huella del cohete. La ruta de aproximación requiere una superficie plana y visible. |
| **B08 · Suministros y puntos de entrega** | Reutiliza palé y paquetes. Añade una bandeja pasacajas de **1,1 × 0,75 × 0,65 m** y un soporte de intercambio de batería que use la cuna B05. **150–400 tris por bandeja**. Pivote al suelo, anclaje encima de la mesa. La bandeja puede ser una marca de relevo visual en viajes largos. |
| **B09 · Cadetes y animación de construcción** | Un rig de astronauta con dos variantes de uniforme, el transporte de Kenney, módulos plegados y efectos de luz o polvo. Mantén las mallas del refugio, el panel y el cohete iguales a las del juego. Separa patas, bisagras, tapas y `thruster_fx`. En Haworth se monta una cuna de batería en la toma donde el resto instala paneles. |

## Modelos y plano de cada mapa

El orden sigue la tabla del proyecto. En cada ficha, los tamaños son del recorte jugable. Para el fondo se puede ampliar o repetir la silueta de una pieza sin cambiar la escala del astronauta.

### 01 · Slater Plain · Fácil

**Plano.** Aterrizaje y refugio en el centro. Hielo en un extremo y refinadora al lado del campamento. Cohete al otro extremo. Dos rutas visibles desde el punto de inicio ayudan a aprender a transportar y pasar cajas.

| Modelo regional | Cómo construirlo |
| --- | --- |
| `slater_llanura.glb` | Paño abierto de **30 × 0,2 × 16 m**, con la mayor parte transitable a una cota y suelo ligeramente facetado fuera de ruta. Divide en sectores A01. Pivote en el centro inferior y un plano físico continuo. **600–1 600 tris**. |
| `slater_relieve_bajo.glb` | Dos lomos de **5 × 0,4–0,7 × 2,5 m** con grava dispersa y tres cráteres someros en márgenes. Centro al suelo, bordes suaves y bajo contraste. **150–450 tris por grupo**. |
| `slater_cruce_tutorial.glb` | Cruce abierto de **3,2 × 0,08 × 3,2 m** con las tres salidas marcadas en relieve. Usa A06, balizas A08 y mesa B08. Originado en el centro, a ras y sin resalto de colisión. **150–350 tris**. |

**Prueba de silueta.** El jugador distingue desde el inicio la caja que recoge, el punto de entrega y el camino de vuelta.

### 02 · Malapert Massif · Fácil

**Plano.** Base y extracción en la cota baja. Una subida ancha termina en un rellano con radio y horizonte hacia la Tierra. La recompensa por subir es una ventana de señal amplia en la simulación.

| Modelo regional | Cómo construirlo |
| --- | --- |
| `malapert_macizo.glb` | Ladera continua de aproximadamente **11 × 2,2 × 6 m**, con roca estratificada de caras anchas y un extremo cortado para el camino. Pivote en el pie del macizo. Guarda un proxy simple para las caras que limitan el paso. **700–1 600 tris**. |
| `malapert_subida_y_mirador.glb` | Dos tramos A05 hacia un mirador de **4 × 0,25 × 3,5 m**. Giro amplio, bordes bajos y espacio libre alrededor de `socket_radio`. La rampa se origina abajo y el mirador en su centro. **300–800 tris fuera del kit**. |
| `malapert_hito_tierra.glb` | Poste bajo de **0,55 × 0,7 × 0,55 m** con pictograma de Tierra y flecha al punto de radio. Base al suelo, colocada al borde de la pasarela. Combínalo con A09 y B06. **100–240 tris**. |

### 03 · Mons Mouton Plateau · Fácil

**Plano.** La meseta alberga campamento y paneles. El hielo se ve al fondo en un ramal más largo. Una bandeja intermedia divide el trayecto para que dos jugadores se pasen el material.

| Modelo regional | Cómo construirlo |
| --- | --- |
| `mouton_plateau_mesa.glb` | Plataforma natural ancha de **15 × 1,6–2,2 × 8 m**, con parte superior plana, borde quebrado y ladera en piezas A04. Pivote en la base y zonas de panel sobre superficie horizontal. **700–1 700 tris**. |
| `mouton_plateau_tramo_hielo.glb` | Ramal modular de **10–14 m** de recorrido, construido con plano A01, pasarelas y A05 donde cambie altura. Balizas repetibles a cada extremo y bandeja B08 en un descanso lateral. Sin rocas ni barandas dentro del ancho útil. |
| `mouton_plateau_pedestal_solar.glb` | Agrupación de paneles B04 sobre tres peanas alineadas. Un falso zócalo de **3,2 × 0,18 × 1,9 m** por panel simplifica la colocación. Anclaje inferior y bisagra del panel independiente. **100–250 tris por zócalo**. |

**Prueba de silueta.** Este mapa se reconoce por la cubierta superior ancha y el viaje largo. El siguiente mapa se reconoce por escalones, pendientes y giros.

### 04 · Mons Mouton · Medio

**Plano.** Tres terrazas escalonadas conectadas por rampas. La zona de soporte vital ocupa la terraza intermedia. Un itinerario continuo rodea la ladera y permite volver desde las cotas alta y baja.

| Modelo regional | Cómo construirlo |
| --- | --- |
| `mouton_terrazas.glb` | Tres plataformas de **6–9 × 0,5–1,2 × 4–6 m** en cotas de partida **0, +1,0, +2,0 m**. Cada una tiene borde rocoso, cara superior plana y conexión A05. Centro inferior por pieza. **350–800 tris por terraza**. |
| `mouton_recodo_y_rampa.glb` | Ensamble en zigzag con dos rampas A05 y descansos que admitan girar con caja. Añade flecha de subida y de bajada a cada nivel. Mantén el collider sin escalones y protege el borde exterior con A07. |
| `mouton_soporte_refugio.glb` | Banqueta con patas ajustadas a la ladera de **6,1 × 0,6–1,0 × 6,0 m** para el refugio B01. Origen al centro y piso de servicio nivelado con el descanso. Separa anclajes frontales de los pilotes. **450–850 tris**. |

### 05 · Peak near Cabeus B · Medio

**Plano.** Una cresta recibe Sol y alimenta el campamento. La ruta baja hacia una pared de cráter oscura para extraer hielo. El cambio entre zonas tiene un umbral visible y una ruta de regreso al refugio.

| Modelo regional | Cómo construirlo |
| --- | --- |
| `cabeus_pico_y_borde.glb` | Pico de silueta triangular de **8–12 × 2,0–3,0 × 4–6 m** con un banco horizontal para B04. Pivote en el pie. Ordena la ruta por el flanco despejado para mantener visible el punto solar. **600–1 400 tris**. |
| `cabeus_cuenco_hielo.glb` | Cuenco abierto de **9 × 2,4 × 7 m** con pared sombreada y boca de paso. Malla exterior, pared y piso extraíble por separado. Encaja rampa A05 y toma B02 al fondo. Provée una superficie física transitable y un borde de cráter visible. **600–1 400 tris**. |
| `cabeus_umbral_luz.glb` | Una faja de entrada de **2,3 × 0,08 × 1,25 m** y postes bajos con iconos de Sol y sombra. Anclaje al suelo en dos tramos. Emisión pequeña, sin collider en las placas. **100–250 tris**. |

**Referencia de hielo.** LCROSS encontró agua en material expulsado de una zona en sombra del cráter Cabeus. La cantera del mapa y su posición respecto del pico son una adaptación de juego. [LCROSS en Cabeus](https://science.nasa.gov/image-detail/20110615lcross/)

### 06 · Nobile Rim 1 · Medio

**Plano.** Borde de cráter con un hombro de roca que cruza la línea de visión. La radio se usa desde un ensanche de la cresta cuando vuelve la señal. El trabajo del campamento sigue disponible durante el corte.

| Modelo regional | Cómo construirlo |
| --- | --- |
| `nobile1_borde_y_hombro.glb` | Borde curvo modular de **10 × 1,5–2,5 × 4 m** y un bloque mayor de **3 × 2,4 × 2,5 m**. Separa el modelo visual del volumen que representa la obstrucción de señal. Pivote al suelo. **500–1 300 tris**. |
| `nobile1_banco_radio.glb` | Ensanche de **4 × 0,18 × 3 m** para B06, con área de giro al frente. Guarda `socket_radio`, `earth_direction` y un punto de espera visible. El equipo queda accesible por la misma pasarela al perder señal. **230–500 tris**. |
| `nobile1_senal_enlace.glb` | Placa de enlace de **0,6 × 0,55 × 0,25 m** y tres muestras de símbolo para disponible, esperando y perdido. Pivote al centro de base y luz en material independiente. **80–180 tris**. |

### 07 · de Gerlache Rim 2 · Difícil

**Plano.** Paneles sobre un filo con luz durante parte del ciclo. Hábitat y cultivo detrás de una pared larga que amplía la sombra de juego. La ruta hacia las baterías queda cerca del refugio.

| Modelo regional | Cómo construirlo |
| --- | --- |
| `gerlache2_muro_de_sombra.glb` | Cresta oblicua de **12 × 2,2–3,2 × 4 m**, con dos secciones y un perfil alto que proyecta la sombra a lo largo del campamento. Origen en el pie. Mantén la cara cercana baja en los puntos críticos de la cámara. **700–1 550 tris**. |
| `gerlache2_banco_solar.glb` | Albardilla de **6 × 0,35 × 2,6 m** con dos piezas B04 y conectores para cables A07. Pivote inferior, superficie plana y borde recortado. **220–500 tris** fuera de paneles y cables. |
| `gerlache2_carril_bateria.glb` | Faja de **3,6 × 0,10 × 2,2 m** que conecta B05 con el soporte vital. Símbolos grandes de rayo y refugio, guías luminosas bajas. Centro inferior, collider plano compartido. **120–300 tris**. |

**Prueba de silueta.** El jugador identifica dónde se genera energía de día y por dónde volver a la batería de noche.

### 08 · Nobile Rim 2 · Difícil

**Plano.** Campamento entre lomos de distinta altura. Los bloques forman dos rutas para transportar. La radio queda detrás de varias obstrucciones y abre pocas ventanas durante la misión. Prepara el relevo y la carga mientras se espera señal.

| Modelo regional | Cómo construirlo |
| --- | --- |
| `nobile2_lomos_escalonados.glb` | Tres masas irregulares de **4–7 × 1,3–2,8 × 2,5–4,2 m**, con varias caras compatibles con A03 y A04. Pivotes inferiores independientes y guías físicas simples. Conserva dos rutas libres, una directa con giros y otra larga y abierta. **320–750 tris por masa**. |
| `nobile2_pasos_de_carga.glb` | Dos esquinas anchas, un tramo serpenteante y un ensanche lateral de **2,8 × 0,15 × 2,5 m** para B08. Usa A05, A06 y señalización de salida a ambos lados. Sin saltos entre niveles ni escalones físicos. |
| `nobile2_relevo_radio.glb` | Pedestal para B06 de **0,9 × 1,4 × 0,9 m** y una placa de cola local de **0,60 × 0,45 × 0,20 m** con estado esperando y respuesta recibida. Base al suelo. **200–450 tris**. En la simulación, conserva mensajes pendientes durante el corte. |

**Prueba de silueta.** Nobile Rim 1 se reconoce por su único horizonte bloqueado. Nobile Rim 2 se reconoce por el corredor quebrado y la doble vuelta.

### 09 · Haworth · Difícil

**Plano.** Recorte del interior de cráter donde el juego representa sombra permanente. Las luces de camino y las baterías enmarcan la ruta del hielo al campamento. La introducción deposita las reservas de batería junto al refugio.

| Modelo regional | Cómo construirlo |
| --- | --- |
| `haworth_interior.glb` | Media pared curva de **13 × 2,5–3,5 × 7 m**, fondo escalonado y dos aperturas para cámara y salida. Usa dos tonos mates, azul grisáceo y carbón. Origen en el centro inferior. Físicas sencillas en bordes y piso plano en la zona principal. **800–1 800 tris**. |
| `haworth_vena_hielo.glb` | Afloramiento de **2,7 × 0,7 × 1,6 m** con vetas de hielo y estación B02 al frente. Separa herramienta y recurso. Usa luz puntual o baliza para verlo y conserva un símbolo en relieve. Pivote al suelo. **350–650 tris**. |
| `haworth_energia_y_guias.glb` | Banco de dos cunas B05 y doce instancias A08 entre zona de aterrizaje, hielo y refugio. Una bandeja para reservas de inicio y otra para la ayuda posterior. Pivote inferior por pieza. Las guías dibujan rutas y salidas con formas, además de color. |

**Criterio de juego.** En el recorte jugable la generación solar es cero. Planifica baterías iniciales y un suministro o reserva recuperable. La salida necesita su propia regla de ventana y de confirmación, como un relé con intervalos reales de juego o un protocolo local ficticio. Cuando se diseñe la misión, comprueba un recorrido de principio a fin con el mínimo de batería previsto y un pequeño desvío recuperable. [NASA · evidencia de hielo en regiones en sombra](https://science.nasa.gov/solar-system/moon/nasas-lro-lunar-ice-deposits-are-widespread/)

## Orden de modelado útil

1. **Kit gris y Slater Plain.** Haz A01, A05, A06 y A08. Coloca refugio, cantera y plataforma existentes. Prueba escala, recorrido y legibilidad. Luego haz el relieve visible de Slater.
2. **Contraste funcional.** Haz el plano de **Nobile Rim 1** para validar relieve y radio, y el de **Peak near Cabeus B** para validar el paso entre luz y sombra. Construye A02, A04 y los soportes B04–B06 durante esta fase.
3. **Variantes del kit.** Con la escala validada, completa Malapert, Mons Mouton Plateau, Mons Mouton, de Gerlache Rim 2 y Nobile Rim 2. Reutiliza tierra, rampas, estaciones y tramos. Modela sus siluetas y soluciones de ruta específicas.
4. **Haworth.** Verifica primero legibilidad con luz artificial, energía inicial y regreso de la cantera. Después termina su look y el montaje con baterías.
5. **Cinemática y acabado.** Reusa el mapa de juego para mostrar el descenso y el montaje. Captura cada mapa desde arriba y a tres cuartos, en el estado normal y durante el riesgo principal.

### Evidencia para la entrega y el jurado

- Si usas mapas de elevación de NASA, guarda **fuente, producto, recorte o coordenadas, resolución y vertical exagerada o comprimida**. PGDA ofrece GeoTIFF de topografía LOLA para varios lugares, como Malapert, Nobile Rim 1, Nobile Rim 2 y Haworth. También ofrece modelos mejorados para las trece zonas originales. Antes de atribuir un recorte a una de las regiones de 2024, comprueba límites y coincidencia espacial. [Topografía LOLA](https://pgda.gsfc.nasa.gov/products/78) · [Modelos de elevación mejorados](https://pgda.gsfc.nasa.gov/products/104)
- Registra por mapa dónde se camina, dónde cambia la exposición solar y dónde afecta el relieve a la radio. Distingue el relieve de referencia de las rutas, yacimientos, ciclos y reglas del simulador.
- Haz que una persona nueva identifique el refugio, la ruta de regreso y la causa de un cambio de luz o señal. Prueba con ambos cadetes y con carga desde las dos entradas del refugio. [Protocolo de observación](../tools/skills/probar-juego-con-ninos/SKILL.md)

### Estudio de integración NASA

El prototipo ya usa un recorte LOLA de Nobile como paisaje y un modelo del módulo Apolo en la introducción. Puede recuperarse el GLB de Nobile al construir Nobile Rim 1. Su encuadre y transformación actual se eligieron para el mapa jugable del prototipo. El relieve no determina por ahora la física ni el bloqueo de señal. [Archivos y recorte](../assets/props_luna/nasa/procedencia.md)

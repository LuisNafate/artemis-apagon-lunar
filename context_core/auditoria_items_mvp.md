# Auditoría de ítems de la campaña individual

El flujo público usa un astronauta, una caja a la vez y un perfil compartido por las nueve bases. El panel lateral muestra el objeto al alcance, su estado y la acción disponible. Las cargas en el suelo tienen prioridad al recoger. Los segundos y amaneceres salen de LunarMission. La interfaz solo los presenta.

| Ítem | Modelo o indicador | Interacción y requisito | Estado, resultado y respuesta | Verificación |
| --- | --- | --- | --- | --- |
| Mesa y muestra de práctica | Consola de la base y caja azul | Acercarse, tomar y entregar en la mesa | Disponible, transportada, suelta o entregada. Entregar abre el ciclo lunar. | MVP en nueve bases |
| Hielo de superficie | Depósito 3D del equipo | Extraer al alcance, con manos libres y sitio para la caja | Unidades, segundos restantes y agotamiento. Vuelve tras 2 amaneceres lejos o 4 cerca. | Campaña, mundo abierto y MVP |
| Mineral de superficie | Marcador de mineral facetado | Extraer bajo las mismas reglas que el hielo | Una caja por extracción; una entrega suma 1 mineral. | Campaña y mundo abierto |
| Taladro y extra del geólogo | Pico 3D, taladro montado y caja del recurso | Instalar con 2 minerales; recoger el extra al alcance del recurso correspondiente | Montaje, pausa eléctrica o instalación. El extra queda pendiente hasta poder recogerse. | Campaña y mundo abierto |
| Hielo transportado | Caja de hielo GLB | Recoger del suelo o entregar en Refinado | Una sola caja, suelta o con dueño. El hielo se consume al iniciar el refinado. | Campaña, mundo abierto y MVP |
| Mineral transportado | Caja facetada violeta | Recoger del suelo y almacenar en Refinado | Material disponible en el contador contextual de mejoras. | Campaña |
| Refinadora | Modelos vacío y lleno del equipo | Entregar hielo con energía y máquina disponible | Cuenta regresiva, pausa por energía y agua automática al terminar. Modelo lleno mientras procesa. | Campaña y MVP; inspección Forward+ |
| Agua | Tanque del equipo e ícono del HUD | Refinar hielo y asignarla a soporte, cultivo o propelente | Reserva viva; cada estación muestra costo o salida. | Campaña y MVP |
| Cultivos e invernadero | Domo y plantas del equipo | Sembrar sin carga y con agua; recoger una ración lista | Cultivo, pausa eléctrica, stock y recogida única por unidad. | Campaña y MVP |
| Ración | Paquete crema con sello verde | Recoger, entregar a la nave o consumir en el refugio | La unidad sale del inventario o stock al usarla. Saciedad y falta de stock visibles. | Campaña y MVP; inspección Forward+ |
| Propelente | Gabinete de dos compartimentos y bidón ámbar | Preparar con agua, recoger lote y cargar en la nave | Temporizador, pausa, stock y cuota. Lotes sueltos y transportados cuentan hacia la cuota. | Campaña y MVP; inspección Forward+ |
| Batería | Pilas y módulo auxiliar | Instalar con 2 minerales | Cuenta de montaje, espera eléctrica o batería auxiliar activa. Aumenta capacidad. | Campaña |
| Riego | Tanque y base de montaje | Instalar con 3 minerales | Cuenta de montaje o mejora activa. Cada cosecha produce más raciones. | Campaña |
| Red solar | Paneles y estación de prioridad | Cambiar entre cultivo y propelente | El botón muestra qué prioridad activará. El texto indica la actual; el aire conserva la prioridad superior. | Campaña |
| Refugio y oxígeno | Plataforma del refugio e ícono de aire | Entrar, refugiarse y comer cuando proceda | Aire, saciedad y condicionantes de agua y energía. Retirada al agotar el aire. | Campaña y MVP |
| Radio | Rover con antena | Enviar lista antes de abordar | Sin señal con tiempo restante, en tránsito, confirmada. La respuesta tarda 2,56 s según la simulación. | Campaña y MVP |
| Nave y plataforma | Etapas Apolo | Entregar tres lotes y dos raciones, confirmar radio y abordar | Requisitos, carga, cuenta, vuelo y regreso. El botón indica si falta carga o se suspende el abordaje. | MVP en nueve bases |
| Puerta y regreso | Muro, hoja corredera y flecha exterior | Acercarse por la ruta | Abre por proximidad; la flecha guía de vuelta. | Mundo abierto y MVP |
| Monedas | Saldo HUD, recibo y aviso de abono | Llegar al amanecer o completar el regreso por primera vez | Abono, compra, saldo y guardado. La economía los concede por hitos. | Campaña y MVP |
| Bases y roles | Fichas del globo y menú de roles | Comprar con el saldo exigido | Disponible, bloqueado, comprado o guardado. El rol seleccionado modifica su habilidad. | Campaña y MVP |
| Punto de control | Guardado del perfil y aviso de amanecer | Llegar al amanecer o guardar y salir | El guardado exacto conserva tiempos. La retirada recupera el estado del amanecer. | Campaña y mundo abierto |
| Palé de suministros de Cresta | Palé y paquetes del prototipo histórico | Recoger cuando llega el evento programado | Pendiente o cobrado. Un depósito lleno conserva la entrega. | Suite de Cresta |
| Refuerzo solar experimental | Registro de diseño VAC-17 | Pendiente de definición | Fuera del mapa interactivo de campaña. | Exclusión comprobada en campaña |

## Evidencia

- Reproducción original en Forward+. Una ración suelta fuera de estaciones existía en inventario de mundo y el panel permanecía oculto.
- Correcciones comprobadas. Carga soltada en el aire baja a la superficie; la recogida exige alcance y conserva un solo propietario; una ración lista espera si hay 24 cajas. Un lote de propelente suelto sigue contando para el límite de la misión.
- Refinado comprobado con entrada real desde la interfaz. Pulsaciones repetidas, pausa, guardado y recarga, agua abonada una vez y sustitución del modelo lleno por el vacío.
- Se comprobó el panel visible sobre una ración suelta, una refinadora llena y un gabinete de propelente en Forward+ a 1280 × 720. Las capturas se prepararon con inventario de prueba y están separadas del recorrido de las nueve bases.
- Queda pendiente una sesión de comprensión con jugadores nuevos y validación en dispositivos físicos. La campaña individual usa producción y depósitos; el palé programado figura en la escena histórica de Cresta.

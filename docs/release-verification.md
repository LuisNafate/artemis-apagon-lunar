# Verificación de la release v1.0.0

| Comprobación | Resultado |
| --- | --- |
| Exportación | Godot 4.7.2 en Windows. APK de release de 96,4 MB para `org.artemis.ultimaventana`, Android 7.0 o posterior y ARM64. |
| Firma e integridad | `apksigner` verificó las firmas v2 y v3. Se comprobó la integridad del ZIP y se publicó la suma SHA-256 con el APK. |
| Manifiesto | Versión 1.0.0, código 1, actividad de inicio, compilación sin depuración y permiso de internet ausente. |
| Recursos empaquetados | Se comprobaron la campaña, las dos cinemáticas, los datos científicos y la configuración. Se inició el contenido extraído del APK con Godot 4.7.2 en Windows. |
| Campaña individual | Campaña lunar y mundo abierto pasaron. La suite del MVP completó las nueve bases con 530 comprobaciones. La ruta con controles visibles completó una misión y verificó el regreso a Tierra. |
| Verificador general | Pasaron formato, lint, importación, arranque y las pruebas Academia, Puesto y 3D. La demo histórica Estación Cresta mantiene 22 fallos de su ruta de movimiento y no forma parte del APK. |
| Repositorio | 13 capturas WebP, verificación del Markdown y revisión de archivos y patrones comunes de credenciales en el historial. Sin coincidencias en el alcance revisado. |
| Instalación y uso en Android | Pendiente. El equipo de verificación no tenía un dispositivo Android conectado. |

La verificación del contenido en Windows comprueba recursos y arranque del juego. La instalación, el rendimiento y los controles táctiles en Android requieren una prueba en el dispositivo.

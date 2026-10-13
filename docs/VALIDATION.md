# Validación de preparación para publicar

Pruebas locales del 17–18 de septiembre de 2026.

## Completado

- Generación desde cero en una carpeta sin código previo: 183 archivos emitidos.
- Comparación de registros con la compilación funcional: las mismas 15.570
  direcciones después de recuperar las diez entradas que estaban añadidas a mano.
- Once pistas explícitas de funciones y dos tablas de saltos guardadas en el
  manifiesto; sus tamaños/destinos se contrastaron con el XEX abierto en IDA.
- Compilación Release completa del juego con Clang 22.1.3 y ReXGlue 0.10.0.
- Compilación independiente del configurador con MSVC 19.51; también compilado
  con Clang como parte del juego.
- Validación ejecutada en ambos configuradores: acepta la copia de referencia;
  rechaza carpeta vacía, XEX de tamaño incorrecto, XEX modificado manteniendo
  el tamaño y copia con DAT ausente o truncado.
- Revisión visual de la interfaz: ruta recordada, selector de pantalla,
  tamaño deshabilitado al elegir pantalla completa, textos sin recortes.
- Inicio del juego mediante el configurador en ventana 1280x720 y selección de
  pantalla completa; ajustes persistidos entre aperturas. Se observaron los
  logos y avisos iniciales renderizados en la compilación regenerada.
- Lectura del estado de audio de la compilación limpia: externalMusic=0,
  envelope=1 y volumen estéreo distinto de cero; hook de música activo.
- Exportación de fuentes por lista explícita. ZIP inspeccionado: conserva
  `.github`, `.gitignore` y `.gitattributes`; no contiene XEX, DAT, ISO, DLL,
  EXE, logs ni código generado. Generación repetida desde una de esas
  exportaciones para verificar que no depende del árbol de desarrollo.
- Creación de un candidato portable con binarios verificados contra los hashes
  de `build-info.json`, documentación, licencias y sumas SHA-256.

## Actualización de presentación (2026-09-19)

- Compilación del juego y launcher con Clang; launcher independiente con MSVC.
- Título `Bakugan: Defenders of the Core` e icono embebido compartido, vistos
  en las ventanas del juego y del configurador.
- Selector Desactivado/FXAA/FXAA Extreme, persistencia al reabrir y paso del
  argumento `--swap_post_effect` al juego comprobados.
- Con FXAA normal se observó el logo de NOWPRO. La primera observación con
  Extreme fue negra; esto no identifica por sí solo un fallo del filtro.
  Falta comparar ambos durante una partida y medir calidad/rendimiento.
- Las comprobaciones de copia válida, XEX modificado y datos ausentes o
  truncados siguieron pasando.

## No certificado todavía

- Partida completa, todos los modos y escenas, guardar/cargar y sesiones largas.
- Todas las resoluciones, DPI, monitores y modelos de GPU.
- Paquete en un PC limpio, sin el entorno de desarrollo.
- Instalación/desinstalación: Inno Setup no estaba instalado en el equipo; se
  preparó su script, pero no se compiló ni ejecutó el instalador.
- El workflow de GitHub está preparado; no se ejecutó en GitHub ni se publicó
  ningún repositorio o release.
- La DLL gráfica precompilada oficial no se probó; el candidato conserva la
  compilación propia confirmada por el autor.

La confirmación auditiva del arreglo de música pertenece a la sesión previa del
usuario. No se presenta la lectura de memoria como una nueva prueba auditiva.

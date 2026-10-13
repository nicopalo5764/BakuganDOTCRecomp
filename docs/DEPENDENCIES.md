# Dependencias verificadas

La instalación usada para la prueba es ReXGlue 0.10.0, Windows AMD64, con sello
de compilación `20260821_2216`. Véanse las huellas en `dependencies.lock.json`.
El nombre de versión por sí solo no identifica una DLL personalizada.

`rexglue.exe` y `rexruntime.dll` coinciden byte a byte con la release oficial
`rexglue-sdk-0.10.0-win-amd64.zip` (cuya huella también está en el lock).

Se aceptan dos `rexgpu-xenos.dll`, ambos probados por el autor:

- El de la release oficial 0.10.0 (`bin/rexgpu-xenos.dll`). Es el que usa
  `EasyBuild.bat` por defecto.
- Una compilación propia desde ReXGlue. Falta registrar el commit y las
  opciones exactas de esa compilación.

Cualquier otro DLL requiere `-AllowUnverifiedDependencies`. El script registrará
los hashes reales y el estado sin verificar. Tras probarlo, añádelo a la lista
`rexgpu_xenos` del lock con su origen.

Antes de una release pública binaria se debe documentar:

- URL/tag/commit del SDK exacto y cómo obtenerlo o compilarlo.
- Commit y opciones de compilación del complemento gráfico, o release oficial.
- Procedencia y licencia de `gamecontrollerdb.txt`.
- Licencias y requisitos de redistribución de las bibliotecas realmente
  incorporadas, incluidos FFmpeg/libmspack cuando corresponda. Copiar avisos
  no sustituye cumplir requisitos de código fuente o reenlazado aplicables.

La exportación contiene avisos recogidos de las fuentes locales del SDK; no se
afirma que esa colección certifique por sí sola la procedencia de cada binario.
No actualices hashes para ocultar una diferencia: verifica la nueva dependencia,
prueba el juego y registra el cambio de versión.

Referencias oficiales:

- https://github.com/rexglue/rexglue-sdk
- https://github.com/rexglue/rexglue-sdk/releases
- https://github.com/rexglue/rexglue-sdk/blob/main/LICENSE
- https://github.com/mdqinc/SDL_GameControllerDB

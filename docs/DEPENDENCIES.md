# Dependencias verificadas

La instalación usada para la prueba es ReXGlue 0.10.0, Windows AMD64, con sello
de compilación `20260821_2216`. Véanse las huellas en `dependencies.lock.json`.
El nombre de versión por sí solo no identifica una DLL personalizada.

Se comprobó que `rexruntime.dll` coincide con el SDK instalado, pero
`rexgpu-xenos.dll` de la versión funcional no coincide con el del SDK.
El autor confirmó que compiló ese complemento desde ReXGlue. Falta registrar
el commit y las opciones exactas de esa compilación.

Conserva el DLL funcional y pásalo mediante `-GpuPluginPath`. Para probar las
versiones precompiladas oficiales usa `-AllowUnverifiedDependencies`. El script
registrará los hashes reales y el estado sin verificar; no presupone que fallarán
ni que funcionarán. Tras probarlas, actualiza el archivo lock con sus huellas y
documenta el origen y los resultados.

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

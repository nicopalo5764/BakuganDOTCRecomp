# Recompilación reproducible

Usa `scripts/Build.ps1` con los tres parámetros del README. Ejecuta primero
`scripts/Verify-Game.ps1 -GameRoot "RUTA"` si solo quieres verificar la copia.
Los scripts no cambian la política de ejecución de PowerShell ni la seguridad
de Windows. Usa un entorno donde tengas autorizado ejecutar scripts locales.

El flujo desde una carpeta nueva es:

1. Validar SHA-256 y tamaño del XEX, y los tamaños de los tres DAT.
2. Verificar las huellas de generador, runtime y complemento gráfico.
3. Copiar exclusivamente las fuentes públicas a `out/recompile`.
4. Escribir rutas locales solo en el manifiesto de esa carpeta ignorada.
5. Ejecutar `rexglue codegen` **antes** de configurar CMake. Esto permite que
   CMake descubra todos los archivos generados en la primera compilación.
6. Compilar con el SDK fijado y copiar el complemento gráfico elegido.
7. Emitir `build-info.json` sin rutas privadas para identificar el resultado.

Para una prueba completamente limpia, exporta las fuentes a una carpeta nueva
con `scripts/Export-Source.ps1` y ejecuta Build.ps1 desde allí. No copies
`generated/`, `out/` ni caches del proyecto anterior. No ejecutes directamente
CMake sobre un checkout sin generar primero las fuentes.

## Direcciones manuales

La prueba limpia encontró diez registros añadidos a mano en el código generado
de la versión funcional. El antiguo `[functions]` estaba fuera de `[entrypoint]`
y el parser lo ignoraba. Ahora se conservan esas diez direcciones y el límite
explícito de `0x8248AE60` en `[entrypoint.functions]`:

| Inicio | Tamaño |
|---|---|
| `0x821BE858` | `0x70` |
| `0x821ED3B0` | `0x34` |
| `0x821FDDC0` | `0x08` |
| `0x82243258` | `0x38` |
| `0x8247F9B8` | `0x08` |
| `0x8247F9C0` | `0x08` |
| `0x8247F9C8` | `0x08` |
| `0x8247F9D8` | `0x08` |
| `0x8248AE60` | `0x18` |
| `0x8248AE78` | `0x18` |
| `0x825AF4F0` | `0x0C` |

Límites contrastados con las instrucciones del XEX en IDA. Build.ps1 comprueba
que todas estas entradas aparezcan en la tabla generada antes de compilar.

También había dos tablas de saltos corregidas a mano. Se conservaron como
`[[entrypoint.switch_tables]]`: 25 destinos en `0x821F6A28` (índice en r4,
no la dirección absoluta cargada en r11) y 14 en `0x8238FFB0` (índice en r11).
Sus destinos se leyeron del XEX en IDA. El script comprueba ambos switches
después de regenerar. Sin estas pistas, el generador emitía solo `case 0`.

Si una partida revela otra llamada sin registrar, conserva el log con la
dirección, comprueba su límite real en el XEX y añade la entrada a `[functions]`
en **el manifiesto de la raíz**, dentro de `[entrypoint.functions]`. Vuelve a ejecutar Build.ps1. No edites
`out/recompile` como fuente permanente ni añadas tamaños por aproximación.

## Correcciones y diagnósticos

El hook de música se compila siempre. Las trazas adicionales están desactivadas.
`BAKUGAN_MUSIC_TRACE=ON` permite instrumentar una compilación de diagnóstico.
Los antiguos hooks locales `audio_debug_hooks.cpp` no se exportan, porque
contenían cuerpos traducidos del juego; no son parte de la solución de BGM.

Para compilar solamente el configurador, sin SDK ni juego:

```powershell
cmake -S launcher -B out/launcher -A x64
cmake --build out/launcher --config Release
```

El configurador acepta `--validate "CARPETA"` sin abrir interfaz: código 0 si
la copia coincide, 2 si es incompatible/incompleta, 3 si ocurre un error de lectura.
`--configure` obliga a mostrar los ajustes, aunque se haya desactivado su apertura.

# Bakugan DOTC Recompiled

🇬🇧 [English](README.md) · 🇪🇸 **Español**

Proyecto comunitario experimental para ejecutar **Bakugan: Defenders of the
Core** (Xbox 360) de forma nativa en Windows x64 mediante una recompilación
estática con [ReXGlue](https://github.com/rexglue/rexglue-sdk). No es un
lanzamiento oficial ni está afiliado a los titulares del juego, Microsoft o Xbox.

**Estado: 0.1.0-preview.** El juego arranca y reproduce SFX, voces y música.
Todavía no se ha certificado una partida completa ni todas las configuraciones
de hardware. Consulta [problemas conocidos](docs/KNOWN_ISSUES.md).

> **Este repositorio no contiene ningún archivo del juego.** Ni el ejecutable,
> ni los datos, ni el código recompilado. Necesitas tu propia copia legal del
> juego de Xbox 360. El código C++ del juego se genera en tu equipo a partir
> de esa copia.

---

## Índice

1. [Requisitos](#1-requisitos)
2. [Preparar tu copia del juego](#2-preparar-tu-copia-del-juego)
3. [Descargar el proyecto](#3-descargar-el-proyecto)
4. [Compilación rápida: EasyBuild.bat](#4-compilación-rápida-easybuildbat) ← **lo más fácil**
5. [Compilación manual](#5-compilación-manual)
6. [Jugar](#6-jugar)
7. [Opcional: paquete portable e instalador](#7-opcional-paquete-portable-e-instalador)
8. [Solución de problemas](#8-solución-de-problemas)
9. [Para desarrolladores](#9-para-desarrolladores)

---

## 1. Requisitos

| Qué | Detalle |
|---|---|
| Sistema | Windows 10/11 **x64** (única plataforma probada) |
| GPU | Moderna, con drivers actualizados |
| Visual Studio 2022 | Carga de trabajo **Desarrollo para el escritorio con C++**, con los componentes **Herramientas de Clang de C++ para Windows** (LLVM) y **Herramientas de CMake de C++ para Windows** |
| ReXGlue SDK | Versión **0.10.0**, Windows AMD64. `EasyBuild.bat` lo descarga solo (manual: [paso 5.1](#51-conseguir-el-sdk-de-rexglue)) |
| Git | Opcional: también puedes descargar el proyecto como ZIP |
| Juego | Tu copia de Bakugan: Defenders of the Core (Xbox 360), ya extraída |
| Espacio en disco | ~4 GB para el juego + ~1 GB para la compilación |

No hace falta instalar CMake ni Ninja por separado: el script usa los que
trae Visual Studio y encuentra la instalación automáticamente.

---

## 2. Preparar tu copia del juego

Necesitas la carpeta **extraída** del disco (no la ISO). Si solo tienes la ISO
o el formato GOD, extráela siguiendo la
[guía de Xenia](https://github.com/xenia-project/xenia/wiki/Quickstart#how-to-rip-games).

La carpeta debe contener exactamente estos archivos:

```
Bakugan_TM__DOTC\
├── default.xex   (7.708.672 bytes)
├── d01.dat       (1.486.018.560 bytes)
├── d02.dat       (1.369.090.048 bytes)
└── d03.dat       (632.233.984 bytes)
```

Solo se admite el ejecutable identificado en [compatibility.json](compatibility.json):

- Title ID: `41560891` · Media ID: `01048E5A`
- SHA-256 de `default.xex`:
  `454b358a66585ed336dae4b9a44f00c2170a54dcd933a3b6f02cf21ed7863019`

No apliques actualizaciones ni sustituyas el XEX por el de otra edición: el
código recompilado depende de ese binario exacto.

---

## 3. Descargar el proyecto

```powershell
git clone https://github.com/nicopalo5764/BakuganDOTCRecomp.git
cd BakuganDOTCRecomp
```

Comprueba que tu copia del juego es compatible antes de seguir:

```powershell
.\scripts\Verify-Game.ps1 -GameRoot "C:\Juegos\Bakugan_TM__DOTC"
```

Si responde `Compatible executable and expected data sizes`, todo está bien.

> **Si PowerShell bloquea los scripts**, puedes permitirlos solo para la
> ventana actual (no cambia la configuración del sistema):
>
> ```powershell
> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
> ```

---

## 4. Compilación rápida: EasyBuild.bat

Con Visual Studio instalado (paso 1) y tu juego extraído (paso 2),
**haz doble clic en `EasyBuild.bat`** en la carpeta del proyecto. El script:

1. Te pide la carpeta del juego con un selector y la verifica.
2. Comprueba que Visual Studio tenga los componentes de C++, Clang y CMake. Si
   faltan, te dice qué instalar y puede instalarlos por ti con `winget`.
3. Descarga el SDK oficial de ReXGlue 0.10.0 (~43 MB) en `tools\` y verifica
   su huella.
4. Genera el código y compila, con tantos procesos en paralelo como permitan tu
   CPU y tu RAM.
5. Deja el launcher configurado con tu carpeta del juego y te ofrece abrirlo.

Recuerda la carpeta del juego para la próxima vez. Al terminar, el juego queda
en `out\build\publish-release\` y puedes pasar a [Jugar](#6-jugar).

> ¿No tienes Git? En la página de GitHub haz clic en **Code → Download ZIP**,
> descomprímelo y haz doble clic en `EasyBuild.bat`.

---

## 5. Compilación manual

Solo hace falta si quieres controlar cada paso.

### 5.1 Conseguir el SDK de ReXGlue

1. Descarga **ReXGlue 0.10.0 para Windows AMD64** desde las
   [releases oficiales](https://github.com/rexglue/rexglue-sdk/releases).
2. Descomprímelo en una carpeta fija, por ejemplo `C:\Herramientas`. Se crea una carpeta `win-amd64`.
   Esa carpeta (el *SdkRoot*) debe contener:

   ```
   C:\Herramientas\win-amd64\
   ├── bin\rexglue.exe
   ├── bin\rexruntime.dll
   └── include\rex\version.h
   ```

3. El complemento gráfico es `bin\rexgpu-xenos.dll`, dentro del SDK.

Las huellas SHA-256 de las herramientas probadas están en
[dependencies.lock.json](dependencies.lock.json). El SDK oficial coincide con
ellas, incluido su `rexgpu-xenos.dll`. También se acepta una compilación propia
del complemento hecha por el autor. Para cualquier otro DLL, añade
`-AllowUnverifiedDependencies`: el build quedará marcado como "pendiente de
validar". Más información en [dependencias](docs/DEPENDENCIES.md).

### 5.2 Generar y compilar

Desde la carpeta del proyecto, en PowerShell:

```powershell
.\scripts\Build.ps1 `
  -GameRoot      "C:\Juegos\Bakugan_TM__DOTC" `
  -SdkRoot       "C:\Herramientas\win-amd64" `
  -GpuPluginPath "C:\Herramientas\win-amd64\bin\rexgpu-xenos.dll"
```

Qué hace el script, en orden:

1. Verifica el SHA-256 del `default.xex` y el tamaño de los tres `.dat`.
2. Verifica la versión del SDK y las huellas de `rexglue.exe`, `rexruntime.dll`
   y `rexgpu-xenos.dll`.
3. Copia las fuentes del proyecto a `out\recompile` y escribe ahí la ruta de tu juego.
   Tu copia del juego y el manifiesto original no se modifican.
4. Ejecuta `rexglue codegen`, que traduce el XEX a C++ en `out\recompile\generated`.
5. Comprueba que las **11 funciones manuales** y las **2 tablas de saltos** del
   manifiesto quedaron en el código generado. Si falta algo, se detiene.
6. Configura CMake con Clang + Ninja y compila en modo Release.
7. Copia el complemento gráfico y escribe `build-info.json` con las huellas del resultado.

El resultado queda en:

```
out\build\publish-release\
├── bakugandotc.exe        ← el juego
├── BakuganLauncher.exe    ← configurador / lanzador
├── rexruntime.dll
├── rexgpu-xenos.dll
└── build-info.json
```

Opciones útiles:

| Opción | Efecto |
|---|---|
| `-Jobs 8` | Compilación en paralelo (por defecto 4; ajústalo a tus núcleos/RAM) |
| `-GenerateOnly` | Solo genera el código C++ y hace las comprobaciones, sin compilar |
| `-AllowUnverifiedDependencies` | Permite un SDK/DLL con huellas distintas a las probadas |

La primera compilación tarda bastante: se generan y compilan cientos de
archivos C++ grandes. Las siguientes son más rápidas.

---

## 6. Jugar

### Con el lanzador (recomendado)

1. Abre `out\build\publish-release\BakuganLauncher.exe`.
2. Selecciona la carpeta de tu juego (la del paso 2). El lanzador la valida.
3. Elige **ventana** o **pantalla completa** y, si quieres, el suavizado de bordes.
4. Pulsa **Jugar**.

El lanzador aparece en español o inglés según el idioma de Windows. Para
forzar uno: `BakuganLauncher.exe --lang=es` o `--lang=en`.

Los ajustes se guardan en `%LOCALAPPDATA%\BakuganDOTCRecomp\launcher.ini`.
Para volver a ver el configurador después de desactivarlo, ejecuta
`BakuganLauncher.exe --configure`.

### Directamente, sin lanzador

```bat
bakugandotc.exe --game_data_root="C:\Juegos\Bakugan_TM__DOTC" --gpu_plugin xenos
```

Puedes guardar esa línea en un `.bat` junto al ejecutable para no tener que escribirla cada vez.

### Mandos

Para mandos que no sean de Xbox, coloca un
[`gamecontrollerdb.txt`](https://github.com/mdqinc/SDL_GameControllerDB)
junto a `bakugandotc.exe`.

### Suavizado de bordes (FXAA)

El selector **Suavizado de bordes** ofrece Desactivado, FXAA y FXAA Extreme.
Es un filtro posterior al renderizado. No sube la resolución interna y también
puede suavizar textos. Por defecto está desactivado. Por línea de comandos:
`--swap_post_effect=fxaa`, `--swap_post_effect=fxaa_extreme` o `none`.

El tamaño de la ventana tampoco cambia la resolución interna. En pantalla
completa se usa la resolución del escritorio.

---

## 7. Opcional: paquete portable e instalador

**Paquete portable** (ZIP con binarios, docs, licencias y sumas SHA-256):

```powershell
.\scripts\Package.ps1 -SdkRoot "C:\Herramientas\win-amd64" `
  -ControllerDatabase "C:\Ruta\gamecontrollerdb.txt"
```

Se crea en `dist\`. Nunca incluye archivos del juego, código generado ni logs.

**Instalador** (requiere [Inno Setup 6](https://jrsoftware.org/isinfo.php)):

```powershell
ISCC.exe /DPackageDir="RUTA_ABSOLUTA_AL_PAQUETE" installer\BakuganDOTC_Setup.iss
```

El instalador está disponible en español e inglés.

Antes de distribuir binarios, revisa la [lista de publicación](docs/RELEASE_CHECKLIST.md)
y [cómo publicar](docs/PUBLISHING.md).

---

## 8. Solución de problemas

| Mensaje / síntoma | Causa y solución |
|---|---|
| `Missing default.xex` | `-GameRoot` no apunta a la carpeta extraída. Debe ser la carpeta que contiene `default.xex` directamente. |
| `Unsupported or modified default.xex` | Tu XEX no es la versión admitida (otra región, actualizado o modificado). Compara su SHA-256 con `compatibility.json`. |
| `Missing or unexpected size: d0X.dat` | Falta un `.dat` o la extracción quedó incompleta. Vuelve a extraer el disco. |
| `This project requires ReXGlue 0.10.0` | `-SdkRoot` apunta a otra versión del SDK o a la carpeta equivocada. Debe contener `include\rex\version.h`. |
| `Dependency hashes differ from the tested build` | Tu SDK o DLL no es uno de los probados. Usa la release oficial 0.10.0, o añade `-AllowUnverifiedDependencies`. |
| `Install Visual Studio with Desktop development with C++...` | Falta Visual Studio o la carga de trabajo de C++. |
| `Missing build tool: ...clang++.exe` / `ninja.exe` | Instala en Visual Studio los componentes **Clang** y **CMake** (paso 1). |
| `Codegen did not register required function 0x...` | El generador no aplicó las funciones del manifiesto. Comprueba que usas el SDK 0.10.0 y el `bakugandotc_manifest.toml` del repo sin modificar. |
| `Incomplete switch generated in sub_...` | Lo mismo pero para las tablas de saltos (`[[entrypoint.switch_tables]]`). |
| PowerShell: "la ejecución de scripts está deshabilitada" | Ver nota del [paso 3](#3-descargar-el-proyecto). |
| El juego se cierra al llegar a cierta escena | Puede ser una función sin registrar. Revisa el log y consulta la [sección 9](#9-para-desarrolladores). |
| Windows SmartScreen bloquea el `.exe` | Es un binario sin firmar compilado por ti. Comprueba su procedencia antes de permitirlo. |

Para informar de un fallo, abre un *issue* con la versión del proyecto, tu
hardware, el hash del XEX, los pasos para reproducirlo y el fragmento relevante
del log. Quita las rutas personales y **no adjuntes archivos del juego ni bases de IDA**.

---

## 9. Para desarrolladores

### Estructura

```
├── src/                        Código propio: entrada, hooks y Discord RPC
│   └── hooks/music_startup_hooks.cpp   Arreglo de la música (ver MUSIC_FIX.md)
├── launcher/                   Configurador/lanzador (Win32, independiente del SDK)
├── scripts/                    Build, verificación, empaquetado, exportación
├── bakugandotc_manifest.toml   Manifiesto de ReXGlue (funciones y switches manuales)
├── compatibility.json          XEX y DAT admitidos
├── dependencies.lock.json      Huellas del SDK y DLL probados
├── installer/                  Script de Inno Setup
├── docs/                       Documentación de build, validación y publicación
└── licenses/                   Licencias de terceros
```

Las carpetas `generated/`, `out/` y `dist/` se crean al compilar y están en
`.gitignore`. **No se deben subir**, porque contienen código derivado del juego
o binarios.

### Funciones que el generador no encuentra

ReXGlue no detecta por sí solo algunas funciones ni dos tablas de saltos del
juego. Están declaradas en `bakugandotc_manifest.toml`, dentro de
`[entrypoint.functions]` y `[[entrypoint.switch_tables]]`, así que se añaden en
cada regeneración. `Build.ps1` comprueba que estén.

Si una partida encuentra otra llamada sin registrar:

1. Guarda el log con la dirección que falla.
2. Comprueba el inicio y el tamaño reales de la función en el XEX (IDA o similar).
3. Añádela al manifiesto **de la raíz** dentro de `[entrypoint.functions]`:
   `0x8XXXXXXX = { size = 0xNN }`.
4. Vuelve a ejecutar `Build.ps1`.

No edites a mano el código de `generated/` ni de `out/recompile`: se
sobrescribe en cada build. Más detalles en [docs/BUILD.md](docs/BUILD.md).

### Compilar solo el lanzador (sin SDK ni juego)

```powershell
cmake -S launcher -B out/launcher -A x64
cmake --build out/launcher --config Release
```

`BakuganLauncher.exe --validate "CARPETA"` valida una copia sin abrir la
interfaz. Devuelve 0 si es compatible, 2 si es incompatible o está incompleta,
y 3 si hay un error de lectura. Esto es lo que ejecuta la integración continua.

### Opciones de CMake de diagnóstico

| Opción | Efecto |
|---|---|
| `BAKUGAN_MUSIC_TRACE=ON` | Compila trazas detalladas de reproducción de música |

---

## Licencia

Los aportes originales de este proyecto se distribuyen bajo la licencia
[MIT](LICENSE). Las dependencias conservan sus propias licencias (ver
[avisos de terceros](THIRD_PARTY_NOTICES.md) y `licenses/`). Esta licencia **no**
cubre el código ni los recursos originales de Bakugan: Defenders of the Core,
que pertenecen a sus respectivos titulares.

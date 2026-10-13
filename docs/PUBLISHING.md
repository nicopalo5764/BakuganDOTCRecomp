# Preparar GitHub y releases

## Fuentes

Ejecuta `scripts/Export-Source.ps1`. En `dist/` crea una carpeta y un ZIP
exclusivamente con los archivos públicos permitidos. Usa **esa carpeta** como
repositorio nuevo. No subas toda la carpeta de desarrollo.

La exportación excluye XEX/DAT/ISO, fuentes traducidas, DLL/EXE, SDK, bases de
IDA, configuración personal, logs, partidas y el historial local de trabajo.
Las correcciones están en el manifiesto y los hooks propios.

Desde la carpeta exportada puedes iniciar el repositorio:

```powershell
git init -b main
git add .
git status
git commit -m "Prepare reproducible Bakugan DOTC preview"
```

Crea un repositorio vacío en tu cuenta de GitHub, añade su URL real como
`origin` y publica `main`. Estas herramientas no crean cuentas/repositorios ni
suben nada automáticamente. Revisa la licencia MIT propuesta para los aportes
originales y los avisos de terceros antes de publicar.

## Paquete para jugadores

Después de una recompilación y prueba limpia:

```powershell
.\scripts\Package.ps1 -SdkRoot "D:\Herramientas\win-amd64" `
  -ControllerDatabase "D:\Dependencias\gamecontrollerdb.txt"
```

Solo copia archivos explícitos de `out/build/publish-release`, documentación,
avisos y la base de mandos aportada. Nunca copia el juego ni el TOML de debug
de una compilación anterior. Produce un candidato portable con sumas SHA-256.

Comprueba las DLL necesarias en un PC limpio: el hecho de que el paquete arranque
en el equipo de desarrollo no garantiza que incluya todas sus dependencias.
El instalador opcional se describe en `installer/INSTALADOR_LEEME.txt`.

Completa RELEASE_CHECKLIST.md, documenta las dependencias y revisa la distribución
del código recompilado antes de subir binarios. Los candidatos locales se marcan
como tales. No se publican automáticamente mediante GitHub Actions.

## Integración continua

El workflow incluido compila el configurador y comprueba su rechazo de carpetas
inválidas. No descarga el juego ni intenta recompilarlo en servidores públicos.
No adjuntes copias del XEX a issues ni como secretos de CI.

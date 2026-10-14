# Límites conocidos

- Solo se admite el XEX exacto identificado en compatibility.json.
- No se han validado otras regiones, revisiones ni actualizaciones del juego.
- Windows x64 tiene el flujo original de compilación y lanzador. Linux AMD64
  tiene un flujo experimental separado; véase [LINUX.md](LINUX.md) para las
  pruebas de pantalla de título y los errores de inicio pendientes de investigar.
  Los demás presets heredados no implican soporte probado.
- El tamaño de ventana no modifica por sí solo la resolución interna.
- La integridad de los DAT se comprueba por tamaño, no por contenido completo.
- Falta registrar el commit de la compilación propia del complemento gráfico.
- No se ha certificado una partida completa; podrían faltar funciones que solo
  se ejecutan en escenas o modos aún no probados.
- Discord Rich Presence forma parte del código existente; usa su integración
  original cuando Discord está abierto en Windows. En Linux no está implementado.
- El instalador es opcional y debe probarse con Inno Setup antes de distribuirlo.
- Si Windows bloquea un binario, registra el mensaje y comprueba su procedencia;
  estos scripts no cambian la configuración de seguridad para ejecutarlo.

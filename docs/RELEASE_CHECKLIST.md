# Pruebas de la versión preliminar

Registrar fecha, versión, GPU, controlador, sistema y hash del XEX al probar.
No marcar una prueba como realizada solo porque la compilación pasa.

- [x] Generación desde una exportación nueva sin fuentes generadas anteriores; compilación completa en una carpeta de trabajo nueva.
- [x] Verificar las once entradas manuales y las dos tablas de saltos.
- [ ] Arrancar usando únicamente el paquete portable en otro PC.
- [x] Rechazar carpeta vacía, XEX incorrecto y DAT ausente/truncado (Clang y MSVC).
- [ ] Probar carpeta con espacios y caracteres no ASCII.
- [ ] Probar ventana, pantalla completa y persistencia de ajustes.
- [ ] Volver al configurador después de ocultarlo al iniciar.
- [ ] Título y menú con música, SFX y voces.
- [ ] Cinemáticas con música y voces, incluyendo transiciones.
- [ ] Iniciar partida, combatir, terminar nivel y volver al menú.
- [ ] Guardar, cerrar y cargar una partida.
- [ ] Comprobar mandos y teclado utilizados por el juego.
- [ ] Sesión prolongada sin llamadas a direcciones sin registrar.
- [ ] Confirmar dependencias y commit/release del complemento gráfico.
- [ ] Revisar avisos, licencias y condiciones de distribución de los binarios.
- [x] Revisar el ZIP de fuentes; sin binarios, archivos originales, fuentes generadas ni datos privados.
- [ ] Revisar el ZIP binario definitivo y SHA256SUMS después de las pruebas de juego.

La prueba anterior al empaquetado confirmó música audible tras el hook de inicio.
La nueva configuración y la compilación sin hooks antiguos requieren sus propias
pruebas. Esta lista es para una preview; completar el juego requiere más cobertura.

Detalles de la validación automatizada y sus límites: `VALIDATION.md`.

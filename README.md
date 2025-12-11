# SenseiCastBar - Full Integration

Una barra de casteo completamente integrada con la infraestructura **SenseiClassResourceBar**, combinando:
- La arquitectura de barras de Sensei (BarMixin, configuración en Edit Mode, LEM)
- La lógica de eventos de cast/channel de FoesCatchyCastbar

## Instalación

1. **Coloca la carpeta `SenseiCastBar` en tu directorio de AddOns:**
   ```
   World of Warcraft/_retail_/Interface/AddOns/SenseiCastBar/
   ```

2. **Asegúrate de que `SenseiClassResourceBar` está instalado** (es una dependencia)

3. **Recarga la interfaz:** `/reload`

## Características

- ✅ **Barra de casteo funcional:** Aparece al castear/canalizar y se oculta al terminar
- ✅ **Integración completa con Sensei:** Configurable en Edit Mode junto con otras barras
- ✅ **Icono del hechizo:** Se muestra a la izquierda (configurable)
- ✅ **Nombre del hechizo:** Se muestra cuando casteás
- ✅ **Tiempo restante:** Muestra segundos restantes en el texto
- ✅ **Color de barrera:** Gris si el cast no es interrumpible, dorado/naranja por defecto
- ✅ **Soporte para Edit Mode:** Barra de ejemplo visible en modo edición

## Uso

### En Juego

1. **Entra en Edit Mode de Sensei** (`/sem` o el atajo configurado)
2. **Busca "Cast Bar" en la lista de barras** que Sensei te muestra
3. **Arrastra y posiciona** la barra donde quieras
4. **Haz clic derecho** para acceder a opciones de estilo/visibilidad

### Opciones Disponibles

- **Show Cast Bar Icon:** Mostrar/ocultar el icono del hechizo
- **Show Text:** Mostrar/ocultar el texto (tiempo restante)
- **Bar Visible:** Controlar cuándo se muestra (siempre, en combate, etc.)
- **Estilo:** Usar los mismos estilos de foreground/background de Sensei

## Troubleshooting

### La barra no aparece al castear
- Verifica en `/reload` que el addon se cargó sin errores
- Prueba en Edit Mode: debería aparecer una barra de ejemplo
- Intenta hacer `/cast Holy Light` (o cualquier hechizo) si no estás en combate

### El icono no aparece
- Abre Edit Mode y asegúrate de que **"Show Cast Bar Icon"** está activado
- Prueba cambiar la opción de visibilidad de la barra

### La barra aparece pero no se actualiza
- Esto indica un problema con eventos. Recarga (`/reload`) y prueba nuevamente
- Si persiste, revisa la consola de errores (`/script UIErrorsFrame:Show()`)

## Estructura del Código

```
SenseiCastBar/
├── SenseiCastBar.toc         # Manifiesto del addon
├── SenseiCastBar.xml         # Loader de script
├── CastBar.lua               # Lógica principal
│   ├── CastBarMixin          # Implementación del mixin (extiende BarMixin)
│   ├── Manejadores de eventos # UNIT_SPELLCAST_START, etc.
│   ├── Métodos de actualización # OnUpdate, UpdateDisplay
│   └── Configuración         # Registro en Sensei
└── README.md                 # Este archivo
```

## Desarrollo Futuro

Características opcionales a añadir:
- [ ] Spark visual (chispa en la punta de la barra) como FCCB
- [ ] Tails (colas) de color
- [ ] Indicador de latencia (lag safe-zone)
- [ ] Animación de fade-out al completar cast
- [ ] Sonidos al completar/interrumpir casteo

## Licencia

Creado como proyecto de integración. Combina:
- SenseiClassResourceBar (licencia original)
- FoesCatchyCastbar (lógica de eventos/estado)

## Soporte

Si encuentras problemas, revisa:
1. El archivo de registro de WoW (`Logs/World of Warcraft/Errors.txt`)
2. La consola de errores (`/script UIErrorsFrame:Show()`)
3. Que SenseiClassResourceBar esté cargado (`/addon list | grep -i sensei`)

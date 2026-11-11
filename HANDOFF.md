# Traspaso — El turno de la sal

Juego Android en Godot 4.3 basado en la historia de Richi (`docs/historia.md`). Richi dirige; el juego se compila con GitHub Actions y se instala en su Samsung (sin PC).

## Flujo
- Repo privado `iskyhigh00/GpA`, rama `main`. Cada push compila un APK firmado en debug y lo publica en el release `latest`.
- APK: https://github.com/iskyhigh00/GpA/releases/download/latest/el-turno-de-la-sal.apk (requiere login de GitHub).
- Hay actualizador dentro del juego (`scripts/updater.gd`). Keystore fijo en `ci/debug.keystore`.
- Estilo con Richi: español neutro, corto y directo, sin listas largas ni relleno, trato de igual a igual.

## Estado (commit 86a7511)
- Godot 4.3, renderer GL Compatibility, horizontal 1280x720. Toda la geometría se construye en GDScript. Multitouch manual en el HUD (`emulate_mouse_from_touch=false`).
- Modelos Quaternius (CC0) en `assets/personajes/`: Sira y el guardia integrados con animaciones mediante `scripts/model_rig.gd` (hereda de `Rig`, con respaldo al Rig procedural si falta el modelo). Tesa, Ivo y Roque solo importados.
- Animaciones: Idle/Walk/Run en bucle (se fuerza `LOOP_LINEAR` en código), Sword_Slash, Roll, HitRecieve, HitRecieve_2, Death. Patrones `scrub` y `oneshot`.
- Pantalla de título: `scenes/title.tscn` + `scripts/title.gd` (escena principal). Icono y arte en `assets/arte/` (`lonja.jpg` sin usar aún).
- `scripts/docs.gd`: 5 documentos (orden, dispensario → cap. 1; informe → cap. 2; censo, partes → cap. 3). Aún sin lector en el juego.
- Rendimiento (el celu se calentaba): `max_fps=40`, `scaling_3d/scale=0.7`, MSAA off, glow off, sombra direccional 1024 ortogonal a 26 m, partículas dust 40 / mist 14 / vapor 12, sin contador de FPS. Texturas con anisotrópico 1.

## Tests
```
godot --headless --import
godot --headless --fixed-fps 60 -s test/run_demo_tests.gd
```
Resultado actual: 114 comprobaciones, 0 fallos. En la sesión anterior Godot estaba en `/home/claude/tools/godot/Godot_v4.3-stable_linux.x86_64`; en otro entorno puede no estar.

## Hecho tras este traspaso
- Lector de folios en `hud.gd` (`open_docs`/`close_docs`, `<` `>` `Cerrar`, tecla ACCIÓN o Esc cierra, pausa el árbol) y papeles sobre la mesa del consultorio (`DESK_POS` en `level.gd`; ACCIÓN cerca de la mesa abre «orden» y «dispensario»).
- Sección 12 de las pruebas (123 comprobaciones, 0 fallos). Verificado con render que el texto cabe.

## Sonido (conectado)
- Originales de Richi en `assets/audio/` (muy largos y desparejos); versiones recortadas y normalizadas con ffmpeg en `assets/audio/juego/`. Los `amb_*` y `latido` llevan `loop=true` en su `.import`.
- `level.gd`: `_start_audio()` carga y sustituye los sintetizados (`beep`=campana, `clang`, `tray_roll`, `ice`, `cart_roll`, `gong`, `grate`, pasos en 3 variantes). Ambiente: 5 capas en bucle (mercado, olas, bomba, goteo, silbato). Reserva ≤ 35: latido que sube de volumen y una respiración (cada 30 s como máximo).
- Siguen sintetizados (`sfx.gd`): hit, swish, dodge, block, slam, pickup, alarm, perfect, door, push. En headless no se reproduce nada.

## Calidad gráfica elegible
- `scripts/quality.gd`: Baja (3D 60%, 30 FPS), Media (70%, 40 FPS, por defecto) y Alta (100%, 60 FPS, brillo y MSAA 2x). Botón en Ajustes; se guarda en `user://calidad.cfg`. Richi dijo que el juego se ve «mediocre»: probar Alta en el celu y decidir si el calor es aceptable.
- Consultorio con camilla armada, estantes con frascos, tubo neumático de latón y palangana. El cono de visión del guardia casi no se ve durante la persecución.

## Informe de QA (agente probador) y lo ya corregido
- Corregido: daño del gancho en el frame de contacto (0,13 s) y clip a ~1× (`SWING_TIME` 0,42); gancho y golpe pesado ya no atraviesan muros (`clear_line`); jugador y guardia colisionan; cámara más baja (pitch 0,58, dist 5,4) y los muros que tapan a Sira se vuelven translúcidos (material, no `transparency`: no funciona en Compatibility); campana y banner de la lámpara solo en la lonja; puerta oculta al abrir; carteles de una sola cara; charcos más claros; ruta «Sur (sin combate)»; hitstop 0,1 s y sacudida 0,3.
- Sin hacer (de su informe): segundo enemigo y más contenido (la demo dura ~12 s si se corre), auto-cámara/lock-on, luces cálidas y niebla de color, botones de combate más grandes con iconos y zona segura, gancho y bastón más gruesos, combo con `Punch_*`, animación `Death`, flecha al objetivo, resaltar bandeja y carro, ↻ con pulsación larga, SFX reales de combate, modelos propios góticos.

## Pendiente
1. Probar en el celu si bajó el calor. Si no, 30 FPS o escala 0.6.
2. Capítulos 2 y 3: usar `lonja.jpg`, los modelos Tesa/Ivo/Roque y los documentos informe/censo/partes.
3. Sonidos y música: Richi puede traerlos desde otras IA; integrarlos cuando lleguen.

## Avisos
- Nada visual se verificó con render (solo headless). La posición del bastón, el gancho y el casco en manos y cabeza puede necesitar ajuste.
- Documento 1: añadí "con apertura de la boca de emergencia en la tercera señal de marea" para cuadrar con la historia.
- Documento 2: tiene un matiz que no coincide del todo con la historia (no existe un "segundo informe").
- Si `git push` es rechazado, hacer `git pull --rebase origin main` y reintentar (Claude Code también sube cambios).
- `gh release view` no funciona en este entorno; usar `gh api repos/iskyhigh00/GpA/releases/tags/latest`.

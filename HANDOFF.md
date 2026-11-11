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

## Pendiente
1. **Lector de folios** en `hud.gd`:
   - Variables `doc_visible`, `doc_list`, `doc_page`; señal `docs_toggled(open)`.
   - `open_docs(list, page)` / `close_docs()` pausan el árbol y limpian toques, como `set_settings`.
   - Panel `Rect2(vs.x*0.5-540, 36, 1080, vs.y-72)`, papel `Color(0.86,0.82,0.7)`, tinta `Color(0.1,0.09,0.08)`. Título tamaño 30; cuerpo desde 24 y se reduce hasta 15 para que quepa. Botones "<", ">" y "Cerrar" con toque manual en `_press`.
2. **Interacción en `level.gd`**:
   - `const DESK_POS := Vector3(-13.5, 0.0, 2.8)` (mesa del consultorio).
   - Papeles sobre la mesa.
   - En `do_action`: si `flat_dist(p, DESK_POS) < 2.4` → `hud.open_docs(Docs.get_docs(["orden","dispensario"]))`.
   - Prompt "ACCIÓN: leer los folios de la mesa" en `_update_prompts()`.
3. **Tests nuevos** (sección 12): datos de Docs; abrir/siguiente/anterior/cerrar y pausa; prompt visible cerca de la mesa; la escena de título carga la textura y `start_game()` lleva a Main.
4. Probar en el celu si bajó el calor. Si no, 30 FPS o escala 0.6.
5. Capítulos 2 y 3: usar `lonja.jpg`, los modelos Tesa/Ivo/Roque y los documentos informe/censo/partes.
6. Sonidos y música: Richi puede traerlos desde otras IA; integrarlos cuando lleguen.

## Avisos
- Nada visual se verificó con render (solo headless). La posición del bastón, el gancho y el casco en manos y cabeza puede necesitar ajuste.
- Documento 1: añadí "con apertura de la boca de emergencia en la tercera señal de marea" para cuadrar con la historia.
- Documento 2: tiene un matiz que no coincide del todo con la historia (no existe un "segundo informe").
- Si `git push` es rechazado, hacer `git pull --rebase origin main` y reintentar (Claude Code también sube cambios).
- `gh release view` no funciona en este entorno; usar `gh api repos/iskyhigh00/GpA/releases/tags/latest`.

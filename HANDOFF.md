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

## Cámara tipo Blood Omen 2 y personajes (última pasada)
- Cámara pegada a la espalda (`player.gd`: `CAM_DIST` 3,3, pitch 0,2, hombro 0,28): se recoloca sola detrás de Sira al moverse (`CAM_FOLLOW`), se encara al guardia en CHASE/WINDUP/STUNNED/BLOCK (`CAM_LOCK`) y el arrastre del dedo la mueve a mano 2 s (`cam_manual_t`).
- `scripts/character_style.gd`: recolorea por nombre de material (los modelos usan color plano por pieza) y añade accesorios en huesos (en Torso/Chest/Neck/Head +Y arriba, +Z al frente, +X izquierda). Sira: abrigo largo con vaivén (`rig.coat`), bufanda, cuello, correa, cinturón, bolsas, coleta. Guardia: mochila oculta, casco con visera y cubrenuca, chaleco con bandas reflectantes, hombreras, farol con luz y llaves.
- Falta: gancho/bastón con mejor forma, combo con `Punch_*`, animación `Death`, caras con más detalle, rostros distintos para Tesa/Ivo/Roque.

## Recursos del zip de ChatGPT (integrados)
- Texturas: `brick_wall_10` (muro divisor), `metal_063` (tuberías y carro), `moss_wood` (puestos y cajones). Sonidos (preescuchas LQ de Freesound, CC0; originales pendientes por login): impacto del gancho, golpe recibido, bloqueo, caída (al morir) y puerta (abre). `puerta_cierra` está en `assets/audio/juego/` sin usar. Fuentes y licencias en `assets/LEEME_extra.txt`.

## Carteles y decales (tanda 3 de ChatGPT, integrados)
- `assets/carteles/` (5 carteles con texto en español) y `assets/decales/` (6 PNG transparentes). Imágenes generadas por IA para el proyecto (sin licencia CC0 externa; ver `assets/LEEME.txt`).
- `level.gd`: `_poster()` y `_decal()` (planos con transparencia; el renderer Compatibility no admite `Decal`) y `_build_decor_images()` con las posiciones. Sustituyen a las etiquetas «LOTE 14» y «SUBASTA POR SECTORES».
- De la tanda 3 aún no llegaron: modelos 3D de escenario, texturas extra, sonidos extra, música e iconos de botones.

## Cronología de folios y frases del guardia
- Orden de inundación fechada 13/11/2026 23:40 (antes decía 14/11, lo que la ponía ~23 h después de la nota del dispensario, 14/11 00:20, y del cierre de intendencia). Noche: ensayos 13/11 22:10-22:15 → orden 23:40 → dispensario 00:20 → cierre 01:00.
- `Level.bark()` muestra frases del guardia como subtítulo (alerta, pierde, ruido, golpe, ataque, derrota) sin pisar mensajes importantes.
- Material de DeepSeek revisado: solo se aprovecharon las frases del guardia. Descartado: diseño del cap. 2 (puzle de ritmo, guardia en el muelle y «canal viejo» no están en la historia; la historia pide reconfigurar cruces girando un pontón vacío con dos cabos), diálogo inicial (ignora que Sira despierta sin pulso en el consultorio), pensamientos de Sira (confunden la lámpara de riel y la bandeja con objetos de Sira), plan de pruebas (agachada, música, varios guardias: no existen) y números de combate (gancho 20 de reserva contradice el 2 acordado).

## Complemento de escenario (zip T3_08, integrado)
- `assets/modelos/` (glTF): `ancla` (Quaternius), `red_pesca` (Pixor), `gancho_carnicero` (OpenGameArt, 21 cm: se escala x3) y textura `glass_frosted_003` (3dtextures.me) usada en `Gfx.mat_glass()` para vitrales y ventana. Colocados en `Level._build_model_props()`. Fuentes en `assets/LEEME_complemento.txt`. Licencias CC0 afirmadas por ChatGPT; no verificadas por nosotros (revisar las fichas de Pixor, OpenGameArt y 3dtextures.me).
- Aún no llegaron de la tanda 3: barriles, farol, cadenas, camilla y demás modelos, texturas extra, sonidos extra, música e iconos.

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

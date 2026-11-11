# El turno de la sal · demo del capítulo 1

Demo de «La subasta a oscuras» (2–4 min), acción y terror portuario en tercera persona para Android (Godot 4.3, GL Compatibility). Toda la geometría y los sonidos se generan por código. La historia completa está en [docs/historia.md](docs/historia.md).

## Instalar el APK en el teléfono
1. En el teléfono abre la página de *Releases* del repositorio y entra al release **latest**.
2. Descarga `el-turno-de-la-sal.apk`.
3. Ábrelo y permite «instalar apps desconocidas» para el navegador cuando Android lo pida. Se reemplaza en cada build, así que desinstala la versión anterior si la firma cambia.

Para actualizar: en el juego abre ⚙ Ajustes → «Descargar e instalar». La app consulta el release «latest», descarga el APK y abre el instalador de Android (que siempre pide confirmar; la primera vez pide permitir «instalar apps desconocidas» para la app). Requiere que el repositorio sea público; si falla, usa «Abrir en el navegador». El APK se firma siempre con `ci/debug.keystore` (clave de depuración fija) para que Android acepte actualizar sobre la versión anterior.

El APK lo compila GitHub Actions (`.github/workflows/android.yml`) en cada push a `main` o a mano con *Run workflow*.

## Cómo se juega
- Stick flotante en la mitad izquierda; arrastra en la derecha para la cámara.
- **GANCHO** golpea (2 golpes desarman al guardia; cada tercer golpe lo bloquea). **ESQUIVA** da una voltereta con invulnerabilidad: el golpe pesado del guardia se anuncia con un aro rojo en el piso, y esquivar justo antes del impacto lo aturde. **FUERZA** arranca el carro de hielo (−35 de reserva), **ACCIÓN** empuja la bandeja o abre el botiquín, **AMPOLLA** restaura 50 de reserva.
- Norte: sigilo con la bandeja (su ruido atrae a la lámpara y al guardia). Sur: combate. Las dos rutas terminan en el carro; al arrancarlo se abre la rejilla y bajas por el hueco.

## Probar en el computador
1. Abre la carpeta con Godot 4.3 y pulsa F5.
2. Teclas: WASD mover · J gancho · Espacio esquiva · K fuerza · E acción · R ampolla · T volver al punto de control. El ratón actúa como un dedo (mitad izquierda stick, mitad derecha cámara).
3. Pruebas automáticas:
   ```
   godot --headless --path . --import
   godot --headless --path . --fixed-fps 60 --script res://test/run_demo_tests.gd
   ```

## Personajes
Sira y el guardia usan modelos 3D de Quaternius (CC0) con sus animaciones, en `assets/personajes/` (crédito y licencia en `Creditos_y_licencia.txt`). Tesa, Ivo y Roque ya están importados para los siguientes capítulos. Si un modelo no carga, el juego usa la figura provisional hecha por código (`scripts/rig.gd`). La integración está en `scripts/model_rig.gd`.

# Capítulo 2 · Un barrio que flota (referencia de diseño)

Origen: borrador de DeepSeek revisado contra `docs/historia.md`. Es diseño en papel; no está implementado.

## Reglas
- Puzle solo espacial. Sin guardias ni sigilo.
- Cabo azul (freno) al noray norte; cabo rojo (corriente) al noray sur. El manual dice lo contrario y Sira lo comprueba en el noray.
- El jugador elige pontón y a qué noray amarra cada cabo. Toca el cabo y lo arrastra al noray.
- Antes de soltar, la pantalla muestra el arco del giro (línea punteada sobre el agua). Si el arco llega a la casa pareja, el cruce conecta; si no, no.
- Al soltar, el pontón gira, forma un puente y las familias cruzan.

## Cruces (propuesta)
1. Casa 1 (Ivo) ↔ Casa 4 (Nieves). Pontón 7.
2. Casa 7 (Tomás) ↔ Casa 9 (Elías). Pontón 4.
3. Casa 11 (Onofre) ↔ Casa 12 (Lucía). Pontón 9.

## Avance y fallos
- La niña marca con tiza cada casa revisada: ese es el marcador de avance.
- La mayoría sube a la cornisa intermedia; quienes siguen abajo llegan al punto de reunión por la misma ruta.
- Fallo 1: noray equivocado, el arco no llega y el cruce no conecta.
- Fallo 2: un cabo se suelta y el pontón se aleja con la corriente; hay que recuperarlo.
- Reintento: se vuelve al último cruce y los cabos se reponen.

## Final
- El jugador elige el cajón del montacargas (reservas de la enfermería o matrices de bomba), a la vista de Ivo.
- Aparece la placa «Salida de Cendal». Sira reconoce su firma. Ivo cuenta que su madre murió durante la prueba del cierre y le pide recuperar el informe completo.

## Diálogo (orden corregido)
```
dlg2_1: Ivo: El pontón gira con dos cabos. Azul al norte, rojo al sur.
dlg2_2: Sira: El manual dice lo contrario.
dlg2_3: Ivo: El manual miente. Compruébalo en el noray.
dlg2_4: Sira: Azul frena. Rojo empuja. ¿Correcto?
dlg2_5: Ivo: Correcto. Elige pontón y noray para cada cruce.
dlg2_6: Sira: Antes de soltar, veo el arco del giro.
dlg2_7: Ivo: Si el arco no llega, el cruce no conecta.
dlg2_8: Sira: Suelto. El pontón gira. Las familias cruzan.
dlg2_9: Sira: La placa dice «Salida de Cendal». Es mi firma.
dlg2_10: Ivo: Mi madre murió durante la prueba del cierre. Recupera el informe completo.
```

## Dudas abiertas
- Qué prueba del cierre fue y si Sira conocía a la madre de Ivo.
- Qué contiene cada cajón más allá de la etiqueta.
- Los pontones 4 y 9 no aparecen en los folios.

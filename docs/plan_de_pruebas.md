# Plan de pruebas de la demo del capítulo 1 (Samsung)

Origen: borrador de DeepSeek corregido contra el juego real. Controles reales: stick flotante, arrastre en la mitad derecha para la cámara, GANCHO, ESQUIVA, FUERZA, ACCIÓN, AMPOLLA, ajustes ⚙, reinicio ↻.

```
check_01: Stick flotante. Probar movimiento en la lonja.
check_02: Arrastre en mitad derecha. Probar giro de cámara.
check_03: Botón GANCHO. Ver coste 2 de reserva.
check_04: Botón ESQUIVA. Ver tiempo de aviso del guardia y la esquiva perfecta.
check_05: Botón FUERZA. Ver coste 35 de reserva junto al carro de hielo.
check_06: ACCIÓN empuja la bandeja y abre el botiquín. FUERZA (35) mueve el carro al contrapeso; la rejilla se abre sola.
check_07: Botón AMPOLLA. Ver recuperación de 50 de reserva.
check_08: Ajustes ⚙. Probar el selector de calidad gráfica (Baja, Media, Alta).
check_09: Reinicio ↻. Probar punto de control tras fallo.
check_10: Ruta norte. Sigilo con bandeja. Ver que el guardia investiga.
check_11: Ruta sur. Combate con un guardia. Música ambiental con capas, sin pistas de música.
check_12: Lector de folios en la mesa del consultorio. Solo orden de inundación y nota del dispensario.
check_13: Cámara pegada a la espalda. Verificar que se recoloca sola y que se encara al guardia en combate.
check_14: Audio. Pasos, agua y capas reales. Sin golpe doble.
check_15: Rendimiento. Medir FPS en la rejilla y en la lonja.
check_16: Calor. Medir temperatura del teléfono tras 10 minutos.
check_17: Tiempo de carga. Medir inicio de partida y cambio de escena.
check_18: Batería. Medir consumo en 15 minutos.
check_19: Guardia único. Verificar que no aparece un segundo guardia.
check_20: Sin agacharse. Verificar que no hay botón de agacharse.

bug_01: Qué hice:
bug_02: Qué esperaba:
bug_03: Qué pasó:
bug_04: Cuántos FPS:
bug_05: Cuánto tardó en calentarse:
```

## Barrido de la lámpara en el paso norte

| Ajuste de RailLamp | Antes | Después |
| --- | ---: | ---: |
| Radio del círculo | 2,3 m | 4,4 m |
| Velocidad sobre el riel | 2,8 m/s | 4,0 m/s |
| Exposición para detectar | 0,5 s | 0,5 s |
| Distracción tras el golpe de la bandeja | 8 s | 8 s |

El paso mide 3 m de ancho (z de −8 a −5). Su borde más lejano queda a 4,27 m del centro del círculo cuando la lámpara está en un extremo del riel.

La prueba headless cruza a velocidad máxima por el centro y ambos lados del paso, con diez tiempos de salida repartidos por todo el barrido. Antes del ajuste, la lámpara detectó 6 de 10 intentos. Con el ajuste detectó 10 de 10. La prueba de ruta norte comprueba que se puede cruzar con la bandeja antes de que terminen los 8 s y sin alertar al guardia.

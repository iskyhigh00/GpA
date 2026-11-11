class_name Docs
extends RefCounted
## Folios que Sira puede leer. «cap» es el capítulo donde aparecen; la demo usa «orden» y «dispensario».

const ALL: Array[Dictionary] = [
	{
		"id": "orden", "cap": 1,
		"titulo": "ORDEN DE INUNDACIÓN DE EMERGENCIA",
		"texto": """Folio DO-2026-114 · Puerto Lumbre, 14/11/2026, 23:40
De: Dirección de Operaciones Portuarias
A: Elvira Roldal, jefa de El Telar; Roque Beltrán, capataz de cuadrillas
Asunto: habilitación del sector La Taza como depósito de emergencia por grieta en el rompeolas.

1. Ejecutar inundación controlada del sector La Taza mediante canal viejo y bombas de El Telar, con apertura de la boca de emergencia en la tercera señal de marea.
2. El sector figura como deshabitado según certificado IC-2019-073, censo 0. No procede aviso vecinal ni alarma.
3. Mantener comunicación oficial de “apertura parcial” hasta revisión técnica.
4. Registrar hora de inicio y cierre de compuertas.

Firma: Hernán Vela, director de Operaciones. Refrendo: Marta Quiles, secretaria técnica.""",
	},
	{
		"id": "dispensario", "cap": 1,
		"titulo": "NOTA INTERNA DEL DISPENSARIO DE SANGRE",
		"texto": """Folio DS-2026-118 · Puerto Lumbre, 14/11/2026, 00:20
De: Tesa Brumal, médica de lonja
A: Personal de dispensario
Asunto: acceso a ampollas municipales.

Se restringe la entrega de ampollas municipales a retiro con orden médica nominal. Excepción vigente: Elvira Roldal, jefa de El Telar, autorizada para retirar “kit de bombeo” y ampollas de adrenalina sin orden. Roque Beltrán figura como segundo autorizado. Vecinos de La Taza no constan en lista de acceso.

Inventario: faltan seis ampollas desde las 22:30 del 13/11/2026. Llave de vitrina: copia en El Telar. Registrar toda entrega en folio aparte.

Firma: Tesa Brumal.""",
	},
	{
		"id": "informe", "cap": 2,
		"titulo": "INFORME DE INSPECCIÓN Y PRÓRROGA DE CIERRE",
		"texto": """Folio IC-2019-073 · Puerto Lumbre, 07/03/2019
Inspectora: Sira Cendal. Sector: La Taza.

Visita de verificación por deterioro de pontones. Se constata ausencia de residentes permanentes. Censo adjunto: 0. Se observan ropa tendida y conexiones de agua activas, sin relevancia administrativa. Se recomienda cierre provisorio por seis meses.

Prórroga: 07/09/2019. Se prorroga el cierre provisional hasta nueva inspección. No se fija fecha de reapertura. El sector queda excluido de censo operativo y de avisos de emergencia.

Firma: Sira Cendal, inspectora. Visto bueno: Hernán Vela, Dirección de Operaciones. Registro: Marta Quiles.""",
	},
	{
		"id": "censo", "cap": 3,
		"titulo": "CENSO INTERNO DE LA TAZA (COPIA NO REGISTRADA)",
		"texto": """Folio CT-2026-12 · Puerto Lumbre, 12/11/2026
Relación de familias residentes:

1. Ivo Luján, estibador, Casa 1.
2. Marisa Cetina, cocinera de lonja, Casa 2.
3. Damián Olmos, calafate, Casa 3.
4. Nieves Arque, lavandera, Casa 4.
5. Bruno Salces, redero, Casa 5.
6. Alba Ferrán, pescadera, Casa 6.
7. Tomás Riel, mecánico de bombas, Casa 7.
8. Vera Canto, costurera de velas, Casa 8.
9. Elías Pardo, vigilante nocturno, Casa 9.
10. Nerea Biel, conservera, Casa 10.
11. Onofre Dúo, jubilado de muelle, Casa 11.
12. Lucía Mena, maestra de lonja, Casa 12.

Total: 12 familias, 41 personas. Copia retirada del registro por orden verbal de Elvira Roldal. No foliar.""",
	},
	{
		"id": "partes", "cap": 3,
		"titulo": "DOS PARTES DE ACCIDENTE",
		"texto": """PARTE A · Folio PA-2026-041-A · 13/11/2026, 22:10
Operario herido: Nadir Pons, auxiliar de válvulas. Testigo: Fermín Oria, capataz de turno.
Durante ensayo de descarga del canal viejo, ordenado como “apertura parcial”, observé el manómetro de la línea sur. La aguja superó la marca roja de 4.2 y se detuvo en 6.8. Informé a Roque Beltrán. Respondió: “Sostener y no corregir hasta nueva orden”. Cinco minutos después se produjo retorno de presión y quemadura por salmuera en antebrazo izquierdo. El registro de sala consigna “parcial”.
Firma: Nadir Pons. Refrendo: Fermín Oria.

PARTE B · Folio PA-2026-041-B · 13/11/2026, 22:15
Operario herido: Orencio Vidal, ayudante de compuerta. Testigo: Paula Sedano, operaria de bombeo.
Escuché tres golpes secos en el tope de la compuerta. Al revisar la marca, el indicador estaba alineado con “TOTAL”, no con “PARCIAL”. Informé a Elvira Roldal. Ordenó: “Anotar apertura parcial y cerrar el parte sin copia”. Al manipular el volante de cierre recibí golpe en la mano derecha. La compuerta siguió abierta hasta las 22:40. No se activó alarma.
Firma: Orencio Vidal. Refrendo: Paula Sedano.""",
	},
]


static func get_docs(ids: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in ids:
		for d in ALL:
			if d["id"] == id:
				out.append(d)
	return out

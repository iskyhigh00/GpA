extends SceneTree
## Pruebas de la demo. Ejecutar:
## godot --headless --path . --fixed-fps 60 --script res://test/run_demo_tests.gd

var fails := 0
var checks := 0
var monitor := Callable()


func _initialize() -> void:
	_run()


func _run() -> void:
	await _t1_tutorial()
	await _t2_north()
	await _t3_south()
	await _t4_low_reserve()
	await _t5_checkpoint()
	await _t6_lamp_signal()
	await _t7_lamp_detects()
	await _t8_buttons()
	await _t9_dodge()
	await _t10_settings()
	await _t11_models()
	await _t12_docs()
	await _t13_audio()
	await _t14_quality()
	await _t16_decor()
	await _t17_barks()
	await _t18_models()
	await _t19_dialogue()
	await _t20_docs_cap2()
	await _t15_combat_fixes()
	await _frames(10)
	print("\n%d comprobaciones, %d fallos" % [checks, fails])
	quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- ayudas

func check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("  ok   ", msg)
	else:
		fails += 1
		print("  FAIL ", msg)


func new_level(skip: bool = true) -> Level:
	monitor = Callable()
	var lv := Level.new()
	root.add_child(lv)
	await _frames(5)
	if skip:
		lv.skip_tutorial()
		await _frames(2)
	return lv


func free_level(lv: Level) -> void:
	lv.queue_free()
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func until(cond: Callable, max_frames: int = 900) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await physics_frame
		if monitor.is_valid():
			monitor.call()
	return cond.call()


func walk(lv: Level, target: Vector3, tol: float = 0.35, max_frames: int = 900) -> bool:
	var pl := lv.player
	for i in max_frames:
		var to := target - pl.global_position
		to.y = 0.0
		if to.length() < tol:
			pl.sim_move = Vector2.ZERO
			return true
		var d := to.normalized()
		pl.sim_move = Vector2(d.dot(pl.cam_right()), -d.dot(pl.cam_forward()))
		await physics_frame
		if monitor.is_valid():
			monitor.call()
	pl.sim_move = Vector2.ZERO
	return false


func walk_path(lv: Level, pts: Array[Vector3]) -> bool:
	for p in pts:
		if not await walk(lv, p):
			print("    (no llegó a ", p, " está en ", lv.player.global_position, ")")
			return false
	return true


func touch(lv: Level, idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = pressed
	lv.hud._input(e)


func drag(lv: Level, idx: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	e.relative = rel
	lv.hud._input(e)


func through_door(lv: Level) -> void:
	await walk_path(lv, [Vector3(-7.0, 0.1, 0.0), Vector3(-3.0, 0.1, 0.0)])


func guard_not_alerted() -> void:
	pass


# ---------------------------------------------------------------- pruebas

func _t1_tutorial() -> void:
	print("1) Tutorial")
	var lv := await new_level(false)
	check(not lv.door_open and lv.tutorial_step == 1, "empieza con la puerta cerrada en el paso 1")
	var yaw0 := lv.player.cam_yaw
	touch(lv, 1, Vector2(1000, 360), true)
	for i in 80:
		drag(lv, 1, Vector2(1000 + i, 360), Vector2(-20, 0))
		await physics_frame
		if lv.door_open:
			break
	touch(lv, 1, Vector2(1000, 360), false)
	check(lv.player.cam_yaw != yaw0, "la cámara giró con el arrastre")
	check(lv.cam_progress >= 1.0 and lv.door_open, "el paso 1 se completa y la puerta se abre")
	check(lv.tutorial_step == 2, "pasa al paso 2")
	await _frames(90)
	check(lv.door_shape.disabled and lv.door_body.position.y > 3.0, "la puerta ya no bloquea")
	check(not lv.checkpoint_saved, "aún no hay punto de control")
	# Caminar con el stick táctil hacia la puerta y cruzarla.
	var origin := Vector2(200, 500)
	touch(lv, 2, origin, true)
	for i in 600:
		var to := Vector3(-2.0, 0.0, 0.0) - lv.player.global_position
		to.y = 0.0
		if to.length() < 0.4:
			break
		var d := to.normalized()
		var v := Vector2(d.dot(lv.player.cam_right()), -d.dot(lv.player.cam_forward()))
		drag(lv, 2, origin + v * 80.0, Vector2.ZERO)
		await physics_frame
	touch(lv, 2, origin, false)
	check(lv.player.global_position.x > -4.0, "Sira cruzó la puerta con el stick táctil")
	check(lv.checkpoint_saved and lv.phase == Level.Phase.PLAY, "se guardó el punto de control")
	check(lv.hud.move_vec == Vector2.ZERO, "el stick se suelta")
	await free_level(lv)


func _t2_north() -> void:
	print("2) Ruta norte sin combate")
	var lv := await new_level()
	await through_door(lv)
	check(lv.checkpoint_saved, "punto de control al cruzar")
	var g := lv.guard
	monitor = func() -> void:
		if g.state == Guard.S.CHASE or g.state == Guard.S.WINDUP:
			check(false, "el guardia se alertó")
			monitor = Callable()
	check(await walk(lv, Vector3(-3.2, 0.1, 8.2)), "llega a la bandeja")
	lv.do_action()
	check(lv.tray.state == Tray.S.ROLLING, "la bandeja rueda")
	check(await walk(lv, Vector3(-1.0, 0.1, -3.5)), "espera cerca del paso norte")
	check(await until(func() -> bool: return lv.lamp.state == RailLamp.S.ATTRACTED), "la lámpara es atraída")
	check(g.state == Guard.S.INVESTIGATE, "el guardia va a investigar")
	check(lv.tray.state == Tray.S.SPENT, "la bandeja llegó (clang)")
	var ok := await walk_path(lv, [Vector3(5.0, 0.1, -6.5), Vector3(9.0, 0.1, -6.5), Vector3(13.0, 0.1, -5.0), Vector3(14.0, 0.1, -2.0)])
	check(ok, "cruza el paso norte")
	check(lv.route == "norte", "ruta registrada: norte")
	check(g.alert_count == 0 and g.state != Guard.S.CHASE, "el guardia nunca se alertó")
	lv.try_force()
	check(is_equal_approx(lv.reserve, 65.0), "la fuerza cuesta 35 (reserva 65)")
	check(lv.cart.state == IceCart.S.TREMBLING, "el carro tiembla")
	check(g.state == Guard.S.STANDDOWN, "el guardia deja de perseguir")
	check(await until(func() -> bool: return lv.grate_open), "la rejilla se abre")
	check(await walk_path(lv, [Vector3(15.0, 0.1, 2.0), Vector3(17.0, 0.1, 4.5)]) or lv.done, "camina al hueco")
	check(await until(func() -> bool: return lv.done), "baja por el hueco y termina")
	check(lv.hud.end_visible, "aparece la pantalla de cierre")
	check(lv.hud.end_lines[0].contains("Norte") and lv.hud.end_lines[1].contains("no"), "cierre: ruta norte, sin combate")
	check(is_equal_approx(lv.reserve, 65.0), "reserva final 65")
	check(g.alert_count == 0, "alertas totales: 0")
	await free_level(lv)


func _t3_south() -> void:
	print("3) Ruta sur con combate")
	var lv := await new_level()
	await through_door(lv)
	var g := lv.guard
	check(await walk(lv, Vector3(3.0, 0.1, 6.5)), "se acerca al paso sur")
	var t := 0
	while g.state != Guard.S.DISARMED and t < 1500 and not lv.dying:
		var to := g.global_position - lv.player.global_position
		to.y = 0.0
		if to.length() < 2.0 and lv.player.hook_cd <= 0.0:
			lv.player.sim_move = Vector2.ZERO
			lv.player.do_hook()
		elif to.length() >= 1.6:
			var d := to.normalized()
			lv.player.sim_move = Vector2(d.dot(lv.player.cam_right()), -d.dot(lv.player.cam_forward()))
		else:
			lv.player.sim_move = Vector2.ZERO
		await physics_frame
		t += 1
	lv.player.sim_move = Vector2.ZERO
	check(g.state == Guard.S.DISARMED and g.hits == 2, "2 golpes con el gancho lo desarman")
	check(lv.combat, "combate registrado")
	check(not lv.dying and lv.reserve > 0.0, "Sira sigue en pie (reserva %d)" % int(lv.reserve))
	check(lv.reserve < 100.0, "los golpes del guardia y el gancho gastan reserva")
	await walk_path(lv, [Vector3(11.0, 0.1, 6.5), Vector3(13.0, 0.1, 2.5)])
	check(lv.route == "sur", "ruta registrada: sur")
	if lv.reserve <= Level.FORCE_COST:
		check(await walk(lv, Vector3(16.5, 0.1, -2.0)), "va al botiquín")
		lv.do_action()
		lv.use_ampoule()
		check(lv.reserve > Level.FORCE_COST, "la ampolla alcanza para el carro")
		await walk(lv, Vector3(14.0, 0.1, -2.0))
	else:
		await walk(lv, Vector3(14.0, 0.1, 2.0))
	var before := lv.reserve
	lv.try_force()
	check(is_equal_approx(lv.reserve, before - 35.0), "el carro arranca (−35)")
	check(await until(func() -> bool: return lv.grate_open), "la rejilla se abre")
	await walk_path(lv, [Vector3(15.0, 0.1, 2.5), Vector3(17.0, 0.1, 4.5)])
	check(await until(func() -> bool: return lv.done), "termina por el hueco")
	check(lv.hud.end_lines[0].contains("Sur") and lv.hud.end_lines[1].contains("sí"), "cierre: ruta sur, con combate")
	await free_level(lv)


func _t4_low_reserve() -> void:
	print("4) Reserva baja")
	var lv := await new_level()
	await through_door(lv)
	lv.reserve = 20.0
	lv.player.global_position = Vector3(14.0, 0.1, -2.0)
	await _frames(5)
	check(lv.hud.cost_preview == 35.0, "el HUD muestra el costo (35) cerca del carro")
	lv.try_force()
	check(is_equal_approx(lv.reserve, 20.0) and lv.cart.state == IceCart.S.FROZEN, "la fuerza falla con 20 de reserva")
	check(lv.hud.last_message.contains("ampolla"), "avisa de la ampolla en el botiquín")
	check(await walk(lv, Vector3(16.5, 0.1, -2.0)), "va al botiquín")
	lv.do_action()
	check(lv.ampoules == 1 and not lv.kit_available, "el botiquín da una ampolla")
	lv.use_ampoule()
	check(is_equal_approx(lv.reserve, 70.0) and lv.ampoules == 0, "la ampolla sube la reserva a 70")
	await walk(lv, Vector3(14.0, 0.1, -2.0))
	lv.try_force()
	check(is_equal_approx(lv.reserve, 35.0) and lv.cart.state == IceCart.S.TREMBLING, "ahora el carro arranca")
	await free_level(lv)


func _t5_checkpoint() -> void:
	print("5) Punto de control")
	var lv := await new_level()
	await through_door(lv)
	var cart_home := lv.cart.position
	lv.player.global_position = Vector3(-3.2, 0.1, 8.2)
	await _frames(3)
	lv.do_action()
	await until(func() -> bool: return lv.tray.state == Tray.S.SPENT)
	check(lv.lamp.state == RailLamp.S.ATTRACTED and lv.guard.state == Guard.S.INVESTIGATE, "mecanismos alterados: bandeja, lámpara y guardia")
	lv.player.global_position = Vector3(16.5, 0.1, -2.0)
	await _frames(3)
	lv.do_action()
	lv.player.global_position = Vector3(14.0, 0.1, -2.0)
	await _frames(3)
	lv.try_force()
	await until(func() -> bool: return lv.grate_open)
	lv.guard.hits = 1
	check(lv.grate_open and not lv.kit_available and lv.cart.state != IceCart.S.FROZEN, "carro, botiquín y rejilla alterados")
	lv.spend(500.0)
	check(lv.dying, "Sira muere sin reserva")
	check(await until(func() -> bool: return not lv.dying, 200), "reaparece")
	check(lv.player.global_position.distance_to(Level.CHECK_POS) < 0.7, "en el punto de control")
	check(is_equal_approx(lv.reserve, 100.0) and lv.ampoules == 0, "reserva restaurada")
	check(lv.tray.state == Tray.S.READY and is_equal_approx(lv.tray.position.x, Tray.START_X), "bandeja restaurada")
	check(lv.guard.state == Guard.S.PATROL and lv.guard.hits == 0 and lv.guard.alert_count == 0, "guardia restaurado")
	check(lv.guard.global_position.distance_to(Guard.HOME) < 0.7, "guardia en su posición")
	check(lv.lamp.state != RailLamp.S.ATTRACTED and is_equal_approx(lv.lamp.head_x, RailLamp.A_X) or lv.lamp.state == RailLamp.S.DWELL, "lámpara restaurada")
	check(lv.cart.state == IceCart.S.FROZEN and lv.cart.position.is_equal_approx(cart_home), "carro restaurado")
	check(lv.kit_available, "botiquín restaurado")
	check(not lv.grate_open and not lv.grate_shape.disabled, "rejilla cerrada")
	check(lv.door_open, "la puerta sigue abierta")
	await free_level(lv)


func _t6_lamp_signal() -> void:
	print("6) Señal de la lámpara")
	var lv := await new_level()
	lv.player.global_position = Vector3(-3.0, 0.1, 0.0)
	var count := [0]
	lv.lamp.signal_emitted.connect(func() -> void: count[0] += 1)
	var min_x := lv.lamp.head_x
	var max_x := lv.lamp.head_x
	var saw_banner := false
	for i in 600:
		await physics_frame
		min_x = minf(min_x, lv.lamp.head_x)
		max_x = maxf(max_x, lv.lamp.head_x)
		if lv.hud.banner_t > 0.0:
			saw_banner = true
	check(count[0] >= 2, "la señal suena varias veces en 10 s (%d)" % count[0])
	check(max_x - min_x > 5.0, "la lámpara se mueve (%.1f m)" % (max_x - min_x))
	check(saw_banner and lv.signals_heard == count[0], "el HUD avisa de cada cambio de lote")
	lv.hud.banner_t = 0.0
	lv.player.global_position = Vector3(-11.0, 0.1, 0.0)
	var quiet := true
	for i in 420:
		await physics_frame
		if lv.hud.banner_t > 0.0:
			quiet = false
	check(quiet, "en el consultorio no suena ni se avisa el cambio de lote")
	await free_level(lv)


func _t7_lamp_detects() -> void:
	print("7) La lámpara detecta a Sira")
	var lv := await new_level()
	await through_door(lv)
	lv.player.global_position = Vector3(lv.lamp.aim.x, 0.1, RailLamp.RAIL_Z)
	check(await until(func() -> bool: return lv.guard.state == Guard.S.CHASE, 300), "el guardia pasa a perseguir")
	await free_level(lv)


func _t8_buttons() -> void:
	print("8) Botones táctiles")
	var lv := await new_level()
	var got := {"hook": 0, "dodge": 0, "force": 0, "action": 0, "ampoule": 0, "restart": 0}
	lv.hud.hook_pressed.connect(func() -> void: got["hook"] += 1)
	lv.hud.dodge_pressed.connect(func() -> void: got["dodge"] += 1)
	lv.hud.force_pressed.connect(func() -> void: got["force"] += 1)
	lv.hud.action_pressed.connect(func() -> void: got["action"] += 1)
	lv.hud.ampoule_pressed.connect(func() -> void: got["ampoule"] += 1)
	lv.hud.restart_pressed.connect(func() -> void: got["restart"] += 1)
	var idx := 5
	for name: String in got:
		touch(lv, idx, lv.hud.button_center(name), true)
		check(lv.hud.held[name] == 1, "botón %s resaltado" % name)
		touch(lv, idx, lv.hud.button_center(name), false)
		idx += 1
		await _frames(2)
	for name: String in got:
		check(got[name] == 1, "botón %s emite su señal" % name)
	check(lv.hud.stick_index == -1, "los botones no activan el stick")
	await _frames(90)
	await free_level(lv)


func _t9_dodge() -> void:
	print("9) Esquiva y bloqueo")
	var lv := await new_level()
	await through_door(lv)
	var g := lv.guard
	lv.player.global_position = Vector3(5.0, 0.1, 6.5)
	g.global_position = Vector3(6.6, 0.1, 6.5)
	g.alert(lv.player.global_position)
	check(await until(func() -> bool: return g.state == Guard.S.WINDUP, 240), "el guardia prepara un golpe (señalado)")
	var before := lv.reserve
	check(await until(func() -> bool: return g.timer < 0.15), "justo antes del impacto")
	lv.player.do_dodge()
	check(lv.player.invuln > 0.0 and lv.player.dodge_t > 0.0, "la esquiva da invulnerabilidad breve")
	await _frames(20)
	check(is_equal_approx(lv.reserve, before), "esquivar a tiempo evita el daño")
	check(g.state == Guard.S.STUNNED, "esquiva perfecta: el guardia queda aturdido")
	check(lv.hud.message_log.any(func(m: String) -> bool: return m.contains("Esquiva perfecta")), "aviso de esquiva perfecta")
	# Sin esquivar, el golpe duele.
	await until(func() -> bool: return g.state == Guard.S.WINDUP, 600)
	var b2 := lv.reserve
	await _frames(60)
	check(lv.reserve < b2, "sin esquivar, el golpe quita reserva")
	await free_level(lv)


func _t10_settings() -> void:
	print("10) Ajustes y actualización")
	var lv := await new_level()
	check(lv.hud.version_text != "", "hay texto de versión (%s)" % lv.hud.version_text)
	touch(lv, 3, lv.hud.button_center("settings"), true)
	touch(lv, 3, lv.hud.button_center("settings"), false)
	check(lv.hud.settings_visible and paused, "el botón ⚙ abre Ajustes y pausa el juego")
	var u := lv.hud.settings_rect("browser").get_center()
	touch(lv, 4, u, true)
	touch(lv, 4, u, false)
	check(lv.update_opened, "«Abrir en el navegador» abre la descarga")
	var up := lv.updater
	up.set_installed("aaaaaaa · build 1")
	up.apply_release({"target_commitish": "aaaaaaa1234567", "assets": [{"name": "x.apk", "browser_download_url": "https://x/x.apk"}]})
	check(up.state == Updater.S.UP_TO_DATE, "misma versión: al día")
	up.apply_release({"target_commitish": "bbbbbbb1234567", "assets": [{"name": "x.apk", "browser_download_url": "https://x/x.apk"}]})
	check(up.state == Updater.S.AVAILABLE and up.apk_url == "https://x/x.apk", "versión distinta: hay actualización")
	check(up.button_label() == "Descargar e instalar", "el botón ofrece descargar e instalar")
	up.apply_release({"target_commitish": "bbbbbbb", "assets": []})
	check(up.state == Updater.S.FAILED, "sin APK en el release: error controlado")
	up.apply_release("basura")
	check(up.state == Updater.S.FAILED, "respuesta inválida: error controlado")
	check(not up.install_apk(), "fuera de Android no intenta instalar")
	var c := lv.hud.settings_rect("close").get_center()
	touch(lv, 5, c, true)
	touch(lv, 5, c, false)
	check(not lv.hud.settings_visible and not paused, "«Cerrar» reanuda el juego")
	await free_level(lv)


func _t11_models() -> void:
	print("11) Modelos de personaje")
	var lv := await new_level()
	var pr := lv.player.rig
	var gr := lv.guard.rig
	check(pr.is_model and gr.is_model, "Sira y el guardia usan sus modelos glTF")
	if not (pr.is_model and gr.is_model):
		await free_level(lv)
		return
	var pm := pr as ModelRig
	var gm := gr as ModelRig
	for clip in ["Idle", "Walk", "Run", "Sword_Slash", "Roll", "HitRecieve", "HitRecieve_2"]:
		check(pm.anim.has_animation(clip) and gm.anim.has_animation(clip), "ambos tienen la animación %s" % clip)
	check(pm.anim.get_animation("Walk").loop_mode == Animation.LOOP_LINEAR, "caminar se repite en bucle")
	await _frames(10)
	check(pm.current == "Idle", "quieta: Sira en Idle (%s)" % pm.current)
	lv.player.sim_move = Vector2(0.0, -1.0)
	await _frames(40)
	check(pm.current == "Run", "a toda velocidad: Sira corre (%s)" % pm.current)
	lv.player.sim_move = Vector2.ZERO
	await _frames(30)
	check(pm.current == "Idle", "al soltar el stick vuelve a Idle (%s)" % pm.current)
	var steps := 0
	lv.player.sim_move = Vector2(0.0, -1.0)
	for i in 90:
		await _frames(1)
		if pm.step_flag:
			steps += 1
	lv.player.sim_move = Vector2.ZERO
	check(steps >= 3, "el ciclo de carrera marca pasos (%d)" % steps)
	lv.player.hook_cd = 0.0
	lv.player.do_hook()
	await _frames(6)
	check(pm.current == "Sword_Slash" and pm.holding, "el gancho reproduce el golpe (%s)" % pm.current)
	await _frames(40)
	lv.player.dodge_cd = 0.0
	lv.player.do_dodge()
	await _frames(4)
	check(pm.current == "Roll", "la esquiva reproduce la voltereta (%s)" % pm.current)
	await _frames(40)
	lv.player.hurt_cd = 0.0
	lv.player.invuln = 0.0
	lv.hurt_player(5.0)
	await _frames(3)
	check(pm.current == "HitRecieve", "un golpe recibido reproduce la reacción (%s)" % pm.current)
	await _frames(60)
	check(pm.current != "HitRecieve" or not pm.anim.is_playing(), "la reacción termina y vuelve a moverse")
	lv.guard.hits = 1
	lv.guard.state = Guard.S.STUNNED
	lv.guard.timer = 1.2
	await _frames(70)
	check(gm.current == "HitRecieve" and gm.holding, "guardia aturdido: queda encorvado (%s)" % gm.current)
	lv.guard.state = Guard.S.DISARMED
	await _frames(70)
	check(gm.current == "HitRecieve_2" and gm.holding, "guardia desarmado: se queda vencido (%s)" % gm.current)
	check(is_instance_valid(gm.hand_r) and is_instance_valid(lv.guard.baton), "el bastón sigue en su mano")
	await free_level(lv)


func _t12_docs() -> void:
	print("12) Folios y pantalla de título")
	var list := Docs.get_docs(["orden", "dispensario"])
	check(list.size() == 2 and str(list[0]["titulo"]).contains("ORDEN"), "Docs entrega los dos folios del capítulo 1")
	var lv := await new_level(false)
	var p := lv.player
	p.global_position = Vector3(-12.0, 0.1, 2.8)
	await _frames(3)
	check(lv.hud.prompts.any(func(m: String) -> bool: return m.contains("folios")), "aparece el aviso de leer los folios")
	lv.do_action()
	check(lv.hud.doc_visible and paused and lv.hud.doc_page == 0, "ACCIÓN abre el lector y pausa el juego")
	var nx := lv.hud.doc_button("next").get_center()
	touch(lv, 6, nx, true)
	touch(lv, 6, nx, false)
	check(lv.hud.doc_page == 1, "«>» pasa al segundo folio")
	touch(lv, 6, nx, true)
	touch(lv, 6, nx, false)
	check(lv.hud.doc_page == 1, "no pasa del último folio")
	var pv := lv.hud.doc_button("prev").get_center()
	touch(lv, 7, pv, true)
	touch(lv, 7, pv, false)
	check(lv.hud.doc_page == 0, "«<» vuelve al primero")
	var cl := lv.hud.doc_button("close").get_center()
	touch(lv, 8, cl, true)
	touch(lv, 8, cl, false)
	check(not lv.hud.doc_visible and not paused, "«Cerrar» reanuda el juego")
	p.global_position = Vector3(-8.0, 0.1, 0.0)
	await _frames(3)
	check(not lv.hud.prompts.any(func(m: String) -> bool: return m.contains("folios")), "lejos de la mesa no hay aviso")
	await free_level(lv)
	var ts: Script = load("res://scripts/title.gd")
	check(ts != null and ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/title.tscn", "la escena principal es la pantalla de título")


func _t13_audio() -> void:
	print("13) Sonidos")
	var lv := await new_level()
	for n in ["campana", "clang", "bandeja_rueda", "hielo", "carro_rueda", "gong", "rejilla", "latido", "respiracion", "amb_mercado", "amb_olas", "amb_bomba", "amb_goteo", "amb_silbato"]:
		check(lv._ld(n) != null, "existe el sonido «%s»" % n)
	for n in ["amb_mercado", "amb_olas", "amb_bomba", "amb_goteo", "amb_silbato", "latido"]:
		var st := lv._ld(n) as AudioStreamOggVorbis
		check(st != null and st.loop, "«%s» está en bucle" % n)
	check(lv.variants.has("step") and (lv.variants["step"] as Array).size() == 3, "tres variantes de pasos")
	check(lv.sounds["beep"] == lv._ld("campana"), "la señal de la lámpara usa la campana de subasta")
	check(lv.sounds["clang"] == lv._ld("clang"), "la bandeja usa el golpe metálico real")
	for n in ["impacto_gancho", "golpe_recibido", "bloqueo", "caida", "puerta_abre", "puerta_cierra"]:
		check(lv._ld(n) != null, "existe el sonido de combate/puerta «%s»" % n)
	check(lv.sounds["hook_hit"] == lv._ld("impacto_gancho") and lv.sounds["hurt"] == lv._ld("golpe_recibido"), "impacto del gancho y golpe recibido son reales")
	for m in [Gfx.mat_brick(), Gfx.mat_steel(), Gfx.mat_mossy()]:
		check(m is ORMMaterial3D, "textura PBR nueva cargada")
	await free_level(lv)


func _t14_quality() -> void:
	print("14) Calidad gráfica")
	var lv := await new_level()
	var before := Quality.level
	Quality.level = 1
	touch(lv, 3, lv.hud.button_center("settings"), true)
	touch(lv, 3, lv.hud.button_center("settings"), false)
	var q := lv.hud.settings_rect("quality").get_center()
	touch(lv, 4, q, true)
	touch(lv, 4, q, false)
	check(Quality.level == 2 and lv.hud.settings_visible, "el botón cambia a Alta sin cerrar Ajustes")
	check(is_equal_approx(lv.get_viewport().scaling_3d_scale, 1.0) and lv.quality_env.glow_enabled, "Alta: 3D al 100% y brillo activo")
	touch(lv, 5, q, true)
	touch(lv, 5, q, false)
	check(Quality.level == 0 and is_equal_approx(lv.get_viewport().scaling_3d_scale, 0.6) and not lv.quality_env.glow_enabled, "Baja: 3D al 60% y sin brillo")
	touch(lv, 6, q, true)
	touch(lv, 6, q, false)
	check(Quality.level == 1 and Engine.max_fps == 40, "Media: 40 FPS")
	Quality.level = before
	Quality.save()
	var cf := ConfigFile.new()
	check(cf.load(Quality.SAVE_PATH) == OK and int(cf.get_value("grafico", "nivel")) == before, "la elección se guarda")
	touch(lv, 7, lv.hud.settings_rect("close").get_center(), true)
	touch(lv, 7, lv.hud.settings_rect("close").get_center(), false)
	await free_level(lv)


func _t15_combat_fixes() -> void:
	print("15) Combate: contacto, muros y colisiones")
	var lv := await new_level()
	await through_door(lv)
	var g := lv.guard
	var p := lv.player
	# El gancho no atraviesa muros.
	p.global_position = Vector3(8.2, 0.1, 0.0)
	g.global_position = Vector3(9.9, 0.1, 0.0)
	g.state = Guard.S.CHASE
	p.hook_cd = 0.0
	p.do_hook()
	await _frames(20)
	check(g.hits == 0, "el gancho no golpea a través de un muro")
	# El daño llega en el frame de contacto, no al pulsar.
	p.global_position = Vector3(5.0, 0.1, 6.5)
	g.global_position = Vector3(6.6, 0.1, 6.5)
	g.state = Guard.S.STANDDOWN
	g.state = Guard.S.CHASE
	g.attack_cd = 5.0
	p.hook_cd = 0.0
	p.do_hook()
	check(g.hits == 0, "al pulsar todavía no hay daño")
	await _frames(14)
	check(g.hits == 1 or g.state == Guard.S.BLOCK, "el golpe conecta en el frame de contacto")
	# El golpe pesado del guardia no atraviesa muros.
	g.hits = 0
	g.state = Guard.S.CHASE
	p.global_position = Vector3(8.2, 0.1, 0.0)
	g.global_position = Vector3(9.9, 0.1, 0.0)
	g.slam = true
	g.state = Guard.S.WINDUP
	g.timer = 0.05
	var before := lv.reserve
	await _frames(10)
	check(is_equal_approx(lv.reserve, before), "el golpe pesado no daña a través de un muro")
	# El jugador y el guardia no se atraviesan.
	g.state = Guard.S.STANDDOWN
	g.global_position = Vector3(4.0, 0.1, 0.0)
	p.global_position = Vector3(2.0, 0.1, 0.0)
	await _frames(5)
	var t := 0
	while t < 90:
		p.sim_move = Vector2(p.cam_right().dot(Vector3.RIGHT), -p.cam_forward().dot(Vector3.RIGHT))
		await physics_frame
		t += 1
	p.sim_move = Vector2.ZERO
	check(p.global_position.x < g.global_position.x + 0.2, "Sira no atraviesa al guardia")
	# Muro entre la cámara y Sira: se hace transparente.
	p.global_position = Vector3(-3.0, 0.1, 9.0)
	p.cam_yaw = 0.0
	p.cam_pitch = 0.3
	await _frames(6)
	check(p.faded.size() > 0 and p.faded[0].material_override == Player._fade_material(), "el muro que tapa a Sira se vuelve transparente")
	p.global_position = Vector3(2.0, 0.1, 0.0)
	p.cam_pitch = 0.58
	await _frames(6)
	check(p.faded.is_empty() and not lv.get_child(0).has_meta("orig_mat"), "y vuelve a ser opaco al salir de en medio")
	# Etiqueta de ruta coherente.
	lv.route = "sur"
	lv.combat = false
	check(lv.route_label().contains("sin combate"), "ruta sur sin pelear: no dice «combate»")
	await free_level(lv)


func _t16_decor() -> void:
	print("16) Carteles y decales")
	var lv := await new_level()
	check(lv.posters == 5, "hay 5 carteles en los muros (%d)" % lv.posters)
	check(lv.decals >= 12, "hay decales de sangre, grietas, óxido, sal y moho (%d)" % lv.decals)
	for f in ["mancha_sangre_seca", "charco_sangre", "oxido_en_gotas", "grieta_larga", "sal_en_juntas", "moho_esquina"]:
		check(ResourceLoader.exists("res://assets/decales/%s.png" % f), "existe el decal «%s»" % f)
	await free_level(lv)


func _t17_barks() -> void:
	print("17) Frases del guardia y cronología de folios")
	var lv := await new_level()
	await through_door(lv)
	lv.hud.message_t = 0.0
	lv.guard.alert(lv.player.global_position)
	check(lv.last_bark == "Alto. Zona cerrada." and lv.hud.last_message.contains("Zona cerrada"), "al verte, el guardia dice su frase como subtítulo")
	lv.hud.say("Mensaje importante", 3.0)
	lv.bark("pierde")
	check(lv.hud.last_message == "Mensaje importante", "una frase no pisa un mensaje importante en curso")
	var orden := str(Docs.get_docs(["orden"])[0]["texto"])
	var disp := str(Docs.get_docs(["dispensario"])[0]["texto"])
	check(orden.contains("13/11/2026, 23:40") and disp.contains("14/11/2026, 00:20"), "la orden (13/11 23:40) precede a la nota del dispensario (14/11 00:20)")
	await free_level(lv)


func _t18_models() -> void:
	print("18) Modelos de escenario y vidrio")
	var lv := await new_level()
	check(lv.models_placed == 7, "ancla, red y 5 ganchos de carnicero colocados (%d)" % lv.models_placed)
	for n in ["ancla", "red_pesca", "gancho_carnicero"]:
		check(ResourceLoader.exists("res://assets/modelos/%s/%s.gltf" % [n, n]), "existe el modelo «%s»" % n)
	check(Gfx.mat_glass(Color(0.4, 0.6, 1.0)).albedo_texture != null, "el vidrio esmerilado usa su textura")
	await free_level(lv)


func _t19_dialogue() -> void:
	print("19) Diálogo inicial y pensamientos de Sira")
	var lv := await new_level(false)
	check(Level.INTRO.size() == 8 and Level.INTRO[0].begins_with("Tesa|"), "el diálogo inicial tiene 8 líneas entre Tesa y Sira")
	check(Level.INTRO.any(func(l: String) -> bool: return l.contains("Sellen el paso Cendal también")), "incluye la frase de Roque de la muestra de sal")
	lv.hud.open_dialogue(Level.INTRO)
	check(lv.hud.dialog_visible and paused and lv.hud.dialog_i == 0, "abre el diálogo y pausa el juego")
	var finished := [false]
	lv.hud.dialogue_finished.connect(func() -> void: finished[0] = true)
	touch(lv, 9, Vector2(640, 300), true)
	touch(lv, 9, Vector2(640, 300), false)
	check(lv.hud.dialog_i == 1, "un toque avanza a la siguiente línea")
	lv.hud._process(5.2)
	check(lv.hud.dialog_i == 2, "a los 5 s avanza solo")
	var sk := lv.hud.dialog_skip_rect().get_center()
	touch(lv, 10, sk, true)
	touch(lv, 10, sk, false)
	check(not lv.hud.dialog_visible and not paused and finished[0], "«Saltar» cierra y reanuda el juego")
	lv.hud.open_dialogue(["Sira|Una sola línea."])
	touch(lv, 11, Vector2(640, 300), true)
	touch(lv, 11, Vector2(640, 300), false)
	check(not lv.hud.dialog_visible and not paused, "al terminar la última línea se cierra solo")
	# Pensamientos: una sola vez y sin pisar mensajes importantes.
	lv.hud.message_t = 0.0
	lv.think("entra")
	check(lv.hud.last_message.contains("Huele a sal"), "pensamiento de entrada a la lonja")
	lv.hud.say("Mensaje importante", 3.0)
	lv.think("lampara")
	check(lv.hud.last_message == "Mensaje importante" and lv.pending_thoughts.size() == 1, "un pensamiento espera si hay un mensaje importante")
	lv.hud.message_t = 0.0
	lv.think("entra")
	check(lv.hud.last_message == "Mensaje importante", "un pensamiento no se repite")
	await free_level(lv)


func _t20_docs_cap2() -> void:
	print("20) Folios del capítulo 2 y 3")
	check(Docs.ALL.size() == 9, "hay 9 folios en total (%d)" % Docs.ALL.size())
	for id in ["carta_ivo", "nota_elvira", "parte_roque", "circular"]:
		check(Docs.get_docs([id]).size() == 1, "existe el folio «%s»" % id)
	var carta := str(Docs.get_docs(["carta_ivo"])[0]["texto"])
	check(carta.contains("doce familias") and carta.contains("Cuarenta y una personas"), "la carta de Ivo coincide con el censo (12 familias, 41 personas)")
	var elvira := str(Docs.get_docs(["nota_elvira"])[0]["texto"])
	check(elvira.contains("13/11/2026, 22:50") and not elvira.contains("ampolla"), "la nota de Elvira es del 13/11 22:50 y no habla de ampollas")
	var circ := str(Docs.get_docs(["circular"])[0]["texto"])
	check(circ.contains("14/11/2026, 01:00"), "la circular de Intendencia es posterior a la orden de inundación (13/11 23:40)")

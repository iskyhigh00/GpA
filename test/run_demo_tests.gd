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
	var got := {"hook": 0, "force": 0, "action": 0, "ampoule": 0, "restart": 0}
	lv.hud.hook_pressed.connect(func() -> void: got["hook"] += 1)
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

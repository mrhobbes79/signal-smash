extends Node3D
## Fight test scene — two procedural fighters on a simple platform.
## Tests: movement, jumping, double jump, basic attack with knockback, KO, ring-out.
##
## Controls (Player 1 — Keyboard):
##   WASD       — Move
##   Space      — Jump / Double Jump
##   J          — Attack
##
## Controls (Player 2 — second player on keyboard for testing):
##   Arrow Keys — Move (mapped in this script)
##   RShift     — Jump
##   RCtrl      — Attack

const FighterBaseScript = preload("res://scripts/fighters/fighter_base.gd")
const StateMachineScript = preload("res://scripts/fighters/state_machine.gd")
const FighterStateScript = preload("res://scripts/fighters/fighter_state.gd")
const IdleStateScript = preload("res://scripts/fighters/states/idle_state.gd")
const RunStateScript = preload("res://scripts/fighters/states/run_state.gd")
const JumpStateScript = preload("res://scripts/fighters/states/jump_state.gd")
const FallStateScript = preload("res://scripts/fighters/states/fall_state.gd")
const AttackStateScript = preload("res://scripts/fighters/states/attack_state.gd")
const HitStateScript = preload("res://scripts/fighters/states/hit_state.gd")
const KOStateScript = preload("res://scripts/fighters/states/ko_state.gd")

const SpectatorHUDScript = preload("res://scenes/ui/spectator_hud.gd")

const ATTACK_DAMAGE: float = 8.0
const ATTACK_KNOCKBACK: float = 4.0

var _fighter1: CharacterBody3D
var _fighter2: CharacterBody3D
var _camera: Camera3D
var _hud_label: Label
var _spectator_hud: CanvasLayer
var _spectator_mode: bool = false
var _fight_over: bool = false
var _fight_over_timer: float = 0.0
var _attack_effects: Array = []  # Array of {pos, timer, type, color}

# Round system (best of 3)
var _round: int = 1
var _max_rounds: int = 3
var _p1_round_wins: int = 0
var _p2_round_wins: int = 0
var _round_over: bool = false
var _round_over_timer: float = 0.0
var _match_over: bool = false

# Weather system
var _weather: int = 0  # 0=normal, 1=night, 2=storm
var _storm_rain: GPUParticles3D = null
var _storm_flash_timer: float = 0.0
var _storm_flash_active: bool = false
var _storm_flash_duration: float = 0.0
var _storm_wind_dir: float = 1.0
var _world_env: WorldEnvironment = null

func _ready() -> void:
	_build_arena()
	_build_fighters()
	_build_camera()
	_build_hud()
	_build_lighting()
	_build_spectator_hud()
	# Start fight music based on arena
	if AudioManager:
		var arena_music: String = GameMgr.get_arena().get("music", "monterrey")
		AudioManager.play_music_fight(arena_music)

var _hazard_antenna: Node3D
var _hazard_area: Area3D
const HAZARD_SPEED: float = 40.0  # Degrees per second
const HAZARD_KNOCKBACK: float = 5.0
const HAZARD_DAMAGE: float = 12.0

func _build_arena() -> void:
	var arena_id: int = GameMgr.selected_arena
	match arena_id:
		0: _build_arena_monterrey()
		1: _build_arena_cdmx()
		2: _build_arena_rio()
		3: _build_arena_dallas()
		4: _build_arena_bogota()
		5: _build_arena_buenos_aires()
		6: _build_arena_miami()
		7: _build_arena_wispa()
		8: _build_arena_wispa_2026()
		9: _build_arena_wispmx()
		_: _build_arena_monterrey()

	# Ground visual (all arenas)
	var ground := ProceduralMesh.create_platform(60.0, 60.0, 0.1, Color("#1a1a1a"))
	ground.position.y = -12.0
	add_child(ground)

func _build_arena_monterrey() -> void:
	# Main rooftop platform
	_add_solid_platform(Vector3(0, -0.25, 0), Vector3(16.0, 0.5, 8.0), Color("#EA580C"))
	var edge := ProceduralMesh.create_platform(16.2, 8.2, 0.1, Color("#9A3412"))
	edge.position.y = -0.55
	add_child(edge)
	# Secondary rooftop platforms
	_add_one_way_platform(Vector3(-5.0, 2.0, 0.0), Vector3(3.5, 0.3, 3.0), Color("#78350F"))
	_add_one_way_platform(Vector3(5.0, 2.0, 0.0), Vector3(3.5, 0.3, 3.0), Color("#78350F"))
	# Towers
	_build_tower(Vector3(-6.0, 0.0, -3.0), 5.5, Color("#6B7280"), Color("#FCD34D"))
	_build_tower(Vector3(6.0, 0.0, -3.0), 4.0, Color("#6B7280"), Color("#FCD34D"))
	# Multiple cable runs between towers
	for ci in range(3):
		var cable := ProceduralMesh.create_cylinder(0.02, 12.5, 4, Color.BLACK)
		cable.position = Vector3(0.0, 4.0 + ci * 0.5, -3.0 + ci * 0.3)
		cable.rotation_degrees.z = 90.0
		add_child(cable)
	# Extra cable run diagonally
	var diag_cable := ProceduralMesh.create_cylinder(0.02, 8.0, 4, Color.BLACK)
	diag_cable.position = Vector3(-2.0, 3.5, -2.5)
	diag_cable.rotation_degrees.z = 70.0
	add_child(diag_cable)
	# Tinaco water tanks on rooftops
	for tx in [-5.5, 5.5]:
		var tinaco := ProceduralMesh.create_cylinder(0.5, 1.0, 8, Color("#374151"))
		tinaco.position = Vector3(tx, 2.8, 1.5)
		add_child(tinaco)
		# Tinaco lid
		var lid := ProceduralMesh.create_cylinder(0.55, 0.08, 8, Color("#1F2937"))
		lid.position = Vector3(tx, 3.35, 1.5)
		add_child(lid)
		# Tinaco legs
		for lx in [-0.3, 0.3]:
			var leg := ProceduralMesh.create_cylinder(0.04, 0.5, 4, Color("#6B7280"))
			leg.position = Vector3(tx + lx, 2.05, 1.5)
			add_child(leg)
	# AC units on rooftop
	for ac_pos in [Vector3(-3.0, 0.35, 2.5), Vector3(2.5, 0.35, 2.8), Vector3(6.5, 2.35, 1.0)]:
		var ac_unit := ProceduralMesh.create_box(Vector3(0.8, 0.6, 0.6), Color("#9CA3AF"))
		ac_unit.position = ac_pos
		add_child(ac_unit)
		# AC fan grill
		var grill := ProceduralMesh.create_cylinder(0.2, 0.05, 6, Color("#4B5563"))
		grill.position = ac_pos + Vector3(0, 0.32, 0)
		add_child(grill)
	# Clotheslines between sides
	for cl_i in range(2):
		var cl_line := ProceduralMesh.create_cylinder(0.01, 10.0, 4, Color("#D1D5DB"))
		cl_line.position = Vector3(0.0, 3.0 + cl_i * 0.6, 1.5 + cl_i * 0.5)
		cl_line.rotation_degrees.z = 90.0
		add_child(cl_line)
		# Clothes hanging (small colored boxes)
		for cl_j in range(5):
			var cloth := ProceduralMesh.create_box(Vector3(0.3, 0.4, 0.05), [Color("#DC2626"), Color("#2563EB"), Color("#FCD34D"), Color("#16A34A"), Color("#A855F7")][cl_j])
			cloth.position = Vector3(-4.0 + cl_j * 2.0, 2.7 + cl_i * 0.6, 1.5 + cl_i * 0.5)
			add_child(cloth)
	# Stairwell access structure
	var stairwell := ProceduralMesh.create_box(Vector3(1.2, 1.8, 1.2), Color("#78350F"))
	stairwell.position = Vector3(-7.0, 0.9, 1.0)
	add_child(stairwell)
	var stair_door := ProceduralMesh.create_box(Vector3(0.5, 1.0, 0.05), Color("#4B5563"))
	stair_door.position = Vector3(-7.0, 0.5, 0.38)
	add_child(stair_door)
	# Distant buildings in background at different heights
	var bldg_data := [
		[Vector3(-12.0, 2.5, -18.0), Vector3(3.0, 5.0, 3.0), Color("#4B5563")],
		[Vector3(-8.0, 3.5, -20.0), Vector3(2.5, 7.0, 2.5), Color("#374151")],
		[Vector3(-4.0, 2.0, -16.0), Vector3(2.0, 4.0, 2.0), Color("#6B7280")],
		[Vector3(4.0, 4.0, -22.0), Vector3(3.0, 8.0, 3.0), Color("#374151")],
		[Vector3(8.0, 2.0, -17.0), Vector3(2.5, 4.0, 2.5), Color("#4B5563")],
		[Vector3(12.0, 3.0, -19.0), Vector3(2.0, 6.0, 2.0), Color("#6B7280")],
		[Vector3(15.0, 1.5, -15.0), Vector3(3.0, 3.0, 2.0), Color("#4B5563")],
	]
	for bd in bldg_data:
		var bldg := ProceduralMesh.create_box(bd[1], bd[2])
		bldg.position = bd[0]
		add_child(bldg)
		# Windows on buildings
		for wr in range(int(bd[1].y) - 1):
			for wc in range(2):
				var bw := ProceduralMesh.create_box(Vector3(0.3, 0.3, 0.05), Color("#FCD34D").darkened(0.3))
				bw.position = bd[0] + Vector3(-0.5 + wc * 1.0, -bd[1].y / 2.0 + 1.0 + wr * 1.2, bd[1].z / 2.0 + 0.03)
				add_child(bw)
	# Street level below — cars and buses visible
	for ci2 in range(5):
		var car_color: Color = [Color("#DC2626"), Color("#2563EB"), Color("#FCD34D"), Color("#16A34A"), Color("#F97316")][ci2]
		var car := ProceduralMesh.create_box(Vector3(1.0, 0.4, 0.5), car_color)
		car.position = Vector3(-6.0 + ci2 * 3.0, -5.0, 5.0)
		add_child(car)
		# Car wheels
		for wx in [-0.3, 0.3]:
			var wheel := ProceduralMesh.create_cylinder(0.12, 0.08, 6, Color("#1F2937"))
			wheel.position = Vector3(-6.0 + ci2 * 3.0 + wx, -5.2, 5.28)
			wheel.rotation_degrees.x = 90.0
			add_child(wheel)
	# Bus
	var bus := ProceduralMesh.create_box(Vector3(2.5, 0.8, 0.7), Color("#16A34A"))
	bus.position = Vector3(2.0, -4.8, 6.5)
	add_child(bus)
	var bus_windows := ProceduralMesh.create_box(Vector3(2.0, 0.3, 0.05), Color("#38BDF8"))
	bus_windows.position = Vector3(2.0, -4.5, 6.86)
	add_child(bus_windows)
	# Sunset gradient sky plane
	var sky_colors := [Color("#FDE68A"), Color("#F97316"), Color("#DC2626"), Color("#7C3AED")]
	for si in range(4):
		var sky_band := ProceduralMesh.create_platform(60.0, 0.1, 5.0, sky_colors[si])
		sky_band.position = Vector3(0, 5.0 + si * 5.0, -45.0)
		sky_band.rotation_degrees.x = 90.0
		add_child(sky_band)
	_build_mountains()
	_build_hazard()

func _build_arena_cdmx() -> void:
	## Torre CDMX — Vertical tower with stacked platforms, swinging cable hazard
	# Base platform (narrow)
	_add_solid_platform(Vector3(0, -0.25, 0), Vector3(12.0, 0.5, 7.0), Color("#64748B"))
	# Stacked vertical platforms (tower structure)
	_add_one_way_platform(Vector3(-3.0, 2.0, 0), Vector3(4.0, 0.3, 3.0), Color("#475569"))
	_add_one_way_platform(Vector3(3.0, 3.5, 0), Vector3(4.0, 0.3, 3.0), Color("#475569"))
	_add_one_way_platform(Vector3(-1.0, 5.0, 0), Vector3(3.5, 0.3, 3.0), Color("#475569"))
	_add_one_way_platform(Vector3(4.0, 6.5, 0), Vector3(3.0, 0.3, 2.5), Color("#475569"))
	# Main tower structure with cross-beams
	_build_tower(Vector3(0.0, 0.0, -4.0), 10.0, Color("#334155"), Color("#3B82F6"))
	_build_tower(Vector3(-5.0, 0.0, -3.0), 7.0, Color("#334155"), Color("#3B82F6"))
	# Tower cross-beams (diagonal bracing)
	for cb_i in range(4):
		var cb := ProceduralMesh.create_cylinder(0.03, 3.5, 4, Color("#475569"))
		cb.position = Vector3(0.0, 2.0 + cb_i * 2.0, -4.0)
		cb.rotation_degrees.z = 45.0 if cb_i % 2 == 0 else -45.0
		add_child(cb)
	# Guy-wires from tower top to ground
	for gw_angle in [-35.0, 35.0]:
		var gw := ProceduralMesh.create_cylinder(0.015, 8.0, 4, Color("#9CA3AF"))
		gw.position = Vector3(gw_angle * 0.08, 5.0, -4.0)
		gw.rotation_degrees.z = gw_angle
		add_child(gw)
	# Equipment shelves on tower
	for es_i in range(3):
		var shelf := ProceduralMesh.create_box(Vector3(1.2, 0.15, 0.6), Color("#6B7280"))
		shelf.position = Vector3(0.0, 3.0 + es_i * 2.5, -3.7)
		add_child(shelf)
		# Equipment box on shelf
		var eq_box := ProceduralMesh.create_box(Vector3(0.5, 0.4, 0.4), Color("#1E293B"))
		eq_box.position = Vector3(0.0, 3.3 + es_i * 2.5, -3.7)
		add_child(eq_box)
		# Status LED on equipment
		var eq_led := ProceduralMesh.create_sphere(0.03, 4, Color("#22C55E"))
		eq_led.position = Vector3(0.28, 3.3 + es_i * 2.5, -3.48)
		add_child(eq_led)
	# Smog layers (background only, behind play area)
	for i in range(3):
		var opacity: float = 0.04 + i * 0.03
		var fog := ProceduralMesh.create_platform(20.0, 15.0, 0.02, Color(0.55, 0.55, 0.6, opacity))
		fog.position = Vector3(0, 1.0 + i * 4.0, -12.0 - i * 5.0)
		add_child(fog)
	# Bellas Artes dome (more detailed)
	var dome := ProceduralMesh.create_sphere(2.5, 8, Color("#D4A574"))
	dome.position = Vector3(8.0, 4.5, -20.0)
	add_child(dome)
	# Dome ornament on top
	var dome_orn := ProceduralMesh.create_sphere(0.4, 6, Color("#FCD34D"))
	dome_orn.position = Vector3(8.0, 7.0, -20.0)
	add_child(dome_orn)
	# Bellas Artes building base
	var dome_base := ProceduralMesh.create_box(Vector3(6.0, 4.0, 5.0), Color("#E5E7EB"))
	dome_base.position = Vector3(8.0, 1.5, -20.0)
	add_child(dome_base)
	# Columns on facade
	for col_i in range(5):
		var column := ProceduralMesh.create_cylinder(0.15, 3.5, 6, Color("#D1D5DB"))
		column.position = Vector3(5.8 + col_i * 1.1, 2.0, -17.5)
		add_child(column)
	# Front stairs
	var stairs := ProceduralMesh.create_box(Vector3(6.5, 0.5, 1.5), Color("#D1D5DB"))
	stairs.position = Vector3(8.0, -0.25, -16.5)
	add_child(stairs)
	var stairs2 := ProceduralMesh.create_box(Vector3(5.5, 0.3, 1.0), Color("#E5E7EB"))
	stairs2.position = Vector3(8.0, 0.1, -15.8)
	add_child(stairs2)
	# Urban backdrop buildings at different heights
	var cdmx_bldgs := [
		[Vector3(-12.0, 4.0, -25.0), Vector3(3.0, 8.0, 3.0), Color("#374151")],
		[Vector3(-8.0, 6.0, -28.0), Vector3(2.5, 12.0, 2.5), Color("#4B5563")],
		[Vector3(-4.0, 3.0, -22.0), Vector3(2.0, 6.0, 2.0), Color("#6B7280")],
		[Vector3(14.0, 5.0, -26.0), Vector3(3.0, 10.0, 3.0), Color("#374151")],
		[Vector3(18.0, 3.5, -23.0), Vector3(2.5, 7.0, 2.5), Color("#4B5563")],
		[Vector3(-15.0, 2.5, -20.0), Vector3(2.0, 5.0, 2.0), Color("#6B7280")],
		[Vector3(10.0, 7.0, -30.0), Vector3(2.0, 14.0, 2.0), Color("#334155")],
	]
	for bd in cdmx_bldgs:
		var bldg := ProceduralMesh.create_box(bd[1], bd[2])
		bldg.position = bd[0]
		add_child(bldg)
	# Satellite dishes on rooftops
	for sd_pos in [Vector3(-12.0, 8.3, -25.0), Vector3(14.0, 10.3, -26.0), Vector3(-4.0, 6.3, -22.0)]:
		var dish := ProceduralMesh.create_sphere(0.5, 6, Color("#D1D5DB"))
		dish.position = sd_pos
		add_child(dish)
		var dish_arm := ProceduralMesh.create_cylinder(0.03, 0.6, 4, Color("#6B7280"))
		dish_arm.position = sd_pos + Vector3(0, -0.3, 0)
		add_child(dish_arm)
	_build_hazard()  # Rotating antenna

func _build_arena_rio() -> void:
	## Favela Rio — Tight close-quarters, colorful buildings, Cristo backdrop
	# Main platform (narrower — tight quarters)
	_add_solid_platform(Vector3(0, -0.25, 0), Vector3(14.0, 0.5, 6.0), Color("#16A34A"))
	# Favela rooftop platforms (irregular heights)
	_add_one_way_platform(Vector3(-4.5, 1.5, 0), Vector3(3.0, 0.3, 3.0), Color("#DC2626"))
	_add_one_way_platform(Vector3(4.5, 1.0, 0), Vector3(2.5, 0.3, 2.5), Color("#2563EB"))
	_add_one_way_platform(Vector3(-1.5, 2.8, 0), Vector3(2.5, 0.3, 2.5), Color("#FCD34D"))
	_add_one_way_platform(Vector3(2.0, 3.5, 0), Vector3(2.0, 0.3, 2.0), Color("#A855F7"))
	# Colorful favela buildings (12 buildings at different heights and depths)
	var colors_favela := [Color("#DC2626"), Color("#2563EB"), Color("#FCD34D"), Color("#16A34A"), Color("#A855F7"),
		Color("#F97316"), Color("#EC4899"), Color("#06B6D4"), Color("#84CC16"), Color("#EF4444"), Color("#8B5CF6"), Color("#14B8A6")]
	var favela_data := [
		[Vector3(-6.0, 0.5, -3.0), Vector3(2.5, 3.0, 1.0)],
		[Vector3(-3.5, 0.8, -3.5), Vector3(2.2, 3.5, 1.0)],
		[Vector3(-1.0, 0.3, -3.0), Vector3(2.0, 2.5, 1.0)],
		[Vector3(1.5, 0.6, -3.3), Vector3(2.3, 3.2, 1.0)],
		[Vector3(4.0, 0.4, -3.0), Vector3(2.0, 2.8, 1.0)],
		[Vector3(6.5, 0.7, -3.5), Vector3(2.2, 3.4, 1.0)],
		[Vector3(-5.0, 1.5, -5.0), Vector3(2.5, 4.0, 1.0)],
		[Vector3(-2.0, 1.8, -5.5), Vector3(2.0, 4.5, 1.0)],
		[Vector3(1.0, 1.2, -5.0), Vector3(2.2, 3.5, 1.0)],
		[Vector3(3.5, 1.6, -5.3), Vector3(2.0, 4.2, 1.0)],
		[Vector3(6.0, 1.0, -5.0), Vector3(2.5, 3.0, 1.0)],
		[Vector3(-7.5, 0.3, -4.0), Vector3(1.8, 2.5, 1.0)],
	]
	for fi in range(favela_data.size()):
		var fd = favela_data[fi]
		var wall := ProceduralMesh.create_box(fd[1], colors_favela[fi])
		wall.position = fd[0]
		add_child(wall)
		# Windows on favela buildings
		for wr in range(int(fd[1].y) - 1):
			var fw := ProceduralMesh.create_box(Vector3(0.3, 0.25, 0.05), Color("#1F2937"))
			fw.position = fd[0] + Vector3(0.4, -fd[1].y / 2.0 + 0.8 + wr * 0.9, fd[1].z / 2.0 + 0.03)
			add_child(fw)
	# Clotheslines between buildings
	for cl_i in range(4):
		var cl := ProceduralMesh.create_cylinder(0.01, 5.0, 4, Color("#D1D5DB"))
		cl.position = Vector3(-4.0 + cl_i * 3.0, 2.5 + cl_i * 0.3, -3.5)
		cl.rotation_degrees.z = 90.0
		add_child(cl)
		# Hanging laundry
		for lj in range(3):
			var laundry_color: Color = colors_favela[(cl_i * 3 + lj) % colors_favela.size()]
			var laundry := ProceduralMesh.create_box(Vector3(0.25, 0.35, 0.04), laundry_color)
			laundry.position = Vector3(-5.0 + cl_i * 3.0 + lj * 1.5, 2.2 + cl_i * 0.3, -3.5)
			add_child(laundry)
	# Cable tangles (messy wires between buildings)
	for ct_i in range(6):
		var tangle := ProceduralMesh.create_cylinder(0.015, 4.0 + ct_i * 0.5, 4, Color.BLACK)
		tangle.position = Vector3(-5.0 + ct_i * 2.2, 2.0 + ct_i * 0.2, -4.0)
		tangle.rotation_degrees.z = 75.0 + ct_i * 8.0
		add_child(tangle)
	# Cristo Redentor backdrop (more detailed)
	var cristo_body := ProceduralMesh.create_box(Vector3(0.8, 4.0, 0.6), Color("#E5E7EB"))
	cristo_body.position = Vector3(0.0, 6.0, -25.0)
	add_child(cristo_body)
	var cristo_arms := ProceduralMesh.create_box(Vector3(5.0, 0.6, 0.4), Color("#E5E7EB"))
	cristo_arms.position = Vector3(0.0, 7.5, -25.0)
	add_child(cristo_arms)
	var cristo_head := ProceduralMesh.create_sphere(0.6, 6, Color("#E5E7EB"))
	cristo_head.position = Vector3(0.0, 8.5, -25.0)
	add_child(cristo_head)
	# Cristo face features
	var cristo_eyes_l := ProceduralMesh.create_sphere(0.08, 4, Color("#9CA3AF"))
	cristo_eyes_l.position = Vector3(-0.15, 8.55, -24.6)
	add_child(cristo_eyes_l)
	var cristo_eyes_r := ProceduralMesh.create_sphere(0.08, 4, Color("#9CA3AF"))
	cristo_eyes_r.position = Vector3(0.15, 8.55, -24.6)
	add_child(cristo_eyes_r)
	# Cristo hands (small boxes at arm ends)
	var cristo_hand_l := ProceduralMesh.create_box(Vector3(0.3, 0.4, 0.3), Color("#E5E7EB"))
	cristo_hand_l.position = Vector3(-2.7, 7.5, -25.0)
	add_child(cristo_hand_l)
	var cristo_hand_r := ProceduralMesh.create_box(Vector3(0.3, 0.4, 0.3), Color("#E5E7EB"))
	cristo_hand_r.position = Vector3(2.7, 7.5, -25.0)
	add_child(cristo_hand_r)
	# Cristo pedestal
	var pedestal := ProceduralMesh.create_box(Vector3(2.0, 1.5, 2.0), Color("#D1D5DB"))
	pedestal.position = Vector3(0.0, 3.5, -25.0)
	add_child(pedestal)
	var pedestal_base := ProceduralMesh.create_box(Vector3(3.0, 0.5, 3.0), Color("#9CA3AF"))
	pedestal_base.position = Vector3(0.0, 2.5, -25.0)
	add_child(pedestal_base)
	# Hill under Cristo
	var hill := ProceduralMesh.create_cone(8.0, 6.0, 6, Color("#166534"))
	hill.position = Vector3(0.0, 0.0, -25.0)
	add_child(hill)
	# Palm trees on hillside
	for pt_pos in [Vector3(-3.0, 2.5, -22.0), Vector3(4.0, 2.0, -23.0), Vector3(-5.0, 1.5, -21.0), Vector3(6.0, 1.0, -22.0)]:
		var pt_trunk := ProceduralMesh.create_cylinder(0.1, 3.0, 6, Color("#92400E"))
		pt_trunk.position = pt_pos
		pt_trunk.rotation_degrees.z = 8.0
		add_child(pt_trunk)
		var pt_fronds := ProceduralMesh.create_sphere(1.0, 6, Color("#22C55E"))
		pt_fronds.position = pt_pos + Vector3(0.2, 2.0, 0)
		add_child(pt_fronds)
	# Bird silhouettes (small dark triangles in sky)
	for bird_i in range(5):
		var bird_l := ProceduralMesh.create_cylinder(0.02, 0.4, 4, Color("#1F2937"))
		bird_l.position = Vector3(-3.0 + bird_i * 1.8, 10.0 + bird_i * 0.5, -18.0)
		bird_l.rotation_degrees.z = 30.0
		add_child(bird_l)
		var bird_r := ProceduralMesh.create_cylinder(0.02, 0.4, 4, Color("#1F2937"))
		bird_r.position = Vector3(-2.7 + bird_i * 1.8, 10.0 + bird_i * 0.5, -18.0)
		bird_r.rotation_degrees.z = -30.0
		add_child(bird_r)
	# Ocean visible in distance
	var ocean := ProceduralMesh.create_platform(50.0, 30.0, 0.1, Color("#0EA5E9"))
	ocean.position = Vector3(0, -1.0, -40.0)
	add_child(ocean)
	# Ocean horizon foam line
	var foam := ProceduralMesh.create_platform(50.0, 0.5, 0.05, Color("#BAE6FD"))
	foam.position = Vector3(0, -0.9, -25.0)
	add_child(foam)
	_build_hazard()

func _build_arena_dallas() -> void:
	## Data Center Dallas — Server room corridors, neon cyan LEDs
	# Main platform (dark industrial floor)
	_add_solid_platform(Vector3(0, -0.25, 0), Vector3(16.0, 0.5, 8.0), Color("#1E293B"))
	# Server rack platforms
	_add_one_way_platform(Vector3(-5.0, 1.5, 0), Vector3(2.5, 0.3, 3.0), Color("#0F172A"))
	_add_one_way_platform(Vector3(5.0, 1.5, 0), Vector3(2.5, 0.3, 3.0), Color("#0F172A"))
	_add_one_way_platform(Vector3(0.0, 3.0, 0), Vector3(3.0, 0.3, 2.5), Color("#0F172A"))
	# Server racks — 16 racks in two rows (left and right)
	for side in [-1, 1]:
		for i in range(8):
			var rack := ProceduralMesh.create_box(Vector3(0.9, 3.0, 0.7), Color("#0F172A"))
			rack.position = Vector3(side * (2.0 + i * 1.1), 1.5, -2.8)
			add_child(rack)
			# Rack face panel
			var face := ProceduralMesh.create_box(Vector3(0.85, 2.8, 0.05), Color("#1E293B"))
			face.position = Vector3(side * (2.0 + i * 1.1), 1.5, -2.43)
			add_child(face)
			# Blinking LED lights (multiple rows)
			for j in range(5):
				var led_color: Color = Color("#06B6D4") if (i + j) % 3 != 0 else Color("#22C55E")
				if (i + j) % 7 == 0:
					led_color = Color("#F59E0B")
				var led := ProceduralMesh.create_sphere(0.03, 4, led_color)
				led.position = Vector3(side * (2.0 + i * 1.1) + 0.3, 0.5 + j * 0.55, -2.42)
				add_child(led)
				var led2 := ProceduralMesh.create_sphere(0.03, 4, Color("#06B6D4") if (i + j) % 2 == 0 else Color("#EF4444"))
				led2.position = Vector3(side * (2.0 + i * 1.1) + 0.15, 0.5 + j * 0.55, -2.42)
				add_child(led2)
	# Cable trays overhead
	for ct_i in range(4):
		var tray := ProceduralMesh.create_box(Vector3(16.0, 0.08, 0.4), Color("#6B7280"))
		tray.position = Vector3(0, 5.5, -2.0 + ct_i * 1.5)
		add_child(tray)
		for cb_i in range(3):
			var cable_color: Color = [Color("#2563EB"), Color("#F97316"), Color("#22C55E")][cb_i]
			var cable := ProceduralMesh.create_cylinder(0.025, 15.5, 4, cable_color)
			cable.position = Vector3(0, 5.55, -2.15 + ct_i * 1.5 + cb_i * 0.12)
			cable.rotation_degrees.z = 90.0
			add_child(cable)
	# Ceiling structure
	var ceiling := ProceduralMesh.create_platform(18.0, 10.0, 0.1, Color("#1E293B"))
	ceiling.position.y = 6.0
	add_child(ceiling)
	# Ceiling fluorescent lights
	for fl_i in range(6):
		var fl := ProceduralMesh.create_box(Vector3(0.15, 0.05, 2.0), Color("#F8FAFC"))
		fl.position = Vector3(-6.0 + fl_i * 2.5, 5.9, -1.0)
		add_child(fl)
	# Raised floor tiles
	for ft_x in range(8):
		for ft_z in range(4):
			var tile := ProceduralMesh.create_box(Vector3(1.8, 0.04, 1.8), Color("#334155"))
			tile.position = Vector3(-7.0 + ft_x * 2.0, 0.02, -3.0 + ft_z * 2.0)
			add_child(tile)
	# Fire suppression pipes (red, overhead)
	for fp_i in range(2):
		var pipe := ProceduralMesh.create_cylinder(0.05, 17.0, 6, Color("#DC2626"))
		pipe.position = Vector3(0, 5.2, -1.0 + fp_i * 3.0)
		pipe.rotation_degrees.z = 90.0
		add_child(pipe)
		for sp_i in range(6):
			var sprinkler := ProceduralMesh.create_sphere(0.06, 4, Color("#DC2626"))
			sprinkler.position = Vector3(-6.0 + sp_i * 2.5, 5.12, -1.0 + fp_i * 3.0)
			add_child(sprinkler)
	# Cooling vents with grates
	for cv_i in range(3):
		var vent := ProceduralMesh.create_box(Vector3(1.5, 0.8, 0.1), Color("#4B5563"))
		vent.position = Vector3(-5.0 + cv_i * 5.0, 1.0, -3.3)
		add_child(vent)
		for gl_i in range(4):
			var grate := ProceduralMesh.create_box(Vector3(1.3, 0.03, 0.05), Color("#1E293B"))
			grate.position = Vector3(-5.0 + cv_i * 5.0, 0.7 + gl_i * 0.2, -3.24)
			add_child(grate)
	# UPS battery cabinets
	for ups_i in range(3):
		var ups := ProceduralMesh.create_box(Vector3(1.5, 2.0, 1.0), Color("#1F2937"))
		ups.position = Vector3(-4.0 + ups_i * 4.0, 1.0, 3.0)
		add_child(ups)
		var ups_panel := ProceduralMesh.create_box(Vector3(0.6, 0.4, 0.05), Color("#0F172A"))
		ups_panel.position = Vector3(-4.0 + ups_i * 4.0, 1.5, 2.47)
		add_child(ups_panel)
		var ups_led := ProceduralMesh.create_sphere(0.04, 4, Color("#22C55E"))
		ups_led.position = Vector3(-4.0 + ups_i * 4.0 + 0.2, 1.6, 2.46)
		add_child(ups_led)
	# Monitoring screens on walls
	for ms_i in range(4):
		var screen := ProceduralMesh.create_box(Vector3(1.2, 0.8, 0.05), Color("#0F172A"))
		screen.position = Vector3(-5.0 + ms_i * 3.5, 3.5, -3.3)
		add_child(screen)
		var screen_glow := ProceduralMesh.create_box(Vector3(1.0, 0.6, 0.02), Color("#06B6D4").darkened(0.5))
		screen_glow.position = Vector3(-5.0 + ms_i * 3.5, 3.5, -3.26)
		add_child(screen_glow)
		for sg_i in range(3):
			var graph := ProceduralMesh.create_box(Vector3(0.8, 0.02, 0.01), Color("#06B6D4"))
			graph.position = Vector3(-5.0 + ms_i * 3.5, 3.25 + sg_i * 0.2, -3.24)
			add_child(graph)
	# Neon floor strips
	for i in range(5):
		var strip := ProceduralMesh.create_box(Vector3(16.0, 0.02, 0.08), Color("#06B6D4"))
		strip.position = Vector3(0, 0.01, -3.0 + i * 1.5)
		add_child(strip)
	_build_hazard()

func _build_arena_bogota() -> void:
	## Selva Bogota — Jungle canopy with relay towers, foliage
	# Main platform (mossy stone)
	_add_solid_platform(Vector3(0, -0.25, 0), Vector3(15.0, 0.5, 7.0), Color("#166534"))
	# Tree platforms
	_add_one_way_platform(Vector3(-5.0, 2.5, 0), Vector3(3.0, 0.3, 2.5), Color("#15803D"))
	_add_one_way_platform(Vector3(5.0, 3.0, 0), Vector3(3.0, 0.3, 2.5), Color("#15803D"))
	_add_one_way_platform(Vector3(0.0, 4.5, 0), Vector3(2.5, 0.3, 2.0), Color("#15803D"))
	# Trees (8+ with varying sizes)
	var tree_data := [
		[Vector3(-7.0, 4.5, -3.0), 0.35, 9.0, 3.0],
		[Vector3(-4.0, 3.5, -4.0), 0.25, 7.0, 2.0],
		[Vector3(-2.0, 4.0, -3.0), 0.3, 8.0, 2.5],
		[Vector3(0.5, 3.0, -5.0), 0.2, 6.0, 1.8],
		[Vector3(3.0, 4.5, -3.0), 0.3, 9.0, 2.8],
		[Vector3(5.5, 3.5, -4.5), 0.25, 7.0, 2.2],
		[Vector3(7.5, 4.0, -3.5), 0.3, 8.0, 2.5],
		[Vector3(-5.5, 3.0, -5.5), 0.2, 6.0, 1.8],
		[Vector3(1.5, 5.0, -6.0), 0.35, 10.0, 3.0],
	]
	for td in tree_data:
		var trunk := ProceduralMesh.create_cylinder(td[1], td[2], 6, Color("#78350F"))
		trunk.position = td[0]
		add_child(trunk)
		var canopy := ProceduralMesh.create_sphere(td[3], 6, Color("#166534"))
		canopy.position = td[0] + Vector3(0, td[2] / 2.0 + td[3] * 0.6, 0)
		add_child(canopy)
		# Secondary canopy layer (lighter green)
		var canopy2 := ProceduralMesh.create_sphere(td[3] * 0.7, 6, Color("#22C55E"))
		canopy2.position = td[0] + Vector3(td[3] * 0.3, td[2] / 2.0 + td[3] * 0.8, 0)
		add_child(canopy2)
	# Hanging vines (10+)
	for vi in range(12):
		var vine_len: float = 2.0 + fmod(vi * 1.7, 3.0)
		var vine := ProceduralMesh.create_cylinder(0.02, vine_len, 4, Color("#22C55E"))
		vine.position = Vector3(-6.0 + vi * 1.2, 6.5 + fmod(vi * 0.7, 1.5), -2.5 - fmod(vi * 0.5, 2.0))
		add_child(vine)
		# Vine curl at bottom
		var curl := ProceduralMesh.create_sphere(0.06, 4, Color("#16A34A"))
		curl.position = vine.position + Vector3(0, -vine_len / 2.0, 0)
		add_child(curl)
	# Orchid flowers (small colored spheres on trees)
	var orchid_colors := [Color("#EC4899"), Color("#A855F7"), Color("#F97316"), Color("#FCD34D"), Color("#DC2626"),
		Color("#F472B6"), Color("#C084FC")]
	for oi in range(7):
		var orchid := ProceduralMesh.create_sphere(0.12, 4, orchid_colors[oi])
		orchid.position = tree_data[oi][0] + Vector3(0.3, tree_data[oi][2] * 0.3, 0.2)
		add_child(orchid)
		# Second orchid cluster
		var orchid2 := ProceduralMesh.create_sphere(0.08, 4, orchid_colors[(oi + 3) % orchid_colors.size()])
		orchid2.position = tree_data[oi][0] + Vector3(-0.2, tree_data[oi][2] * 0.5, 0.15)
		add_child(orchid2)
	# Fallen logs as obstacles
	var log1 := ProceduralMesh.create_cylinder(0.2, 3.0, 6, Color("#78350F").darkened(0.2))
	log1.position = Vector3(-3.0, 0.2, 1.5)
	log1.rotation_degrees.z = 90.0
	add_child(log1)
	var log2 := ProceduralMesh.create_cylinder(0.25, 2.5, 6, Color("#78350F").darkened(0.15))
	log2.position = Vector3(4.0, 0.2, 2.0)
	log2.rotation_degrees.z = 85.0
	add_child(log2)
	# Moss on logs
	var moss1 := ProceduralMesh.create_sphere(0.3, 4, Color("#166534"))
	moss1.position = Vector3(-3.0, 0.4, 1.5)
	add_child(moss1)
	# River/stream below (blue plane)
	var river := ProceduralMesh.create_platform(20.0, 2.0, 0.05, Color("#0EA5E9").darkened(0.3))
	river.position = Vector3(0, -3.0, 0)
	add_child(river)
	# River banks
	var bank_l := ProceduralMesh.create_platform(20.0, 0.5, 0.08, Color("#78350F"))
	bank_l.position = Vector3(0, -2.95, -1.1)
	add_child(bank_l)
	var bank_r := ProceduralMesh.create_platform(20.0, 0.5, 0.08, Color("#78350F"))
	bank_r.position = Vector3(0, -2.95, 1.1)
	add_child(bank_r)
	# Mist layers (more layers)
	for i in range(4):
		var opacity: float = 0.06 + i * 0.03
		var mist := ProceduralMesh.create_platform(22.0, 14.0, 0.02, Color(0.8, 0.9, 0.8, opacity))
		mist.position = Vector3(0, 0.3 + i * 1.5, -4.0 - i * 1.0)
		add_child(mist)
	# Relay tower with equipment boxes
	_build_tower(Vector3(0.0, 0.0, -8.0), 12.0, Color("#6B7280"), Color("#A3E635"))
	# Equipment boxes at tower base
	for eq_i in range(3):
		var eq_box := ProceduralMesh.create_box(Vector3(0.6, 0.5, 0.4), Color("#374151"))
		eq_box.position = Vector3(-0.8 + eq_i * 0.8, 0.25, -8.0)
		add_child(eq_box)
		var eq_led := ProceduralMesh.create_sphere(0.03, 4, Color("#A3E635"))
		eq_led.position = Vector3(-0.8 + eq_i * 0.8, 0.4, -7.78)
		add_child(eq_led)
	# Monkeys (small brown spheres on branches)
	var monkey_positions := [
		Vector3(-6.5, 7.0, -3.0), Vector3(3.5, 7.5, -3.0), Vector3(7.0, 6.5, -3.5),
		Vector3(-1.5, 8.0, -3.0), Vector3(5.0, 6.0, -4.5),
	]
	for mp in monkey_positions:
		# Monkey body
		var m_body := ProceduralMesh.create_sphere(0.2, 4, Color("#92400E"))
		m_body.position = mp
		add_child(m_body)
		# Monkey head
		var m_head := ProceduralMesh.create_sphere(0.12, 4, Color("#A16207"))
		m_head.position = mp + Vector3(0.1, 0.2, 0)
		add_child(m_head)
		# Monkey tail (small cylinder)
		var m_tail := ProceduralMesh.create_cylinder(0.02, 0.4, 4, Color("#92400E"))
		m_tail.position = mp + Vector3(-0.15, 0.0, 0)
		m_tail.rotation_degrees.z = 45.0
		add_child(m_tail)
	_build_hazard()

func _build_arena_buenos_aires() -> void:
	## Pampa Buenos Aires — Wide open field, long-range towers, Obelisco
	# Wide main platform (open pampa)
	_add_solid_platform(Vector3(0, -0.25, 0), Vector3(20.0, 0.5, 10.0), Color("#78716C"))
	# Distant elevated platforms (far apart for long-range combat)
	_add_one_way_platform(Vector3(-7.0, 1.5, 0), Vector3(3.0, 0.3, 3.0), Color("#57534E"))
	_add_one_way_platform(Vector3(7.0, 1.5, 0), Vector3(3.0, 0.3, 3.0), Color("#57534E"))
	# Multiple long-range towers with cables between them
	_build_tower(Vector3(-8.0, 0.0, -4.0), 8.0, Color("#9CA3AF"), Color("#F59E0B"))
	_build_tower(Vector3(8.0, 0.0, -4.0), 8.0, Color("#9CA3AF"), Color("#F59E0B"))
	_build_tower(Vector3(0.0, 0.0, -6.0), 10.0, Color("#9CA3AF"), Color("#F59E0B"))
	_build_tower(Vector3(-14.0, 0.0, -8.0), 6.0, Color("#9CA3AF"), Color("#F59E0B"))
	_build_tower(Vector3(14.0, 0.0, -8.0), 6.0, Color("#9CA3AF"), Color("#F59E0B"))
	# Cables between all towers
	var cable_pairs := [
		[Vector3(-8.0, 7.5, -4.0), Vector3(0.0, 9.5, -6.0)],
		[Vector3(0.0, 9.5, -6.0), Vector3(8.0, 7.5, -4.0)],
		[Vector3(-14.0, 5.5, -8.0), Vector3(-8.0, 7.5, -4.0)],
		[Vector3(8.0, 7.5, -4.0), Vector3(14.0, 5.5, -8.0)],
	]
	for cp in cable_pairs:
		var dist: float = cp[0].distance_to(cp[1])
		var mid: Vector3 = (cp[0] + cp[1]) / 2.0
		var cb := ProceduralMesh.create_cylinder(0.02, dist, 4, Color.BLACK)
		cb.position = mid
		var dir: Vector3 = (cp[1] - cp[0]).normalized()
		cb.rotation_degrees.z = rad_to_deg(atan2(dir.y, dir.x)) + 90.0
		add_child(cb)
	# Golden grass (more patches)
	for i in range(14):
		var grass := ProceduralMesh.create_platform(3.0, 2.0, 0.05, Color("#FDE68A"))
		grass.position = Vector3(-9.0 + i * 1.5, 0.03, 2.5 + fmod(i * 1.3, 3.0))
		add_child(grass)
	# Darker grass patches for variation
	for i in range(8):
		var dg := ProceduralMesh.create_platform(2.5, 1.5, 0.04, Color("#D4A017"))
		dg.position = Vector3(-8.0 + i * 2.5, 0.04, 4.0 + fmod(i * 0.9, 2.0))
		add_child(dg)
	# Fence posts with wire
	for fp_i in range(10):
		var post := ProceduralMesh.create_cylinder(0.04, 1.2, 4, Color("#78350F"))
		post.position = Vector3(-9.0 + fp_i * 2.0, 0.6, 4.5)
		add_child(post)
	# Fence wire
	for fw_i in range(2):
		var wire := ProceduralMesh.create_cylinder(0.01, 18.0, 4, Color("#6B7280"))
		wire.position = Vector3(0, 0.5 + fw_i * 0.4, 4.5)
		wire.rotation_degrees.z = 90.0
		add_child(wire)
	# Windmill/molino in background
	var molino_pole := ProceduralMesh.create_cylinder(0.1, 6.0, 6, Color("#6B7280"))
	molino_pole.position = Vector3(-12.0, 3.0, -12.0)
	add_child(molino_pole)
	var molino_hub := ProceduralMesh.create_sphere(0.3, 6, Color("#9CA3AF"))
	molino_hub.position = Vector3(-12.0, 6.2, -12.0)
	add_child(molino_hub)
	# Windmill blades (4 flat rectangles)
	for bl_i in range(4):
		var blade := ProceduralMesh.create_box(Vector3(0.2, 2.0, 0.05), Color("#D1D5DB"))
		blade.position = Vector3(-12.0, 6.2, -12.0)
		blade.rotation_degrees.z = bl_i * 45.0
		add_child(blade)
	# Windmill water tank
	var wm_tank := ProceduralMesh.create_cylinder(0.8, 0.6, 8, Color("#374151"))
	wm_tank.position = Vector3(-11.0, 0.3, -11.5)
	add_child(wm_tank)
	# Gaucho hut
	var hut_walls := ProceduralMesh.create_box(Vector3(2.5, 1.8, 2.0), Color("#92400E"))
	hut_walls.position = Vector3(12.0, 0.9, -10.0)
	add_child(hut_walls)
	var hut_roof := ProceduralMesh.create_cone(2.0, 1.2, 4, Color("#78350F"))
	hut_roof.position = Vector3(12.0, 2.4, -10.0)
	add_child(hut_roof)
	var hut_door := ProceduralMesh.create_box(Vector3(0.6, 1.2, 0.05), Color("#78350F").darkened(0.3))
	hut_door.position = Vector3(12.0, 0.6, -8.98)
	add_child(hut_door)
	# Hut window
	var hut_win := ProceduralMesh.create_box(Vector3(0.4, 0.4, 0.05), Color("#FDE68A"))
	hut_win.position = Vector3(12.8, 1.2, -8.98)
	add_child(hut_win)
	# Distant city skyline (Buenos Aires)
	var skyline_data := [
		[Vector3(-6.0, 3.0, -28.0), Vector3(2.0, 6.0, 1.5)],
		[Vector3(-3.0, 4.0, -30.0), Vector3(1.5, 8.0, 1.5)],
		[Vector3(-1.0, 2.5, -27.0), Vector3(2.0, 5.0, 1.5)],
		[Vector3(2.0, 3.5, -29.0), Vector3(1.8, 7.0, 1.5)],
		[Vector3(5.0, 2.0, -26.0), Vector3(2.5, 4.0, 1.5)],
		[Vector3(7.0, 3.0, -28.0), Vector3(1.5, 6.0, 1.5)],
	]
	for sd in skyline_data:
		var bldg := ProceduralMesh.create_box(sd[1], Color("#6B7280").darkened(0.3))
		bldg.position = sd[0]
		add_child(bldg)
	# Obelisco (more detailed with base plaza)
	var obelisco := ProceduralMesh.create_box(Vector3(0.8, 12.0, 0.8), Color("#E5E7EB"))
	obelisco.position = Vector3(0.0, 6.0, -22.0)
	add_child(obelisco)
	var obelisco_tip := ProceduralMesh.create_cone(0.5, 1.5, 4, Color("#E5E7EB"))
	obelisco_tip.position = Vector3(0.0, 12.5, -22.0)
	add_child(obelisco_tip)
	# Obelisco base plaza
	var plaza := ProceduralMesh.create_platform(6.0, 6.0, 0.15, Color("#D1D5DB"))
	plaza.position = Vector3(0.0, -0.1, -22.0)
	add_child(plaza)
	# Plaza inner ring
	var plaza_inner := ProceduralMesh.create_platform(3.0, 3.0, 0.1, Color("#9CA3AF"))
	plaza_inner.position = Vector3(0.0, 0.0, -22.0)
	add_child(plaza_inner)
	# Obelisco window slits
	for ow_i in range(5):
		var slit := ProceduralMesh.create_box(Vector3(0.1, 0.5, 0.05), Color("#9CA3AF"))
		slit.position = Vector3(0.0, 2.0 + ow_i * 2.0, -21.58)
		add_child(slit)
	# Argentine flag color accents (celeste y blanco stripes on platform edge)
	var flag_celeste := ProceduralMesh.create_box(Vector3(20.0, 0.08, 0.15), Color("#75AADB"))
	flag_celeste.position = Vector3(0, 0.02, -5.0)
	add_child(flag_celeste)
	var flag_white := ProceduralMesh.create_box(Vector3(20.0, 0.08, 0.15), Color.WHITE)
	flag_white.position = Vector3(0, 0.02, -4.8)
	add_child(flag_white)
	var flag_celeste2 := ProceduralMesh.create_box(Vector3(20.0, 0.08, 0.15), Color("#75AADB"))
	flag_celeste2.position = Vector3(0, 0.02, -4.6)
	add_child(flag_celeste2)
	_build_hazard()

func _build_arena_miami() -> void:
	## Beach Miami — Beachfront + hotel rooftop, neon sunset
	# Beach platform (sand colored)
	_add_solid_platform(Vector3(0, -0.25, 0), Vector3(16.0, 0.5, 8.0), Color("#FDE68A"))
	# Hotel rooftop platform (elevated right)
	_add_one_way_platform(Vector3(5.0, 2.5, 0), Vector3(4.0, 0.3, 3.5), Color("#F472B6"))
	# Pool deck platform (left)
	_add_one_way_platform(Vector3(-5.0, 1.5, 0), Vector3(3.5, 0.3, 3.0), Color("#38BDF8"))
	# Hotel building backdrop (main)
	var hotel := ProceduralMesh.create_box(Vector3(5.0, 8.0, 3.0), Color("#F9A8D4"))
	hotel.position = Vector3(5.0, 4.0, -4.0)
	add_child(hotel)
	# Hotel windows (more rows)
	for row in range(5):
		for col in range(4):
			var win := ProceduralMesh.create_box(Vector3(0.5, 0.4, 0.1), Color("#38BDF8"))
			win.position = Vector3(3.2 + col * 1.1, 1.5 + row * 1.4, -2.45)
			add_child(win)
	# Pool with blue water (on pool deck)
	var pool := ProceduralMesh.create_box(Vector3(2.5, 0.15, 1.8), Color("#0EA5E9"))
	pool.position = Vector3(-5.0, 1.7, 0.0)
	add_child(pool)
	# Pool edge
	var pool_edge := ProceduralMesh.create_box(Vector3(2.8, 0.08, 2.1), Color("#E5E7EB"))
	pool_edge.position = Vector3(-5.0, 1.62, 0.0)
	add_child(pool_edge)
	# Lounge chairs by pool
	for lc_i in range(3):
		var chair_base := ProceduralMesh.create_box(Vector3(0.4, 0.08, 0.8), Color("#F8FAFC"))
		chair_base.position = Vector3(-6.5, 1.68, -0.8 + lc_i * 0.9)
		add_child(chair_base)
		var chair_back := ProceduralMesh.create_box(Vector3(0.4, 0.4, 0.08), Color("#F8FAFC"))
		chair_back.position = Vector3(-6.5, 1.88, -0.4 + lc_i * 0.9)
		chair_back.rotation_degrees.x = -30.0
		add_child(chair_back)
	# Bar counter
	var bar := ProceduralMesh.create_box(Vector3(1.8, 0.8, 0.5), Color("#78350F"))
	bar.position = Vector3(-3.5, 2.0, 1.2)
	add_child(bar)
	# Bar stools
	for bs_i in range(3):
		var stool := ProceduralMesh.create_cylinder(0.12, 0.5, 6, Color("#6B7280"))
		stool.position = Vector3(-4.1 + bs_i * 0.6, 1.85, 1.6)
		add_child(stool)
		var seat := ProceduralMesh.create_cylinder(0.15, 0.05, 6, Color("#DC2626"))
		seat.position = Vector3(-4.1 + bs_i * 0.6, 2.12, 1.6)
		add_child(seat)
	# Lifeguard tower
	var lg_legs_l := ProceduralMesh.create_cylinder(0.06, 3.0, 4, Color("#FDE68A").darkened(0.2))
	lg_legs_l.position = Vector3(8.0, 1.5, 1.0)
	add_child(lg_legs_l)
	var lg_legs_r := ProceduralMesh.create_cylinder(0.06, 3.0, 4, Color("#FDE68A").darkened(0.2))
	lg_legs_r.position = Vector3(8.8, 1.5, 1.0)
	add_child(lg_legs_r)
	var lg_seat := ProceduralMesh.create_box(Vector3(1.2, 0.6, 0.8), Color("#F97316"))
	lg_seat.position = Vector3(8.4, 3.2, 1.0)
	add_child(lg_seat)
	var lg_roof := ProceduralMesh.create_box(Vector3(1.5, 0.08, 1.0), Color("#F97316"))
	lg_roof.position = Vector3(8.4, 3.8, 1.0)
	add_child(lg_roof)
	# Surfboards leaning on wall
	for sb_i in range(3):
		var sb_color: Color = [Color("#06B6D4"), Color("#F97316"), Color("#EC4899")][sb_i]
		var surfboard := ProceduralMesh.create_box(Vector3(0.3, 2.0, 0.06), sb_color)
		surfboard.position = Vector3(7.0 + sb_i * 0.5, 1.2, -2.4)
		surfboard.rotation_degrees.z = -10.0 + sb_i * 5.0
		add_child(surfboard)
	# Neon signs (colored glowing boxes on hotel)
	var neon_colors := [Color("#F472B6"), Color("#06B6D4"), Color("#A855F7"), Color("#22C55E")]
	for ns_i in range(4):
		var neon := ProceduralMesh.create_box(Vector3(0.8, 0.3, 0.08), neon_colors[ns_i])
		neon.position = Vector3(3.5 + ns_i * 1.0, 7.5, -2.45)
		add_child(neon)
	# "MIAMI" neon sign
	var miami_sign := ProceduralMesh.create_box(Vector3(3.0, 0.5, 0.08), Color("#F472B6"))
	miami_sign.position = Vector3(5.0, 8.5, -2.45)
	add_child(miami_sign)
	# Palm trees (6+)
	var palm_positions := [-8.0, -5.0, -2.0, 2.0, 7.5, 9.5]
	for px in palm_positions:
		var trunk := ProceduralMesh.create_cylinder(0.15, 4.0, 6, Color("#92400E"))
		trunk.position = Vector3(px, 2.0, -1.5)
		trunk.rotation_degrees.z = 5.0 + fmod(px * 3.0, 8.0) - 4.0
		add_child(trunk)
		var fronds := ProceduralMesh.create_sphere(1.2, 6, Color("#22C55E"))
		fronds.position = Vector3(px + 0.2, 4.5, -1.5)
		add_child(fronds)
		# Coconuts
		var coconut := ProceduralMesh.create_sphere(0.1, 4, Color("#92400E"))
		coconut.position = Vector3(px + 0.3, 3.8, -1.3)
		add_child(coconut)
	# Ocean backdrop
	var ocean := ProceduralMesh.create_platform(50.0, 35.0, 0.1, Color("#0EA5E9"))
	ocean.position = Vector3(0, -0.5, -18.0)
	add_child(ocean)
	# Ocean wave lines
	for wv_i in range(3):
		var wave := ProceduralMesh.create_platform(50.0, 0.3, 0.05, Color("#BAE6FD"))
		wave.position = Vector3(0, -0.4, -5.0 - wv_i * 4.0)
		add_child(wave)
	# Cruise ship in distance
	var ship_hull := ProceduralMesh.create_box(Vector3(5.0, 1.2, 1.5), Color("#F8FAFC"))
	ship_hull.position = Vector3(-15.0, 0.5, -30.0)
	add_child(ship_hull)
	var ship_upper := ProceduralMesh.create_box(Vector3(3.5, 0.8, 1.2), Color("#E5E7EB"))
	ship_upper.position = Vector3(-15.0, 1.5, -30.0)
	add_child(ship_upper)
	var ship_funnel := ProceduralMesh.create_cylinder(0.2, 0.8, 6, Color("#DC2626"))
	ship_funnel.position = Vector3(-14.0, 2.3, -30.0)
	add_child(ship_funnel)
	# Ship windows
	for sw_i in range(6):
		var sw := ProceduralMesh.create_sphere(0.06, 4, Color("#38BDF8"))
		sw.position = Vector3(-16.5 + sw_i * 0.7, 0.5, -29.24)
		add_child(sw)
	# Jet ski on water
	var jetski := ProceduralMesh.create_box(Vector3(0.6, 0.3, 0.3), Color("#F97316"))
	jetski.position = Vector3(10.0, -0.2, -8.0)
	add_child(jetski)
	var jetski_seat := ProceduralMesh.create_box(Vector3(0.3, 0.2, 0.2), Color("#1F2937"))
	jetski_seat.position = Vector3(10.1, 0.0, -8.0)
	add_child(jetski_seat)
	# Sunset gradient layers
	var sunset_colors := [Color("#FDE68A"), Color("#FDBA74"), Color("#F97316"), Color("#DC2626"), Color("#7C3AED")]
	for si in range(5):
		var sky_band := ProceduralMesh.create_platform(60.0, 0.1, 4.0, sunset_colors[si])
		sky_band.position = Vector3(0, 3.0 + si * 4.0, -48.0)
		sky_band.rotation_degrees.x = 90.0
		add_child(sky_band)
	_build_hazard()

func _build_arena_wispa() -> void:
	## WISPA Convention Center — Vendor booths as platforms, stage, event lighting
	# Main convention floor
	_add_solid_platform(Vector3(0, -0.25, 0), Vector3(18.0, 0.5, 9.0), Color("#1D4ED8"))
	# Vendor booth platforms
	_add_one_way_platform(Vector3(-5.5, 1.5, 0), Vector3(3.5, 0.3, 3.0), Color("#1E40AF"))
	_add_one_way_platform(Vector3(5.5, 1.5, 0), Vector3(3.5, 0.3, 3.0), Color("#1E40AF"))
	# Stage platform (center elevated)
	_add_one_way_platform(Vector3(0, 3.0, 0), Vector3(5.0, 0.4, 3.5), Color("#3B82F6"))
	# 8 vendor booth walls with different brand colors
	var booth_colors := [Color("#1E40AF"), Color("#3B82F6"), Color("#7C3AED"), Color("#059669"),
		Color("#DC2626"), Color("#F59E0B"), Color("#06B6D4"), Color("#EC4899")]
	var booth_names_colors := [Color("#F8FAFC"), Color("#FDE68A"), Color("#A5F3FC"), Color("#BBF7D0"),
		Color("#FECDD3"), Color("#FDE68A"), Color("#E0F2FE"), Color("#FCE7F3")]
	for i in range(8):
		var bx: float = -7.0 + i * 2.2
		var booth := ProceduralMesh.create_box(Vector3(1.8, 2.5, 0.5), booth_colors[i])
		booth.position = Vector3(bx, 1.25, -3.5)
		add_child(booth)
		# Banner on top
		var banner := ProceduralMesh.create_box(Vector3(2.0, 0.5, 0.08), booth_names_colors[i])
		banner.position = Vector3(bx, 2.75, -3.5)
		add_child(banner)
		# Table in front of booth
		var table := ProceduralMesh.create_box(Vector3(1.5, 0.6, 0.6), Color("#E5E7EB"))
		table.position = Vector3(bx, 0.3, -2.8)
		add_child(table)
		# Brochures/items on table (small colored boxes)
		for bri in range(2):
			var brochure := ProceduralMesh.create_box(Vector3(0.2, 0.08, 0.15), booth_colors[i].lightened(0.3))
			brochure.position = Vector3(bx - 0.3 + bri * 0.5, 0.65, -2.8)
			add_child(brochure)
	# Registration desk (near entrance area)
	var reg_desk := ProceduralMesh.create_box(Vector3(3.0, 1.0, 0.8), Color("#1E293B"))
	reg_desk.position = Vector3(-7.0, 0.5, 3.5)
	add_child(reg_desk)
	# Registration sign
	var reg_sign := ProceduralMesh.create_box(Vector3(2.5, 0.5, 0.05), Color("#3B82F6"))
	reg_sign.position = Vector3(-7.0, 1.3, 3.1)
	add_child(reg_sign)
	# Badge printer (small box on desk)
	var badge_printer := ProceduralMesh.create_box(Vector3(0.4, 0.25, 0.3), Color("#374151"))
	badge_printer.position = Vector3(-7.5, 1.15, 3.5)
	add_child(badge_printer)
	# Printer status LED
	var printer_led := ProceduralMesh.create_sphere(0.03, 4, Color("#22C55E"))
	printer_led.position = Vector3(-7.5, 1.3, 3.34)
	add_child(printer_led)
	# Badge stack
	var badges := ProceduralMesh.create_box(Vector3(0.3, 0.15, 0.2), Color("#F8FAFC"))
	badges.position = Vector3(-6.5, 1.08, 3.5)
	add_child(badges)
	# Big projection screen backdrop
	var screen := ProceduralMesh.create_box(Vector3(10.0, 5.0, 0.2), Color("#0F172A"))
	screen.position = Vector3(0, 5.0, -5.0)
	add_child(screen)
	# Animated glow border on screen
	var glow_top := ProceduralMesh.create_box(Vector3(10.2, 0.12, 0.1), Color("#06B6D4"))
	glow_top.position = Vector3(0, 7.55, -4.88)
	add_child(glow_top)
	var glow_bot := ProceduralMesh.create_box(Vector3(10.2, 0.12, 0.1), Color("#06B6D4"))
	glow_bot.position = Vector3(0, 2.45, -4.88)
	add_child(glow_bot)
	var glow_l := ProceduralMesh.create_box(Vector3(0.12, 5.2, 0.1), Color("#06B6D4"))
	glow_l.position = Vector3(-5.05, 5.0, -4.88)
	add_child(glow_l)
	var glow_r := ProceduralMesh.create_box(Vector3(0.12, 5.2, 0.1), Color("#06B6D4"))
	glow_r.position = Vector3(5.05, 5.0, -4.88)
	add_child(glow_r)
	# SIGNAL SMASH on screen (colored accent bars)
	var bar1 := ProceduralMesh.create_box(Vector3(4.0, 0.3, 0.1), Color("#06B6D4"))
	bar1.position = Vector3(-1.5, 6.5, -4.85)
	add_child(bar1)
	var bar2 := ProceduralMesh.create_box(Vector3(3.5, 0.3, 0.1), Color("#F59E0B"))
	bar2.position = Vector3(1.5, 6.0, -4.85)
	add_child(bar2)
	# Screen content lines
	for scl_i in range(4):
		var scl := ProceduralMesh.create_box(Vector3(3.0 + scl_i * 0.5, 0.15, 0.05), Color("#3B82F6"))
		scl.position = Vector3(0, 4.0 + scl_i * 0.5, -4.88)
		add_child(scl)
	# Balloon decorations (colored spheres floating)
	var balloon_colors := [Color("#DC2626"), Color("#3B82F6"), Color("#22C55E"), Color("#F59E0B"),
		Color("#A855F7"), Color("#EC4899")]
	for bi in range(6):
		var balloon := ProceduralMesh.create_sphere(0.3, 6, balloon_colors[bi])
		balloon.position = Vector3(-6.0 + bi * 2.8, 7.0 + fmod(bi * 0.7, 1.5), -1.0 + fmod(bi * 0.5, 2.0))
		add_child(balloon)
		# Balloon string
		var bstr := ProceduralMesh.create_cylinder(0.01, 1.5, 4, Color("#D1D5DB"))
		bstr.position = balloon.position + Vector3(0, -1.0, 0)
		add_child(bstr)
	# Floor markings (aisle lines)
	for fm_i in range(3):
		var fl_mark := ProceduralMesh.create_box(Vector3(0.1, 0.02, 9.0), Color("#F59E0B"))
		fl_mark.position = Vector3(-4.0 + fm_i * 4.0, 0.02, 0)
		add_child(fl_mark)
	# Cross aisle marks
	for fm_i in range(2):
		var fl_cross := ProceduralMesh.create_box(Vector3(18.0, 0.02, 0.1), Color("#F59E0B"))
		fl_cross.position = Vector3(0, 0.02, -2.0 + fm_i * 4.0)
		add_child(fl_cross)
	# Swag table (right side)
	var swag_table := ProceduralMesh.create_box(Vector3(2.5, 0.7, 0.8), Color("#E5E7EB"))
	swag_table.position = Vector3(7.5, 0.35, 3.0)
	add_child(swag_table)
	# Swag items (t-shirts, stickers — small colored boxes)
	var swag_colors := [Color("#3B82F6"), Color("#DC2626"), Color("#22C55E"), Color("#F59E0B")]
	for sw_i in range(4):
		var swag := ProceduralMesh.create_box(Vector3(0.35, 0.15, 0.25), swag_colors[sw_i])
		swag.position = Vector3(6.8 + sw_i * 0.5, 0.78, 3.0)
		add_child(swag)
	# Coffee station
	var coffee_table := ProceduralMesh.create_box(Vector3(1.8, 0.7, 0.6), Color("#78350F"))
	coffee_table.position = Vector3(7.5, 0.35, 1.0)
	add_child(coffee_table)
	# Coffee machine
	var coffee_machine := ProceduralMesh.create_box(Vector3(0.4, 0.5, 0.3), Color("#1F2937"))
	coffee_machine.position = Vector3(7.2, 0.95, 1.0)
	add_child(coffee_machine)
	# Coffee cups
	for cc_i in range(3):
		var cup := ProceduralMesh.create_cylinder(0.06, 0.12, 6, Color("#F8FAFC"))
		cup.position = Vector3(7.6 + cc_i * 0.25, 0.78, 1.0)
		add_child(cup)
	# Networking lounge area (back right)
	for ch_i in range(4):
		var chair := ProceduralMesh.create_box(Vector3(0.5, 0.5, 0.5), Color("#6B7280"))
		chair.position = Vector3(5.5 + (ch_i % 2) * 1.5, 0.25, 3.5 + int(ch_i / 2) * 1.2)
		add_child(chair)
		var cushion := ProceduralMesh.create_box(Vector3(0.45, 0.08, 0.45), Color("#3B82F6"))
		cushion.position = Vector3(5.5 + (ch_i % 2) * 1.5, 0.54, 3.5 + int(ch_i / 2) * 1.2)
		add_child(cushion)
	# Small coffee table in lounge
	var lounge_table := ProceduralMesh.create_cylinder(0.4, 0.4, 6, Color("#374151"))
	lounge_table.position = Vector3(6.25, 0.2, 4.1)
	add_child(lounge_table)
	# Spotlights (colored spheres above)
	for i in range(7):
		var spot_color: Color = [Color("#FBBF24"), Color("#F472B6"), Color("#06B6D4"), Color("#FBBF24"),
			Color("#A855F7"), Color("#22C55E"), Color("#FBBF24")][i]
		var spot := ProceduralMesh.create_sphere(0.2, 6, spot_color)
		spot.position = Vector3(-6.0 + i * 2.0, 8.0, -2.0)
		add_child(spot)
	# Convention ceiling
	var conv_ceiling := ProceduralMesh.create_platform(20.0, 12.0, 0.1, Color("#1E293B"))
	conv_ceiling.position.y = 9.0
	add_child(conv_ceiling)
	# Ceiling trusses
	for tr_i in range(4):
		var truss := ProceduralMesh.create_box(Vector3(20.0, 0.15, 0.15), Color("#6B7280"))
		truss.position = Vector3(0, 8.5, -3.0 + tr_i * 2.5)
		add_child(truss)
	_build_hazard()

func _build_tower(pos: Vector3, height: float, color: Color, accent: Color) -> void:
	# Main pole
	var pole := ProceduralMesh.create_cylinder(0.08, height, 6, color)
	pole.position = pos + Vector3(0, height / 2.0, 0)
	add_child(pole)

	# Cross bars
	for i in range(3):
		var bar := ProceduralMesh.create_cylinder(0.03, 1.0, 4, color)
		bar.position = pos + Vector3(0, height * 0.3 * (i + 1), 0)
		bar.rotation_degrees.z = 90.0
		add_child(bar)

	# Antenna on top
	var ant := ProceduralMesh.create_cone(0.2, 0.5, 6, accent)
	ant.position = pos + Vector3(0, height + 0.25, 0)
	add_child(ant)

	# Blinking light on top (red sphere)
	var light := ProceduralMesh.create_sphere(0.06, 6, Color("#EF4444"))
	light.position = pos + Vector3(0, height + 0.55, 0)
	add_child(light)

func _build_mountains() -> void:
	var mountain_color := Color("#78350F").lightened(0.15)

	# Cerro de la Silla silhouette — distinctive saddle shape
	# Left peak
	var peak1 := ProceduralMesh.create_cone(5.0, 9.0, 4, mountain_color)
	peak1.position = Vector3(-10.0, 0.0, -30.0)
	add_child(peak1)

	# Right peak (slightly taller — the "saddle")
	var peak2 := ProceduralMesh.create_cone(4.5, 11.0, 4, mountain_color.darkened(0.1))
	peak2.position = Vector3(-3.0, 0.0, -33.0)
	add_child(peak2)

	# Saddle connection (lower ridge)
	var ridge := ProceduralMesh.create_cone(3.0, 6.0, 4, mountain_color.darkened(0.05))
	ridge.position = Vector3(-6.5, 0.0, -28.0)
	add_child(ridge)

	# Distant mountains
	var bg1 := ProceduralMesh.create_cone(6.0, 7.0, 4, mountain_color.darkened(0.2))
	bg1.position = Vector3(8.0, 0.0, -35.0)
	add_child(bg1)

	var bg2 := ProceduralMesh.create_cone(4.0, 5.0, 4, mountain_color.darkened(0.25))
	bg2.position = Vector3(15.0, 0.0, -30.0)
	add_child(bg2)

func _build_hazard() -> void:
	# Rotating sector antenna — mounted on a pole in the center-back area
	# When it sweeps past a fighter, it deals damage and knockback

	# Hazard pivot (rotates)
	_hazard_antenna = Node3D.new()
	_hazard_antenna.position = Vector3(0.0, 0.0, -2.0)
	add_child(_hazard_antenna)

	# Base pole
	var pole := ProceduralMesh.create_cylinder(0.12, 2.0, 6, Color("#6B7280"))
	pole.position.y = 1.0
	_hazard_antenna.add_child(pole)

	# Rotating arm (extends outward)
	var arm := ProceduralMesh.create_cylinder(0.04, 3.0, 4, Color("#9CA3AF"))
	arm.position = Vector3(1.5, 2.1, 0.0)
	arm.rotation_degrees.z = 90.0
	_hazard_antenna.add_child(arm)

	# Sector antenna head (the dangerous part — cone shape)
	var sector := ProceduralMesh.create_cone(0.35, 0.8, 6, Color("#FCD34D"))
	sector.position = Vector3(3.0, 2.1, 0.0)
	sector.rotation_degrees.z = 90.0
	_hazard_antenna.add_child(sector)

	# Warning stripes on arm
	var warning := ProceduralMesh.create_box(Vector3(0.5, 0.08, 0.08), Color("#EF4444"))
	warning.position = Vector3(1.5, 2.1, 0.0)
	_hazard_antenna.add_child(warning)

	# Hazard collision area (Area3D on the sector head)
	_hazard_area = Area3D.new()
	_hazard_area.collision_layer = 1 << 7  # Layer 8 = Hazards
	_hazard_area.collision_mask = (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4)  # Scan player bodies
	_hazard_area.monitoring = true

	var hazard_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.5, 0.8, 0.8)
	hazard_shape.shape = shape
	hazard_shape.position = Vector3(2.5, 2.1, 0.0)
	_hazard_area.add_child(hazard_shape)

	_hazard_antenna.add_child(_hazard_area)

	# Connect hazard to damage
	_hazard_area.body_entered.connect(_on_hazard_hit)

## Creates a platform with both visual mesh and physics collision
func _add_solid_platform(pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1  # Layer 1 = World
	body.collision_mask = 0

	# Visual mesh
	var mesh := ProceduralMesh.create_platform(size.x, size.z, size.y, color)
	body.add_child(mesh)

	# Collision shape
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	add_child(body)

## Creates a one-way platform — can jump through from below, press DOWN to drop through
func _add_one_way_platform(pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = "OneWayPlatform"
	body.position = pos
	body.collision_layer = 1 << 8  # Layer 9 = One-way platforms (separate from Layer 1 ground)
	body.collision_mask = 0
	body.add_to_group("one_way_platforms")

	# Visual mesh
	var mesh := ProceduralMesh.create_platform(size.x, size.z, size.y, color)
	body.add_child(mesh)

	# Collision shape — thin, only at the TOP surface
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, 0.1, size.z)  # Very thin
	col.shape = shape
	col.position.y = size.y / 2.0  # At the top
	body.add_child(col)

	add_child(body)

func _build_fighters() -> void:
	var p1 := GameMgr.get_p1()
	_fighter1 = _create_fighter(1, Vector3(-3.0, 1.0, 0.0), p1["color"], p1["secondary"], p1["accent"], p1["name"])
	add_child(_fighter1)
	_apply_equipment(_fighter1, GameMgr.p1_equipment)
	_fighter1.add_to_group("fighters")

	var p2 := GameMgr.get_p2()
	_fighter2 = _create_fighter(2, Vector3(3.0, 1.0, 0.0), p2["color"], p2["secondary"], p2["accent"], p2["name"])
	_fighter2.set("facing_right", false)
	add_child(_fighter2)
	_apply_equipment(_fighter2, GameMgr.p2_equipment)
	_fighter2.add_to_group("fighters")

	# Assign controllers from InputManager
	_assign_controllers()

## Apply equipment modifiers to a fighter
func _apply_equipment(fighter: CharacterBody3D, equipment: Dictionary) -> void:
	var mods := GameMgr.get_equipment_modifiers(equipment)
	# Speed: +10 stat ≈ +1.0 move speed
	fighter.equip_speed_mod = mods["speed"] / 10.0
	# Power: +10 stat ≈ +20% damage
	fighter.equip_power_mod = mods["power"] / 50.0
	# Defense: +10 stat ≈ 10% damage reduction (max 50%)
	fighter.equip_defense_mod = clampf(mods["stability"] / 100.0, 0.0, 0.5)
	# Range: +10 stat ≈ +10% hitbox scale
	fighter.equip_range_mod = mods["range"] / 100.0
	# Special passives
	fighter.equip_specials = GameMgr.get_equipment_specials(equipment)

	# Scale hitbox based on range modifier
	var hitbox_scale: float = fighter.get_hitbox_scale()
	if hitbox_scale != 1.0:
		var hitbox: Area3D = fighter.get_node_or_null("Model/Hitbox")
		if hitbox:
			hitbox.scale = Vector3(hitbox_scale, hitbox_scale, hitbox_scale)

	if fighter.equip_specials.size() > 0:
		print("[FIGHT] P%d equipment specials: %s" % [fighter.player_id, ", ".join(fighter.equip_specials)])

func _assign_controllers() -> void:
	if InputManager == null:
		# Fallback: P1 keyboard, P2 manual keyboard
		_fighter2.set("use_manual_input", true)
		var f2_sm = _fighter2.get_node_or_null("StateMachine")
		if f2_sm:
			f2_sm.process_input = false
		return

	var p1_device: int = InputManager.get_device(0)
	var p2_device: int = InputManager.get_device(1)

	# P1: keyboard (-1) or gamepad
	_fighter1.set("device_id", p1_device)

	# P2: if gamepad assigned, use it directly; otherwise manual keyboard
	if p2_device >= 0:
		# P2 has a gamepad — use device-based input
		_fighter2.set("device_id", p2_device)
		_fighter2.set("use_manual_input", false)
		print("[FIGHT] P2 using gamepad: %s" % InputManager.get_controller_name(p2_device))
	else:
		# P2 on keyboard (arrows) — manual input
		_fighter2.set("use_manual_input", true)
		var f2_sm = _fighter2.get_node_or_null("StateMachine")
		if f2_sm:
			f2_sm.process_input = false
		print("[FIGHT] P2 using keyboard (arrows)")

func _create_fighter(id: int, pos: Vector3, primary: Color, secondary: Color, accent: Color, fighter_name: String) -> CharacterBody3D:
	var fighter: CharacterBody3D = CharacterBody3D.new()
	fighter.set_script(FighterBaseScript)
	fighter.player_id = id
	fighter.position = pos

	# Collision shape
	var col_shape := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.2
	col_shape.shape = shape
	col_shape.position.y = 0.6
	fighter.add_child(col_shape)

	# Model (detailed procedural character)
	var model_node := Node3D.new()
	model_node.name = "Model"

	match fighter_name:
		"RICO":
			_build_rico_model(model_node, primary, secondary, accent)
		"ING. VERO":
			_build_vero_model(model_node, primary, secondary, accent)
		"DON AURELIO":
			_build_aurelio_model(model_node, primary, secondary, accent)
		"MORXEL":
			_build_morxel_model(model_node, primary, secondary, accent)
		_:
			_build_rico_model(model_node, primary, secondary, accent)

	# Name label
	var label := Label3D.new()
	label.text = fighter_name
	label.font_size = 36
	label.position.y = 2.0
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = accent
	label.outline_size = 4
	label.outline_modulate = Color.BLACK
	model_node.add_child(label)

	fighter.add_child(model_node)

	# Hurtbox (Area3D — layer 7)
	var hurtbox := Area3D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 1 << 6   # Layer 7
	hurtbox.collision_mask = 1 << 5    # Scan layer 6 (hitboxes)
	var hurtbox_shape := CollisionShape3D.new()
	var hshape := CapsuleShape3D.new()
	hshape.radius = 0.4
	hshape.height = 1.4
	hurtbox_shape.shape = hshape
	hurtbox_shape.position.y = 0.7
	hurtbox.add_child(hurtbox_shape)
	fighter.add_child(hurtbox)

	# Hitbox (Area3D — layer 6, initially disabled)
	var hitbox := Area3D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 1 << 5    # Layer 6
	hitbox.collision_mask = 1 << 6     # Scan layer 7 (hurtboxes)
	hitbox.monitoring = false

	var hitbox_shape := CollisionShape3D.new()
	var hit_s := BoxShape3D.new()
	hit_s.size = Vector3(1.4, 0.8, 1.4)
	hitbox_shape.shape = hit_s
	hitbox_shape.position = Vector3(0.0, 0.8, 0.0)
	hitbox.add_child(hitbox_shape)

	# Hitbox visual (red box, visible when active)
	var hit_visual := ProceduralMesh.create_box(Vector3(1.4, 0.8, 1.4), Color(1, 0, 0, 0.4))
	hit_visual.position = Vector3(0.0, 0.8, 0.0)
	hit_visual.visible = false
	hitbox.add_child(hit_visual)

	# Track which targets have been hit per attack swing (reset in attack_state.enter)
	var hit_targets: Array = []
	hitbox.set_meta("hit_targets", hit_targets)

	# Connect hitbox to damage (uses attacker's power modifier)
	hitbox.area_entered.connect(func(area: Area3D) -> void:
		if area.name == "Hurtbox" and area.get_parent() != fighter:
			var target = area.get_parent()
			# Per-target hit tracking: same attack can't hit same target twice
			var targets_hit: Array = hitbox.get_meta("hit_targets", [])
			if target in targets_hit:
				return
			if target and target.has_method("take_damage") and not target.is_invincible:
				targets_hit.append(target)
				hitbox.set_meta("hit_targets", targets_hit)
				var dmg: float = ATTACK_DAMAGE * fighter.get_damage_multiplier()
				var kb: float = ATTACK_KNOCKBACK * fighter.get_damage_multiplier()
				target.take_damage(dmg, fighter.global_position, kb)
				# Visual attack effect
				var hit_pos: Vector3 = (fighter.global_position + target.global_position) / 2.0
				hit_pos.y += 0.8
				_spawn_attack_effect(hit_pos, fighter)
				# Charge attacker's combo meter
				fighter.combo_meter = minf(fighter.combo_meter + fighter.COMBO_HIT_CHARGE, fighter.COMBO_MAX)
				# Hit SFX
				if AudioManager:
					AudioManager.play_sfx("hit_light")
					if target.signal_percent <= 0.0:
						AudioManager.play_sfx("link_down", 3.0)
				print("[FIGHT] P%d hit P%d for %.1f dmg! Target signal: %.0f%%" % [
					fighter.player_id, target.player_id, dmg, target.signal_percent])
	)
	# Hitbox is child of Model so it rotates with facing direction
	model_node.add_child(hitbox)

	# State machine
	var sm := Node.new()
	sm.set_script(StateMachineScript)
	sm.name = "StateMachine"

	var idle := Node.new()
	idle.set_script(IdleStateScript)
	idle.name = "Idle"
	sm.add_child(idle)
	sm.initial_state = idle

	var run := Node.new()
	run.set_script(RunStateScript)
	run.name = "Run"
	sm.add_child(run)

	var jump_s := Node.new()
	jump_s.set_script(JumpStateScript)
	jump_s.name = "Jump"
	sm.add_child(jump_s)

	var fall := Node.new()
	fall.set_script(FallStateScript)
	fall.name = "Fall"
	sm.add_child(fall)

	var attack := Node.new()
	attack.set_script(AttackStateScript)
	attack.name = "Attack"
	sm.add_child(attack)

	var hit := Node.new()
	hit.set_script(HitStateScript)
	hit.name = "Hit"
	sm.add_child(hit)

	var ko := Node.new()
	ko.set_script(KOStateScript)
	ko.name = "KO"
	sm.add_child(ko)

	fighter.add_child(sm)

	# Set collision layer per player
	fighter.collision_layer = 1 << id  # Layer 2 or 3
	fighter.collision_mask = 1 | (1 << 8)  # Scan layer 1 (ground) + layer 9 (one-way platforms)

	return fighter

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 5, 14)
	_camera.rotation_degrees.x = -15
	_camera.fov = 55.0
	_camera.current = true
	add_child(_camera)

func _build_lighting() -> void:
	_weather = GameMgr.selected_weather

	# World environment
	_world_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR

	match _weather:
		0:  # Normal
			env.background_color = Color("#FDE68A")
			env.ambient_light_color = Color("#EA580C")
			env.ambient_light_energy = 0.4
		1:  # Night — darker ambient, blue tint
			env.background_color = Color("#0F172A")
			env.ambient_light_color = Color("#1E3A8A")
			env.ambient_light_energy = 0.15
		2:  # Storm — dark grey sky, desaturated
			env.background_color = Color("#374151")
			env.ambient_light_color = Color("#6B7280")
			env.ambient_light_energy = 0.25

	_world_env.environment = env
	add_child(_world_env)

	# Sun / moon / storm light
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true

	match _weather:
		0:  # Normal
			sun.rotation_degrees = Vector3(-35, -45, 0)
			sun.light_color = Color("#FCD34D")
			sun.light_energy = 1.3
		1:  # Night — moonlight, dimmer, blue-white
			sun.rotation_degrees = Vector3(-50, -30, 0)
			sun.light_color = Color("#93C5FD")
			sun.light_energy = 0.5
		2:  # Storm — grey overcast light
			sun.rotation_degrees = Vector3(-40, -45, 0)
			sun.light_color = Color("#9CA3AF")
			sun.light_energy = 0.6

	add_child(sun)

	# Night: spotlight on fighter area
	if _weather == 1:
		var spot := SpotLight3D.new()
		spot.position = Vector3(0, 12, 3)
		spot.rotation_degrees = Vector3(-70, 0, 0)
		spot.light_color = Color("#DBEAFE")
		spot.light_energy = 2.5
		spot.spot_range = 25.0
		spot.spot_angle = 40.0
		spot.shadow_enabled = true
		add_child(spot)

	# Storm: rain particle overlay + initialize timers
	if _weather == 2:
		_build_storm_rain()
		_storm_flash_timer = randf_range(3.0, 7.0)

func _build_storm_rain() -> void:
	## Simple rain using GPUParticles3D with a basic ParticleProcessMaterial
	_storm_rain = GPUParticles3D.new()
	_storm_rain.amount = 300
	_storm_rain.lifetime = 1.2
	_storm_rain.position = Vector3(0, 15, 0)
	_storm_rain.visibility_aabb = AABB(Vector3(-20, -20, -10), Vector3(40, 40, 20))

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.2, -1, 0)  # Slight wind angle
	mat.spread = 5.0
	mat.initial_velocity_min = 18.0
	mat.initial_velocity_max = 25.0
	mat.gravity = Vector3(0, -15, 0)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(15, 0.5, 8)
	mat.scale_min = 0.02
	mat.scale_max = 0.04
	_storm_rain.process_material = mat

	# Simple white mesh for rain drops (tiny stretched box)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.02, 0.5, 0.02)
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.albedo_color = Color(0.7, 0.8, 1.0, 0.6)
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mesh_mat
	_storm_rain.draw_pass_1 = mesh
	add_child(_storm_rain)

func _update_weather(delta: float) -> void:
	if _weather != 2:
		return

	# Lightning flash system
	_storm_flash_timer -= delta
	if _storm_flash_timer <= 0.0 and not _storm_flash_active:
		_storm_flash_active = true
		_storm_flash_duration = randf_range(0.1, 0.25)
		# Brighten the scene temporarily
		if _world_env and _world_env.environment:
			_world_env.environment.ambient_light_energy = 1.5
			_world_env.environment.background_color = Color("#D1D5DB")

	if _storm_flash_active:
		_storm_flash_duration -= delta
		if _storm_flash_duration <= 0.0:
			_storm_flash_active = false
			_storm_flash_timer = randf_range(4.0, 10.0)
			# Restore dark storm lighting
			if _world_env and _world_env.environment:
				_world_env.environment.ambient_light_energy = 0.25
				_world_env.environment.background_color = Color("#374151")

	# Wind push on fighters — subtle lateral force
	_storm_wind_dir = sign(sin(Time.get_ticks_msec() / 1000.0 * 0.3))
	var wind_force: float = 0.8 * _storm_wind_dir
	if _fighter1 and not _fighter1.is_on_floor():
		_fighter1.velocity.x += wind_force * delta
	if _fighter2 and not _fighter2.is_on_floor():
		_fighter2.velocity.x += wind_force * delta

func _build_spectator_hud() -> void:
	_spectator_hud = CanvasLayer.new()
	_spectator_hud.set_script(SpectatorHUDScript)
	_spectator_hud.fighter1 = _fighter1
	_spectator_hud.fighter2 = _fighter2
	_spectator_hud.visible = false
	add_child(_spectator_hud)

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	_hud_label = Label.new()
	_hud_label.position = Vector2(20, 20)
	_hud_label.add_theme_font_size_override("font_size", 18)
	_hud_label.add_theme_color_override("font_color", Color("#06B6D4"))
	_hud_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_hud_label.add_theme_constant_override("shadow_offset_x", 1)
	_hud_label.add_theme_constant_override("shadow_offset_y", 1)
	canvas.add_child(_hud_label)

## ═══════════ COMBO CINEMATIC STATE ═══════════
var _combo_attacker: CharacterBody3D = null
var _combo_target: CharacterBody3D = null
var _combo_phase: int = 0  # 0=zoom, 1=attack, 2=flash, 3=damage, 4=done
var _combo_phase_timer: float = 0.0
var _combo_flash_alpha: float = 0.0
var _combo_label: Label = null
var _combo_flash_rect: ColorRect = null
var _camera_original_pos: Vector3

func _process(delta: float) -> void:
	# If combo cinematic is active, run that instead of normal game
	if _combo_attacker != null:
		_update_combo_cinematic(delta)
		return

	_update_p2_movement()
	_update_hazard(delta)
	_update_hud()
	_update_camera()
	_check_fight_end(delta)
	_update_combo_meters(delta)
	_update_attack_effects(delta)
	_update_weather(delta)

func _update_combo_meters(delta: float) -> void:
	# Check combo timer decay for active combos in fighter_base
	for f in [_fighter1, _fighter2]:
		if f and f.combo_active:
			f.combo_timer -= delta
			if f.combo_timer <= 0:
				f.combo_active = false
				f.is_invincible = false

func _spawn_attack_effect(pos: Vector3, attacker: CharacterBody3D) -> void:
	# Slash arc mesh (temporary)
	var slash := ProceduralMesh.create_box(Vector3(1.5, 0.08, 0.08), Color(1, 1, 1, 0.9))
	slash.position = pos
	slash.rotation_degrees.z = randf_range(-30, 30)
	slash.rotation_degrees.y = randf_range(-20, 20)
	add_child(slash)

	# Impact sparks (4-6 small spheres flying outward)
	var sparks: Array[MeshInstance3D] = []
	for s in range(5):
		var spark := ProceduralMesh.create_sphere(0.06, 4, Color(1, 0.9, 0.3))
		spark.position = pos
		add_child(spark)
		sparks.append(spark)

	# Flash on attacker model (white overlay)
	var flash := ProceduralMesh.create_box(Vector3(0.6, 1.2, 0.4), Color(1, 1, 1, 0.6))
	flash.position = attacker.global_position + Vector3(0, 0.6, 0)
	add_child(flash)

	_attack_effects.append({
		"slash": slash,
		"sparks": sparks,
		"flash": flash,
		"timer": 0.0,
		"max_time": 0.3,
		"spark_dirs": [],
	})
	# Generate random spark directions
	var effect = _attack_effects[-1]
	for s2 in range(sparks.size()):
		effect["spark_dirs"].append(Vector3(
			randf_range(-3, 3),
			randf_range(1, 4),
			randf_range(-2, 2)
		))

	# Camera micro-shake on hit
	if _camera:
		_camera.position.x += randf_range(-0.15, 0.15)
		_camera.position.y += randf_range(-0.1, 0.1)

func _update_attack_effects(delta: float) -> void:
	var to_remove: Array[int] = []
	for i in range(_attack_effects.size()):
		var fx: Dictionary = _attack_effects[i]
		fx["timer"] += delta
		var progress: float = fx["timer"] / fx["max_time"]

		if progress >= 1.0:
			# Remove all meshes
			if fx["slash"] and is_instance_valid(fx["slash"]):
				fx["slash"].queue_free()
			if fx["flash"] and is_instance_valid(fx["flash"]):
				fx["flash"].queue_free()
			for spark in fx["sparks"]:
				if is_instance_valid(spark):
					spark.queue_free()
			to_remove.append(i)
		else:
			# Animate slash (scale up and fade)
			if is_instance_valid(fx["slash"]):
				fx["slash"].scale = Vector3(1.0 + progress * 2.0, 1.0 - progress * 0.5, 1.0)
			# Animate flash (fade out)
			if is_instance_valid(fx["flash"]):
				fx["flash"].scale = Vector3(1.0 + progress, 1.0 + progress, 1.0 + progress) * (1.0 - progress)
			# Animate sparks (fly outward)
			for s in range(fx["sparks"].size()):
				if is_instance_valid(fx["sparks"][s]):
					fx["sparks"][s].position += fx["spark_dirs"][s] * delta
					fx["sparks"][s].scale = Vector3.ONE * (1.0 - progress)

	for i in range(to_remove.size() - 1, -1, -1):
		_attack_effects.remove_at(to_remove[i])

func _trigger_combo(attacker: CharacterBody3D, target: CharacterBody3D) -> void:
	_combo_attacker = attacker
	_combo_target = target
	_combo_phase = 0
	_combo_phase_timer = 0.0
	_camera_original_pos = _camera.position

	attacker.activate_combo()
	attacker.velocity = Vector3.ZERO
	target.velocity = Vector3.ZERO

	# Create flash overlay
	if _combo_flash_rect == null:
		var canvas := CanvasLayer.new()
		canvas.layer = 20
		add_child(canvas)
		_combo_flash_rect = ColorRect.new()
		_combo_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_combo_flash_rect.color = Color(1, 1, 1, 0)
		_combo_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(_combo_flash_rect)
		_combo_label = Label.new()
		_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_combo_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_combo_label.add_theme_font_size_override("font_size", 64)
		_combo_label.add_theme_color_override("font_color", Color("#06B6D4"))
		_combo_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		_combo_label.add_theme_constant_override("shadow_offset_x", 3)
		_combo_label.add_theme_constant_override("shadow_offset_y", 3)
		_combo_label.text = ""
		_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(_combo_label)

	if AudioManager:
		AudioManager.play_sfx("fight_start")

func _update_combo_cinematic(delta: float) -> void:
	_combo_phase_timer += delta

	match _combo_phase:
		0:  # Zoom out — 0.8s
			var progress := clampf(_combo_phase_timer / 0.8, 0.0, 1.0)
			var center := (_combo_attacker.global_position + _combo_target.global_position) / 2.0
			_camera.position = _camera.position.lerp(Vector3(center.x, center.y + 5.0, 18.0), 0.1)
			_combo_label.text = ""
			if _combo_phase_timer >= 0.8:
				_combo_phase = 1
				_combo_phase_timer = 0.0
				# Get character-specific combo name
				var char_name: String = ""
				if _combo_attacker == _fighter1:
					char_name = GameMgr.get_p1()["name"]
				else:
					char_name = GameMgr.get_p2()["name"]
				var combo_name := _get_combo_name(char_name)
				_combo_label.text = combo_name
				if AudioManager:
					AudioManager.play_sfx("hit_heavy")

		1:  # Character attack name display — 1.0s
			# Shake camera
			_camera.position.x += randf_range(-0.1, 0.1)
			_camera.position.y += randf_range(-0.05, 0.05)
			# Move attacker toward target
			var dir := (_combo_target.global_position - _combo_attacker.global_position).normalized()
			_combo_attacker.global_position += dir * delta * 8.0
			if _combo_phase_timer >= 1.0:
				_combo_phase = 2
				_combo_phase_timer = 0.0
				_combo_label.text = "FULL SIGNAL\nACHIEVED"
				_combo_label.add_theme_color_override("font_color", Color("#F59E0B"))
				_combo_flash_alpha = 1.0
				if AudioManager:
					AudioManager.play_sfx("victory")
					AudioManager.play_sfx("hit_critical")

		2:  # Flash + FULL SIGNAL text — 1.0s
			_combo_flash_alpha = maxf(_combo_flash_alpha - delta * 1.5, 0.0)
			_combo_flash_rect.color = Color(1, 1, 1, _combo_flash_alpha)
			# Apply massive damage to target
			if _combo_phase_timer < delta * 2:  # Only first frame
				var combo_damage: float = 35.0
				var combo_kb: float = 12.0
				_combo_target.take_damage(combo_damage, _combo_attacker.global_position, combo_kb)
				print("[FIGHT] FULL SIGNAL COMBO! %.0f damage to P%d!" % [combo_damage, _combo_target.player_id])
			if _combo_phase_timer >= 1.0:
				_combo_phase = 3
				_combo_phase_timer = 0.0

		3:  # Return to normal — 0.5s
			_combo_flash_rect.color = Color(1, 1, 1, 0)
			_combo_label.text = ""
			_combo_label.add_theme_color_override("font_color", Color("#06B6D4"))
			_camera.position = _camera.position.lerp(_camera_original_pos, 0.15)
			if _combo_phase_timer >= 0.5:
				_combo_attacker.combo_active = false
				_combo_attacker.is_invincible = false
				_combo_attacker = null
				_combo_target = null

func _get_combo_name(char_name: String) -> String:
	match char_name:
		"RICO": return "CABLE WHIP\nSURGE"
		"ING. VERO": return "INTERFERENCE\nBLAST"
		"DON AURELIO": return "TOWER\nSLAM"
		"MORXEL": return "DDoS\nSWARM"
		_: return "FULL\nSIGNAL"

func _update_hazard(delta: float) -> void:
	if _hazard_antenna:
		_hazard_antenna.rotation_degrees.y += HAZARD_SPEED * delta

var _hazard_cooldown: Dictionary = {}  # { fighter_id: float } — prevent rapid re-hits

func _on_hazard_hit(body: Node3D) -> void:
	# Check if it's a fighter
	if not body.has_method("take_damage"):
		return

	var pid: int = body.get("player_id") if "player_id" in body else -1
	if pid < 0:
		return

	# Cooldown to prevent hitting same fighter every frame
	var now: float = Time.get_ticks_msec() / 1000.0
	if pid in _hazard_cooldown and now - _hazard_cooldown[pid] < 1.0:
		return
	_hazard_cooldown[pid] = now

	# Apply damage and knockback from hazard position
	body.take_damage(HAZARD_DAMAGE, _hazard_antenna.global_position, HAZARD_KNOCKBACK)

	if AudioManager:
		AudioManager.play_sfx("hit_heavy")

	print("[FIGHT] HAZARD hit P%d! Sector antenna sweep!" % pid)

func _update_p2_movement() -> void:
	if _fighter2 == null:
		return
	var p2_dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_LEFT):
		p2_dir.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		p2_dir.x += 1.0
	if Input.is_key_pressed(KEY_UP):
		p2_dir.z -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		p2_dir.z += 1.0

	_fighter2.set("input_direction", p2_dir)

	var f2_model = _fighter2.get_node_or_null("Model")
	if p2_dir.x > 0.1:
		_fighter2.set("facing_right", true)
		if f2_model:
			f2_model.rotation_degrees.y = 0.0
	elif p2_dir.x < -0.1:
		_fighter2.set("facing_right", false)
		if f2_model:
			f2_model.rotation_degrees.y = 180.0

func _update_hud() -> void:
	if _hud_label == null:
		return

	var sm1 = _fighter1.get("state_machine")
	var sm2 = _fighter2.get("state_machine")
	var state1: String = sm1.current_state.name if sm1 and sm1.current_state else "?"
	var state2: String = sm2.current_state.name if sm2 and sm2.current_state else "?"

	var p1_name: String = GameMgr.get_p1()["name"]
	var p2_name: String = GameMgr.get_p2()["name"]
	var arena_name: String = GameMgr.get_arena()["name"]
	var p1_combo: String = "FULL SIGNAL READY! [E]" if _fighter1.can_activate_combo() else "Combo: %.0f%%" % _fighter1.combo_meter
	var p2_combo: String = "FULL SIGNAL READY! [O]" if _fighter2.can_activate_combo() else "Combo: %.0f%%" % _fighter2.combo_meter
	_hud_label.text = """SIGNAL SMASH — %s  |  Round %d/%d  [P1: %d - P2: %d]

P1 %s:  Signal %.0f%%  |  Damage %.0f  |  %s  |  %s
P2 %s:  Signal %.0f%%  |  Damage %.0f  |  %s  |  %s

P1: WASD+SPACE+J+Q(special)+E(combo)  |  P2: Arrows+Shift+L+K(special)+O(combo)
TAB = NOC Dashboard | R = Reset""" % [
		arena_name, _round, _max_rounds, _p1_round_wins, _p2_round_wins,
		p1_name, _fighter1.signal_percent, _fighter1.damage_accumulated, state1, p1_combo,
		p2_name, _fighter2.signal_percent, _fighter2.damage_accumulated, state2, p2_combo
	]

func _update_camera() -> void:
	# Simple dynamic camera — track center between fighters
	if _fighter1 == null or _fighter2 == null:
		return
	var center: Vector3 = (_fighter1.global_position + _fighter2.global_position) / 2.0
	var dist: float = _fighter1.global_position.distance_to(_fighter2.global_position)
	var target_z: float = clampf(dist * 0.8 + 8.0, 10.0, 20.0)

	_camera.position = _camera.position.lerp(
		Vector3(center.x, center.y + 4.0, target_z), 0.12)

func _check_fight_end(delta: float) -> void:
	# Match over — waiting to go to victory screen
	if _match_over:
		_fight_over_timer -= delta
		if _fight_over_timer <= 0.0:
			get_tree().change_scene_to_file("res://scenes/main/victory_screen.tscn")
		return

	# Round over — waiting to start next round
	if _round_over:
		_round_over_timer -= delta
		if _round_over_timer <= 0.0:
			_start_next_round()
		return

	if _fighter1 == null or _fighter2 == null:
		return

	# Check if either fighter is KO'd
	var p1_ko: bool = _fighter1.signal_percent <= 0.0
	var p2_ko: bool = _fighter2.signal_percent <= 0.0

	if not p1_ko and not p2_ko:
		return

	# Someone got KO'd — determine round winner
	_round_over = true

	if p2_ko and not p1_ko:
		_p1_round_wins += 1
		print("[FIGHT] Round %d: P1 WINS! (Score: P1 %d - P2 %d)" % [_round, _p1_round_wins, _p2_round_wins])
	elif p1_ko and not p2_ko:
		_p2_round_wins += 1
		print("[FIGHT] Round %d: P2 WINS! (Score: P1 %d - P2 %d)" % [_round, _p1_round_wins, _p2_round_wins])
	else:
		# Double KO — no one gets a point
		print("[FIGHT] Round %d: DOUBLE KO!" % _round)

	if AudioManager:
		AudioManager.play_sfx("round_end")

	# Check if match is decided (best of 3 = first to 2 wins)
	var wins_needed: int = (_max_rounds / 2) + 1
	if _p1_round_wins >= wins_needed or _p2_round_wins >= wins_needed or _round >= _max_rounds:
		_end_match()
	else:
		_round_over_timer = 2.5  # Pause before next round

func _start_next_round() -> void:
	_round += 1
	_round_over = false
	_round_over_timer = 0.0

	# Reset both fighters
	_fighter1.position = Vector3(-3.0, 1.0, 0.0)
	_fighter1.reset_fighter()
	_fighter2.position = Vector3(3.0, 1.0, 0.0)
	_fighter2.reset_fighter()
	_fighter2.set("facing_right", false)
	var f2_model = _fighter2.get_node_or_null("Model")
	if f2_model:
		f2_model.rotation_degrees.y = 180.0

	print("[FIGHT] === ROUND %d ===" % _round)
	if AudioManager:
		AudioManager.play_sfx("fight_start")

func _end_match() -> void:
	_match_over = true
	_fight_over_timer = 2.5  # Pause before victory screen

	# Record result in progression
	var phase_before: int = Progression.current_phase

	if _p1_round_wins > _p2_round_wins:
		var result := Progression.record_fight_win(_fighter1.damage_accumulated)
		result["phase_before"] = phase_before
		result["p1_rounds"] = _p1_round_wins
		result["p2_rounds"] = _p2_round_wins
		Progression.last_fight_result = result
		print("[FIGHT] MATCH OVER: P1 WINS %d-%d! +%d SP" % [_p1_round_wins, _p2_round_wins, result["sp_earned"]])
	elif _p2_round_wins > _p1_round_wins:
		var result := Progression.record_fight_loss(_fighter1.damage_accumulated)
		result["phase_before"] = phase_before
		result["p1_rounds"] = _p1_round_wins
		result["p2_rounds"] = _p2_round_wins
		Progression.last_fight_result = result
		print("[FIGHT] MATCH OVER: P2 WINS %d-%d! P1 gets +%d SP" % [_p2_round_wins, _p1_round_wins, result["sp_earned"]])
	else:
		# Draw — tied round wins (e.g. double KO every round). No win/loss recorded.
		Progression.total_fights += 1
		Progression.signal_points += Progression.SP_FIGHT_LOSS
		var result := {
			"won": false,
			"perfect": false,
			"draw": true,
			"sp_earned": Progression.SP_FIGHT_LOSS,
			"kt_earned": 0,
			"phase_before": phase_before,
			"p1_rounds": _p1_round_wins,
			"p2_rounds": _p2_round_wins,
		}
		Progression.last_fight_result = result
		Progression.save_game()
		print("[FIGHT] MATCH OVER: DRAW %d-%d! P1 gets +%d SP" % [_p1_round_wins, _p2_round_wins, result["sp_earned"]])

	if AudioManager:
		AudioManager.stop_music()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Reset fighters
		if event.keycode == KEY_R:
			_fighter1.position = Vector3(-3.0, 1.0, 0.0)
			_fighter1.reset_fighter()
			_fighter2.position = Vector3(3.0, 1.0, 0.0)
			_fighter2.reset_fighter()

		# Toggle spectator mode
		if event.keycode == KEY_TAB:
			_spectator_mode = not _spectator_mode
			_spectator_hud.visible = _spectator_mode
			_hud_label.visible = not _spectator_mode

		# P1 Special (Q key)
		if event.keycode == KEY_Q:
			_fighter1.activate_special()

		# P1 drop through (S key)
		if event.keycode == KEY_S and _fighter1.is_on_floor():
			_fighter1.drop_through_timer = 0.3

		# P1 FULL SIGNAL COMBO (E key)
		if event.keycode == KEY_E and _combo_attacker == null:
			if _fighter1.can_activate_combo():
				_trigger_combo(_fighter1, _fighter2)

		# Back to menu
		if event.keycode == KEY_ESCAPE:
			if AudioManager:
				AudioManager.stop_music()
			get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")

	# Player 2 controls (arrow keys + shift/ctrl)
	if event is InputEventKey:
		_handle_p2_input(event)

func _handle_p2_input(event: InputEventKey) -> void:
	if _fighter2 == null:
		return

	var f2_sm = _fighter2.get_node_or_null("StateMachine")
	if f2_sm == null:
		return

	# P2 drop through (Down arrow)
	if event.pressed and event.keycode == KEY_DOWN and _fighter2.is_on_floor():
		_fighter2.drop_through_timer = 0.3

	# P2 jump (Right Shift)
	if event.pressed and event.keycode == KEY_SHIFT:
		if _fighter2.is_on_floor():
			f2_sm._on_state_transition("jump")
		elif _fighter2.get("can_double_jump"):
			_fighter2.set("can_double_jump", false)
			_fighter2.velocity.y = _fighter2.DOUBLE_JUMP_FORCE
			f2_sm._on_state_transition("jump")

	# P2 attack (Right Ctrl or L key for easier testing)
	if event.pressed and (event.keycode == KEY_CTRL or event.keycode == KEY_L):
		f2_sm._on_state_transition("attack")

	# P2 Special (K key)
	if event.pressed and event.keycode == KEY_K:
		_fighter2.activate_special()

	# P2 FULL SIGNAL COMBO (O key)
	if event.pressed and event.keycode == KEY_O and _combo_attacker == null:
		if _fighter2.can_activate_combo():
			_trigger_combo(_fighter2, _fighter1)

## ═══════════ CHARACTER MODELS ═══════════

func _build_rico_model(model: Node3D, primary: Color, secondary: Color, accent: Color) -> void:
	## Rico — Cable Specialist. Blue/yellow. Try .glb blockout first, fallback to procedural.
	var glb_path := "res://assets/models/characters/rico_blockout.glb"
	if ResourceLoader.exists(glb_path):
		var scene: PackedScene = load(glb_path)
		if scene:
			var instance := scene.instantiate()
			instance.name = "RicoBlockout"
			instance.scale = Vector3(1.7, 1.7, 1.7)
			# Z-up → Y-up, compensate TripoSR intrinsic lean (~7° X, ~3.5° Z)
			instance.rotation_degrees = Vector3(-87.0, 180.0, 7.0)
			# Feet at original Z=-0.499, after rotation ≈ Y=-0.498 * 1.7 = -0.85
			instance.position.y = 0.85

			# Load baked texture
			var tex_path := "res://assets/models/characters/rico_blockout_texture.png"
			var texture: Texture2D = null
			if ResourceLoader.exists(tex_path):
				texture = load(tex_path)

			# Apply materials
			var mesh_nodes := instance.find_children("*", "MeshInstance3D", true)
			for node in mesh_nodes:
				var mesh_inst: MeshInstance3D = node
				for surf_idx in range(mesh_inst.mesh.get_surface_count()):
					var mat := StandardMaterial3D.new()
					mat.albedo_color = Color.WHITE
					mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					mat.cull_mode = BaseMaterial3D.CULL_DISABLED
					mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					mat.no_depth_test = false
					if texture:
						mat.albedo_texture = texture
						mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
					mesh_inst.set_surface_override_material(surf_idx, mat)

			model.add_child(instance)
			print("[FIGHT] Rico: loaded .glb blockout (texture: %s)" % str(texture != null))
			return

	print("[FIGHT] Rico: using procedural fallback")
	_build_rico_model_procedural(model, primary, secondary, accent)

func _build_rico_model_procedural(model: Node3D, primary: Color, secondary: Color, accent: Color) -> void:
	## Rico procedural fallback — Cable Specialist. Blue/yellow. Hard hat, cable whip on belt, tool pouch.

	# Boots (dark brown, chunky)
	var boot_l := ProceduralMesh.create_box(Vector3(0.14, 0.15, 0.2), Color("#3B2507"))
	boot_l.position = Vector3(-0.15, 0.08, 0.02)
	model.add_child(boot_l)
	var boot_r := ProceduralMesh.create_box(Vector3(0.14, 0.15, 0.2), Color("#3B2507"))
	boot_r.position = Vector3(0.15, 0.08, 0.02)
	model.add_child(boot_r)

	# Legs (work pants — secondary color)
	var leg_l := ProceduralMesh.create_cylinder(0.09, 0.45, 6, secondary)
	leg_l.position = Vector3(-0.15, 0.38, 0.0)
	model.add_child(leg_l)
	var leg_r := ProceduralMesh.create_cylinder(0.09, 0.45, 6, secondary)
	leg_r.position = Vector3(0.15, 0.38, 0.0)
	model.add_child(leg_r)

	# Belt
	var belt := ProceduralMesh.create_cylinder(0.32, 0.06, 8, Color("#1C1917"))
	belt.position.y = 0.6
	model.add_child(belt)

	# Belt buckle (accent)
	var buckle := ProceduralMesh.create_box(Vector3(0.08, 0.06, 0.05), accent)
	buckle.position = Vector3(0.0, 0.6, 0.3)
	model.add_child(buckle)

	# Tool pouch on belt (right side)
	var pouch := ProceduralMesh.create_box(Vector3(0.1, 0.12, 0.08), Color("#78350F"))
	pouch.position = Vector3(0.32, 0.58, 0.0)
	model.add_child(pouch)

	# Torso (work shirt — primary blue)
	var torso := ProceduralMesh.create_box(Vector3(0.5, 0.45, 0.3), primary)
	torso.position.y = 0.88
	model.add_child(torso)

	# Shirt collar (lighter blue)
	var collar := ProceduralMesh.create_box(Vector3(0.3, 0.06, 0.22), primary.lightened(0.2))
	collar.position.y = 1.13
	model.add_child(collar)

	# Arms (sleeves — primary color)
	var arm_l := ProceduralMesh.create_cylinder(0.08, 0.45, 6, primary)
	arm_l.position = Vector3(-0.34, 0.75, 0.0)
	arm_l.rotation_degrees.z = 12.0
	model.add_child(arm_l)
	var arm_r := ProceduralMesh.create_cylinder(0.08, 0.45, 6, primary)
	arm_r.position = Vector3(0.34, 0.75, 0.0)
	arm_r.rotation_degrees.z = -12.0
	model.add_child(arm_r)

	# Gloves (accent yellow)
	var glove_l := ProceduralMesh.create_sphere(0.09, 6, accent)
	glove_l.position = Vector3(-0.38, 0.52, 0.0)
	model.add_child(glove_l)
	var glove_r := ProceduralMesh.create_sphere(0.09, 6, accent)
	glove_r.position = Vector3(0.38, 0.52, 0.0)
	model.add_child(glove_r)

	# Neck
	var neck := ProceduralMesh.create_cylinder(0.08, 0.1, 6, Color("#D4A574"))
	neck.position.y = 1.18
	model.add_child(neck)

	# Head
	var head := ProceduralMesh.create_sphere(0.22, 8, Color("#D4A574"))
	head.position.y = 1.38
	model.add_child(head)

	# Eyes
	var eye_l := ProceduralMesh.create_sphere(0.045, 6, Color.WHITE)
	eye_l.position = Vector3(-0.09, 1.42, 0.18)
	model.add_child(eye_l)
	var pupil_l := ProceduralMesh.create_sphere(0.025, 6, Color.BLACK)
	pupil_l.position = Vector3(-0.09, 1.42, 0.22)
	model.add_child(pupil_l)
	var eye_r := ProceduralMesh.create_sphere(0.045, 6, Color.WHITE)
	eye_r.position = Vector3(0.09, 1.42, 0.18)
	model.add_child(eye_r)
	var pupil_r := ProceduralMesh.create_sphere(0.025, 6, Color.BLACK)
	pupil_r.position = Vector3(0.09, 1.42, 0.22)
	model.add_child(pupil_r)

	# Mouth (small dark line)
	var mouth := ProceduralMesh.create_box(Vector3(0.1, 0.02, 0.02), Color("#7C3030"))
	mouth.position = Vector3(0.0, 1.32, 0.2)
	model.add_child(mouth)

	# Hard hat (safety helmet — accent yellow)
	var hat_brim := ProceduralMesh.create_cylinder(0.28, 0.04, 8, accent)
	hat_brim.position.y = 1.52
	model.add_child(hat_brim)
	var hat_dome := ProceduralMesh.create_sphere(0.22, 8, accent)
	hat_dome.position.y = 1.58
	model.add_child(hat_dome)

	# Cable whip on back (coiled fiber — accent)
	var cable_coil := ProceduralMesh.create_cylinder(0.12, 0.2, 8, accent)
	cable_coil.position = Vector3(0.0, 0.9, -0.25)
	cable_coil.rotation_degrees.x = 15.0
	model.add_child(cable_coil)

	# Cable hanging end
	var cable_end := ProceduralMesh.create_cylinder(0.015, 0.35, 4, accent)
	cable_end.position = Vector3(0.1, 0.7, -0.28)
	cable_end.rotation_degrees.z = -30.0
	model.add_child(cable_end)

	# Company badge on chest
	var badge := ProceduralMesh.create_box(Vector3(0.1, 0.08, 0.02), Color.WHITE)
	badge.position = Vector3(-0.12, 1.0, 0.17)
	model.add_child(badge)

func _build_vero_model(model: Node3D, primary: Color, secondary: Color, accent: Color) -> void:
	## Ing. Vero — Spectrum Engineer. Purple/cyan. Visor, spectrum scanner, lab coat style.

	# Boots (professional — dark purple)
	var boot_l := ProceduralMesh.create_box(Vector3(0.12, 0.13, 0.18), secondary)
	boot_l.position = Vector3(-0.13, 0.07, 0.02)
	model.add_child(boot_l)
	var boot_r := ProceduralMesh.create_box(Vector3(0.12, 0.13, 0.18), secondary)
	boot_r.position = Vector3(0.13, 0.07, 0.02)
	model.add_child(boot_r)

	# Legs (dark pants)
	var leg_l := ProceduralMesh.create_cylinder(0.08, 0.42, 6, secondary)
	leg_l.position = Vector3(-0.13, 0.35, 0.0)
	model.add_child(leg_l)
	var leg_r := ProceduralMesh.create_cylinder(0.08, 0.42, 6, secondary)
	leg_r.position = Vector3(0.13, 0.35, 0.0)
	model.add_child(leg_r)

	# Belt (thin, tech-style)
	var belt := ProceduralMesh.create_cylinder(0.28, 0.04, 8, accent)
	belt.position.y = 0.58
	model.add_child(belt)

	# Torso (lab coat / tech jacket — primary purple)
	var torso := ProceduralMesh.create_box(Vector3(0.46, 0.48, 0.28), primary)
	torso.position.y = 0.85
	model.add_child(torso)

	# Lab coat flaps (slightly lighter, extend below torso)
	var flap_l := ProceduralMesh.create_box(Vector3(0.15, 0.15, 0.12), primary.lightened(0.1))
	flap_l.position = Vector3(-0.15, 0.58, 0.1)
	model.add_child(flap_l)
	var flap_r := ProceduralMesh.create_box(Vector3(0.15, 0.15, 0.12), primary.lightened(0.1))
	flap_r.position = Vector3(0.15, 0.58, 0.1)
	model.add_child(flap_r)

	# Spectrum scanner on chest (glowing cyan device)
	var scanner := ProceduralMesh.create_box(Vector3(0.15, 0.1, 0.05), accent)
	scanner.position = Vector3(0.1, 0.95, 0.17)
	model.add_child(scanner)
	# Scanner screen (darker center)
	var screen := ProceduralMesh.create_box(Vector3(0.1, 0.06, 0.01), Color("#0F172A"))
	screen.position = Vector3(0.1, 0.95, 0.2)
	model.add_child(screen)

	# Arms (jacket sleeves)
	var arm_l := ProceduralMesh.create_cylinder(0.07, 0.42, 6, primary)
	arm_l.position = Vector3(-0.3, 0.72, 0.0)
	arm_l.rotation_degrees.z = 10.0
	model.add_child(arm_l)
	var arm_r := ProceduralMesh.create_cylinder(0.07, 0.42, 6, primary)
	arm_r.position = Vector3(0.3, 0.72, 0.0)
	arm_r.rotation_degrees.z = -10.0
	model.add_child(arm_r)

	# Hands (tech gloves — accent cyan)
	var hand_l := ProceduralMesh.create_sphere(0.07, 6, accent)
	hand_l.position = Vector3(-0.33, 0.5, 0.0)
	model.add_child(hand_l)
	var hand_r := ProceduralMesh.create_sphere(0.07, 6, accent)
	hand_r.position = Vector3(0.33, 0.5, 0.0)
	model.add_child(hand_r)

	# Handheld scanner in right hand
	var handheld := ProceduralMesh.create_box(Vector3(0.05, 0.15, 0.03), Color("#1E293B"))
	handheld.position = Vector3(0.35, 0.45, 0.05)
	model.add_child(handheld)
	var handheld_screen := ProceduralMesh.create_box(Vector3(0.04, 0.06, 0.01), accent)
	handheld_screen.position = Vector3(0.35, 0.5, 0.07)
	model.add_child(handheld_screen)

	# Neck
	var neck := ProceduralMesh.create_cylinder(0.07, 0.08, 6, Color("#C4956A"))
	neck.position.y = 1.13
	model.add_child(neck)

	# Head
	var head := ProceduralMesh.create_sphere(0.21, 8, Color("#C4956A"))
	head.position.y = 1.32
	model.add_child(head)

	# Hair (dark, tied back — shorter on sides)
	var hair := ProceduralMesh.create_sphere(0.22, 8, Color("#1C1917"))
	hair.position = Vector3(0.0, 1.38, -0.03)
	model.add_child(hair)
	# Ponytail
	var ponytail := ProceduralMesh.create_cylinder(0.04, 0.2, 4, Color("#1C1917"))
	ponytail.position = Vector3(0.0, 1.28, -0.2)
	ponytail.rotation_degrees.x = 30.0
	model.add_child(ponytail)

	# Eyes
	var eye_l := ProceduralMesh.create_sphere(0.04, 6, Color.WHITE)
	eye_l.position = Vector3(-0.08, 1.36, 0.17)
	model.add_child(eye_l)
	var pupil_l := ProceduralMesh.create_sphere(0.022, 6, Color.BLACK)
	pupil_l.position = Vector3(-0.08, 1.36, 0.21)
	model.add_child(pupil_l)
	var eye_r := ProceduralMesh.create_sphere(0.04, 6, Color.WHITE)
	eye_r.position = Vector3(0.08, 1.36, 0.17)
	model.add_child(eye_r)
	var pupil_r := ProceduralMesh.create_sphere(0.022, 6, Color.BLACK)
	pupil_r.position = Vector3(0.08, 1.36, 0.21)
	model.add_child(pupil_r)

	# Spectrum visor (cyan translucent band across eyes)
	var visor := ProceduralMesh.create_box(Vector3(0.3, 0.06, 0.05), Color(accent, 0.7))
	visor.position = Vector3(0.0, 1.37, 0.18)
	model.add_child(visor)

	# Antenna array on back (spectrum analysis equipment)
	var backpack := ProceduralMesh.create_box(Vector3(0.2, 0.25, 0.12), Color("#1E293B"))
	backpack.position = Vector3(0.0, 0.9, -0.22)
	model.add_child(backpack)
	# Small antennas on backpack
	var ant1 := ProceduralMesh.create_cylinder(0.015, 0.25, 4, accent)
	ant1.position = Vector3(-0.06, 1.15, -0.22)
	model.add_child(ant1)
	var ant2 := ProceduralMesh.create_cylinder(0.015, 0.2, 4, accent)
	ant2.position = Vector3(0.06, 1.12, -0.22)
	model.add_child(ant2)

	# ID badge
	var badge := ProceduralMesh.create_box(Vector3(0.08, 0.1, 0.02), Color.WHITE)
	badge.position = Vector3(-0.15, 0.98, 0.16)
	model.add_child(badge)
	var badge_text := ProceduralMesh.create_box(Vector3(0.06, 0.03, 0.01), primary)
	badge_text.position = Vector3(-0.15, 0.96, 0.18)
	model.add_child(badge_text)

func _build_aurelio_model(model: Node3D, primary: Color, secondary: Color, accent: Color) -> void:
	## Don Aurelio — Old School Veteran. Brown/gold. Sombrero, big mustache, poncho, vintage tools.
	var skin := Color("#B8845C")

	# Boots (worn leather, chunky old-style)
	var boot_l := ProceduralMesh.create_box(Vector3(0.15, 0.16, 0.22), Color("#4A3520"))
	boot_l.position = Vector3(-0.16, 0.08, 0.02)
	model.add_child(boot_l)
	var boot_r := ProceduralMesh.create_box(Vector3(0.15, 0.16, 0.22), Color("#4A3520"))
	boot_r.position = Vector3(0.16, 0.08, 0.02)
	model.add_child(boot_r)
	# Boot soles (darker)
	var sole_l := ProceduralMesh.create_box(Vector3(0.16, 0.04, 0.24), Color("#2A1A0E"))
	sole_l.position = Vector3(-0.16, 0.02, 0.02)
	model.add_child(sole_l)
	var sole_r := ProceduralMesh.create_box(Vector3(0.16, 0.04, 0.24), Color("#2A1A0E"))
	sole_r.position = Vector3(0.16, 0.02, 0.02)
	model.add_child(sole_r)

	# Legs (sturdy work pants — secondary color)
	var leg_l := ProceduralMesh.create_cylinder(0.1, 0.42, 6, secondary)
	leg_l.position = Vector3(-0.16, 0.38, 0.0)
	model.add_child(leg_l)
	var leg_r := ProceduralMesh.create_cylinder(0.1, 0.42, 6, secondary)
	leg_r.position = Vector3(0.16, 0.38, 0.0)
	model.add_child(leg_r)

	# Belt (thick leather)
	var belt := ProceduralMesh.create_cylinder(0.34, 0.07, 8, Color("#3B2507"))
	belt.position.y = 0.6
	model.add_child(belt)
	# Big belt buckle (gold accent)
	var buckle := ProceduralMesh.create_box(Vector3(0.1, 0.08, 0.06), accent)
	buckle.position = Vector3(0.0, 0.6, 0.32)
	model.add_child(buckle)

	# Tool holster — left side (vintage wrench)
	var holster := ProceduralMesh.create_box(Vector3(0.08, 0.18, 0.06), Color("#5C3D1E"))
	holster.position = Vector3(-0.35, 0.55, 0.0)
	model.add_child(holster)
	var wrench := ProceduralMesh.create_box(Vector3(0.03, 0.22, 0.03), Color("#888888"))
	wrench.position = Vector3(-0.35, 0.58, 0.04)
	model.add_child(wrench)

	# Torso (wide, stocky build — primary brown)
	var torso := ProceduralMesh.create_box(Vector3(0.55, 0.48, 0.34), primary)
	torso.position.y = 0.88
	model.add_child(torso)

	# Poncho/serape over shoulders (accent gold, draped)
	var poncho_front := ProceduralMesh.create_box(Vector3(0.6, 0.3, 0.08), accent)
	poncho_front.position = Vector3(0.0, 1.0, 0.18)
	poncho_front.rotation_degrees.x = -5.0
	model.add_child(poncho_front)
	var poncho_back := ProceduralMesh.create_box(Vector3(0.6, 0.35, 0.08), accent.darkened(0.15))
	poncho_back.position = Vector3(0.0, 0.95, -0.18)
	poncho_back.rotation_degrees.x = 5.0
	model.add_child(poncho_back)
	# Poncho zigzag stripe (decorative)
	var stripe := ProceduralMesh.create_box(Vector3(0.5, 0.04, 0.02), Color("#FFFFFF"))
	stripe.position = Vector3(0.0, 1.02, 0.23)
	model.add_child(stripe)
	var stripe2 := ProceduralMesh.create_box(Vector3(0.5, 0.04, 0.02), Color("#DC2626"))
	stripe2.position = Vector3(0.0, 0.96, 0.23)
	model.add_child(stripe2)

	# Arms (thick, strong — primary color)
	var arm_l := ProceduralMesh.create_cylinder(0.1, 0.45, 6, primary)
	arm_l.position = Vector3(-0.38, 0.75, 0.0)
	arm_l.rotation_degrees.z = 15.0
	model.add_child(arm_l)
	var arm_r := ProceduralMesh.create_cylinder(0.1, 0.45, 6, primary)
	arm_r.position = Vector3(0.38, 0.75, 0.0)
	arm_r.rotation_degrees.z = -15.0
	model.add_child(arm_r)

	# Hands (weathered, large — skin tone)
	var hand_l := ProceduralMesh.create_sphere(0.1, 6, skin.darkened(0.1))
	hand_l.position = Vector3(-0.42, 0.52, 0.0)
	model.add_child(hand_l)
	var hand_r := ProceduralMesh.create_sphere(0.1, 6, skin.darkened(0.1))
	hand_r.position = Vector3(0.42, 0.52, 0.0)
	model.add_child(hand_r)

	# Neck (thick)
	var neck := ProceduralMesh.create_cylinder(0.09, 0.1, 6, skin)
	neck.position.y = 1.18
	model.add_child(neck)

	# Head (slightly larger, weathered)
	var head := ProceduralMesh.create_sphere(0.24, 8, skin)
	head.position.y = 1.38
	model.add_child(head)

	# Big mustache (signature feature — dark gray)
	var mustache_l := ProceduralMesh.create_box(Vector3(0.14, 0.04, 0.08), Color("#3D3D3D"))
	mustache_l.position = Vector3(-0.08, 1.33, 0.2)
	mustache_l.rotation_degrees.z = -10.0
	model.add_child(mustache_l)
	var mustache_r := ProceduralMesh.create_box(Vector3(0.14, 0.04, 0.08), Color("#3D3D3D"))
	mustache_r.position = Vector3(0.08, 1.33, 0.2)
	mustache_r.rotation_degrees.z = 10.0
	model.add_child(mustache_r)
	# Mustache center
	var mustache_c := ProceduralMesh.create_box(Vector3(0.06, 0.035, 0.06), Color("#3D3D3D"))
	mustache_c.position = Vector3(0.0, 1.34, 0.22)
	model.add_child(mustache_c)
	# Mustache tips (curled down)
	var tip_l := ProceduralMesh.create_cylinder(0.02, 0.06, 4, Color("#3D3D3D"))
	tip_l.position = Vector3(-0.16, 1.3, 0.18)
	tip_l.rotation_degrees.z = -20.0
	model.add_child(tip_l)
	var tip_r := ProceduralMesh.create_cylinder(0.02, 0.06, 4, Color("#3D3D3D"))
	tip_r.position = Vector3(0.16, 1.3, 0.18)
	tip_r.rotation_degrees.z = 20.0
	model.add_child(tip_r)

	# Eyes (squinting, experienced)
	var eye_l := ProceduralMesh.create_sphere(0.04, 6, Color.WHITE)
	eye_l.position = Vector3(-0.09, 1.42, 0.19)
	model.add_child(eye_l)
	var pupil_l := ProceduralMesh.create_sphere(0.025, 6, Color("#1C1917"))
	pupil_l.position = Vector3(-0.09, 1.42, 0.23)
	model.add_child(pupil_l)
	var eye_r := ProceduralMesh.create_sphere(0.04, 6, Color.WHITE)
	eye_r.position = Vector3(0.09, 1.42, 0.19)
	model.add_child(eye_r)
	var pupil_r := ProceduralMesh.create_sphere(0.025, 6, Color("#1C1917"))
	pupil_r.position = Vector3(0.09, 1.42, 0.23)
	model.add_child(pupil_r)
	# Bushy eyebrows
	var brow_l := ProceduralMesh.create_box(Vector3(0.08, 0.025, 0.04), Color("#4D4D4D"))
	brow_l.position = Vector3(-0.09, 1.47, 0.2)
	brow_l.rotation_degrees.z = 5.0
	model.add_child(brow_l)
	var brow_r := ProceduralMesh.create_box(Vector3(0.08, 0.025, 0.04), Color("#4D4D4D"))
	brow_r.position = Vector3(0.09, 1.47, 0.2)
	brow_r.rotation_degrees.z = -5.0
	model.add_child(brow_r)

	# Sombrero (wide brim + tall crown — accent gold)
	var sombrero_brim := ProceduralMesh.create_cylinder(0.42, 0.04, 10, accent)
	sombrero_brim.position.y = 1.54
	model.add_child(sombrero_brim)
	var sombrero_crown := ProceduralMesh.create_cylinder(0.18, 0.2, 8, accent)
	sombrero_crown.position.y = 1.65
	model.add_child(sombrero_crown)
	var sombrero_top := ProceduralMesh.create_cylinder(0.19, 0.03, 8, accent.darkened(0.1))
	sombrero_top.position.y = 1.76
	model.add_child(sombrero_top)
	# Sombrero band (decorative)
	var hat_band := ProceduralMesh.create_cylinder(0.19, 0.04, 8, Color("#DC2626"))
	hat_band.position.y = 1.57
	model.add_child(hat_band)

	# Old-school antenna on back (long yagi-style)
	var yagi_boom := ProceduralMesh.create_cylinder(0.015, 0.5, 4, Color("#888888"))
	yagi_boom.position = Vector3(0.0, 0.95, -0.28)
	yagi_boom.rotation_degrees.x = 20.0
	model.add_child(yagi_boom)
	# Yagi elements
	for i in range(4):
		var el := ProceduralMesh.create_box(Vector3(0.18 - i * 0.02, 0.015, 0.015), Color("#AAAAAA"))
		el.position = Vector3(0.0, 1.05 + i * 0.1, -0.3 - i * 0.03)
		model.add_child(el)

func _build_morxel_model(model: Node3D, primary: Color, secondary: Color, accent: Color) -> void:
	## MorXel — Reality Hacker. Green/emerald. Hoodie, terminal visor, digital glitch aesthetic.
	var skin := Color("#8B7355")

	# Boots (tech/tactical — dark with green accents)
	var boot_l := ProceduralMesh.create_box(Vector3(0.13, 0.14, 0.2), Color("#1A1A2E"))
	boot_l.position = Vector3(-0.14, 0.07, 0.02)
	model.add_child(boot_l)
	var boot_r := ProceduralMesh.create_box(Vector3(0.13, 0.14, 0.2), Color("#1A1A2E"))
	boot_r.position = Vector3(0.14, 0.07, 0.02)
	model.add_child(boot_r)
	# Boot accent strips (glowing green)
	var strip_l := ProceduralMesh.create_box(Vector3(0.02, 0.12, 0.18), accent)
	strip_l.position = Vector3(-0.2, 0.08, 0.02)
	model.add_child(strip_l)
	var strip_r := ProceduralMesh.create_box(Vector3(0.02, 0.12, 0.18), accent)
	strip_r.position = Vector3(0.2, 0.08, 0.02)
	model.add_child(strip_r)

	# Legs (dark cargo pants)
	var leg_l := ProceduralMesh.create_cylinder(0.085, 0.44, 6, secondary)
	leg_l.position = Vector3(-0.14, 0.37, 0.0)
	model.add_child(leg_l)
	var leg_r := ProceduralMesh.create_cylinder(0.085, 0.44, 6, secondary)
	leg_r.position = Vector3(0.14, 0.37, 0.0)
	model.add_child(leg_r)

	# Belt (tech belt with glowing buckle)
	var belt := ProceduralMesh.create_cylinder(0.3, 0.05, 8, Color("#0F172A"))
	belt.position.y = 0.59
	model.add_child(belt)
	var buckle := ProceduralMesh.create_box(Vector3(0.06, 0.06, 0.04), accent)
	buckle.position = Vector3(0.0, 0.59, 0.28)
	model.add_child(buckle)

	# Utility pouches (hacking tools)
	var pouch_l := ProceduralMesh.create_box(Vector3(0.07, 0.08, 0.05), Color("#1E293B"))
	pouch_l.position = Vector3(-0.3, 0.57, 0.05)
	model.add_child(pouch_l)
	var pouch_r := ProceduralMesh.create_box(Vector3(0.07, 0.08, 0.05), Color("#1E293B"))
	pouch_r.position = Vector3(0.3, 0.57, 0.05)
	model.add_child(pouch_r)

	# Torso (hoodie — primary green)
	var torso := ProceduralMesh.create_box(Vector3(0.48, 0.46, 0.3), primary)
	torso.position.y = 0.86
	model.add_child(torso)

	# Hoodie front pocket (kangaroo pocket)
	var pocket := ProceduralMesh.create_box(Vector3(0.3, 0.12, 0.04), primary.darkened(0.15))
	pocket.position = Vector3(0.0, 0.72, 0.17)
	model.add_child(pocket)

	# Hood (draped behind head)
	var hood := ProceduralMesh.create_box(Vector3(0.35, 0.2, 0.18), primary.darkened(0.1))
	hood.position = Vector3(0.0, 1.2, -0.15)
	model.add_child(hood)

	# Arms (hoodie sleeves)
	var arm_l := ProceduralMesh.create_cylinder(0.075, 0.44, 6, primary)
	arm_l.position = Vector3(-0.32, 0.73, 0.0)
	arm_l.rotation_degrees.z = 12.0
	model.add_child(arm_l)
	var arm_r := ProceduralMesh.create_cylinder(0.075, 0.44, 6, primary)
	arm_r.position = Vector3(0.32, 0.73, 0.0)
	arm_r.rotation_degrees.z = -12.0
	model.add_child(arm_r)

	# Hands (fingerless gloves — dark with green tips)
	var hand_l := ProceduralMesh.create_sphere(0.08, 6, Color("#1A1A2E"))
	hand_l.position = Vector3(-0.36, 0.5, 0.0)
	model.add_child(hand_l)
	var hand_r := ProceduralMesh.create_sphere(0.08, 6, Color("#1A1A2E"))
	hand_r.position = Vector3(0.36, 0.5, 0.0)
	model.add_child(hand_r)
	# Glowing fingertips
	var tip_l := ProceduralMesh.create_sphere(0.03, 4, accent)
	tip_l.position = Vector3(-0.36, 0.46, 0.06)
	model.add_child(tip_l)
	var tip_r := ProceduralMesh.create_sphere(0.03, 4, accent)
	tip_r.position = Vector3(0.36, 0.46, 0.06)
	model.add_child(tip_r)

	# Keyboard in left hand (hacking prop)
	var keyboard := ProceduralMesh.create_box(Vector3(0.15, 0.02, 0.08), Color("#0F172A"))
	keyboard.position = Vector3(-0.38, 0.48, 0.1)
	keyboard.rotation_degrees.z = 15.0
	model.add_child(keyboard)
	# Key lights on keyboard
	var keys := ProceduralMesh.create_box(Vector3(0.12, 0.01, 0.05), accent.darkened(0.3))
	keys.position = Vector3(-0.38, 0.49, 0.1)
	keys.rotation_degrees.z = 15.0
	model.add_child(keys)

	# Neck
	var neck := ProceduralMesh.create_cylinder(0.07, 0.08, 6, skin)
	neck.position.y = 1.14
	model.add_child(neck)

	# Head
	var head := ProceduralMesh.create_sphere(0.21, 8, skin)
	head.position.y = 1.33
	model.add_child(head)

	# Hair (short, messy — dark with green-tinted tips)
	var hair := ProceduralMesh.create_sphere(0.22, 8, Color("#1C1917"))
	hair.position = Vector3(0.0, 1.4, -0.02)
	model.add_child(hair)
	# Green-tipped spikes
	var spike1 := ProceduralMesh.create_cone(0.04, 0.1, 4, accent.darkened(0.3))
	spike1.position = Vector3(-0.06, 1.52, 0.02)
	spike1.rotation_degrees.z = 10.0
	model.add_child(spike1)
	var spike2 := ProceduralMesh.create_cone(0.04, 0.12, 4, accent.darkened(0.3))
	spike2.position = Vector3(0.04, 1.54, -0.02)
	spike2.rotation_degrees.z = -8.0
	model.add_child(spike2)
	var spike3 := ProceduralMesh.create_cone(0.035, 0.09, 4, accent.darkened(0.3))
	spike3.position = Vector3(0.12, 1.5, 0.0)
	spike3.rotation_degrees.z = -15.0
	model.add_child(spike3)

	# Terminal visor (signature — glowing green band)
	var visor := ProceduralMesh.create_box(Vector3(0.32, 0.06, 0.04), accent)
	visor.position = Vector3(0.0, 1.37, 0.19)
	model.add_child(visor)
	# Visor screen overlay (darker green scanline effect)
	var visor_screen := ProceduralMesh.create_box(Vector3(0.28, 0.04, 0.01), Color("#022C22"))
	visor_screen.position = Vector3(0.0, 1.37, 0.22)
	model.add_child(visor_screen)

	# Eyes behind visor (barely visible, glowing)
	var eye_l := ProceduralMesh.create_sphere(0.03, 6, accent)
	eye_l.position = Vector3(-0.08, 1.37, 0.2)
	model.add_child(eye_l)
	var eye_r := ProceduralMesh.create_sphere(0.03, 6, accent)
	eye_r.position = Vector3(0.08, 1.37, 0.2)
	model.add_child(eye_r)

	# Mouth (smirk)
	var mouth := ProceduralMesh.create_box(Vector3(0.08, 0.02, 0.02), Color("#4A3030"))
	mouth.position = Vector3(0.02, 1.27, 0.2)
	mouth.rotation_degrees.z = -8.0
	model.add_child(mouth)

	# Backpack (server/router on back)
	var backpack := ProceduralMesh.create_box(Vector3(0.22, 0.28, 0.1), Color("#0F172A"))
	backpack.position = Vector3(0.0, 0.88, -0.22)
	model.add_child(backpack)
	# LED lights on backpack (blinking indicators)
	for i in range(4):
		var led := ProceduralMesh.create_sphere(0.015, 4, accent if i % 2 == 0 else Color("#FF4444"))
		led.position = Vector3(-0.06 + i * 0.04, 1.04, -0.28)
		model.add_child(led)
	# Ethernet cables dangling from backpack
	var eth1 := ProceduralMesh.create_cylinder(0.012, 0.2, 4, Color("#2563EB"))
	eth1.position = Vector3(-0.08, 0.68, -0.24)
	eth1.rotation_degrees.z = 10.0
	model.add_child(eth1)
	var eth2 := ProceduralMesh.create_cylinder(0.012, 0.18, 4, accent)
	eth2.position = Vector3(0.08, 0.7, -0.24)
	eth2.rotation_degrees.z = -8.0
	model.add_child(eth2)

func _build_arena_wispa_2026() -> void:
	## WISPA 2026 — Purple/Gold themed convention, larger stage, trophy display, year banner
	# Main convention floor (larger than standard WISPA)
	_add_solid_platform(Vector3(0, -0.25, 0), Vector3(22.0, 0.5, 11.0), Color("#7C3AED"))
	# Vendor booth platforms (more booths)
	_add_one_way_platform(Vector3(-7.0, 1.5, 0), Vector3(4.0, 0.3, 3.0), Color("#5B21B6"))
	_add_one_way_platform(Vector3(7.0, 1.5, 0), Vector3(4.0, 0.3, 3.0), Color("#5B21B6"))
	_add_one_way_platform(Vector3(-3.0, 1.5, 0), Vector3(3.0, 0.3, 3.0), Color("#6D28D9"))
	_add_one_way_platform(Vector3(3.0, 1.5, 0), Vector3(3.0, 0.3, 3.0), Color("#6D28D9"))
	# Grand stage platform (center elevated, larger)
	_add_one_way_platform(Vector3(0, 3.5, 0), Vector3(7.0, 0.5, 4.0), Color("#FBBF24"))
	# Vendor booth walls with brand colors
	var booth_colors := [Color("#5B21B6"), Color("#7C3AED"), Color("#FBBF24"), Color("#059669"), Color("#1E40AF"), Color("#EC4899")]
	for i in range(6):
		var booth := ProceduralMesh.create_box(Vector3(2.0, 2.5, 0.5), booth_colors[i])
		booth.position = Vector3(-7.5 + i * 3.0, 1.25, -4.0)
		add_child(booth)
		var banner := ProceduralMesh.create_box(Vector3(2.2, 0.6, 0.1), Color("#FBBF24"))
		banner.position = Vector3(-7.5 + i * 3.0, 2.8, -4.0)
		add_child(banner)
	# Big screen backdrop
	var screen := ProceduralMesh.create_box(Vector3(12.0, 6.0, 0.2), Color("#0F172A"))
	screen.position = Vector3(0, 5.5, -6.0)
	add_child(screen)
	# Year banner "2026" — gold bars
	var year_bar := ProceduralMesh.create_box(Vector3(6.0, 1.2, 0.1), Color("#FBBF24"))
	year_bar.position = Vector3(0, 8.0, -5.85)
	add_child(year_bar)
	var year_bg := ProceduralMesh.create_box(Vector3(5.5, 0.8, 0.1), Color("#4C1D95"))
	year_bg.position = Vector3(0, 8.0, -5.8)
	add_child(year_bg)
	# SIGNAL SMASH accent bars on screen
	var bar1 := ProceduralMesh.create_box(Vector3(5.0, 0.3, 0.1), Color("#06B6D4"))
	bar1.position = Vector3(-1.5, 7.0, -5.85)
	add_child(bar1)
	var bar2 := ProceduralMesh.create_box(Vector3(4.5, 0.3, 0.1), Color("#FBBF24"))
	bar2.position = Vector3(1.5, 6.5, -5.85)
	add_child(bar2)
	# Trophy display (center-left)
	var trophy_base := ProceduralMesh.create_box(Vector3(1.0, 0.8, 1.0), Color("#292524"))
	trophy_base.position = Vector3(-9.0, 0.4, 2.0)
	add_child(trophy_base)
	var trophy_cup := ProceduralMesh.create_cone(0.3, 0.8, 6, Color("#FBBF24"))
	trophy_cup.position = Vector3(-9.0, 1.2, 2.0)
	add_child(trophy_cup)
	var trophy_star := ProceduralMesh.create_sphere(0.15, 6, Color("#FBBF24"))
	trophy_star.position = Vector3(-9.0, 1.8, 2.0)
	add_child(trophy_star)
	# Spotlights (purple/gold alternating)
	for i in range(7):
		var spot_color: Color = Color("#FBBF24") if i % 2 == 0 else Color("#7C3AED")
		var spot := ProceduralMesh.create_sphere(0.25, 6, spot_color)
		spot.position = Vector3(-6.0 + i * 2.0, 9.5, -2.0)
		add_child(spot)
	_build_hazard()

func _build_arena_wispmx() -> void:
	## WISPMX Monterrey — Mexican flag colors, papel picado, Cerro de la Silla, mariachi stage
	# Main floor (red base)
	_add_solid_platform(Vector3(0, -0.25, 0), Vector3(20.0, 0.5, 10.0), Color("#DC2626"))
	# Side platforms (green)
	_add_one_way_platform(Vector3(-6.0, 1.5, 0), Vector3(4.0, 0.3, 3.0), Color("#16A34A"))
	_add_one_way_platform(Vector3(6.0, 1.5, 0), Vector3(4.0, 0.3, 3.0), Color("#16A34A"))
	# Center white platform
	_add_one_way_platform(Vector3(0, 1.0, 0), Vector3(5.0, 0.3, 3.0), Color("#F5F5F4"))
	# Mariachi stage (elevated, right side)
	_add_one_way_platform(Vector3(7.0, 3.0, -2.0), Vector3(4.0, 0.4, 3.0), Color("#7F1D1D"))
	# Mariachi stage backdrop
	var mariachi_bg := ProceduralMesh.create_box(Vector3(4.5, 3.0, 0.2), Color("#450A0A"))
	mariachi_bg.position = Vector3(7.0, 4.5, -3.5)
	add_child(mariachi_bg)
	# Papel picado decorations (colored triangles hanging on strings)
	var picado_colors := [Color("#DC2626"), Color("#16A34A"), Color("#FBBF24"), Color("#EC4899"), Color("#7C3AED"), Color("#06B6D4"), Color("#F97316"), Color("#F5F5F4")]
	for row in range(3):
		var row_y: float = 6.0 + row * 1.5
		var row_z: float = -1.0 - row * 2.0
		# String line
		var string_line := ProceduralMesh.create_cylinder(0.02, 18.0, 4, Color("#92400E"))
		string_line.position = Vector3(0, row_y, row_z)
		string_line.rotation_degrees.z = 90.0
		add_child(string_line)
		# Hanging triangle flags
		for i in range(10):
			var flag_color: Color = picado_colors[(i + row) % picado_colors.size()]
			var flag := ProceduralMesh.create_cone(0.3, 0.5, 3, flag_color)
			flag.position = Vector3(-8.0 + i * 1.8, row_y - 0.4, row_z)
			flag.rotation_degrees.x = 180.0  # Point downward
			add_child(flag)
	# Cerro de la Silla (larger version)
	var mountain_color := Color("#78350F").lightened(0.15)
	var peak1 := ProceduralMesh.create_cone(7.0, 12.0, 4, mountain_color)
	peak1.position = Vector3(-12.0, 0.0, -35.0)
	add_child(peak1)
	var peak2 := ProceduralMesh.create_cone(6.0, 14.0, 4, mountain_color.darkened(0.1))
	peak2.position = Vector3(-4.0, 0.0, -38.0)
	add_child(peak2)
	var ridge := ProceduralMesh.create_cone(4.0, 8.0, 4, mountain_color.darkened(0.05))
	ridge.position = Vector3(-8.0, 0.0, -32.0)
	add_child(ridge)
	# Monterrey cityscape (background buildings)
	var city_colors := [Color("#374151"), Color("#4B5563"), Color("#1F2937"), Color("#6B7280")]
	for i in range(8):
		var bldg_h: float = randf_range(4.0, 10.0)
		var bldg := ProceduralMesh.create_box(Vector3(2.0, bldg_h, 1.5), city_colors[i % city_colors.size()])
		bldg.position = Vector3(-14.0 + i * 4.0, bldg_h / 2.0 - 0.5, -20.0)
		add_child(bldg)
	# Mexican flag colors accent bars
	var flag_g := ProceduralMesh.create_box(Vector3(3.0, 0.4, 0.1), Color("#16A34A"))
	flag_g.position = Vector3(-3.5, 5.0, -5.0)
	add_child(flag_g)
	var flag_w := ProceduralMesh.create_box(Vector3(3.0, 0.4, 0.1), Color("#F5F5F4"))
	flag_w.position = Vector3(0.0, 5.0, -5.0)
	add_child(flag_w)
	var flag_r := ProceduralMesh.create_box(Vector3(3.0, 0.4, 0.1), Color("#DC2626"))
	flag_r.position = Vector3(3.5, 5.0, -5.0)
	add_child(flag_r)
	# Spotlights
	for i in range(5):
		var spot := ProceduralMesh.create_sphere(0.2, 6, Color("#FBBF24"))
		spot.position = Vector3(-4.0 + i * 2.0, 9.0, -2.0)
		add_child(spot)
	_build_hazard()

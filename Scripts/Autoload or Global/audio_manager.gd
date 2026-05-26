extends Node

const MUSIC_BUS_NAME := "Music"
const SFX_BUS_NAME := "SFX"
const SETTINGS_PATH := "user://audio_settings.cfg"

const TRACK_PATHS := {
	"MAIN_MENU_MUSIC": "res://Sounds/BACKGROUND_MUSICS/MAIN_MENU_MUSIC.mp3",
	"Introduction_Music": "res://Sounds/BACKGROUND_MUSICS/Introduction_Music.mp3",
	"INSIDE_SCHOOL_MAP": "res://Sounds/BACKGROUND_MUSICS/INSIDE_SCHOOL_MAP.mp3",
	"SHS_PROFESSOR_TEACHING": "res://Sounds/BACKGROUND_MUSICS/SHS_PROFESSOR_TEACHING.mp3",
	"REMEDIAL": "res://Sounds/BACKGROUND_MUSICS/REMEDIAL.mp3",
	"OUTSIDE_SCHOOL": "res://Sounds/BACKGROUND_MUSICS/OUTSIDE_SCHOOL.mp3",
	"11-7_PROF CUTSCENE": "res://Sounds/BACKGROUND_MUSICS/11-7_PROF CUTSCENE.mp3",
	"INTERNET_CAFE": "res://Sounds/BACKGROUND_MUSICS/INTERNET_CAFE.mp3",
	"SPAGHETTI_MAN_CUTSCENE": "res://Sounds/BACKGROUND_MUSICS/SPAGHETTI_MAN_CUTSCENE.mp3",
	"GRADUATION_DAY": "res://Sounds/BACKGROUND_MUSICS/GRADUATION_DAY.mp3",
	"CHOOSE YOUR FAVORITE PROFESSOR": "res://Sounds/BACKGROUND_MUSICS/CHOOSE YOUR FAVORITE PROFESSOR.mp3",
	"INSIDE_COLLEGE_MAP": "res://Sounds/BACKGROUND_MUSICS/INSIDE_COLLEGE_MAP.mp3",
	"Professor_Markup": "res://Sounds/BACKGROUND_MUSICS/Professor_Markup.mp3",
	"Professor_Syntax": "res://Sounds/BACKGROUND_MUSICS/Professor_Syntax.mp3",
	"Professor_View": "res://Sounds/BACKGROUND_MUSICS/Professor_View.mp3",
	"Professor_Query": "res://Sounds/BACKGROUND_MUSICS/Professor_Query.mp3",
	"Professor_Token": "res://Sounds/BACKGROUND_MUSICS/Professor_Token.mp3",
	"Professor_Auth": "res://Sounds/BACKGROUND_MUSICS/Professor_Auth.mp3",
	"Professor_Rest": "res://Sounds/BACKGROUND_MUSICS/Professor_Rest.mp3",
	"STUDENT_CHALLENGES": "res://Sounds/BACKGROUND_MUSICS/STUDENT_CHALLENGES.mp3",
	"PPT": "res://Sounds/BACKGROUND_MUSICS/PPT.mp3",
	"REMOVAL EXAMS": "res://Sounds/BACKGROUND_MUSICS/REMOVAL EXAMS.mp3",
}

var _music_player: AudioStreamPlayer
var _track_cache: Dictionary = {}
var _current_track: String = ""
var _current_scene_path: String = ""
var _music_volume: float = 0.75
var _sfx_volume: float = 0.85

func _ready() -> void:
	_ensure_audio_bus(MUSIC_BUS_NAME)
	_ensure_audio_bus(SFX_BUS_NAME)
	_load_settings()

	_music_player = AudioStreamPlayer.new()
	_music_player.name = "BackgroundMusicPlayer"
	_music_player.bus = MUSIC_BUS_NAME
	add_child(_music_player)

	_apply_volumes()

	get_tree().node_added.connect(_on_node_added)
	_route_audio_tree(get_tree().root)

	_current_scene_path = _get_current_scene_path()
	play_scene_music(true)
	set_process(true)

func _process(_delta: float) -> void:
	var scene_path = _get_current_scene_path()
	if scene_path == _current_scene_path:
		return

	_current_scene_path = scene_path
	play_scene_music(true)

func play_track(track_key: String, restart: bool = false) -> void:
	if track_key == "":
		return

	var stream = _get_track_stream(track_key)
	if stream == null:
		return

	if not restart and _current_track == track_key and _music_player.playing:
		return

	_current_track = track_key
	if _music_player.stream != stream:
		_music_player.stream = stream
	_music_player.play()

func play_scene_music(restart: bool = false) -> void:
	var scene_track = _resolve_scene_track(_current_scene_path)
	if scene_track != "":
		play_track(scene_track, restart)

func set_music_volume(value: float) -> void:
	_music_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(MUSIC_BUS_NAME, _music_volume)
	_save_settings()

func set_sfx_volume(value: float) -> void:
	_sfx_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(SFX_BUS_NAME, _sfx_volume)
	_save_settings()

func get_music_volume() -> float:
	return _music_volume

func get_sfx_volume() -> float:
	return _sfx_volume

func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return

	AudioServer.add_bus(AudioServer.get_bus_count())
	AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, bus_name)

func _apply_volumes() -> void:
	_apply_bus_volume(MUSIC_BUS_NAME, _music_volume)
	_apply_bus_volume(SFX_BUS_NAME, _sfx_volume)

func _apply_bus_volume(bus_name: String, linear_value: float) -> void:
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return
	AudioServer.set_bus_volume_db(bus_index, _linear_to_db(linear_value))

func _linear_to_db(value: float) -> float:
	if value <= 0.001:
		return -80.0
	return linear_to_db(value)

func _get_track_stream(track_key: String) -> AudioStream:
	if _track_cache.has(track_key):
		return _track_cache[track_key]

	if not TRACK_PATHS.has(track_key):
		push_warning("AudioManager: Unknown track key: " + track_key)
		return null

	var path = String(TRACK_PATHS[track_key])
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: Missing music file: " + path)
		return null

	var stream = load(path)
	if stream is AudioStream:
		_track_cache[track_key] = stream
		return stream

	push_warning("AudioManager: Resource is not an AudioStream: " + path)
	return null

func _get_current_scene_path() -> String:
	var scene = get_tree().current_scene
	if scene == null:
		return ""
	return String(scene.scene_file_path)

func _resolve_scene_track(scene_path: String) -> String:
	if scene_path.ends_with("login_screen.tscn") or scene_path.ends_with("main_menu.tscn"):
		return "MAIN_MENU_MUSIC"
	if scene_path.ends_with("intro_slides.tscn"):
		return "Introduction_Music"
	if scene_path.ends_with("learning_mode.tscn") or scene_path.ends_with("learning_professor_select.tscn"):
		return "CHOOSE YOUR FAVORITE PROFESSOR"
	if scene_path.ends_with("python_history_quiz_game.tscn"):
		return "SHS_PROFESSOR_TEACHING"
	if scene_path.ends_with("school_map.tscn") or scene_path.ends_with("school_map_npc_challenges_testing.tscn"):
		return "INSIDE_SCHOOL_MAP"
	if scene_path.ends_with("outdoor_map_convenience_store_cutscene2.tscn"):
		return "11-7_PROF CUTSCENE"
	if scene_path.ends_with("outdoor_map.tscn") or scene_path.ends_with("outdoor_map_local_backup.tscn"):
		return "OUTSIDE_SCHOOL"
	if scene_path.ends_with("internet_cafe_map.tscn") or scene_path.ends_with("internet_cafe_map_cutscene.tscn"):
		return "INTERNET_CAFE"
	if scene_path.ends_with("removal_quiz_game.tscn"):
		return "REMOVAL EXAMS"
	if scene_path.ends_with("college_map.tscn") or scene_path.ends_with("college_2nd_floor_map.tscn"):
		return "INSIDE_COLLEGE_MAP"
	if scene_path.contains("main_office"):
		return "GRADUATION_DAY"
	return ""

func _on_node_added(node: Node) -> void:
	_route_audio_tree(node)

func _route_audio_tree(node: Node) -> void:
	_route_audio_node(node)
	for child in node.get_children():
		_route_audio_tree(child)

func _route_audio_node(node: Node) -> void:
	if node == _music_player:
		return
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		if String(node.bus) == "" or String(node.bus) == "Master":
			node.bus = SFX_BUS_NAME

func _load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	_music_volume = float(config.get_value("audio", "music_volume", _music_volume))
	_sfx_volume = float(config.get_value("audio", "sfx_volume", _sfx_volume))

func _save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "music_volume", _music_volume)
	config.set_value("audio", "sfx_volume", _sfx_volume)
	config.save(SETTINGS_PATH)

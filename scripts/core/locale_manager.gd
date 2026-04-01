extends Node
## LocaleManager — Autoload singleton for trilingual support (EN/ES/PT).
## Loads translations from CSV and provides tr() function.
## Change language at runtime with set_language().

var _translations: Dictionary = {}  # { key: { "en": val, "es": val, "pt": val } }
var _current_language: String = "es"  # Default Spanish for WISP LATAM
var _available_languages: Array[String] = ["en", "es", "pt"]

signal language_changed(lang: String)

func _ready() -> void:
	_load_csv("res://data/localization/messages.csv")
	print("[LOCALE] Loaded %d keys, language: %s" % [_translations.size(), _current_language])

func _load_csv(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("[LOCALE] Cannot open: %s" % path)
		return

	# First line = headers (keys,en,es,pt)
	var headers_line: String = file.get_line()
	var headers: PackedStringArray = headers_line.split(",")

	# Map column indices to language codes
	var lang_columns: Dictionary = {}
	for i in range(1, headers.size()):
		lang_columns[i] = headers[i].strip_edges()

	# Read data lines
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line == "":
			continue

		# CSV parse that handles quoted values containing commas
		var parts: Array[String] = _parse_csv_line(line)
		if parts.size() < 2:
			continue

		var key: String = parts[0].strip_edges()
		var entry: Dictionary = {}
		for i in range(1, mini(parts.size(), headers.size())):
			var lang: String = lang_columns.get(i, "")
			if lang != "":
				entry[lang] = parts[i].strip_edges()

		_translations[key] = entry

## Get translated string for current language
func t(key: String) -> String:
	if key not in _translations:
		return key  # Fallback: return key itself
	var entry: Dictionary = _translations[key]
	if _current_language in entry:
		return entry[_current_language]
	if "en" in entry:
		return entry["en"]  # Fallback to English
	return key

## Set language and emit signal
func set_language(lang: String) -> void:
	if lang in _available_languages:
		_current_language = lang
		language_changed.emit(lang)
		print("[LOCALE] Language changed to: %s" % lang)

## Cycle to next language
func cycle_language() -> void:
	var idx: int = _available_languages.find(_current_language)
	idx = (idx + 1) % _available_languages.size()
	set_language(_available_languages[idx])

## Get current language code
func get_language() -> String:
	return _current_language

## Parse a CSV line handling quoted values that may contain commas
func _parse_csv_line(line: String) -> Array[String]:
	var result: Array[String] = []
	var current := ""
	var in_quotes := false
	var i := 0
	while i < line.length():
		var c := line[i]
		if c == '"':
			in_quotes = not in_quotes
		elif c == ',' and not in_quotes:
			result.append(current)
			current = ""
		else:
			current += c
		i += 1
	result.append(current)
	return result

## Get display name for current language
func get_language_name() -> String:
	match _current_language:
		"en": return "English"
		"es": return "Español"
		"pt": return "Português"
	return _current_language

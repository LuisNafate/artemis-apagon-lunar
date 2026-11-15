class_name LunarLanguage
extends HBoxContainer
## Selector de idioma (espanol / ingles) para la portada y el lobby. Los textos del
## juego estan en espanol; la traduccion al ingles se registra solo mientras el
## ingles esta activo, asi el espanol siempre muestra el texto original.

signal changed

const SAVE_PATH := "user://idioma.cfg"
const LANGUAGES := {"es": "Español", "en": "English"}

static var _english: Translation
## Idioma elegido en el juego. No depende del idioma de la computadora, para que el juego
## empiece en español aunque Windows esté en inglés.
static var _code := "es"

var _buttons := {}


static func setup() -> void:
	var code := "es"
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) == OK:
		code = String(file.get_value("idioma", "codigo", "es"))
	set_language(code if LANGUAGES.has(code) else "es", false)


static func current() -> String:
	return _code


static func set_language(code: String, save := true) -> void:
	if _english == null:
		_english = Translation.new()
		_english.locale = "en"
		for source: String in LunarEnglish.TEXT:
			_english.add_message(source, LunarEnglish.TEXT[source])
	TranslationServer.remove_translation(_english)
	if code == "en":
		TranslationServer.add_translation(_english)
	TranslationServer.set_locale(code)
	_code = code
	if save:
		var file := ConfigFile.new()
		file.set_value("idioma", "codigo", code)
		file.save(SAVE_PATH)


## Traduce un texto que se arma por partes (formatos y textos pegados), donde la
## traduccion automatica de los controles no llega.
static func t(text: String) -> String:
	return TranslationServer.translate(text)


func _init() -> void:
	add_theme_constant_override("separation", 6)
	for code: String in LANGUAGES:
		var button := Button.new()
		button.text = code.to_upper()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(66, 46)
		button.tooltip_text = "%s / Language" % LANGUAGES[code]
		button.pressed.connect(_choose.bind(code))
		add_child(button)
		_buttons[code] = button
	_refresh()


func _choose(code: String) -> void:
	if code == current():
		return
	set_language(code)
	_refresh()
	changed.emit()


func _refresh() -> void:
	for code: String in _buttons:
		LunarButtonKit.apply(
			_buttons[code], &"construir" if code == current() else &"seguimiento", 16
		)

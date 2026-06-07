class_name UITokens
extends RefCounted

const BG := Color("#080b12")
const SURFACE := Color("#0f1624")
const ELEVATED := Color("#17243a")
const SELECTED := Color("#203653")
const BORDER := Color("#2a3b56")
const BORDER_STRONG := Color("#49698f")
const TEXT := Color("#f4f7fb")
const TEXT_SECONDARY := Color("#b8c5d6")
const TEXT_MUTED := Color("#708099")
const PRIMARY := Color("#66e3f0")
const SECONDARY := Color("#ffd166")
const SUCCESS := Color("#80ed99")
const WARNING := Color("#ffb347")
const DANGER := Color("#ff6b5e")
const CURSE := Color("#b57bff")
const HEALTH := Color("#ff4d7a")
const XP := Color("#66e3f0")
const FONT_PATH := "res://assets/fonts/NotoSansSC-VF.ttf"

const SPACE_1 := 4
const SPACE_2 := 8
const SPACE_3 := 12
const SPACE_4 := 16
const SPACE_6 := 24
const SPACE_8 := 32

const ICONS := {
	"shell_pistol": "res://assets/ui/icons/01_shell_pistol.png",
	"magnetic_coin": "res://assets/ui/icons/02_magnetic_coin.png",
	"frost_crystal": "res://assets/ui/icons/03_frost_crystal.png",
	"cracked_brick": "res://assets/ui/icons/04_cracked_brick.png",
	"mark": "res://assets/ui/icons/05_mark.png",
	"shock": "res://assets/ui/icons/06_shock.png",
	"freeze": "res://assets/ui/icons/07_freeze.png",
	"burn": "res://assets/ui/icons/08_burn.png",
	"lightning_chain": "res://assets/ui/icons/09_lightning_chain.png",
	"shatter": "res://assets/ui/icons/10_shatter.png",
	"thermal_shock": "res://assets/ui/icons/11_thermal_shock.png",
	"active_skill": "res://assets/ui/icons/12_stellar_circuit.png",
	"health": "res://assets/ui/icons/13_health.png",
	"experience": "res://assets/ui/icons/14_experience.png",
	"reroll": "res://assets/ui/icons/15_reroll.png",
	"pause": "res://assets/ui/icons/16_pause_settings.png",
	"shifted_balance": "res://assets/ui/icons/17_shifted_balance.png",
	"hollow_defense": "res://assets/ui/icons/18_hollow_defense.png",
	"rushed_pulse": "res://assets/ui/icons/19_rushed_pulse.png",
	"stardust_leak": "res://assets/ui/icons/20_stardust_leak.png",
	"freeze_dullness": "res://assets/ui/icons/21_freeze_dullness.png",
	"rift_echo": "res://assets/ui/icons/22_rift_echo.png",
}


static func panel_style(color: Color = SURFACE, border_color: Color = BORDER, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = SPACE_4
	style.content_margin_right = SPACE_4
	style.content_margin_top = SPACE_4
	style.content_margin_bottom = SPACE_4
	return style


static func build_theme() -> Theme:
	var result := Theme.new()
	result.default_font = load(FONT_PATH) as Font
	result.default_font_size = 18
	result.set_color("font_color", "Label", TEXT)
	result.set_color("font_color", "Button", TEXT)
	result.set_color("font_hover_color", "Button", TEXT)
	result.set_color("font_focus_color", "Button", TEXT)
	result.set_color("font_pressed_color", "Button", BG)
	result.set_color("font_disabled_color", "Button", TEXT_MUTED)
	result.set_stylebox("normal", "Button", panel_style(SURFACE, BORDER))
	result.set_stylebox("hover", "Button", panel_style(ELEVATED, BORDER_STRONG))
	result.set_stylebox("focus", "Button", panel_style(SELECTED, PRIMARY))
	result.set_stylebox("pressed", "Button", panel_style(PRIMARY, PRIMARY))
	result.set_stylebox("disabled", "Button", panel_style(Color("#0b101a"), Color("#202c3e")))
	result.set_stylebox("panel", "PanelContainer", panel_style())
	result.set_stylebox("background", "ProgressBar", panel_style(Color("#26333c"), BORDER, 4))
	result.set_stylebox("fill", "ProgressBar", panel_style(PRIMARY, PRIMARY, 4))
	result.set_color("font_color", "ProgressBar", TEXT)
	result.set_constant("outline_size", "Label", 2)
	result.set_color("font_outline_color", "Label", Color("#05070bcc"))
	return result

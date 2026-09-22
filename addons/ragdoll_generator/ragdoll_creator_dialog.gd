@tool
class_name RagdollCreatorDialog
extends AcceptDialog

signal ragdoll_create_requested(config: Dictionary)

const SLOT_KEYS: Array[String] = [
	"pelvis",
	"left_hips",
	"left_knee",
	"left_foot",
	"right_hips",
	"right_knee",
	"right_foot",
	"left_arm",
	"left_elbow",
	"left_hand",
	"right_arm",
	"right_elbow",
	"right_hand",
	"middle_spine",
	"head",
]

const SLOT_LABELS: Dictionary = {
	"pelvis": "Pelvis",
	"left_hips": "Left Hips",
	"left_knee": "Left Knee",
	"left_foot": "Left Foot",
	"right_hips": "Right Hips",
	"right_knee": "Right Knee",
	"right_foot": "Right Foot",
	"left_arm": "Left Arm",
	"left_elbow": "Left Elbow",
	"left_hand": "Left Hand",
	"right_arm": "Right Arm",
	"right_elbow": "Right Elbow",
	"right_hand": "Right Hand",
	"middle_spine": "Middle Spine",
	"head": "Head",
}

const REQUIRED_SLOTS: Array[String] = [
	"pelvis",
	"left_hips",
	"left_knee",
	"right_hips",
	"right_knee",
	"middle_spine",
	"head",
	"left_arm",
	"left_elbow",
	"right_arm",
	"right_elbow",
]

const KNOWN_PREFIXES: Array[String] = [
	"mixamorig8:", "mixamorig:", "mixamorig8_", "mixamorig_",
	"bip01_", "bip001_", "bip01 ", "bip001 ",
	"cc_base_", "cc_base",
	"def_", "deform_", "def.", "deform.",
	"j_", "jnt_", "bone_",
	"character1:", "character1_",
	"metarig_", "rig_",
	"valvebiped.bip01_",
	"vrm_",
]

var _skeleton: Skeleton3D = null
var _slot_values: Dictionary = {}
var _slot_buttons: Dictionary = {}
var _pick_buttons: Dictionary = {}

var _header_label: Label = null
var _mass_spin: SpinBox = null
var _strength_spin: SpinBox = null
var _flip_forward_check: CheckBox = null

var _error_container: HBoxContainer = null
var _error_icon: TextureRect = null
var _error_label: Label = null
var _create_button: Button = null

var _picker_dialog: ConfirmationDialog = null
var _picker_filter: LineEdit = null
var _picker_list: ItemList = null
var _current_picker_slot: String = ""
var _cached_bones: PackedStringArray = PackedStringArray()

var _fallback_error_texture: ImageTexture = null
var _fallback_valid_texture: ImageTexture = null
var _target_icon_texture: ImageTexture = null

func _init() -> void:
	title = "Create Ragdoll"
	min_size = Vector2i(420, 560)
	size = Vector2i(460, 680)
	exclusive = false
	unresizable = false
	_generate_fallback_icons()
	_build_ui()

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_ENTER_TREE:
		_apply_native_theme()

func _generate_fallback_icons() -> void:
	var err_svg = """<svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
		<circle cx="8" cy="8" r="7.5" fill="#D32F2F" stroke="#9A0007" stroke-width="1"/>
		<path d="M8 4V9" stroke="white" stroke-width="1.8" stroke-linecap="round"/>
		<circle cx="8" cy="12" r="1.1" fill="white"/>
	</svg>"""
	var err_img = Image.new()
	if err_img.load_svg_from_string(err_svg, 1.0) == OK:
		_fallback_error_texture = ImageTexture.create_from_image(err_img)

	var valid_svg = """<svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
		<circle cx="8" cy="8" r="7.5" fill="#2E7D32" stroke="#1B5E20" stroke-width="1"/>
		<path d="M5 8.5L7.5 11L11.5 5.5" stroke="white" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
	</svg>"""
	var valid_img = Image.new()
	if valid_img.load_svg_from_string(valid_svg, 1.0) == OK:
		_fallback_valid_texture = ImageTexture.create_from_image(valid_img)

	var target_svg = """<svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
		<circle cx="8" cy="8" r="5.5" stroke="#9E9E9E" stroke-width="1.5"/>
		<circle cx="8" cy="8" r="1.8" fill="#9E9E9E"/>
	</svg>"""
	var target_img = Image.new()
	if target_img.load_svg_from_string(target_svg, 1.0) == OK:
		_target_icon_texture = ImageTexture.create_from_image(target_img)

func _get_editor_icon(icon_name: String, fallback: Texture2D = null) -> Texture2D:
	if is_inside_tree() and has_theme_icon(icon_name, "EditorIcons"):
		return get_theme_icon(icon_name, "EditorIcons")
	return fallback

func _apply_native_theme() -> void:
	if not is_inside_tree():
		return

	if _header_label:
		if has_theme_color("font_placeholder_color", "LineEdit"):
			_header_label.add_theme_color_override("font_color", get_theme_color("font_placeholder_color", "LineEdit"))
		elif has_theme_color("font_color", "Label"):
			_header_label.add_theme_color_override("font_color", get_theme_color("font_color", "Label") * Color(1, 1, 1, 0.75))

	for slot_key in SLOT_KEYS:
		_update_slot_ui(slot_key)

	_validate_and_update_status()

func _build_ui() -> void:
	_create_button = get_ok_button()
	_create_button.text = "Create"
	_create_button.custom_minimum_size = Vector2(90, 0)
	_create_button.disabled = true
	confirmed.connect(_on_create_pressed)

	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 6)
	add_child(main_vbox)

	_header_label = Label.new()
	_header_label.text = "Drag all bones from the hierarchy into their slots.\nMake sure your character is in T-Stand."
	main_vbox.add_child(_header_label)

	var sep1 = HSeparator.new()
	main_vbox.add_child(sep1)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	var form_vbox = VBoxContainer.new()
	form_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(form_vbox)

	for slot_key in SLOT_KEYS:
		var slot_row = _create_slot_row(slot_key, SLOT_LABELS[slot_key])
		form_vbox.add_child(slot_row)

	var sep2 = HSeparator.new()
	form_vbox.add_child(sep2)

	var mass_row = HBoxContainer.new()
	mass_row.add_theme_constant_override("separation", 6)
	var mass_label = Label.new()
	mass_label.text = "Total Mass"
	mass_label.custom_minimum_size = Vector2(125, 0)
	mass_row.add_child(mass_label)

	_mass_spin = SpinBox.new()
	_mass_spin.min_value = 0.5
	_mass_spin.max_value = 1000.0
	_mass_spin.step = 0.5
	_mass_spin.value = 20.0
	_mass_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mass_row.add_child(_mass_spin)
	form_vbox.add_child(mass_row)

	var strength_row = HBoxContainer.new()
	strength_row.add_theme_constant_override("separation", 6)
	var strength_label = Label.new()
	strength_label.text = "Strength"
	strength_label.custom_minimum_size = Vector2(125, 0)
	strength_row.add_child(strength_label)

	_strength_spin = SpinBox.new()
	_strength_spin.min_value = 0.0
	_strength_spin.max_value = 100.0
	_strength_spin.step = 0.1
	_strength_spin.value = 0.0
	_strength_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strength_row.add_child(_strength_spin)
	form_vbox.add_child(strength_row)

	var flip_row = HBoxContainer.new()
	flip_row.add_theme_constant_override("separation", 6)
	var flip_label = Label.new()
	flip_label.text = "Flip Forward"
	flip_label.custom_minimum_size = Vector2(125, 0)
	flip_row.add_child(flip_label)

	_flip_forward_check = CheckBox.new()
	_flip_forward_check.button_pressed = false
	flip_row.add_child(_flip_forward_check)
	form_vbox.add_child(flip_row)

	var sep3 = HSeparator.new()
	main_vbox.add_child(sep3)

	_error_container = HBoxContainer.new()
	_error_container.custom_minimum_size = Vector2(0, 24)
	_error_container.add_theme_constant_override("separation", 6)

	_error_icon = TextureRect.new()
	_error_icon.texture = _fallback_error_texture
	_error_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_error_icon.custom_minimum_size = Vector2(16, 16)
	_error_container.add_child(_error_icon)

	_error_label = Label.new()
	_error_label.text = "Pelvis has not been assigned yet."
	_error_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_error_container.add_child(_error_label)

	main_vbox.add_child(_error_container)

	_build_picker_dialog()

class RagdollSlotButton:
	extends Button

	signal slot_dropped(slot_key: String, bone_name: String)

	var slot_key: String = ""

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if data is String and not data.is_empty():
			return true
		if data is Dictionary:
			if data.has("bone_name"):
				return true
			if data.get("type") == "nodes" and data.has("nodes"):
				return true
		return false

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if data is String:
			slot_dropped.emit(slot_key, data)
		elif data is Dictionary:
			if data.has("bone_name"):
				slot_dropped.emit(slot_key, str(data["bone_name"]))
			elif data.get("type") == "nodes" and data.has("nodes"):
				var nodes = data["nodes"]
				if nodes.size() > 0:
					var path_str = str(nodes[0])
					var b_name = path_str.get_file()
					slot_dropped.emit(slot_key, b_name)

func _create_slot_row(slot_key: String, label_text: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(125, 0)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(label)

	var slot_btn = RagdollSlotButton.new()
	slot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	slot_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	slot_btn.focus_mode = Control.FOCUS_NONE
	slot_btn.slot_key = slot_key
	slot_btn.slot_dropped.connect(_on_slot_dropped)
	slot_btn.pressed.connect(_on_slot_button_pressed.bind(slot_key))

	_slot_buttons[slot_key] = slot_btn
	_slot_values[slot_key] = ""
	row.add_child(slot_btn)

	var pick_btn = Button.new()
	pick_btn.tooltip_text = "Select bone from skeleton"
	pick_btn.focus_mode = Control.FOCUS_NONE
	pick_btn.icon = _target_icon_texture
	pick_btn.pressed.connect(_on_slot_button_pressed.bind(slot_key))
	_pick_buttons[slot_key] = pick_btn
	row.add_child(pick_btn)

	return row

func _build_picker_dialog() -> void:
	_picker_dialog = ConfirmationDialog.new()
	_picker_dialog.title = "Select Bone"
	_picker_dialog.min_size = Vector2i(320, 420)
	_picker_dialog.size = Vector2i(340, 450)
	_picker_dialog.confirmed.connect(_on_picker_confirmed)

	var p_vbox = VBoxContainer.new()
	p_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	p_vbox.add_theme_constant_override("separation", 6)
	_picker_dialog.add_child(p_vbox)

	_picker_filter = LineEdit.new()
	_picker_filter.placeholder_text = "Filter bones..."
	_picker_filter.clear_button_enabled = true
	_picker_filter.text_changed.connect(_on_picker_filter_changed)
	_picker_filter.text_submitted.connect(_on_picker_filter_submitted)
	p_vbox.add_child(_picker_filter)

	_picker_list = ItemList.new()
	_picker_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_picker_list.item_activated.connect(_on_picker_item_activated)
	p_vbox.add_child(_picker_list)

	add_child(_picker_dialog)

func _open_picker(slot_key: String) -> void:
	_current_picker_slot = slot_key
	var slot_title = SLOT_LABELS.get(slot_key, slot_key)
	_picker_dialog.title = "Select Bone for " + slot_title
	_picker_filter.text = ""
	_populate_picker_list("")
	_picker_dialog.popup_centered(Vector2i(340, 450))
	_picker_filter.grab_focus()

func _populate_picker_list(filter_text: String) -> void:
	_picker_list.clear()
	var f = filter_text.strip_edges().to_lower()
	var bone_icon = _get_editor_icon("Bone", null)
	var clear_icon = _get_editor_icon("Clear", null)

	if f.is_empty() or "none".contains(f) or "clear".contains(f):
		var idx = _picker_list.add_item("None (Clear slot)", clear_icon)
		_picker_list.set_item_metadata(idx, "")

	var current_val = _slot_values.get(_current_picker_slot, "")
	var selected_idx = -1

	for bone in _cached_bones:
		if f.is_empty() or bone.to_lower().contains(f):
			var idx = _picker_list.add_item(bone, bone_icon)
			_picker_list.set_item_metadata(idx, bone)
			if bone == current_val:
				selected_idx = idx

	if selected_idx != -1:
		_picker_list.select(selected_idx)
		_picker_list.ensure_current_is_visible()
	elif _picker_list.item_count > 0 and not f.is_empty():
		_picker_list.select(0)

func _on_picker_filter_changed(new_text: String) -> void:
	_populate_picker_list(new_text)

func _on_picker_filter_submitted(_text: String) -> void:
	var selected = _picker_list.get_selected_items()
	if selected.size() > 0:
		_on_picker_item_activated(selected[0])
	elif _picker_list.item_count > 0:
		_on_picker_item_activated(0)

func _on_picker_confirmed() -> void:
	var selected = _picker_list.get_selected_items()
	if selected.size() > 0:
		var selected_bone = str(_picker_list.get_item_metadata(selected[0]))
		_set_slot_value(_current_picker_slot, selected_bone)
	_picker_dialog.hide()

func _on_picker_item_activated(index: int) -> void:
	var selected_bone = str(_picker_list.get_item_metadata(index))
	_set_slot_value(_current_picker_slot, selected_bone)
	_picker_dialog.hide()

func _on_slot_button_pressed(slot_key: String) -> void:
	_open_picker(slot_key)

func _on_slot_dropped(slot_key: String, bone_name: String) -> void:
	if _skeleton:
		var found_idx = _skeleton.find_bone(bone_name)
		if found_idx != -1:
			_set_slot_value(slot_key, _skeleton.get_bone_name(found_idx))
			return
		for b in _cached_bones:
			if b.to_lower() == bone_name.to_lower():
				_set_slot_value(slot_key, b)
				return
	_set_slot_value(slot_key, bone_name)

func setup_with_skeleton(skeleton: Skeleton3D) -> void:
	_skeleton = skeleton
	_cached_bones.clear()

	if _skeleton:
		for i in range(_skeleton.get_bone_count()):
			_cached_bones.append(_skeleton.get_bone_name(i))

	for k in SLOT_KEYS:
		_slot_values[k] = ""
		_update_slot_ui(k)

	if _skeleton:
		auto_assign_bones()

	_apply_native_theme()
	_validate_and_update_status()

func auto_assign_bones() -> void:
	if not _skeleton:
		return

	var matches: Dictionary = _match_common_bones(_cached_bones)
	for slot_key in matches:
		if slot_key in _slot_values:
			_set_slot_value(slot_key, matches[slot_key])

func _set_slot_value(slot_key: String, bone_name: String) -> void:
	_slot_values[slot_key] = bone_name
	_update_slot_ui(slot_key)
	_validate_and_update_status()

func _update_slot_ui(slot_key: String) -> void:
	var btn = _slot_buttons.get(slot_key)
	if not btn:
		return

	var val = _slot_values.get(slot_key, "")
	if val.is_empty():
		btn.text = "None (Transform)"
		btn.icon = null
		if is_inside_tree() and has_theme_color("font_placeholder_color", "LineEdit"):
			btn.add_theme_color_override("font_color", get_theme_color("font_placeholder_color", "LineEdit"))
		elif is_inside_tree() and has_theme_color("font_disabled_color", "Button"):
			btn.add_theme_color_override("font_color", get_theme_color("font_disabled_color", "Button"))
	else:
		btn.text = val
		btn.icon = _get_editor_icon("Bone", null)
		btn.remove_theme_color_override("font_color")

func _match_common_bones(bone_names: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	var candidates: Dictionary = {}

	for key in SLOT_KEYS:
		candidates[key] = []

	for bone in bone_names:
		var slot_match = _classify_bone_to_slot(bone)
		if not slot_match.is_empty():
			var score = _score_bone_match(bone, slot_match)
			candidates[slot_match].append({"bone": bone, "score": score})

	for key in SLOT_KEYS:
		var c_list: Array = candidates[key]
		if c_list.size() > 0:
			c_list.sort_custom(func(a, b): return a["score"] > b["score"])
			result[key] = c_list[0]["bone"]

	return result

func _classify_bone_to_slot(bone_name: String) -> String:
	var lower = _strip_prefix(bone_name).to_lower()

	var side = ""
	var stripped = lower

	if "left" in lower:
		side = "left"
		stripped = lower.replace("left", "")
	elif "right" in lower:
		side = "right"
		stripped = lower.replace("right", "")
	elif lower.begins_with("l_") or lower.begins_with("l.") or lower.begins_with("l ") or lower.begins_with("l-"):
		side = "left"
		stripped = lower.substr(2)
	elif lower.begins_with("r_") or lower.begins_with("r.") or lower.begins_with("r ") or lower.begins_with("r-"):
		side = "right"
		stripped = lower.substr(2)
	elif lower.ends_with("_l") or lower.ends_with(".l") or lower.ends_with(" l") or lower.ends_with("-l"):
		side = "left"
		stripped = lower.substr(0, lower.length() - 2)
	elif lower.ends_with("_r") or lower.ends_with(".r") or lower.ends_with(" r") or lower.ends_with("-r"):
		side = "right"
		stripped = lower.substr(0, lower.length() - 2)

	var clean = stripped.replace("_", "").replace(".", "").replace(" ", "").replace("-", "").replace(":", "")

	if side.is_empty():
		if clean in ["hips", "hip", "pelvis", "root"]:
			return "pelvis"
		if clean in ["spine1", "spine01", "spine", "spine0", "chest", "spine2", "spine02", "abdomen", "torso"]:
			return "middle_spine"
		if clean in ["head", "skull", "cranium"]:
			return "head"
		return ""

	var prefix = "left_" if side == "left" else "right_"

	if clean in ["upperleg", "upleg", "thigh", "femur"]:
		return prefix + "hips"
	if clean in ["lowerleg", "leg", "knee", "calf", "shin", "tibia"]:
		return prefix + "knee"
	if clean in ["foot", "ankle", "heel"]:
		return prefix + "foot"

	if clean in ["forearm", "lowerarm", "elbow", "radius", "ulna"]:
		return prefix + "elbow"
	if clean in ["hand", "wrist", "palm"]:
		return prefix + "hand"
	if clean in ["upperarm", "uparm", "arm", "bicep", "humerus"]:
		return prefix + "arm"

	return ""

func _strip_prefix(bone_name: String) -> String:
	return strip_bone_prefix(bone_name)

static func strip_bone_prefix(bone_name: String) -> String:
	if bone_name.is_empty():
		return ""

	var s: String = bone_name

	# 1. Strip namespace/hierarchy paths (e.g. "Namespace:Bone", "Rig|Bone", "Path/Bone")
	for sep in [":", "|", "/"]:
		var last_idx: int = s.rfind(sep)
		if last_idx != -1 and last_idx < s.length() - 1:
			s = s.substr(last_idx + 1)

	# 2. Check for known rig patterns via RegEx:
	# Mixamo rigs with any number: mixamorig, mixamorig0-99, mixamo, mixamo0-99 with optional separator
	var mixamo_regex = RegEx.create_from_string("^(?i)mixamo(?:rig)?\\d*[_.:\\s-]*")
	if mixamo_regex:
		var m = mixamo_regex.search(s)
		if m and m.get_end() > 0 and m.get_end() < s.length():
			return s.substr(m.get_end())

	# Biped rigs: bip01_, bip001_, valvebiped.bip01_, biped_
	var biped_regex = RegEx.create_from_string("^(?i)(?:valvebiped\\.)?(?:bip|biped)\\d*[_.:\\s-]*")
	if biped_regex:
		var m = biped_regex.search(s)
		if m and m.get_end() > 0 and m.get_end() < s.length():
			return s.substr(m.get_end())

	# Rigify / CC / VRM / MetaRig / Generic technical prefixes
	var tech_regex = RegEx.create_from_string("^(?i)(?:cc_base|def|deform|mch|org|vrm|metarig|rig\\d*|j|jnt|bone|character\\d*|char\\d*|actor\\d*|player\\d*|bot\\d*|npc\\d*|model\\d*)[_.:\\s-]+")
	if tech_regex:
		var m = tech_regex.search(s)
		if m and m.get_end() > 0 and m.get_end() < s.length():
			return s.substr(m.get_end())

	# 3. Known static prefixes fallback list
	var lower_s = s.to_lower()
	for p in KNOWN_PREFIXES:
		if lower_s.begins_with(p):
			s = s.substr(p.length())
			lower_s = s.to_lower()
			break

	# 4. Generalized prefix stripper ("the front of the name should not matter")
	# If the bone has delimiters (_ or -), scan segments from left to right.
	# Any segment before a recognized bone or side keyword is stripped.
	for delim in ["_", "-"]:
		if delim in s:
			var parts = s.split(delim)
			if parts.size() > 1:
				for i in range(parts.size()):
					var seg = parts[i].to_lower()
					if _is_bone_keyword(seg):
						if i > 0:
							var remaining: PackedStringArray = []
							for j in range(i, parts.size()):
								remaining.append(parts[j])
							return delim.join(remaining)
						break

	return s

static func _is_bone_keyword(seg: String) -> bool:
	if seg.is_empty():
		return false
	if seg == "l" or seg == "r":
		return true
	if seg.begins_with("left") or seg.begins_with("right"):
		return true
	if seg.begins_with("upper") or seg.begins_with("up") or seg.begins_with("lower") or seg.begins_with("low") or seg.begins_with("mid") or seg.begins_with("middle"):
		return true
	if seg.begins_with("hip") or seg.begins_with("pelvis") or seg.begins_with("root"):
		return true
	if seg.begins_with("spine") or seg.begins_with("chest") or seg.begins_with("torso") or seg.begins_with("abdomen"):
		return true
	if seg.begins_with("neck") or seg.begins_with("head") or seg.begins_with("skull") or seg.begins_with("cranium"):
		return true
	if seg.begins_with("shoulder") or seg.begins_with("clavicle"):
		return true
	if seg.begins_with("arm") or seg.begins_with("forearm") or seg.begins_with("elbow") or seg.begins_with("hand") or seg.begins_with("wrist") or seg.begins_with("palm"):
		return true
	if seg.begins_with("leg") or seg.begins_with("thigh") or seg.begins_with("calf") or seg.begins_with("shin") or seg.begins_with("knee") or seg.begins_with("foot") or seg.begins_with("ankle") or seg.begins_with("heel") or seg.begins_with("toe"):
		return true
	if seg.begins_with("femur") or seg.begins_with("tibia") or seg.begins_with("radius") or seg.begins_with("ulna") or seg.begins_with("humerus"):
		return true
	return false

func _score_bone_match(bone_name: String, slot_key: String) -> int:
	var lower = _strip_prefix(bone_name).to_lower()
	var score = 10

	if slot_key == "middle_spine":
		if "spine1" in lower or "spine_01" in lower or "spine01" in lower:
			score += 50
		elif "spine" in lower and not "spine2" in lower and not "spine3" in lower:
			score += 40
		elif "chest" in lower:
			score += 30

	if slot_key.ends_with("_hips"):
		if "thigh" in lower or "upleg" in lower or "upperleg" in lower:
			score += 30

	if slot_key.ends_with("_knee"):
		if "knee" in lower or "calf" in lower or "lowerleg" in lower:
			score += 30

	if slot_key == "pelvis":
		if "pelvis" in lower or "hips" in lower:
			score += 30

	if slot_key.ends_with("_elbow"):
		if "forearm" in lower or "elbow" in lower:
			score += 30

	if slot_key.ends_with("_hand"):
		if "hand" in lower and not ("thumb" in lower or "finger" in lower or "index" in lower or "mid" in lower or "ring" in lower or "pinky" in lower):
			score += 40

	if slot_key.ends_with("_arm"):
		if "upperarm" in lower:
			score += 30

	return score

func _validate_and_update_status() -> void:
	if not _error_icon or not _error_label:
		return

	var err_color = Color(1.0, 0.4, 0.4)
	var succ_color = Color(0.4, 0.85, 0.4)
	if is_inside_tree() and has_theme_color("error_color", "Editor"):
		err_color = get_theme_color("error_color", "Editor")
	if is_inside_tree() and has_theme_color("success_color", "Editor"):
		succ_color = get_theme_color("success_color", "Editor")

	for req in REQUIRED_SLOTS:
		var val = _slot_values.get(req, "")
		if val.is_empty():
			var slot_name = SLOT_LABELS.get(req, req)
			_error_icon.texture = _get_editor_icon("StatusError", _fallback_error_texture)
			_error_label.text = "%s has not been assigned yet." % slot_name
			_error_label.add_theme_color_override("font_color", err_color)
			_create_button.disabled = true
			return

	_error_icon.texture = _get_editor_icon("StatusSuccess", _fallback_valid_texture)
	_error_label.text = "All required bones assigned. Ready to create ragdoll."
	_error_label.add_theme_color_override("font_color", succ_color)
	_create_button.disabled = false

func _on_create_pressed() -> void:
	var config: Dictionary = {
		"skeleton": _skeleton,
		"slots": _slot_values.duplicate(),
		"total_mass": _mass_spin.value if _mass_spin else 20.0,
		"strength": _strength_spin.value if _strength_spin else 0.0,
		"flip_forward": _flip_forward_check.button_pressed if _flip_forward_check else false,
	}
	ragdoll_create_requested.emit(config)
	hide()

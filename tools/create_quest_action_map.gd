extends SceneTree

const OUTPUT := "res://openxr_action_map.tres"
const HANDS := ["/user/hand/left", "/user/hand/right"]

func _initialize() -> void:
	var action_map := OpenXRActionMap.new()
	var action_set := OpenXRActionSet.new()
	action_set.resource_name = "vectorverse"
	action_set.localized_name = "Synomize Smoke Test"

	var aim_pose := _action("aim_pose", "Aim pose", OpenXRAction.OPENXR_ACTION_POSE)
	var grip_pose := _action("grip_pose", "Grip pose", OpenXRAction.OPENXR_ACTION_POSE)
	var select := _action("select", "Select with trigger", OpenXRAction.OPENXR_ACTION_BOOL)
	var grab := _action("grab", "Grab with side grip", OpenXRAction.OPENXR_ACTION_BOOL)
	for action in [aim_pose, grip_pose, select, grab]:
		action_set.add_action(action)
	action_map.add_action_set(action_set)

	var touch := OpenXRInteractionProfile.new()
	touch.resource_name = "oculus_touch_controller"
	touch.interaction_profile_path = "/interaction_profiles/oculus/touch_controller"
	touch.bindings = [
		_binding(aim_pose, "/user/hand/left/input/aim/pose"),
		_binding(aim_pose, "/user/hand/right/input/aim/pose"),
		_binding(grip_pose, "/user/hand/left/input/grip/pose"),
		_binding(grip_pose, "/user/hand/right/input/grip/pose"),
		_binding(select, "/user/hand/left/input/trigger/value"),
		_binding(select, "/user/hand/right/input/trigger/value"),
		_binding(grab, "/user/hand/left/input/squeeze/value"),
		_binding(grab, "/user/hand/right/input/squeeze/value")
	]
	action_map.add_interaction_profile(touch)

	var error := ResourceSaver.save(action_map, OUTPUT)
	if error == OK:
		print("VECTORVERSE_QUEST_ACTION_MAP_CREATED")
		quit(0)
	else:
		push_error("Could not save Quest action map: %s" % error_string(error))
		quit(1)

func _action(action_name: String, localized_name: String, action_type: OpenXRAction.ActionType) -> OpenXRAction:
	var action := OpenXRAction.new()
	action.resource_name = action_name
	action.localized_name = localized_name
	action.action_type = action_type
	action.toplevel_paths = PackedStringArray(HANDS)
	return action

func _binding(action: OpenXRAction, path: String) -> OpenXRIPBinding:
	var binding := OpenXRIPBinding.new()
	binding.action = action
	binding.binding_path = path
	return binding

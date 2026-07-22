extends Node

const MESSAGE := {{MESSAGE_LITERAL}}

func execute() -> String:
	print(MESSAGE)
	return MESSAGE

func _ready() -> void:
	execute()


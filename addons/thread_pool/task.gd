class_name Task

var target_instance: Object
var target_method: String
var target_argument
var result
var tag
var __no_argument: bool
var __array_argument: bool

func _init(instance: Object, method: String, parameter, task_tag, no_argument: bool, array_argument: bool):
	target_instance = instance
	target_method = method
	target_argument = parameter
	result = null
	tag = task_tag
	__no_argument = no_argument
	__array_argument = array_argument


func __execute_task():
	if __no_argument:
		result = target_instance.call(target_method)
	elif __array_argument:
		result = target_instance.callv(target_method, target_argument)
	else:
		result = target_instance.call(target_method, target_argument)

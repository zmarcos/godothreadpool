class_name Future

var target_instance: Object
var target_method: String
var target_argument
var result
var tag
var cancelled: bool # true if was requested for this future to avoid being executed
var completed: bool # true if this future executed completely
var finished: bool # true if this future is considered finished and no further processing will take place
var __no_argument: bool
var __array_argument: bool
var __lock: Mutex
var __wait: Semaphore
var __pool

func _init(instance: Object, method: String, parameter, task_tag, no_argument: bool, array_argument: bool, pool):
	target_instance = instance
	target_method = method
	target_argument = parameter
	result = null
	tag = task_tag
	__no_argument = no_argument
	__array_argument = array_argument
	cancelled = false
	completed = false
	finished = false
	__lock = Mutex.new()
	__wait = Semaphore.new()
	__pool = pool


func cancel() -> void:
	cancelled = true


func wait_for_result() -> void:
	if not finished:
		__verify_task_execution()


func get_result():
	wait_for_result()
	return result


func __execute_task() -> void:
	if __no_argument:
		result = target_instance.call(target_method)
	elif __array_argument:
		result = target_instance.callv(target_method, target_argument)
	else:
		result = target_instance.call(target_method, target_argument)
	__wait.post()


func __verify_task_execution() -> void:
	__lock.lock()
	if not finished:
		var task = null
		if __pool != null:
			task = __pool.__drain_this_task(self)
		if task != null:
			__pool.__execute_this_task(task)
		else:
			__wait.wait()
	__lock.unlock()


func __finish():
	finished = true
	__pool = null

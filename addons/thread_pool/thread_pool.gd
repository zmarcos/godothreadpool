extends Node
class_name ThreadPool

onready var pool = __create_pool()
var tasks = []
var started = false
var finished = false
var tasks_lock = Mutex.new()
var tasks_wait = Semaphore.new()
var __finished_tasks = []
var __finished_tasks_lock = Mutex.new()
export var discard_finished_tasks: bool = false
signal task_finished(task_tag)
signal task_discarded(task)

class Task:
	var target_instance: Object
	var target_method: String
	var target_argument
	var result
	var tag
	var __no_param: bool
	var __array_param: bool

	func _init(instance: Object, method: String, parameter, task_tag, no_param, array_param):
		target_instance = instance
		target_method = method
		target_argument = parameter
		result = null
		tag = task_tag
		__no_param = no_param
		__array_param = array_param

	func __execute_task():
		if __no_param:
			result = target_instance.call(target_method)
		elif __array_param:
			result = target_instance.callv(target_method, target_argument)
		else:
			result = target_instance.call(target_method, target_argument)

func __enqueue_task(instance: Object, method: String, parameter = null, task_tag = null, no_param = false, array_param = false) -> void:
	tasks_lock.lock()
	tasks.push_front(Task.new(instance, method, parameter, task_tag, no_param, array_param))
	tasks_wait.post()
	__start()
	tasks_lock.unlock()


func submit_task(instance: Object, method: String, parameter, task_tag = null) -> void:
	__enqueue_task(instance, method, parameter, task_tag, false, false)


func submit_task_unparameterized(instance: Object, method: String, task_tag = null) -> void:
	__enqueue_task(instance, method, null, task_tag, true, false)


func submit_task_array_parameterized(instance: Object, method: String, parameter: Array, task_tag = null) -> void:
	__enqueue_task(instance, method, parameter, task_tag, false, true)


func shutdown():
	finished = true
	for i in pool:
		tasks_wait.post()


func queue_free() -> void:
	shutdown()
	.queue_free()


func _notification(what: int):
	if what == NOTIFICATION_PREDELETE:
		__wait_for_shutdown()


func __wait_for_shutdown():
	shutdown()
	for t in pool:
		if t.is_active():
			t.wait_to_finish()


func __create_pool():
	var result = []
	for c in range(OS.get_processor_count()):
		result.append(Thread.new())
	return result


func __start() -> void:
	if not started:
		for t in pool:
			(t as Thread).start(self, "__execute_tasks", t)
		started = true


func __drain_task() -> Task:
	tasks_lock.lock()
	var result
	if tasks.empty():
		result = Task.new(self, "do_nothing", null, null, true, false)# normally, this is not expected, but better safe than sorry
	else:
		result = tasks.pop_back()
	tasks_lock.unlock()
	return result;


func __execute_tasks(arg_thread) -> void:
	#print_debug(arg_thread)
	while not finished:
		tasks_wait.wait()
		var task = __drain_task() as Task
		task.__execute_task()
		if discard_finished_tasks:
			call_deferred("emit_signal", "task_discarded", task)
		else:
			__finished_tasks_lock.lock()
			__finished_tasks.append(task)
			__finished_tasks_lock.unlock()
			call_deferred("emit_signal", "task_finished", task.tag)


func do_nothing(arg) -> void:
	#print("doing nothing")
	OS.delay_msec(1) # if there is nothing to do, go sleep


func fetch_finished_tasks() -> Array:
	__finished_tasks_lock.lock()
	var result = __finished_tasks
	__finished_tasks = []
	__finished_tasks_lock.unlock()
	return result


func fetch_finished_tasks_by_tag(tag) -> Array:
	__finished_tasks_lock.lock()
	var result = []
	var new_finished_tasks = []
	for t in __finished_tasks.size():
		var task = __finished_tasks[t]
		match task.tag:
			tag:
				result.append(task)
			_:
				new_finished_tasks.append(task)
	__finished_tasks = new_finished_tasks
	__finished_tasks_lock.unlock()
	return result


func print_thread_pool_info(arg=null) -> void:
	#var task = Task.new(self, "do_nothing")
	#task.execute_task()
	print(pool)


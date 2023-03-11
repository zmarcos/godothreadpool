@icon("thread.png")
class_name FakeThreadPool
extends Node
## A fake thread pool.
##
## For environments that do NOT support multithreading.[br]
## [br][b]WARNING[/b]: We can NOT guarantee that it is 100% compatible with your code, you should test your game thoroughly.

## See [signal ThreadPool.task_finished].
signal task_finished(task_tag)
## See [signal ThreadPool.task_discarded].
signal task_discarded(task)

## See [member ThreadPool.discard_finished_tasks].
@export var discard_finished_tasks: bool = true
## Time in milliseconds the thread pool will spare for execution of tasks.[br]
## [br][b]WARNING[/b]: If a single task you submitted takes more than this to execute, it will only execute that task, but it will wait until it is completely done.
@export var msec_exec_time: int = 11

var __tasks: Array = []
var __finished: bool = false
var __finished_tasks: Array = []
var __last_fetch: int = 0
var __last_frame: int = 0

func _notification(what: int):
	if what == NOTIFICATION_PREDELETE:
		shutdown()


## See [method Node.queue_free].
func queue_free() -> void:
	shutdown()
	super.queue_free()


## See [method ThreadPool.submit_task].
func submit_task(instance: Object, method: String, parameter, task_tag = null) -> void:
	__enqueue_task(instance, method, parameter, task_tag, false, false)


## See [method ThreadPool.submit_task_unparameterized].
func submit_task_unparameterized(instance: Object, method: String, task_tag = null) -> void:
	__enqueue_task(instance, method, null, task_tag, true, false)


## See [method ThreadPool.submit_task_array_parameterized].
func submit_task_array_parameterized(instance: Object, method: String, parameter: Array, task_tag = null) -> void:
	__enqueue_task(instance, method, parameter, task_tag, false, true)


## See [method ThreadPool.shutdown].
func shutdown():
	__finished = true
	__tasks.clear()


## See [method ThreadPool.fetch_finished_tasks].
func fetch_finished_tasks() -> Array:
	__avoid_fake_deadlock_on_fetch()
	var result = __finished_tasks
	__finished_tasks = []
	return result


## See [method ThreadPool.fetch_finished_tasks_by_tag].
func fetch_finished_tasks_by_tag(tag) -> Array:
	__avoid_fake_deadlock_on_fetch()
	var result = []
	var new_finished_tasks = []
	for t in __finished_tasks.size():
		var task = __finished_tasks[t]
		if task.tag == tag:
			result.append(task)
		else:
			new_finished_tasks.append(task)
	__finished_tasks = new_finished_tasks
	return result


## When doing nothing is necessary.[br]
## [br]This time, it actually does nothing.
func do_nothing(arg) -> void:
	#print("doing nothing")
	pass


func _process(delta):
	__execute_tasks()


func __avoid_fake_deadlock_on_fetch():
	if (Time.get_ticks_msec() - __last_fetch) < 2:
		__execute_tasks(true)
	__last_fetch = Time.get_ticks_msec()


func __enqueue_task(instance: Object, method: String, parameter = null, task_tag = null, no_argument = false, array_argument = false) -> void:
	if __finished:
		return
	__tasks.push_front(Task.new(instance, method, parameter, task_tag, no_argument, array_argument))


func __drain_task() -> Task:
	var result = null
	if not __tasks.is_empty():
		result = __tasks.pop_back()
	return result;


func __execute_tasks(force_execution = false) -> void:
	if (__last_frame == get_tree().get_frame()) and not force_execution:
		return
	__last_frame = get_tree().get_frame()
	var exec_time = Time.get_ticks_msec()
	while not __finished:
		var task: Task = __drain_task()
		if task == null:
			return
		task.__execute_task()
		if discard_finished_tasks:
			emit_signal("task_discarded", task)
		else:
			__finished_tasks.append(task)
			emit_signal("task_finished", task.tag)
		if (Time.get_ticks_msec() - exec_time) > msec_exec_time:
			return


## Provides information for the task that was performed.
##
## See [ThreadPool.Task].
class Task extends ThreadPool.Task:
	func _init(instance: Object, method: String, parameter, task_tag, no_argument: bool, array_argument: bool):
		self.instance = instance
		self.method = method
		self.parameter = parameter
		self.task_tag = task_tag
		self.no_argument = no_argument
		self.array_argument = array_argument


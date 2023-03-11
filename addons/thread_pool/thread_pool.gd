@icon("thread.png")
class_name ThreadPool
extends Node
## A thread pool designed to perform your tasks efficiently.
##
## A GDScript Thread Pool suited for use with signaling and processing performed by Godot nodes.

## When a task finishes and property [member discard_finished_tasks] is [code]false[/code].[br]
## [br]Argument [param task_tag] is the task tag that was defined when [method submit_task] or [method submit_task_unparameterized] or [method submit_task_array_parameterized] was called.
signal task_finished(task_tag)

## When a task finishes and property [member discard_finished_tasks] is [code]true[/code].[br]
## [br]Argument [param task] is the finished task and can be casted to class [ThreadPool.Task].
signal task_discarded(task)

## This property controls whether the thread pool should discard or store the results of finished tasks.
@export var discard_finished_tasks: bool = true

var __tasks: Array = []
var __started = false
var __finished = false
var __tasks_lock: Mutex = Mutex.new()
var __tasks_wait: Semaphore = Semaphore.new()
var __finished_tasks: Array = []
var __finished_tasks_lock: Mutex = Mutex.new()

@onready var __pool = __create_pool()

func _notification(what: int):
	if what == NOTIFICATION_PREDELETE:
		__wait_for_shutdown()


## See [method Node.queue_free].
func queue_free() -> void:
	shutdown()
	super.queue_free()


## This function submits a task for execution.[br]
## [br]Argument [param instance] is the object where task will execute, [param method] is the function to call on the task, [param parameter] is the argument passed to the function being called, and [param task_tag] can be used to help identify this task later.
## [br][br]This is equivalent to calling [code]instance.call(method, parameter)[/code], see [method Object.call].
func submit_task(instance: Object, method: String, parameter, task_tag = null) -> void:
	__enqueue_task(instance, method, parameter, task_tag, false, false)


## This function also submits a task for execution, useful for tasks without parameters.[br]
## [br]This is equivalent to calling [code]instance.call(method)[/code], see [method Object.call].
func submit_task_unparameterized(instance: Object, method: String, task_tag = null) -> void:
	__enqueue_task(instance, method, null, task_tag, true, false)


## Yet another function to submit a task for execution, useful for tasks with many parameters.[br]
## [br]This is equivalent to calling [code]instance.callv(method, parameter)[/code], see [method Object.callv].
func submit_task_array_parameterized(instance: Object, method: String, parameter: Array, task_tag = null) -> void:
	__enqueue_task(instance, method, parameter, task_tag, false, true)


## Cancels the execution of pending tasks.[br]
## [br]After calling shutdown(), the thread pool will:
## [br]- continue the tasks that were already running
## [br]- discard pending tasks
## [br]- ignore new tasks submission
## [br][br][b]NOTE:[/b] When the player asks to leave the game, this function is called automatically.
func shutdown():
	__finished = true
	for i in __pool:
		__tasks_wait.post()
	__tasks_lock.lock()
	__tasks.clear()
	__tasks_lock.unlock()


## If [member discard_finished_tasks] is false, this function will fetch all finished tasks until this point in time.[br]
## [br]After a task is fetched, the thread pool will NOT reference it anymore, and users are considered the owners of it now.
## [br]Example of use:
##[codeblock]
##var tasks = $ThreadPool.fetch_finished_tasks()
##if tasks.size() > 0:
##  prints("task result", (tasks[0] as ThreadPool.Task).result)
##  prints("task tag", (tasks[0] as ThreadPool.Task).tag)
##[/codeblock]
func fetch_finished_tasks() -> Array:
	__finished_tasks_lock.lock()
	var result = __finished_tasks
	__finished_tasks = []
	__finished_tasks_lock.unlock()
	return result


## If [member discard_finished_tasks] is false, this function will fetch all finished tasks that match tag parameter until this point in time.[br]
## [br]For every task being fetched, the thread pool will NOT reference it anymore, and users are considered the owners of it now.
## [br]Example of use:
##[codeblock]
##var tag = "AI stuff"
##$ThreadPool.submit_task(my_game_object, "my_game_logic", my_game_data, tag)
##var tasks = $ThreadPool.fetch_finished_tasks_by_tag(tag)
##[/codeblock]
func fetch_finished_tasks_by_tag(tag) -> Array:
	__finished_tasks_lock.lock()
	var result = []
	var new_finished_tasks = []
	for t in __finished_tasks.size():
		var task = __finished_tasks[t]
		if task.tag == tag:
			result.append(task)
		else:
			new_finished_tasks.append(task)
	__finished_tasks = new_finished_tasks
	__finished_tasks_lock.unlock()
	return result


## When doing nothing is necessary.[br]
## [br]This method actually does something, it tells the operational system to do nothing for 1 millisecond.
func do_nothing(arg) -> void:
	#print("doing nothing")
	OS.delay_msec(1) # if there is nothing to do, go sleep


func __enqueue_task(instance: Object, method: String, parameter = null, task_tag = null, no_argument = false, array_argument = false) -> void:
	if __finished:
		return
	__tasks_lock.lock()
	__tasks.push_front(Task.new(instance, method, parameter, task_tag, no_argument, array_argument))
	__tasks_wait.post()
	__start()
	__tasks_lock.unlock()


func __wait_for_shutdown():
	shutdown()
	for t in __pool:
		if t.is_alive():
			t.wait_to_finish()


func __create_pool():
	var result = []
	for c in range(OS.get_processor_count()):
		result.append(Thread.new())
	return result


func __start() -> void:
	if not __started:
		for t in __pool:
			(t as Thread).start(__execute_tasks.bind(t))
		__started = true


func __drain_task() -> Task:
	__tasks_lock.lock()
	var result
	if __tasks.is_empty():
		result = Task.new(self, "do_nothing", null, null, true, false)# normally, this is not expected, but better safe than sorry
		result.tag = result
	else:
		result = __tasks.pop_back()
	__tasks_lock.unlock()
	return result;


func __execute_tasks(arg_thread) -> void:
	#print_debug(arg_thread)
	while not __finished:
		__tasks_wait.wait()
		if __finished:
			return
		var task: Task = __drain_task()
		task.__execute_task()
		if not (task.tag is Task):# tasks tagged this way are considered hidden
			if discard_finished_tasks:
				call_deferred("emit_signal", "task_discarded", task)
			else:
				__finished_tasks_lock.lock()
				__finished_tasks.append(task)
				__finished_tasks_lock.unlock()
				call_deferred("emit_signal", "task_finished", task.tag)


## Provides information for the task that was performed.
##
## [b]WARNING[/b]: All properties listed here should be considered read-only.
class Task:
	## As defined in argument [param instance] when function [method ThreadPool.submit_task] or [method ThreadPool.submit_task_unparameterized] or [method ThreadPool.submit_task_array_parameterized] was called.
	var target_instance: Object
	## As defined in argument [param method] when function [method ThreadPool.submit_task] or [method ThreadPool.submit_task_unparameterized] or [method ThreadPool.submit_task_array_parameterized] was called.
	var target_method: String
	## As defined in argument [param parameter] when function [method ThreadPool.submit_task] or [method ThreadPool.submit_task_array_parameterized] was called.
	var target_argument
	## Result from the execution of this task.
	var result
	## As defined in parameter [param task_tag] when function [method ThreadPool.submit_task] or [method ThreadPool.submit_task_unparameterized] or [method ThreadPool.submit_task_array_parameterized] was called.
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

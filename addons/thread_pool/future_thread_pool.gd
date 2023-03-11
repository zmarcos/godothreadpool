@icon("thread.png")
class_name FutureThreadPool
extends Node
## A thread pool designed to perform your tasks efficiently with support for Futures.

## When a Future completes its task and the result is ready for access.[br]
## [br]Argument [param task] is the Future and can be casted to class [FutureThreadPool.Future].
signal task_completed(task)

##This property controls whether the thread pool should emit signals.
@export var use_signals: bool = false

var __tasks: Array = []
var __started = false
var __finished = false
var __tasks_lock: Mutex = Mutex.new()
var __tasks_wait: Semaphore = Semaphore.new()

@onready var __pool = __create_pool()

func _notification(what: int):
	if what == NOTIFICATION_PREDELETE:
		__wait_for_shutdown()


## See [method Node.queue_free].
func queue_free() -> void:
	shutdown()
	super.queue_free()


## See [method ThreadPool.submit_task].
func submit_task(instance: Object, method: String, parameter, task_tag = null) -> Future:
	return __enqueue_task(instance, method, parameter, task_tag, false, false)


## See [method ThreadPool.submit_task_unparameterized].
func submit_task_unparameterized(instance: Object, method: String, task_tag = null) -> Future:
	return __enqueue_task(instance, method, null, task_tag, true, false)


## See [method ThreadPool.submit_task_array_parameterized].
func submit_task_array_parameterized(instance: Object, method: String, parameter: Array, task_tag = null) -> Future:
	return __enqueue_task(instance, method, parameter, task_tag, false, true)


## See [method ThreadPool.shutdown].
func shutdown():
	__finished = true
	__tasks_lock.lock()
	if not __tasks.is_empty():
		var size = __tasks.size()
		for i in size:
			(__tasks[i] as Future).__finish()
		__tasks.clear()
	for i in __pool:
		__tasks_wait.post()
	__tasks_lock.unlock()


## See [method ThreadPool.do_nothing].
func do_nothing(arg) -> void:
	#print("doing nothing")
	OS.delay_msec(1) # if there is nothing to do, go sleep


func __enqueue_task(instance: Object, method: String, parameter = null, task_tag = null, no_argument = false, array_argument = false) -> Future:
	var result = Future.new(instance, method, parameter, task_tag, no_argument, array_argument, self) 
	if __finished:
		result.__finish()
		return result
	__tasks_lock.lock()
	__tasks.push_front(result)
	__tasks_wait.post()
	__start()
	__tasks_lock.unlock()
	return result


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

func __drain_this_task(task: Future) -> Future:
	__tasks_lock.lock()
	if __tasks.is_empty():
		__tasks_lock.unlock()
		return null
	var result = null
	var size = __tasks.size()
	for i in size:
		var candidate_task: Future = __tasks[i]
		if task == candidate_task:
			__tasks.erase(i)
			result = candidate_task
			break
	__tasks_lock.unlock()
	return result;


func __drain_task() -> Future:
	__tasks_lock.lock()
	var result
	if __tasks.is_empty():
		result = Future.new(self, "do_nothing", null, null, true, false, self)# normally, this is not expected, but better safe than sorry
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
		var task: Future = __drain_task()
		__execute_this_task(task)


func __execute_this_task(task: Future) -> void:
	if task.cancelled:
		task.__finish()
		return
	task.__execute_task()
	task.completed = true
	task.__finish()
	if use_signals:
		if not (task.tag is Future):# tasks tagged this way are considered hidden
			call_deferred("emit_signal", "task_completed", task)


## An object that acts as a proxy for a result that is initially unknown, but will be known in the future.
##
## [b]WARNING[/b]: All properties listed here should be considered read-only.
class Future:
	## As defined in argument [param instance] when function [method FutureThreadPool.submit_task] or [method FutureThreadPool.submit_task_unparameterized] or [method FutureThreadPool.submit_task_array_parameterized] was called.
	var target_instance: Object
	## As defined in argument [param method] when function [method FutureThreadPool.submit_task] or [method FutureThreadPool.submit_task_unparameterized] or [method FutureThreadPool.submit_task_array_parameterized] was called.
	var target_method: String
	## As defined in argument [param parameter] when function [method FutureThreadPool.submit_task] or [method FutureThreadPool.submit_task_array_parameterized] was called.
	var target_argument
	## Result from the execution of this task.
	var result
	## As defined in parameter [param tag] when function [method FutureThreadPool.submit_task] or [method FutureThreadPool.submit_task_unparameterized] or [method FutureThreadPool.submit_task_array_parameterized] was called.
	var tag
	## Property will be [code]true[/code] if this future received a request to cancel execution.
	var cancelled: bool
	## Property will be [code]true[/code] if this future executed completely.
	var completed: bool
	## Property will be [code]true[/code] if this future is considered finished and no further processing will take place.
	var finished: bool
	var __no_argument: bool
	var __array_argument: bool
	var __lock: Mutex
	var __wait: Semaphore
	var __pool: FutureThreadPool

	func _init(instance: Object, method: String, parameter, task_tag, no_argument: bool, array_argument: bool, pool: FutureThreadPool):
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


	## This function will request the task cancellation.[br]
	## [br]If the task is already running in another thread, cancellation will not occur.
	func cancel() -> void:
		cancelled = true


	## Waits for the execution or cancellation of the task.
	func wait_for_result() -> void:
		if not finished:
			__verify_task_execution()


	## Waits for the execution or cancellation of the task, and returns the property [member result].
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
			var task: Future = null
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

class_name FutureThreadPool
extends Node
# A thread pool designed to perform your tasks efficiently

signal task_completed(task)

export var use_signals: bool = false

var __tasks: Array = []
var __started = false
var __finished = false
var __tasks_lock: Mutex = Mutex.new()
var __tasks_wait: Semaphore = Semaphore.new()

onready var __pool = __create_pool()

func _notification(what: int):
	if what == NOTIFICATION_PREDELETE:
		__wait_for_shutdown()


func queue_free() -> void:
	shutdown()
	.queue_free()


func submit_task(instance: Object, method: String, parameter, task_tag = null) -> Future:
	return __enqueue_task(instance, method, parameter, task_tag, false, false)


func submit_task_unparameterized(instance: Object, method: String, task_tag = null) -> Future:
	return __enqueue_task(instance, method, null, task_tag, true, false)


func submit_task_array_parameterized(instance: Object, method: String, parameter: Array, task_tag = null) -> Future:
	return __enqueue_task(instance, method, parameter, task_tag, false, true)


func shutdown():
	__finished = true
	__tasks_lock.lock()
	if not __tasks.empty():
		var size = __tasks.size()
		for i in size:
			(__tasks[i] as Future).__finish()
		__tasks.clear()
	for i in __pool:
		__tasks_wait.post()
	__tasks_lock.unlock()


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
		if t.is_active():
			t.wait_to_finish()


func __create_pool():
	var result = []
	for c in range(OS.get_processor_count()):
		result.append(Thread.new())
	return result


func __start() -> void:
	if not __started:
		for t in __pool:
			(t as Thread).start(self, "__execute_tasks", t)
		__started = true

func __drain_this_task(task: Future) -> Future:
	__tasks_lock.lock()
	if __tasks.empty():
		__tasks_lock.unlock()
		return null
	var result = null
	var size = __tasks.size()
	for i in size:
		var candidate_task: Future = __tasks[i]
		if task == candidate_task:
			__tasks.remove(i)
			result = candidate_task
			break
	__tasks_lock.unlock()
	return result;


func __drain_task() -> Future:
	__tasks_lock.lock()
	var result
	if __tasks.empty():
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


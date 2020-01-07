extends Node
class_name ThreadPool

onready var pool = __create_pool()
var tasks = []
var started = false
var finished = false
var tasks_lock = Mutex.new()
var tasks_wait = Semaphore.new()

class Task:
	var object_this: Object
	var method_of_this: String
	var userdata_argument

	func _init(instance: Object, method: String, userdata = null):
		object_this = instance
		method_of_this = method
		userdata_argument = userdata

	func execute_task():
		object_this.call(method_of_this, userdata_argument)


func submit_task(instance: Object, method: String, userdata = null) -> void:
	tasks_lock.lock()
	tasks.push_front(Task.new(instance, method, userdata))
	tasks_wait.post()
	__start()
	tasks_lock.unlock()


func shutdown():
	finished = true
	for i in pool:
		tasks_wait.post()


func free():
	shutdown()
	.free()


func __create_pool():
	var result = []
	for c in range(OS.get_processor_count()):
		result.append(Thread.new())
	return result


func __start() -> void:
	if not started:
		for t in pool:
			#(t as Thread).start(self, "__execute_tasks")
			(t as Thread).start(self, "__execute_tasks", t)# the thread as argument
		started = true


func __drain_task() -> Task:
	tasks_lock.lock()
	var result
	if tasks.empty():
		result = Task.new(self, "do_nothing")# normally, this is not expected, but better safe than sorry
	else:
		result = tasks.pop_back()
	tasks_lock.unlock()
	return result;


func __execute_tasks(arg_thread) -> void:
	#print(arg_thread)
	while not finished:
		tasks_wait.wait()
		var task = __drain_task() as Task
		task.execute_task()


func do_nothing(arg) -> void:
	#print("doing nothing")
	OS.delay_msec(1) # if there is nothing to do, go to sleep


func print_thread_pool_info(arg=null) -> void:
	#var task = Task.new(self, "do_nothing")
	#task.execute_task()
	print(pool)


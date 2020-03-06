# GODOThreadPOOL

GDScript Thread Pool, designed to perform your tasks efficiently.

Doesn't matter how many tasks you need to execute, they run with all the power the machine has, neither more nor less.

## How to use

Just add the ThreadPool node to the scene, and call the `submit_task()` function:
```GDScript
$ThreadPool.submit_task(my_game_object, "my_game_logic", my_game_data)
```
The function `ThreadPool.submit_task()` works the same way as Godot built-in `Thread.start()`.

Using **Autoload** also works, and is the recommend way to use it, because having more than one thread pool would waste resources.

### Properties

- `discard_finished_tasks: bool`
    
    This property controls whether the thread pool should discard or store the results of finished tasks. 

### Functions

- `func submit_task(instance: Object, method: String, parameter, task_tag = null) -> void`
  
    This function submits a task for execution.
    Parameter `instance` is the object where task will execute, `method` is the function to call on the task, `parameter` is the argument passed to the function being called, and `task_tag` can be used to help identify this task later.
  
    This is equivalent to calling `instance.call(method, parameter)`.
    
- `func submit_task_unparameterized(instance: Object, method: String, task_tag = null) -> void`
  
    This function also submits a task for execution, useful for tasks without parameters.
  
    This is equivalent to calling `instance.call(method)`.

- `func submit_task_array_parameterized(instance: Object, method: String, parameter: Array, task_tag = null) -> void`
  
    Yet another function to submit a task for execution, useful for tasks with many parameters.
    
    This is equivalent to calling `instance.callv(method, parameter)`.

- `func fetch_finished_tasks() -> Array`
  
    If `discard_finished_tasks` is **false**, this function will fetch all finished tasks until this point in time.
  
    After a task is fetched, the thread pool will **NOT** reference it anymore, and users are considered the owners of it now.
  
    Example of use:
    ```GDScript
    var tasks = $ThreadPool.fetch_finished_tasks()
    if tasks.size() > 0:
        prints("task result", (tasks[0] as ThreadPool.Task).result)    
        prints("task tag", (tasks[0] as ThreadPool.Task).tag)
    ```
  
- `func fetch_finished_tasks_by_tag(tag) -> Array`
  
    If `discard_finished_tasks` is **false**, this function will fetch all finished tasks that match `tag` parameter until this point in time.
  
    For every task being fetched, the thread pool will **NOT** reference it anymore, and users are considered the owners of it now.
  
    Example of use:
    ```GDScript
    var tag = "AI stuff"
    $ThreadPool.submit_task(my_game_object, "my_game_logic", my_game_data, tag)
    var tasks = $ThreadPool.fetch_finished_tasks_by_tag(tag)
    ```

### Signals

- `signal task_finished(task_tag)`
    
    When a task finishes and property `discard_finished_tasks` is false.
    
    Argument `task_tag` is the task tag, user defined by `submit_task()`.

- `signal task_discarded(task)`
    
    When a task finishes and property `discard_finished_tasks` is true.
    
    Argument `task` is the finished task and can be casted to class `ThreadPool.Task`.

### Emergency shutdown

If you need to cancel the execution of pending tasks, call the `shutdown()` function.

After calling `shutdown()`, the thread pool will:
 - continue the tasks that were already running 
 - discard pending tasks
 - ignore new tasks submission

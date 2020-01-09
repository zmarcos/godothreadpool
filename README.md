# GODOThreadPOOL

GDScript Thread Pool

## How to use

The function `ThreadPool.submit_task()` works the same way as Godot `Thread.start()`.

Just add the ThredPool node to the scene, and call the `submit_task()` function:
```GDScript
$ThreadPool.submit_task(my_game_object, "my_game_logic", my_game_data)
```

If you need to cancel the execution of pending tasks, call the `shutdown()` function.

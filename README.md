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

## Additional Information

For further information, read documentation on the [wiki](https://github.com/zmarcos/godothreadpool/wiki).

Finding problems in the code, open a ticket on [GitHub](https://github.com/zmarcos/godothreadpool/issues).

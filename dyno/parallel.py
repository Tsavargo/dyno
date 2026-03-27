import multiprocessing

from .context import context


def parallel(input_context: context, function) -> context:
    # 1. Create a Manager to handle inter-process communication
    with multiprocessing.Manager() as manager:
        # 2. Create a process-safe shared list
        shared_list = manager.list()

        # 3. Create the new context, passing in the shared list
        output_context = context(store=shared_list)

        # 4. Prepare the tasks (argument lists) for the Pool.
        tasks = []
        for key, value in input_context.items():
            tasks.append((value, output_context))

        # 5. Start the Pool
        with multiprocessing.Pool() as pool:
            pool.starmap(function, tasks)

        # 6. Copy the data into a standard, final context instance
        final_context = context()
        for key, value in output_context.items():
            final_context.register(key, value)

    return final_context

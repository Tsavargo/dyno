import multiprocessing
from typing import Any, Callable

from .context import context


class proxy:
    def __init__(self, shared_list):
        self.list = shared_list

    def register(self, key: str, obj: Any) -> None:
        self.list.append((key, obj))


def parallel(input_context: context, target_key: str, function: Callable) -> context:
    try:
        items_to_process = input_context.get(target_key)
    except KeyError:
        return context()

    if not items_to_process:
        return context()

    with multiprocessing.Manager() as manager:
        shared_list = manager.list()
        proxy_context = proxy(shared_list)

        tasks = [(item, proxy_context) for item in items_to_process]

        with multiprocessing.Pool() as pool:
            pool.starmap(function, tasks)

        final_context = context()
        for key, value in shared_list:
            final_context.register(key, value)

    return final_context

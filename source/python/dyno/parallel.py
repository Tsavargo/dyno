from concurrent.futures import ThreadPoolExecutor
from typing import Any, Callable

from .context import context


class proxy:
    def __init__(self, shared_list):
        self.list = shared_list

    def register(self, key: str, obj: Any) -> None:
        self.list.append((key, obj))


def parallel(input_context: context, target_key: str, function: Callable) -> None:
    try:
        items_to_process = input_context.get(target_key)
    except KeyError:
        return

    if not items_to_process:
        return

    shared_list = []
    proxy_context = proxy(shared_list)

    with ThreadPoolExecutor() as executor:
        executor.map(lambda item: function(item, proxy_context), items_to_process)

    for key, value in shared_list:
        input_context.register(key, value)

from collections import defaultdict
from typing import Any, Iterator, List, Tuple

# https://docs.python.org/3/library/collections.html#collections.defaultdict


class context:
    def __init__(self, runtime_id):
        self.runtime_id = runtime_id
        self._store = defaultdict(list)

    def register(self, key: str, obj: Any) -> None:
        self._store[key].append(obj)

    def get(self, input_key: str) -> List[Any]:
        if input_key not in self._store:
            raise KeyError(f"The key is not registered in the context: {input_key}")
        return self._store.pop(input_key)

    def __iter__(self) -> Iterator[str]:
        return iter(self._store.keys())

    def items(self) -> Iterator[Tuple[str, List[Any]]]:
        return iter(self._store.items())

    def __len__(self) -> int:
        return len(self._store)

from collections import defaultdict
from typing import Any, Dict, Iterator, List, Optional, Tuple

# https://docs.python.org/3/library/collections.html#collections.defaultdict


class context:
    def __init__(self, store: Optional[Dict[str, List[Any]]] = None):
        self._store = defaultdict(list)
        if store:
            self._store.update(store)

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

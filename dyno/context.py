from typing import Any, Iterator, Tuple


# object ősosztály?
# collections.abc

class context:
    def __init__(self, store=None):
        self._store = store if store is not None else []

    def register(self, key: str, obj: Any) -> None:
        self._store.append((key, obj))

    def get(self, input_key: str) -> list[Any]:
        results = [value for key, value in self._store if key == input_key]
        if not results:
            raise KeyError(f"The key is not registered in the context: {input_key}")
        return results

    def __iter__(self) -> Iterator[str]:
        return (key for key, value in self._store)

    def items(self) -> Iterator[Tuple[str, Any]]:
        return iter(self._store)

    def __len__(self) -> int:
        return len(self._store)

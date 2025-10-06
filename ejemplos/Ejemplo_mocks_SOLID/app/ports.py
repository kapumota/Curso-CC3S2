#ports.py
from typing import Protocol, Any

class HttpPort(Protocol):
    def get_json(self, url: str) -> Any: ...

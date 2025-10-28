#ports.py
from typing import Protocol, Dict, Any

class StoragePort(Protocol):
    def ensure_bucket(self, name: str, public: bool, classification: str) -> Dict[str, Any]:
        ...
    def set_prefix_policy(self, name: str, prefix: str) -> Dict[str, Any]:
        ...
    def describe(self, name: str) -> Dict[str, Any]:
        ...

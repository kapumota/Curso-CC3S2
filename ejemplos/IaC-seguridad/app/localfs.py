#localfs.py
import os, json
from typing import Dict, Any

class LocalEncryptedStorage:
    """
    Simula un "bucket" local como carpeta bajo DATA_ROOT con metadata.json.
    No usa criptografía real para evitar dependencias, pero marca 'encrypted': true.
    """
    def __init__(self, data_root: str) -> None:
        self.data_root = data_root
        os.makedirs(self.data_root, exist_ok=True)

    def _bucket_path(self, name: str) -> str:
        return os.path.join(self.data_root, name)

    def _meta_path(self, name: str) -> str:
        return os.path.join(self._bucket_path(name), "metadata.json")

    def ensure_bucket(self, name: str, public: bool, classification: str) -> Dict[str, Any]:
        bpath = self._bucket_path(name)
        os.makedirs(bpath, exist_ok=True)
        meta = {
            "name": name,
            "public": bool(public),
            "classification": classification,
            "encrypted": True,
            "prefix_policies": []
        }
        # merge with existing if exists
        if os.path.exists(self._meta_path(name)):
            try:
                with open(self._meta_path(name), "r", encoding="utf-8") as f:
                    current = json.load(f)
            except Exception:
                current = {}
            current.update(meta)
            meta = current
        with open(self._meta_path(name), "w", encoding="utf-8") as f:
            json.dump(meta, f, indent=2)
        return meta

    def set_prefix_policy(self, name: str, prefix: str) -> Dict[str, Any]:
        meta = self.describe(name)
        policies = set(meta.get("prefix_policies", []))
        policies.add(prefix)
        meta["prefix_policies"] = sorted(list(policies))
        with open(self._meta_path(name), "w", encoding="utf-8") as f:
            json.dump(meta, f, indent=2)
        return meta

    def describe(self, name: str) -> Dict[str, Any]:
        try:
            with open(self._meta_path(name), "r", encoding="utf-8") as f:
                return json.load(f)
        except FileNotFoundError:
            return {"name": name, "exists": False}

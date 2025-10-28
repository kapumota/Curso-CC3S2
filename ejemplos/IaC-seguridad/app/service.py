#service.py
import os, json, yaml
from typing import Dict, Any, List
from .ports import StoragePort

class BucketService:
    def __init__(self, storage: StoragePort, evidence_dir: str) -> None:
        self.storage = storage
        self.evidence_dir = evidence_dir
        os.makedirs(self.evidence_dir, exist_ok=True)

    def load_desired(self, path: str) -> Dict[str, Any]:
        with open(path, "r", encoding="utf-8") as f:
            return yaml.safe_load(f)

    def plan(self, desired: Dict[str, Any], state: Dict[str, Any]) -> Dict[str, Any]:
        desired_names = {b["name"] for b in desired.get("buckets", [])}
        state_names = {r["name"] for r in state.get("resources", [])}

        creates = []
        updates = []

        # create or update
        for b in desired.get("buckets", []):
            name = b["name"]
            public = bool(b.get("public", False))
            classification = b.get("classification", "Internal")
            allowed_prefix = b.get("allowed_prefix", "")

            if name not in state_names:
                creates.append({"type": "bucket", "name": name,
                                "public": public, "classification": classification,
                                "allowed_prefix": allowed_prefix})
            else:
                # compare fields for drift/update
                # (simple comparison vs last state)
                s = next(r for r in state["resources"] if r["name"] == name)
                changes = {}
                for k in ("public", "classification", "allowed_prefix"):
                    if s.get(k) != b.get(k):
                        changes[k] = {"from": s.get(k), "to": b.get(k)}
                if changes:
                    updates.append({"type": "bucket", "name": name, "changes": changes})

        # No deletes automáticos por seguridad (necesitarías --force)
        plan = {
            "creates": creates,
            "updates": updates,
            "outputs": {
                # No se exponen secretos, solo datos mínimos
                "count_desired_buckets": len(desired_names),
                "count_state_buckets": len(state_names)
            }
        }
        return plan

    def save_evidence(self, name: str, data: Dict[str, Any]) -> str:
        path = os.path.join(self.evidence_dir, name)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        return path

    def apply(self, plan: Dict[str, Any], state: Dict[str, Any]) -> Dict[str, Any]:
        # apply creates
        for c in plan.get("creates", []):
            meta = self.storage.ensure_bucket(c["name"], c["public"], c["classification"])
            if c.get("allowed_prefix"):
                self.storage.set_prefix_policy(c["name"], c["allowed_prefix"])
            # update state
            self._upsert_state(state, {
                "type": "bucket",
                "name": c["name"],
                "public": c["public"],
                "classification": c["classification"],
                "allowed_prefix": c.get("allowed_prefix","")
            })

        # apply updates
        for u in plan.get("updates", []):
            desired_public = u["changes"].get("public", {}).get("to", None)
            desired_class = u["changes"].get("classification", {}).get("to", None)
            meta = self.storage.describe(u["name"])
            public = meta.get("public") if desired_public is None else desired_public
            classification = meta.get("classification") if desired_class is None else desired_class
            meta = self.storage.ensure_bucket(u["name"], public, classification)
            if "allowed_prefix" in u["changes"]:
                self.storage.set_prefix_policy(u["name"], u["changes"]["allowed_prefix"]["to"])
            # sync state
            s = next(r for r in state["resources"] if r["name"] == u["name"])
            if desired_public is not None: s["public"] = desired_public
            if desired_class is not None: s["classification"] = desired_class
            if "allowed_prefix" in u["changes"]:
                s["allowed_prefix"] = u["changes"]["allowed_prefix"]["to"]

        return state

    def _upsert_state(self, state: Dict[str, Any], res: Dict[str, Any]) -> None:
        for i, r in enumerate(state["resources"]):
            if r["name"] == res["name"]:
                state["resources"][i] = res
                return
        state["resources"].append(res)

#plan.py
import os, sys, json
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.localfs import LocalEncryptedStorage
from app.service import BucketService

def load_json(path):
    try:
        import json, io
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return {"version": 1, "resources": []}

def main():
    from dotenv import dotenv_values
    env = dotenv_values(".env")
    data_root = env.get("DATA_ROOT", "./data")
    evidence_dir = env.get("EVIDENCE_DIR", "./.evidence")

    storage = LocalEncryptedStorage(data_root)
    svc = BucketService(storage, evidence_dir)

    desired = svc.load_desired("desired/config.yaml")
    state = load_json("state/state.json")
    plan = svc.plan(desired, state)
    path = svc.save_evidence("plan.json", plan)
    print(f"Plan guardado en: {path}")

if __name__ == "__main__":
    main()

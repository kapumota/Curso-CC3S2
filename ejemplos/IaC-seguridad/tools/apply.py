#apply.py
import json
import os, sys, json
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from app.localfs import LocalEncryptedStorage
from app.service import BucketService

def load_json(path):
    try:
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

    with open(f"{evidence_dir}/plan.json", "r", encoding="utf-8") as f:
        plan = json.load(f)

    state = load_json("state/state.json")
    new_state = svc.apply(plan, state)

    with open("state/state.json", "w", encoding="utf-8") as f:
        json.dump(new_state, f, indent=2)
    print("Apply completado y estado actualizado en state/state.json")

if __name__ == "__main__":
    main()

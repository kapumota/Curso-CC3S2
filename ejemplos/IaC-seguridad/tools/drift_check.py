#drift_check.py
import os, json
import os, sys, json
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from app.localfs import LocalEncryptedStorage
from app.service import BucketService

def main():
    from dotenv import dotenv_values
    env = dotenv_values(".env")
    data_root = env.get("DATA_ROOT", "./data")
    evidence_dir = env.get("EVIDENCE_DIR", "./.evidence")

    storage = LocalEncryptedStorage(data_root)
    svc = BucketService(storage, evidence_dir)

    with open("state/state.json","r",encoding="utf-8") as f:
        state = json.load(f)

    drift = []
    for r in state.get("resources", []):
        meta = storage.describe(r["name"])
        if not meta or not meta.get("name"):
            drift.append({"name": r["name"], "reason": "missing"})
            continue
        for k in ("public","classification"):
            if meta.get(k) != r.get(k):
                drift.append({"name": r["name"], "field": k, "state": r.get(k), "actual": meta.get(k)})

    result = {"drift": drift}
    svc.save_evidence("drift.json", result)
    if drift:
        print("DRIFT DETECTADO: ver ./.evidence/drift.json")
        exit(2)
    else:
        print("Sin drift.")

if __name__ == "__main__":
    main()

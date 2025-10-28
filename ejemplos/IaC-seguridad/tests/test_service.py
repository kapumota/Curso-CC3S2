#test_service.py
from app.service import BucketService
from app.localfs import LocalEncryptedStorage
import os, json

def test_plan_and_apply(tmp_path):
    data_root = tmp_path / "data"
    evidence = tmp_path / ".evidence"
    os.makedirs(data_root, exist_ok=True)
    os.makedirs(evidence, exist_ok=True)

    storage = LocalEncryptedStorage(str(data_root))
    svc = BucketService(storage, str(evidence))

    desired = {
        "buckets": [
            {"name":"alpha","public": False, "classification":"Restricted","allowed_prefix":"exp/"},
            {"name":"docs","public": False, "classification":"Internal","allowed_prefix":"hand/"},
        ]
    }
    state = {"version":1,"resources":[]}

    plan = svc.plan(desired, state)
    assert plan["creates"] and len(plan["updates"]) == 0

    new_state = svc.apply(plan, state)
    assert any(r["name"]=="alpha" for r in new_state["resources"])
    assert any(r["name"]=="docs" for r in new_state["resources"])

    # update desired -> classification change should produce an update
    desired["buckets"][1]["classification"] = "Restricted"
    plan2 = svc.plan(desired, new_state)
    assert plan2["updates"]

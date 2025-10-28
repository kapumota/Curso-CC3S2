#sbom.py
import os, json, hashlib, sys
def sha256_of_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()

def walk_hash(root):
    items = []
    for dirpath, _, filenames in os.walk(root):
        for fn in filenames:
            p = os.path.join(dirpath, fn)
            try:
                items.append({"path": p, "sha256": sha256_of_file(p)})
            except Exception:
                pass
    return {"generated_by": "local_iac_demo", "artifacts": items}

if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv)>1 else "."
    sbom = walk_hash(target)
    os.makedirs(".evidence", exist_ok=True)
    out = ".evidence/sbom.json"
    with open(out, "w", encoding="utf-8") as f:
        json.dump(sbom, f, indent=2)
    print(f"SBOM guardado en {out}")

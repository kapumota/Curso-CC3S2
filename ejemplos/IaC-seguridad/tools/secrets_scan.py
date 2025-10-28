#secrets_scan.py
import os, re, json, sys

PATTERNS = [
    re.compile(r'api[_-]?key\s*[:=]\s*["\']?[A-Za-z0-9_\-]{12,}'),
    re.compile(r'secret\s*[:=]\s*["\']?[A-Za-z0-9_\-]{12,}'),
    re.compile(r'password\s*[:=]\s*["\']?.{6,}')
]

def scan(root):
    findings = []
    for dirpath, _, filenames in os.walk(root):
        for fn in filenames:
            if fn.endswith((".png",".jpg",".gif",".bin",".lock",".pyc",".zip")):
                continue
            p = os.path.join(dirpath, fn)
            try:
                with open(p, "r", encoding="utf-8", errors="ignore") as f:
                    data = f.read()
                for rx in PATTERNS:
                    for m in rx.finditer(data):
                        findings.append({"file": p, "match": m.group(0)[:80]})
            except Exception as e:
                pass
    return findings

if __name__ == "__main__":
    root = sys.argv[1] if len(sys.argv)>1 else "."
    res = scan(root)
    if res:
        print(json.dumps({"secrets": res}, indent=2))
        sys.exit(2)
    print("No secrets found.")

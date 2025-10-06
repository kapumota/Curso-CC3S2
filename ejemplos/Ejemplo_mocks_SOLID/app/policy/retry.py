#retry.py
import random
import time
import requests

def get_with_retry(http, url, attempts=3, base_ms=100, max_ms=1000):
    for i in range(attempts):
        try:
            r = http.get(url, timeout=2.0)
            r.raise_for_status()
            return r
        except requests.RequestException:
            if i == attempts - 1:
                raise
            # jitter con SystemRandom para satisfacer S311
            sleep_ms = min(max_ms, base_ms * (2 ** i)) + random.SystemRandom().randint(0, 50)
            time.sleep(sleep_ms / 1000.0)

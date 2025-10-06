from .adapters import FakeHttpClient

def main():
    fixtures = {"https://api.ejemplo.com/status": {"ok": True, "service": "up"}}
    http = FakeHttpClient(fixtures)
    from .service import MovieService
    svc = MovieService(http)
    print(svc.status())

if __name__ == "__main__":
    main()

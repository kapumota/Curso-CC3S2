#service.py
from .ports import HttpPort

class MovieService:
    def __init__(self, http: HttpPort):
        self.http = http
    def status(self):
        return self.http.get_json("https://api.ejemplo.com/status")

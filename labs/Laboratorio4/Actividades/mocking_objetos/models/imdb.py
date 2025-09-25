"""
Acceso a la base de datos de películas de Internet Movie Database
Implementa las APIs SearchTitle, Reviews y Ratings
"""

import logging
from typing import Any, Dict
import requests

logger = logging.getLogger(__name__)

class IMDb:
    """Acceso a la base de datos de películas de Internet Movie Database"""

    def __init__(self, apikey: str):
        self.apikey = apikey

    def search_titles(self, title: str) -> Dict[str, Any]:
        """Busca una película por título"""
        logger.info("Buscando en IMDb el título: %s", title)
        resultados = requests.get(
            f"https://imdb-api.com/API/SearchTitle/{self.apikey}/{title}",  # noqa: E231
        )
        if resultados.status_code == 200:
            return resultados.json()
        return {}

    def movie_reviews(self, imdb_id: str) -> Dict[str, Any]:
        """Obtiene reseñas para una película"""
        logger.info("Buscando en IMDb las reseñas: %s", imdb_id)
        resultados = requests.get(
            f"https://imdb-api.com/API/Reviews/{self.apikey}/{imdb_id}",  # noqa: E231
        )
        if resultados.status_code == 200:
            return resultados.json()
        return {}

    def movie_ratings(self, imdb_id: str) -> Dict[str, Any]:
        """Obtiene calificaciones para una película"""
        logger.info("Buscando en IMDb las calificaciones: %s", imdb_id)
        resultados = requests.get(
            f"https://imdb-api.com/API/Ratings/{self.apikey}/{imdb_id}",  # noqa: E231
        )
        if resultados.status_code == 200:
            return resultados.json()
        return {}

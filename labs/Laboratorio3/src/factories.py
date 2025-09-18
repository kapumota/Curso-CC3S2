# pylint: disable=too-few-public-methods
# src/factories.py
import factory
from src.carrito import Producto

class ProductoFactory(factory.Factory):  # pylint: disable=too-few-public-methods
    class Meta:
        model = Producto

    nombre = factory.Faker("word")
    precio = factory.Faker("pyfloat", left_digits=2, right_digits=2, positive=True)

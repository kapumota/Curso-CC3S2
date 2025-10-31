"""
ETL batch:
- Extract: lee data/input.csv
- Transform: calcula value_squared
- Load: inserta en Postgres (tabla processed_data)

Cumple 12-Factor: credenciales vienen de variables de entorno,
NO están hardcodeadas en la imagen ni en el código (más allá de los nombres).
"""

import os
import pandas as pd
import psycopg2
import psycopg2.extras


def extract():
    csv_path = os.environ.get("ETL_INPUT", "data/input.csv")
    df = pd.read_csv(csv_path)
    return df


def transform(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df["value_squared"] = df["value"] ** 2
    return df[["name", "value", "value_squared"]]


def _get_conn():
    return psycopg2.connect(
        dbname=os.environ["POSTGRES_DB"],
        user=os.environ["POSTGRES_USER"],
        password=os.environ["POSTGRES_PASSWORD"],
        host=os.environ.get("POSTGRES_HOST", "postgres"),
        port=os.environ.get("POSTGRES_PORT", "5432"),
        connect_timeout=5,
    )


def load(df: pd.DataFrame) -> None:
    with _get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS processed_data (
                    name TEXT,
                    value NUMERIC,
                    value_squared NUMERIC
                )
                """
            )
        with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
            cur.executemany(
                """
                INSERT INTO processed_data (name, value, value_squared)
                VALUES (%(name)s, %(value)s, %(value_squared)s)
                """,
                df.to_dict(orient="records"),
            )
        conn.commit()


def run_etl():
    df_raw = extract()
    df_clean = transform(df_raw)
    load(df_clean)


if __name__ == "__main__":
    run_etl()

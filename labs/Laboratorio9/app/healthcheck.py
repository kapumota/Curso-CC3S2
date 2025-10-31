import os
import psycopg2

def main():
    try:
        conn = psycopg2.connect(
            dbname=os.environ["POSTGRES_DB"],
            user=os.environ["POSTGRES_USER"],
            password=os.environ["POSTGRES_PASSWORD"],
            host=os.environ.get("POSTGRES_HOST", "postgres"),
            port=os.environ.get("POSTGRES_PORT", "5432"),
            connect_timeout=3,
        )
        cur = conn.cursor()
        cur.execute("SELECT 1;")
        cur.fetchone()
        conn.close()
        print("healthy")
    except Exception as e:
        print(f"unhealthy: {e}")
        raise SystemExit(1)

if __name__ == "__main__":
    main()

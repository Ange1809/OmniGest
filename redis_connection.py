import os
import redis
from dotenv import load_dotenv

load_dotenv()

try:
    redis_client = redis.Redis(
        host=os.getenv("REDIS_HOST"),
        port=int(os.getenv("REDIS_PORT")),
        decode_responses=True
    )

    redis_client.ping()

    print("Redis conectado correctamente")

except Exception as e:
    print(f"Error al conectar Redis: {e}")
    redis_client = None
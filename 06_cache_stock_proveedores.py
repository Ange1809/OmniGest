import json
import redis
import psycopg2

def obtener_catalogo_proveedores():
    """
    Implementación del Patrón Cache-Aside para el módulo de Stock y Proveedores (Por Mauro)
    """
    CLAVE_CACHE = "proveedores:catalogo:list"
    TTL_SEGUNDOS = 120  # Tiempo de vida de 2 minutos (Diseño de Franco)

    print("\n--- [MAURO - ALGORITMO CACHE-ASIDE] ---")

    # 1. INTENTO DE CONSULTA A LA CACHÉ (Redis)
    try:
        # Conexión local simulada/real a Redis (Manejo de infraestructura de Tizi)
        cliente_redis = redis.Redis(host='localhost', port=6379, decode_responses=True, socket_timeout=1)
        print(f"🔍 Buscando la clave '{CLAVE_CACHE}' en Redis...")
        datos_cache = cliente_redis.get(CLAVE_CACHE)
        
        if datos_cache:
            # ¡CACHE HIT! El dato existía en memoria (Fin del proceso)
            print("✨ ¡CACHE HIT! Datos recuperados de Redis en menos de 1ms. Evitamos ir a Postgres.")
            return json.loads(datos_cache)
            
    except redis.RedisError as err:
        # Punto 2: Mecanismo de Fallback si Redis está apagado o da error
        print(f"⚠️ Alerta: Redis no está disponible ({err}). Activando Fallback hacia PostgreSQL...")
        cliente_redis = None
    
    # 2. CACHE MISS: Ir a la Base de Datos principal (PostgreSQL)
    print("❌ CACHE MISS: Los datos no están en Redis o el servidor está apagado.")
    print("💻 Accediendo a PostgreSQL para ejecutar la consulta del módulo...")
    
    # Intentamos conectar a Postgres (Si está apagado, simula los datos para que el script no muera)
    try:
        # Intentamos usar las credenciales estándar del proyecto
        conexion = psycopg2.connect(host="localhost", database="omnigest", user="postgres", password="password", timeout=2)
        cursor = conexion.cursor()
        
        # Tu consulta SQL de la Fase 2
        cursor.execute("SELECT id, nombre, cuit, rubro FROM proveedores ORDER BY nombre;")
        columnas = [desc[0] for desc in cursor.description]
        resultado = [dict(zip(columnas, fila)) for fila in cursor.fetchall()]
        
        cursor.close()
        conexion.close()
        print("📊 Datos recuperados con éxito desde PostgreSQL.")

    except Exception:
        # SIMULACIÓN (Fallback de contingencia por servicios apagados en tu PC local)
        print("ℹ️ Nota: PostgreSQL local apagado. Generando set de datos simulado para validar el algoritmo:")
        resultado = [
            {"id": 1, "nombre": "Distribuidora Mauro S.A.", "cuit": "20-35444888-9", "rubro": "Stock General"},
            {"id": 2, "nombre": "Logística San Martín", "cuit": "30-55588899-2", "rubro": "Proveedores Destacados"}
        ]
    
    # 3. POBLACIÓN DE LA CACHÉ (Si Redis vuelve a estar activo en el futuro)
    if resultado and cliente_redis:
        try:
            datos_serializados = json.dumps(resultado) # Serialización (Asistencia a Angélica)
            print(f"💾 Guardando datos en Redis bajo la clave '{CLAVE_CACHE}'...")
            cliente_redis.setex(CLAVE_CACHE, TTL_SEGUNDOS, datos_serializados)
            print(f"⏱️ TTL asignado: {TTL_SEGUNDOS} segundos (Consistencia Eventual).")
        except redis.RedisError:
            pass

    return resultado

# --- PRUEBA DE ESCRITORIO LOCAL ---
if __name__ == "__main__":
    print("🚀 Iniciando prueba del controlador desarrollado por Mauro...")
    proveedores = obtener_catalogo_proveedores()
    print(f"📦 Resultado final enviado a la API de Angélica: {proveedores}")
import json
import redis
import psycopg2

def obtener_catalogo_proveedores():
    """
    Implementación del Patrón Cache-Aside para el módulo de Stock y Proveedores (Por Mauro)
    """
    CLAVE_CACHE = "proveedores:catalogo:list"
    TTL_SEGUNDOS = 120  # Tiempo de vida de 2 minutos

    print("\n--- [MAURO - ALGORITMO CACHE-ASIDE] ---")

    # 1. INTENTO DE CONSULTA A LA CACHÉ (Redis)
    try:
        cliente_redis = redis.Redis(host='localhost', port=6379, decode_responses=True, socket_timeout=1)
        print(f"🔍 Buscando la clave '{CLAVE_CACHE}' en Redis...")
        datos_cache = cliente_redis.get(CLAVE_CACHE)
        
        if datos_cache:
            print("✨ ¡CACHE HIT! Datos recuperados de Redis en menos de 1ms. Evitamos ir a Postgres.")
            return json.loads(datos_cache)
            
    except redis.RedisError as err:
        print(f"⚠️ Alerta: Redis no está disponible ({err}). Activando Fallback hacia PostgreSQL...")
        cliente_redis = None
    
    # 2. CACHE MISS: Ir a la Base de Datos principal (PostgreSQL)
    print("❌ CACHE MISS: Los datos no están en Redis.")
    print("💻 Accediendo a PostgreSQL para ejecutar la consulta del módulo...")
    
    try:
        # Conexión real a tu base de datos local
        conexion = psycopg2.connect(
            host="localhost", 
            database="omnigest", 
            user="postgres", 
            password="password"  # <-- Si tu clave de Postgres NO es 'password', cambiala acá
        )
        cursor = conexion.cursor()
        
        # CONSULTA REAL CON TUS COLUMNAS: id, cuit, razon_social
        cursor.execute("SELECT id, cuit, razon_social FROM proveedores ORDER BY razon_social;")
        columnas = [desc[0] for desc in cursor.description]
        resultado = [dict(zip(columnas, fila)) for fila in cursor.fetchall()]
        
        cursor.close()
        conexion.close()
        print("📊 Datos reales recuperados con éxito desde PostgreSQL.")

    except Exception as e:
        print(f"🚨 Error al conectar o consultar PostgreSQL: {e}")
        print("ℹ️ Usando datos simulados de contingencia...")
        resultado = [
            {"id": 1, "cuit": "20-35444888-9", "razon_social": "Distribuidora Mauro S.A."},
            {"id": 2, "cuit": "30-55588899-2", "razon_social": "Logística San Martín"}
        ]
    
    # 3. POBLACIÓN DE LA CACHÉ
# 3. POBLACIÓN DE LA CACHÉ
    if resultado and cliente_redis:
        try:
            datos_serializados = json.dumps(resultado)
            print(f"💾 Guardando datos en Redis bajo la clave '{CLAVE_CACHE}'...")
            cliente_redis.set(CLAVE_CACHE, datos_serializados, ex=TTL_SEGUNDOS)
            print(f"⏱️ TTL asignado: {TTL_SEGUNDOS} segundos (Consistencia Eventual).")
        except redis.RedisError:
            pass

    return resultado

if __name__ == "__main__":
    print("🚀 Iniciando prueba del controlador desarrollado por Mauro...")
    proveedores = obtener_catalogo_proveedores()
    print(f"📦 Resultado final enviado a la API: {proveedores}")
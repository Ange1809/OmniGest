import os
import psycopg2
from dotenv import load_dotenv

load_dotenv()

def probar_conexion():
    try:
        conexion = psycopg2.connect(
            host=os.getenv("DB_HOST"),
            port=os.getenv("DB_PORT"),
            dbname=os.getenv("DB_NAME"),
            user=os.getenv("DB_USER"),
            password=os.getenv("DB_PASS"),
            client_encoding='utf8' # <--- ESTA ES LA MAGIA PARA VER EL ERROR REAL
        )
        
        print("✅ ¡Conexión exitosa a la base de datos OmniGest!")
        
        cursor = conexion.cursor()
        cursor.execute("SELECT count(*) FROM ventas_detalle;")
        cantidad = cursor.fetchone()[0]
        
        print(f"📊 Verificación lista: Tenés {cantidad} registros en ventas_detalle.")
        
        cursor.close()
        conexion.close()

    except Exception as e:
        print(f"❌ El servidor rechazó la conexión. El motivo real es:\n{e}")

if __name__ == "__main__":
    probar_conexion()
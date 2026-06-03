import os
import datetime
from flask import Flask, jsonify, request
import psycopg2
from dotenv import load_dotenv

dotenv_path = os.path.join(os.path.dirname(__file__), '.env')
load_dotenv(dotenv_path=dotenv_path)

static_folder = os.path.join(os.path.dirname(__file__), 'Frontend')
app = Flask(__name__, static_folder=static_folder, static_url_path='')

def obtener_conexion():
    conn = psycopg2.connect(
        host=os.getenv("DB_HOST"),
        port=os.getenv("DB_PORT"),
        dbname=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASS")
    )
    # Establecer la codificación del cliente explícitamente
    try:
        conn.set_client_encoding('UTF8')
    except Exception:
        pass
    return conn

LOG_FILE = os.path.join(os.path.dirname(__file__), "auditoria_errores.txt")

def registrar_log_en_archivo(sqlstate, mensaje):
    """Simula la inserción en la tabla audit_logs guardando el error en un archivo .txt"""
    fecha_hora = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    mensaje_limpio = str(mensaje).replace("\n", " ").replace("\r", " ")
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(f"{fecha_hora}|{sqlstate}|{mensaje_limpio}\n")

@app.route('/')
def index():
    return app.send_static_file('index.html')

TOTAL_CACHEADO = None

# Endpoint 1
@app.route('/api/reportes/total-facturado', methods=['GET'])
def total_facturado():
    global TOTAL_CACHEADO
    try:
        if TOTAL_CACHEADO is not None:
            return jsonify({"total": TOTAL_CACHEADO})
            
        print("Procesando el millón de registros por primera vez... Espera...")
        conn = obtener_conexion()
        cursor = conn.cursor()
        cursor.execute("SELECT SUM(cantidad * precio_unitario_cobrado) FROM ventas_detalle;") 
        resultado = cursor.fetchone()[0]
        
        cursor.close()
        conn.close()

        TOTAL_CACHEADO = float(resultado or 0)
        return jsonify({"total": TOTAL_CACHEADO})
    except Exception as e:
        registrar_log_en_archivo("50000", f"Error en métrica: {str(e)}")
        return jsonify({"error": str(e)}), 500

# Endpoint 2
@app.route('/api/transacciones/procesar', methods=['POST'])
def procesar_transaccion():
    datos = request.json
    producto_id = datos.get('producto_id')
    cantidad = datos.get('cantidad')
    
    conn = None
    try:
        conn = obtener_conexion()
        cursor = conn.cursor()

        cursor.execute("SELECT precio_costo FROM productos WHERE id = %s AND eliminado_at IS NULL;", (producto_id,))
        producto = cursor.fetchone()
        
        if not producto:
            raise Exception(f"Regla de Negocio: El producto con ID {producto_id} no existe en los registros.")
            
        precio_costo = float(producto[0])
        precio_venta = precio_costo * 1.30
        total_operacion = precio_venta * cantidad

        cursor.execute(
            "INSERT INTO ventas_cabecera (fecha, total, metodo_pago) VALUES (CURRENT_TIMESTAMP, %s, 'Efectivo') RETURNING id;",
            (total_operacion,)
        )
        id_venta = cursor.fetchone()[0]

        cursor.execute(
            "INSERT INTO ventas_detalle (id_venta, id_producto, cantidad, precio_unitario_cobrado) VALUES (%s, %s, %s, %s);",
            (id_venta, producto_id, cantidad, precio_venta)
        )
        
        conn.commit()
        
        cursor.close()
        conn.close()
        return jsonify({"mensaje": "¡Transacción procesada y guardada con éxito (Simulación de Procedure)!"}), 200
        
    except Exception as e:
        if conn:
            conn.rollback()
            conn.close()
        
        mensaje_limpio = str(e)
        registrar_log_en_archivo("45001", mensaje_limpio)
        
        return jsonify({"error": mensaje_limpio}), 400

# Endpoint 3
@app.route('/api/auditoria/logs', methods=['GET'])
def obtener_logs():
    lista_logs = []
    try:
        if os.path.exists(LOG_FILE):
            with open(LOG_FILE, "r", encoding="utf-8") as f:
                lineas = f.readlines()
                for linea in reversed(lineas[-10:]):
                    if (idx := linea.strip().split('|', 2)) and len(idx) == 3:
                        lista_logs.append({
                            "fecha_hora": idx[0],
                            "sqlstate": idx[1],
                            "mensaje_error": idx[2]
                        })
        return jsonify(lista_logs), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    print("Iniciando servidor de OmniGest en el puerto 8080...")
    app.run(host="127.0.0.1", port=8080, debug=True)
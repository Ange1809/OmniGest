import os
import datetime
from flask import Flask, jsonify, request
import psycopg2
from dotenv import load_dotenv
from redis_connection import redis_client

load_dotenv()

app = Flask(__name__, static_folder='frontend', static_url_path='')

def obtener_conexion():
    return psycopg2.connect(
        host=os.getenv("DB_HOST"),
        port=os.getenv("DB_PORT"),
        dbname=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASS"),
        client_encoding='utf8'
    )

LOG_FILE = "auditoria_errores.txt"

def registrar_log_en_archivo(sqlstate, mensaje):
    fecha_hora = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(f"{fecha_hora}|{sqlstate}|{mensaje}\n")

@app.route('/')
def index():
    return app.send_static_file('index.html')

# ENDPOINT 1 - TOTAL FACTURADO
@app.route('/api/reportes/total-facturado', methods=['GET'])
def total_facturado():
    try:
        # CACHE REDIS
        if redis_client:
            try:
                dato_cache = redis_client.get("reportes:total_facturado")

                if dato_cache:
                    print("Cache HIT - Redis")
                    return jsonify({"total": float(dato_cache)})

            except Exception as redis_error:
                print(f"Redis no disponible: {redis_error}")

        print("Consultando PostgreSQL...")

        conn = obtener_conexion()
        cursor = conn.cursor()

        cursor.execute("""
            SELECT SUM(cantidad * precio_unitario_cobrado)
            FROM ventas_detalle;
        """)

        resultado = cursor.fetchone()[0]

        cursor.close()
        conn.close()

        total = float(resultado or 0)

        try:
            if redis_client:
                redis_client.setex(
                    "reportes:total_facturado",
                    120,
                    total
                )
        except Exception as redis_error:
            print(f"No se pudo guardar en Redis: {redis_error}")

        return jsonify({"total": total})

    except Exception as e:
        registrar_log_en_archivo("50000", f"Error en métrica: {str(e)}")
        return jsonify({"error": str(e)}), 500


# ENDPOINT 2 - TRANSACCIONES
@app.route('/api/transacciones/procesar', methods=['POST'])
def procesar_transaccion():
    datos = request.json
    producto_id = datos.get('producto_id')
    cantidad = datos.get('cantidad')

    conn = None
    try:
        conn = obtener_conexion()
        cursor = conn.cursor()

        cursor.execute("""
            SELECT precio_costo
            FROM productos
            WHERE id = %s;
        """, (producto_id,))

        producto = cursor.fetchone()

        if not producto:
            return jsonify({"error": "Producto no existe"}), 404

        precio_costo = float(producto[0])
        precio_venta = precio_costo * 1.30
        total = precio_venta * cantidad

        cursor.execute("""
            INSERT INTO ventas_cabecera (fecha, total, metodo_pago)
            VALUES (CURRENT_TIMESTAMP, %s, 'Efectivo')
            RETURNING id;
        """, (total,))

        id_venta = cursor.fetchone()[0]

        cursor.execute("""
            INSERT INTO ventas_detalle
            (id_venta, id_producto, cantidad, precio_unitario_cobrado)
            VALUES (%s, %s, %s, %s);
        """, (id_venta, producto_id, cantidad, precio_venta))

        conn.commit()

        cursor.close()
        conn.close()

        return jsonify({"mensaje": "Transacción procesada"}), 200

    except Exception as e:
        if conn:
            conn.rollback()
            conn.close()

        registrar_log_en_archivo("45001", str(e))
        return jsonify({"error": str(e)}), 400


# ENDPOINT 3 - LOGS
@app.route('/api/auditoria/logs', methods=['GET'])
def obtener_logs():
    lista_logs = []

    try:
        if os.path.exists(LOG_FILE):
            with open(LOG_FILE, "r", encoding="utf-8") as f:
                lineas = f.readlines()

                for linea in reversed(lineas[-10:]):
                    partes = linea.strip().split('|')
                    if len(partes) == 3:
                        lista_logs.append({
                            "fecha_hora": partes[0],
                            "sqlstate": partes[1],
                            "mensaje_error": partes[2]
                        })

        return jsonify(lista_logs), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ENDPOINT 4 - UPDATE PRODUCTOS
@app.route('/api/productos/<int:id>', methods=['PUT'])
def actualizar_producto(id):
    datos = request.json

    conn = None
    try:
        conn = obtener_conexion()
        cursor = conn.cursor()

        cursor.execute("SELECT * FROM productos WHERE id = %s;", (id,))
        existe = cursor.fetchone()

        if not existe:
            return jsonify({"error": "Producto no encontrado"}), 404

        if not datos:
            return jsonify({"error": "Body vacío"}), 400

        campos_permitidos = ["nombre", "precio", "stock"]

        campos = []
        valores = []

        for key, value in datos.items():
            if key in campos_permitidos:
                campos.append(f"{key} = %s")
                valores.append(value)

        if not campos:
            return jsonify({"error": "No hay campos válidos para actualizar"}), 400

        valores.append(id)

        query = f"""
            UPDATE productos
            SET {", ".join(campos)}
            WHERE id = %s
            RETURNING *;
        """

        cursor.execute(query, valores)

        producto = cursor.fetchone()
        columnas = [desc[0] for desc in cursor.description]
        producto_dict = dict(zip(columnas, producto))

        conn.commit()

        cursor.close()
        conn.close()

#Cache-Redis
        try:
            keys = redis_client.keys("catalogo:*")

            for key in keys:
                redis_client.delete(key)

        except Exception as e:
            print("Redis no disponible:", e)

        return jsonify({
            "mensaje": "Producto actualizado correctamente",
            "producto": producto_dict
        }), 200

    except Exception as e:
        if conn:
            conn.rollback()
            conn.close()

        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    print("Iniciando servidor OmniGest en puerto 8080...")
    app.run(host="127.0.0.1", port=8080, debug=True)
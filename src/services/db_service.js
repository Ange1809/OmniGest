// src/services/db_service.js
const { Pool } = require('pg');

const pool = new Pool({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASS,
});

const insertarProducto = async (producto) => {
    // Requisito: Garantizar activo = true y devolver el registro insertado
    const query = `
        INSERT INTO productos (sku, codigo_barras, nombre, id_categoria, precio_costo, activo)
        VALUES ($1, $2, $3, $4, $5, true)
        RETURNING *;
    `;
    const values = [
        producto.sku,
        producto.codigo_barras,
        producto.nombre,
        producto.id_categoria,
        producto.precio_costo
    ];

    const result = await pool.query(query, values);
    return result.rows[0];
};

async function procesarVentaCompleta(cliente_id, producto_id, cantidad) {
    // Definimos el CALL con 5 argumentos (3 IN, 2 NULL para los OUT)
    const query = 'CALL sp_procesar_venta_completa($1, $2, $3, NULL, NULL)';
    const values = [cliente_id, producto_id, cantidad];
    
    try {
        await pool.query(query, values);
        return { mensaje: "Transacción procesada con éxito" };
    } catch (err) {
        throw new Error(err.message);
    }
}

const obtenerTotalFacturado = async () => {
    const query = 'SELECT COALESCE(SUM(total), 0) as total FROM ventas_cabecera';
    const result = await pool.query(query);
    return result.rows[0].total;
};

module.exports = { insertarProducto, procesarVentaCompleta, obtenerTotalFacturado };

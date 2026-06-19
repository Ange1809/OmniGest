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

const actualizarProducto = async (id, datos) => {

    const campos = [];
    const valores = [];
    let contador = 1;

    for (const [key, value] of Object.entries(datos)) {
        campos.push(`${key} = $${contador}`);
        valores.push(value);
        contador++;
    }

    valores.push(id);

    const query = `
        UPDATE productos
        SET ${campos.join(', ')}
        WHERE id = $${contador}
        RETURNING *;
    `;

    const result = await pool.query(query, valores);

    return result.rows[0] || null;
};

module.exports = {
    insertarProducto,
    actualizarProducto
};

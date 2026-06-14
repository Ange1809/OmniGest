-- Dentro de sql/01_creacion_tablas.sql, reemplaza la tabla productos con esto:

CREATE TABLE productos (
    id SERIAL PRIMARY KEY,
    sku VARCHAR(50) UNIQUE NOT NULL,
    codigo_barras VARCHAR(50) NOT NULL,
    nombre VARCHAR(200) NOT NULL,
    id_categoria INT REFERENCES categorias(id),
    precio_costo DECIMAL(12,2) NOT NULL,
    especificaciones JSONB,
    activo BOOLEAN NOT NULL DEFAULT true, -- NUEVO: Columna añadida para soportar tu POST y el PUT de Franco
    eliminado_at TIMESTAMP DEFAULT NULL
);
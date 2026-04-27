-- 1. Habilitar extensión necesaria para el Punto C
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- 2. Creación de tablas de OmniGest
CREATE TABLE categorias (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    id_padre INT REFERENCES categorias(id)
);

CREATE TABLE productos (
    id SERIAL PRIMARY KEY,
    sku VARCHAR(50) UNIQUE NOT NULL,
    codigo_barras VARCHAR(50) NOT NULL,
    nombre VARCHAR(200) NOT NULL,
    id_categoria INT REFERENCES categorias(id),
    precio_costo DECIMAL(12,2) NOT NULL,
    especificaciones JSONB, 
    eliminado_at TIMESTAMP DEFAULT NULL
);

CREATE TABLE ventas_cabecera (
    id SERIAL PRIMARY KEY,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total DECIMAL(12,2) DEFAULT 0,
    metodo_pago VARCHAR(50)
);

CREATE TABLE ventas_detalle (
    id BIGSERIAL PRIMARY KEY,
    id_venta INT REFERENCES ventas_cabecera(id),
    id_producto INT REFERENCES productos(id),
    cantidad INT NOT NULL,
    precio_unitario_cobrado DECIMAL(12,2) NOT NULL
);

CREATE TABLE promociones (
    id SERIAL PRIMARY KEY,
    id_producto INT REFERENCES productos(id),
    descuento_pct DECIMAL(5,2),
    vigencia DATERANGE 
);
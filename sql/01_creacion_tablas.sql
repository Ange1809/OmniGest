-- =============================================================================
-- ARCHIVO: 01_creacion_tablas.sql
-- DESCRIPCIÓN: Definición de estructura base y hardening de OmniGest
-- =============================================================================

-- 1. Extensiones necesarias (Requisito B de la Parte 1/2)
CREATE EXTENSION IF NOT EXISTS btree_gist; [cite: 500]
CREATE EXTENSION IF NOT EXISTS pg_stat_statements; -- Caja negra de rendimiento [cite: 150, 249]

-- 2. Estructura de tablas
CREATE TABLE categorias (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    id_padre INT REFERENCES categorias(id) ON DELETE CASCADE -- Jerarquía recursiva [cite: 57]
);

CREATE TABLE productos (
    id SERIAL PRIMARY KEY,
    sku VARCHAR(50) UNIQUE NOT NULL,
    codigo_barras VARCHAR(50) NOT NULL,
    nombre VARCHAR(200) NOT NULL,
    id_categoria INT REFERENCES categorias(id),
    precio_costo DECIMAL(12,2) NOT NULL,
    especificaciones JSONB, -- Atributos dinámicos (Clase 4) [cite: 418, 488]
    eliminado_at TIMESTAMP DEFAULT NULL
);

CREATE TABLE ventas_cabecera (
    id SERIAL PRIMARY KEY,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total DECIMAL(12,2) DEFAULT 0,
    metodo_pago VARCHAR(50) CHECK (metodo_pago IN ('Efectivo', 'Debito', 'QR', 'Credito')) -- Blindaje de datos [cite: 738]
);

CREATE TABLE ventas_detalle (
    id BIGSERIAL PRIMARY KEY, -- Soporte para alta volumetría [cite: 166]
    id_venta INT REFERENCES ventas_cabecera(id) ON DELETE CASCADE,
    id_producto INT REFERENCES productos(id),
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario_cobrado DECIMAL(12,2) NOT NULL
);

CREATE TABLE promociones (
    id SERIAL PRIMARY KEY,
    id_producto INT REFERENCES productos(id),
    descuento_pct DECIMAL(5,2),
    vigencia DATERANGE NOT NULL, -- Manejo de estados de tiempo [cite: 500]
    EXCLUDE USING gist (id_producto WITH =, vigencia WITH &&) -- Evita solapamiento de promos
);

-- 3. Capa de Auditoría y Forense de Datos (Requisito C - Parte 2)
CREATE TABLE audit_logs (
    id SERIAL PRIMARY KEY,
    fecha TIMESTAMPTZ DEFAULT NOW(),
    usuario TEXT DEFAULT current_user,
    codigo_error TEXT, -- Almacena RETURNED_SQLSTATE [cite: 761, 1003]
    mensaje_error TEXT, -- Almacena MESSAGE_TEXT [cite: 764, 1003]
    contexto_error TEXT -- Almacena el Stack Trace [cite: 770]
);
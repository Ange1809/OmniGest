-- 1. Extensiones necesarias
CREATE EXTENSION IF NOT EXISTS btree_gist; -- Para DATERANGE en promociones
CREATE EXTENSION IF NOT EXISTS pg_stat_statements; -- Para auditoría de rendimiento [cite: 248, 250]

-- 2. Categorías (Jerarquía Recursiva) [cite: 57, 58]
CREATE TABLE categorias (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    id_padre INT REFERENCES categorias(id) ON DELETE CASCADE -- Borrado en cascada para evitar registros huérfanos
);

-- 3. Productos (Uso de JSONB para flexibilidad) [cite: 418, 488]
CREATE TABLE productos (
    id SERIAL PRIMARY KEY,
    sku VARCHAR(50) UNIQUE NOT NULL,
    codigo_barras VARCHAR(50) NOT NULL,
    nombre VARCHAR(200) NOT NULL,
    id_categoria INT REFERENCES categorias(id),
    precio_costo DECIMAL(12,2) NOT NULL,
    especificaciones JSONB, -- Ideal para atributos variables de supermercado [cite: 488]
    eliminado_at TIMESTAMP DEFAULT NULL
);

-- 4. Ventas Cabecera
CREATE TABLE ventas_cabecera (
    id SERIAL PRIMARY KEY,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total DECIMAL(12,2) DEFAULT 0,
    metodo_pago VARCHAR(50) CHECK (metodo_pago IN ('Efectivo', 'Debito', 'QR', 'Credito')) -- Restricción para integridad de datos
);

-- 5. Ventas Detalle (Uso de BIGSERIAL por volumetría) [cite: 76]
CREATE TABLE ventas_detalle (
    id BIGSERIAL PRIMARY KEY,
    id_venta INT REFERENCES ventas_cabecera(id) ON DELETE CASCADE,
    id_producto INT REFERENCES productos(id),
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario_cobrado DECIMAL(12,2) NOT NULL
);

-- 6. Promociones (Patrón de Históricos/Vigencia) [cite: 8, 10]
CREATE TABLE promociones (
    id SERIAL PRIMARY KEY,
    id_producto INT REFERENCES productos(id),
    descuento_pct DECIMAL(5,2),
    vigencia DATERANGE NOT NULL, -- Uso de DATERANGE para evitar solapamientos
    EXCLUDE USING gist (id_producto WITH =, vigencia WITH &&) -- Evita dos promos activas para el mismo producto [cite: 500, 507]
);

-- 7. Tabla de Auditoría Forense (Caja Negra) [cite: 778, 779]
CREATE TABLE audit_logs (
    id SERIAL PRIMARY KEY,
    fecha TIMESTAMPTZ DEFAULT NOW(),
    usuario TEXT DEFAULT current_user,
    codigo_error TEXT,
    mensaje_error TEXT,
    contexto_error TEXT
);
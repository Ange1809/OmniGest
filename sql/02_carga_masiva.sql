-- =============================================================================
-- ARCHIVO: 02_carga_masiva.sql
-- DESCRIPCIÓN: Set-based data insertion (Optimización de un millón de registros)
-- =============================================================================

BEGIN; -- Agrupamos en un solo bloque para evitar I/O masivo en disco [cite: 708, 859]

-- 1. CARGA DE CATEGORÍAS
INSERT INTO categorias (nombre, id_padre) VALUES ('Almacen General', NULL);

INSERT INTO categorias (nombre, id_padre) 
SELECT 'Subcategoría ' || i, 1 
FROM generate_series(1, 9) i; -- Generador lógico de filas [cite: 169]

-- 2. CARGA DE PRODUCTOS
INSERT INTO productos (sku, codigo_barras, nombre, id_categoria, precio_costo)
SELECT 
    'SKU-' || i, 
    'BAR-' || (100000 + i), 
    'Producto ' || i, 
    (SELECT id FROM categorias ORDER BY RANDOM() LIMIT 1), -- Subconsulta escalar aleatoria [cite: 175]
    floor(random() * (5000 - 100 + 1) + 100)::DECIMAL(12,2) -- Fórmula matemática de negocio [cite: 185, 189]
FROM generate_series(1, 200000) i;

-- 3. CARGA DE CABECERAS
INSERT INTO ventas_cabecera (fecha, total, metodo_pago)
SELECT 
    NOW() - (random() * INTERVAL '730 days'), 
    0, 
    (ARRAY['Efectivo', 'Debito', 'QR', 'Credito'])[floor(random() * 4) + 1]
FROM generate_series(1, 200000) i;

-- 4. CARGA DEL MILLÓN (Detalles de Ventas masivas)
INSERT INTO ventas_detalle (id_venta, id_producto, cantidad, precio_unitario_cobrado)
SELECT 
    (floor(random() * 200000) + 1)::INT, 
    (SELECT id FROM productos ORDER BY RANDOM() LIMIT 1), -- Garantiza integridad referencial [cite: 183]
    floor(random() * 10 + 1)::INT,
    floor(random() * (8000 - 150 + 1) + 150)::DECIMAL(12,2)
FROM generate_series(1, 800000) i;

-- Verification block (Reporte de salud de la carga masiva)
SELECT 
    (SELECT COUNT(*) FROM categorias) AS total_categorias,
    (SELECT COUNT(*) FROM productos) AS total_productos,
    (SELECT COUNT(*) FROM ventas_detalle) AS total_registros_del_millon; [cite: 194]

COMMIT; -- Cierre atómico [cite: 839]
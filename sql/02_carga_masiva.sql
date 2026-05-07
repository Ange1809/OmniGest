-- Envolvemos en una sola transacción para minimizar el costo de I/O [cite: 82, 88]
BEGIN;

-- 1. CATEGORÍAS (Carga en bloque) [cite: 167, 169]
INSERT INTO categorias (nombre, id_padre) VALUES ('Almacen General', NULL);

INSERT INTO categorias (nombre, id_padre) 
SELECT 'Subcategoría ' || i, 1 
FROM generate_series(1, 9) i;

-- 2. PRODUCTOS (Simulación de datos realistas) [cite: 185]
INSERT INTO productos (sku, codigo_barras, nombre, id_categoria, precio_costo)
SELECT 
    'SKU-' || i, 
    'BAR-' || (100000 + i), 
    'Producto ' || i, 
    (SELECT id FROM categorias ORDER BY RANDOM() LIMIT 1), -- Integridad referencial garantizada [cite: 177, 183]
    floor(random() * (5000 - 100 + 1) + 100)::DECIMAL(12,2) -- Fórmula (Max - Min + 1) + Min 
FROM generate_series(1, 200000) i;

-- 3. VENTAS CABECERA (Fechas aleatorias SARGables) [cite: 90, 96]
INSERT INTO ventas_cabecera (fecha, total, metodo_pago)
SELECT 
    NOW() - (random() * INTERVAL '730 days'), 
    0, -- El total se puede calcular luego con un UPDATE o View
    (ARRAY['Efectivo', 'Debito', 'QR', 'Credito'])[floor(random() * 4) + 1]
FROM generate_series(1, 200000) i;

-- 4. CARGA DEL MILLÓN (Detalles con relación cruzada) [cite: 177]
INSERT INTO ventas_detalle (id_venta, id_producto, cantidad, precio_unitario_cobrado)
SELECT 
    (floor(random() * 200000) + 1)::INT, -- Referencia a cabeceras
    (SELECT id FROM productos ORDER BY RANDOM() LIMIT 1), -- Referencia a productos existentes
    floor(random() * 10 + 1)::INT,
    floor(random() * (8000 - 150 + 1) + 150)::DECIMAL(12,2)
FROM generate_series(1, 800000) i;

-- 5. VERIFICACIÓN DE SALUD DE LA CARGA [cite: 193, 194]
SELECT 
    (SELECT COUNT(*) FROM categorias) AS total_categorias,
    (SELECT COUNT(*) FROM productos) AS total_productos,
    (SELECT COUNT(*) FROM ventas_detalle) AS total_detalles_ventas;

COMMIT;
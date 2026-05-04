-- 1 Envolvemos todo en una transacción para que sea ultra rápido
BEGIN;

-- 2. CARGA DE CATEGORÍAS
INSERT INTO categorias (nombre, id_padre) VALUES ('Almacen General', NULL);
INSERT INTO categorias (nombre, id_padre) 
SELECT 'Subcategoría ' || i, 1 FROM generate_series(1, 9) i;

-- 3. CARGA DE PRODUCTOS (Corregido con precio_costo y codigo_barras)
INSERT INTO productos (sku, codigo_barras, nombre, id_categoria, precio_costo)
SELECT 
    'SKU-' || i, 
    'BAR-' || (100000 + i), 
    'Producto ' || i, 
    (floor(random() * 10) + 1)::INT, 
    (random() * 5000 + 100)::DECIMAL(12,2)
FROM generate_series(1, 200000) i;

-- 4. CARGA DE CABECERAS
INSERT INTO ventas_cabecera (fecha, total, metodo_pago)
SELECT 
    NOW() - (random() * INTERVAL '730 days'), 
    0, 
    (ARRAY['Efectivo', 'Debito', 'QR', 'Credito'])[floor(random() * 4) + 1]
FROM generate_series(1, 200000) i;

-- 5. CARGA DEL MILLÓN (Detalles)
INSERT INTO ventas_detalle (id_venta, id_producto, cantidad, precio_unitario_cobrado)
SELECT 
    (floor(random() * 200000) + 1)::INT, 
    (floor(random() * 200000) + 1)::INT, 
    (floor(random() * 10) + 1)::INT,
    (random() * 8000 + 150)::DECIMAL(12,2)
FROM generate_series(1, 800000) i;

COMMIT;


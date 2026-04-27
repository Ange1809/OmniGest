-- Envolvemos todo en una transacción para que sea ultra rápido
BEGIN;

-- 1. Cargar 10 Categorías Recursivas (1 raíz, 9 hijas)
INSERT INTO categorias (nombre, id_padre) VALUES ('Almacen General', NULL);
INSERT INTO categorias (nombre, id_padre)
SELECT 'Subcategoría ' || i, 1 FROM generate_series(1, 9) i;

-- 2. Cargar 200.000 Productos (Inyectando JSONB aleatorio)
INSERT INTO productos (sku, codigo_barras, nombre, id_categoria, precio_costo, especificaciones)
SELECT 
    'SKU-' || i,
    (7790000000000 + i)::VARCHAR,
    'Producto OmniGest ' || i,
    (floor(random() * 10) + 1)::INT, -- Asigna ID categoría del 1 al 10
    (random() * 5000 + 100)::DECIMAL(12,2),
    jsonb_build_object(
        'marca', 'Marca_' || (floor(random() * 50) + 1)::INT,
        'peso', (floor(random() * 5) + 1)::TEXT || 'kg',
        'origen', (ARRAY['Argentina', 'Brasil', 'Chile'])[floor(random() * 3) + 1]
    )
FROM generate_series(1, 200000) i;

-- 3. Cargar 200.000 Cabeceras de Ventas (Histórico de 2 años)
INSERT INTO ventas_cabecera (fecha, total, metodo_pago)
SELECT 
    NOW() - (random() * INTERVAL '730 days'),
    0, -- El total real se calcularía con un trigger, lo dejamos en 0 por ahora
    (ARRAY['Efectivo', 'Debito', 'QR', 'Credito'])[floor(random() * 4) + 1]
FROM generate_series(1, 200000) i;

-- 4. Cargar 800.000 Detalles de Venta (Completando el Millón de Registros)
INSERT INTO ventas_detalle (id_venta, id_producto, cantidad, precio_unitario_cobrado)
SELECT 
    (floor(random() * 200000) + 1)::INT, -- Relaciona con las cabeceras
    (floor(random() * 200000) + 1)::INT, -- Relaciona con los productos
    (floor(random() * 10) + 1)::INT,
    (random() * 8000 + 150)::DECIMAL(12,2)
FROM generate_series(1, 800000) i;

COMMIT;
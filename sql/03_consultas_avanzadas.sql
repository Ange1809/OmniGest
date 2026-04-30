

WITH RECURSIVE arbol_categorias AS (
    -- Caso base: Categorías principales
    SELECT id, nombre, id_padre, 1 AS nivel, nombre::text AS ruta
    FROM categorias
    WHERE id_padre IS NULL
    UNION ALL
    -- Parte recursiva: Buscamos los hijos
    SELECT c.id, c.nombre, c.id_padre, ac.nivel + 1, (ac.ruta || ' > ' || c.nombre)
    FROM categorias c
    JOIN arbol_categorias ac ON c.id_padre = ac.id
)
SELECT * FROM arbol_categorias ORDER BY ruta;

SELECT 
    categoria, 
    producto, 
    total_recaudado,
    RANK() OVER (PARTITION BY categoria_id ORDER BY total_recaudado DESC) as puesto
FROM (
    SELECT 
        c.nombre as categoria, 
        p.nombre as producto, 
        c.id as categoria_id, 
        SUM(vd.cantidad * vd.precio_unitario_cobrado) as total_recaudado
    FROM ventas_detalle vd 
    JOIN productos p ON vd.id_producto = p.id 
    JOIN categorias c ON p.id_categoria = c.id
    GROUP BY c.id, c.nombre, p.id, p.nombre
) sub
WHERE total_recaudado > 0
LIMIT 20; -- Mostramos los primeros para probar

-- REPORTE DE VENTAS TOTALES POR CATEGORÍA (NIVEL JERÁRQUICO)
EXPLAIN ANALYZE
SELECT 
    c.nombre AS categoria,
    SUM(vd.cantidad) AS unidades_vendidas,
    SUM(vd.cantidad * vd.precio_unitario_cobrado) AS total_recaudado
FROM categorias c
JOIN productos p ON c.id = p.id_categoria
JOIN ventas_detalle vd ON p.id = vd.id_producto
GROUP BY c.nombre
ORDER BY total_recaudado DESC;


-- REPORTE DE VENTAS CON PROMOCIÓN ACTIVA
EXPLAIN ANALYZE
SELECT 
    p.nombre AS producto,
    pr.descuento_pct AS porcentaje_aplicado,
    COUNT(vd.id) AS cantidad_ventas,
    SUM(vd.cantidad * vd.precio_unitario_cobrado) AS total_por_promo
FROM productos p
JOIN promociones pr ON p.id = pr.id_producto
JOIN ventas_detalle vd ON p.id = vd.id_producto
JOIN ventas_cabecera vc ON vd.id_venta = vc.id -- Filtramos ventas que ocurrieron dentro de la vigencia de la promo
WHERE vc.fecha::date <@ pr.vigencia
GROUP BY p.nombre, pr.descuento_pct
ORDER BY total_por_promo DESC;

-- Insertamos una promo para el producto 1 que dure todo el 2026
INSERT INTO promociones (id_producto, descuento_pct, vigencia)
VALUES (1, 15.00, '[2026-01-01, 2026-12-31]');


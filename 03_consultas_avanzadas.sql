

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
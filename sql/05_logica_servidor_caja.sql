CREATE OR REPLACE PROCEDURE sp_procesar_venta_completa(
    p_cliente_id INT,
    p_id_producto INT,
    p_cantidad INT
)
AS $$
DECLARE
    v_id_venta INT;
    v_precio_costo NUMERIC;
BEGIN
    -- 1. Iniciar cabecera
    INSERT INTO ventas_cabecera (fecha, total, cliente_id, metodo_pago)
    VALUES (CURRENT_TIMESTAMP, 0, p_cliente_id, 'Efectivo')
    RETURNING id INTO v_id_venta;

    -- 2. Obtener precio
    SELECT precio_costo INTO v_precio_costo FROM productos WHERE id = p_id_producto;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Producto % no existe', p_id_producto;
    END IF;

    -- 3. Insertar detalle (Si falla, el bloque EXCEPTION lo captura sin tumbar la cabecera)
    BEGIN
        INSERT INTO ventas_detalle (id_venta, id_producto, cantidad, precio_unitario_cobrado)
        VALUES (v_id_venta, p_id_producto, p_cantidad, v_precio_costo);
    EXCEPTION WHEN OTHERS THEN
        INSERT INTO audit_logs (mensaje_error) VALUES ('Fallo en detalle: ' || SQLERRM);
        -- Aquí NO pongas ROLLBACK, deja que el EXCEPTION actúe solo
    END;

    -- 4. Actualizar total
    UPDATE ventas_cabecera 
    SET total = (SELECT COALESCE(SUM(cantidad * precio_unitario_cobrado), 0) FROM ventas_detalle WHERE id_venta = v_id_venta)
    WHERE id = v_id_venta;

    -- El COMMIT se hace desde Node.js o se deja al finalizar el procedimiento si no hay errores
    -- En procedimientos de Postgres, si no hay errores, se hace el commit automático.
END;
$$ LANGUAGE plpgsql;
-- =============================================================================
-- ARCHIVO: 05_logica_servidor_caja.sql
-- DESCRIPCIÓN: Capa procedural de Facturación, Excepciones y Hardening (Angelica)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- REQUISITO A y D: FUNCIÓN DE CÁLCULO DE IVA (Blindada)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_calcular_iva(p_monto NUMERIC)
RETURNS NUMERIC
AS $$
BEGIN
    RETURN p_monto * 0.21;
END;
$$ LANGUAGE plpgsql
IMMUTABLE -- Optimización: valor constante puro
SECURITY DEFINER -- Principio de privilegio mínimo
SET search_path = public;


-- -----------------------------------------------------------------------------
-- REQUISITO A, B y C: PROCEDIMIENTO DE FACTURACIÓN COMPLEJA
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_procesar_venta_completa(
    p_metodo_pago ventas_cabecera.metodo_pago%TYPE, -- Robustez mediante %TYPE
    p_id_producto productos.id%TYPE,
    p_cantidad INT,
    OUT p_exito BOOLEAN,
    OUT p_mensaje TEXT
)
AS $$
DECLARE
    v_id_venta ventas_cabecera.id%TYPE;
    v_precio_costo productos.precio_costo%TYPE;
    
    -- Variables forenses para auditoría (Requisito C)
    v_sqlstate TEXT;
    v_message TEXT;
    v_context TEXT;
BEGIN
    p_exito := FALSE;

    -- 1. Iniciar cabecera de la factura
    INSERT INTO ventas_cabecera (fecha, total, metodo_pago)
    VALUES (CURRENT_TIMESTAMP, 0, p_metodo_pago)
    RETURNING id INTO v_id_venta;

    -- 2. Obtención dinámica de datos del producto
    SELECT precio_costo INTO v_precio_costo FROM productos WHERE id = p_id_producto;

    IF v_precio_costo IS NULL THEN
        RAISE EXCEPTION 'Código de producto (%) inválido o inexistente.', p_id_producto;
    END IF;

    -- 3. SUB-BLOQUE SEGURO (PostgreSQL crea un SAVEPOINT implícito aquí)
    BEGIN
        INSERT INTO ventas_detalle (id_venta, id_producto, cantidad, precio_unitario_cobrado)
        VALUES (v_id_venta, p_id_producto, p_cantidad, v_precio_costo);
        
    EXCEPTION WHEN OTHERS THEN
        -- Al entrar aquí, PostgreSQL YA HIZO el rollback automático al inicio del sub-bloque.
        -- No hace falta (ni se permite) escribir ROLLBACK TO SAVEPOINT de forma manual.
        
        -- Extracción de metadatos forenses del error (Requisito C)
        GET STACKED DIAGNOSTICS 
            v_sqlstate = RETURNED_SQLSTATE,
            v_message = MESSAGE_TEXT,
            v_context = PG_EXCEPTION_CONTEXT;

        -- Logueo persistente en la caja negra sin tumbar la cabecera
        INSERT INTO audit_logs (codigo_error, mensaje_error, contexto_error)
        VALUES (v_sqlstate, 'Fallo controlado en detalle: ' || v_message, v_context);
        
        RAISE NOTICE 'Transacción secundaria recuperada exitosamente vía Savepoint automático.';
    END;

    -- 4. Sincronización del total macro de la venta
    UPDATE ventas_cabecera 
    SET total = (SELECT COALESCE(SUM(cantidad * precio_unitario_cobrado), 0) FROM ventas_detalle WHERE id_venta = v_id_venta)
    WHERE id = v_id_venta;

    COMMIT; -- Confirmación física en almacenamiento
    p_exito := TRUE;
    p_mensaje := 'Factura emitida con éxito. ID: ' || v_id_venta;

EXCEPTION WHEN OTHERS THEN
    ROLLBACK; -- Botón de pánico transaccional (Si muere la cabecera)
    
    GET STACKED DIAGNOSTICS 
        v_sqlstate = RETURNED_SQLSTATE,
        v_message = MESSAGE_TEXT,
        v_context = PG_EXCEPTION_CONTEXT;

    INSERT INTO audit_logs (codigo_error, mensaje_error, contexto_error)
    VALUES (v_sqlstate, 'CRITICAL ABORT: ' || v_message, v_context);

    p_exito := FALSE;
    p_mensaje := 'Error transaccional en el servidor. Proceso revertido por seguridad. Código: ' || v_sqlstate;
END;
$$ LANGUAGE plpgsql;


-- -----------------------------------------------------------------------------
-- REQUISITO E: AUTOMATIZACIÓN REACTIVA MEDIANTE TRIGGERS
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_auditar_productos_seguros()
RETURNS TRIGGER AS $$
BEGIN
    NEW.sku := UPPER(NEW.sku);

    IF NEW.precio_costo <= 0 THEN
        RAISE EXCEPTION 'Violación de consistencia: El precio del producto no puede ser negativo o cero.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Dropeamos por seguridad antes de crear para evitar conflictos en pgAdmin
DROP TRIGGER IF EXISTS trg_auditar_productos_seguros ON productos;

CREATE TRIGGER trg_auditar_productos_seguros
BEFORE INSERT ON productos 
FOR EACH ROW
EXECUTE FUNCTION fn_trg_auditar_productos_seguros();



-- Prueba una venta con cantidad negativa para ver cómo actúa el savepoint automático
CALL sp_procesar_venta_completa('Efectivo'::varchar, 1, -5, NULL, NULL);

-- Revisa que la cabecera se guardó y el error quedó registrado en tu bitácora
SELECT * FROM audit_logs ORDER BY fecha DESC LIMIT 1;
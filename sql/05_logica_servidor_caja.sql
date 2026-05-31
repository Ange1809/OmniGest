-- =============================================================================
-- ARCHIVO: 03_logica_servidor_caja.sql
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
IMMUTABLE -- Optimización extrema: el valor nunca cambia lógicamente [cite: 818, 993]
SECURITY DEFINER -- Ejecución controlada (Privilegio Mínimo) [cite: 1006]
SET search_path = public; -- Previene ataques de escalada de privilegios [cite: 1007]


-- -----------------------------------------------------------------------------
-- REQUISITO A, B y C: PROCEDIMIENTO DE FACTURACIÓN COMPLEJA
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_procesar_venta_completa(
    p_metodo_pago ventas_cabecera.metodo_pago%TYPE, -- Robustez mediante %TYPE [cite: 668, 995]
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

    -- 3. SAVEPOINT para evitar abortar toda la transacción ante fallos parciales
    SAVEPOINT sv_registro_detalle; [cite: 845, 999]

    BEGIN
        INSERT INTO ventas_detalle (id_venta, id_producto, cantidad, precio_unitario_cobrado)
        VALUES (v_id_venta, p_id_producto, p_cantidad, v_precio_costo);
        
        RELEASE SAVEPOINT sv_registro_detalle; [cite: 847]
        
    EXCEPTION WHEN OTHERS THEN
        ROLLBACK TO SAVEPOINT sv_registro_detalle; -- Sub-rollback transaccional [cite: 754, 846]
        
        -- Extracción de metadatos forenses del error (Requisito C)
        GET STACKED DIAGNOSTICS 
            v_sqlstate = RETURNED_SQLSTATE, [cite: 761, 783]
            v_message = MESSAGE_TEXT, [cite: 764, 783]
            v_context = PG_EXCEPTION_CONTEXT; [cite: 770, 783]

        -- Logueo persistente sin tumbar la operación completa [cite: 775]
        INSERT INTO audit_logs (codigo_error, mensaje_error, contexto_error)
        VALUES (v_sqlstate, 'Fallo controlado en detalle: ' || v_message, v_context);
        
        RAISE NOTICE 'Transacción secundaria recuperada vía Savepoint.';
    END;

    -- 4. Sincronización del total macro de la venta [cite: 529]
    UPDATE ventas_cabecera 
    SET total = (SELECT COALESCE(SUM(cantidad * precio_unitario_cobrado), 0) FROM ventas_detalle WHERE id_venta = v_id_venta)
    WHERE id = v_id_venta;

    COMMIT; -- Confirmación física en almacenamiento [cite: 839, 998]
    p_exito := TRUE;
    p_mensaje := 'Factura emitida con éxito. ID: ' || v_id_venta;

EXCEPTION WHEN OTHERS THEN
    ROLLBACK; -- Botón de pánico transaccional (Consistencia Total) [cite: 840, 998]
    
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
    -- Normalización imperativa mediante pseudovariables (NEW)
    NEW.sku := UPPER(NEW.sku); [cite: 1011]

    -- Validación preventiva estricta (BEFORE INSERT) [cite: 1010]
    IF NEW.precio_costo <= 0 THEN
        RAISE EXCEPTION 'Violación de consistencia: El precio del producto no puede ser negativo o cero.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auditar_productos_seguros
BEFORE INSERT ON productos -- Intercepción DML por cada fila [cite: 1009, 1010]
FOR EACH ROW
EXECUTE FUNCTION fn_trg_auditar_productos_seguros();
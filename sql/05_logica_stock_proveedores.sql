-- ============================================================================
-- PARTE 2: LÓGICA DE NEGOCIO - STOCK Y PROVEEDORES (Por Mauro)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- CAPA DE AUDITORÍA: Tabla de Logs para Errores
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_logs (
    id SERIAL PRIMARY KEY,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    proceso VARCHAR(100),
    sql_state VARCHAR(10),
    mensaje_error TEXT,
    usuario VARCHAR(50) DEFAULT CURRENT_USER
);

-- ----------------------------------------------------------------------------
-- FUNCIÓN ORIENTADA A VALORES (Control de Volatilidad)
-- Calcula el costo total de stock de un producto específico.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_calcular_valor_inventario(p_producto_id INT)
RETURNS DECIMAL(12,2)
STABLE 
AS $$
DECLARE
    v_precio_costo productos.precio_costo%TYPE;
    v_cantidad_total INT;
BEGIN
    SELECT precio_costo INTO v_precio_costo FROM productos WHERE id = p_producto_id;
    
    SELECT COALESCE(SUM(cantidad), 0) INTO v_cantidad_total FROM ventas_detalle WHERE id_producto = p_producto_id;
    
    RETURN (v_precio_costo * v_cantidad_total);
END;
$$ LANGUAGE plpgsql;


-- ----------------------------------------------------------------------------
-- PROCEDIMIENTO ALMACENADO COMPLEJO + TRANSACCIONES + HARDENING
-- Proceso crítico: Reabastecer stock de un proveedor y actualizar costos
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE pr_registrar_ingreso_stock(
    p_producto_id INT,
    p_cuit_proveedor VARCHAR,
    p_cantidad INT,
    p_nuevo_costo DECIMAL
)
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_prov_record proveedores%ROWTYPE;
    v_costo_viejo productos.precio_costo%TYPE;
    v_err_state TEXT;
    v_err_msg TEXT;
BEGIN
    SELECT * INTO v_prov_record FROM proveedores WHERE cuit = p_cuit_proveedor;
    
    IF v_prov_record.id IS NULL THEN
        RAISE EXCEPTION 'El proveedor con CUIT % no está registrado.', p_cuit_proveedor;
    END IF;

    -- En PL/pgSQL, el inicio de un bloque BEGIN/EXCEPTION ya actúa como un Savepoint automático.
    -- Si algo falla aquí adentro, Postgres limpia este bloque solo sin abortar el procedimiento entero.
    BEGIN
        SELECT precio_costo INTO v_costo_viejo FROM productos WHERE id = p_producto_id;

        UPDATE productos 
        SET precio_costo = p_nuevo_costo 
        WHERE id = p_producto_id;

        INSERT INTO auditoria_precios (id_producto, precio_viejo, precio_nuevo)
        VALUES (p_producto_id, v_costo_viejo, p_nuevo_costo);

    EXCEPTION WHEN OTHERS THEN
        -- Capturamos el error de forma forense
        GET STACKED DIAGNOSTICS 
            v_err_state = RETURNED_SQLSTATE,
            v_err_msg = MESSAGE_TEXT;
            
        INSERT INTO audit_logs (proceso, sql_state, mensaje_error)
        VALUES ('INGRESO STOCK - ACTUALIZAR COSTO', v_err_state, v_err_msg);
    END;

EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS 
        v_err_state = RETURNED_SQLSTATE,
        v_err_msg = MESSAGE_TEXT;
        
    INSERT INTO audit_logs (proceso, sql_state, mensaje_error)
    VALUES ('INGRESO STOCK - CRÍTICO', v_err_state, v_err_msg);
    
    RAISE INFO 'Proceso abortado de forma segura. Detalle guardado en audit_logs.';
END;
$$ LANGUAGE plpgsql;


-- ----------------------------------------------------------------------------
-- AUTOMATIZACIÓN CON TRIGGERS (Variables de Estado)
-- Trigger BEFORE que valida que las especificaciones JSONB de stock traigan marca
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_validar_proveedor_producto()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.especificaciones IS NULL OR NOT (NEW.especificaciones ? 'marca') THEN
        NEW.especificaciones = jsonb_build_object('marca', 'Sin Proveedor Asignado', 'origen', 'Desconocido');
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_validar_producto_stock
BEFORE INSERT OR UPDATE ON productos
FOR EACH ROW
EXECUTE FUNCTION fn_trg_validar_proveedor_producto();
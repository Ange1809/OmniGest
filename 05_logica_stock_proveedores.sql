-- ============================================================================
-- PARTE 2: LÓGICA DE NEGOCIO - STOCK Y PROVEEDORES (Por Mauro)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- ENTREGABLE C: Capa de Auditoría - Tabla de Logs para Errores [cite: 17, 19]
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
-- ENTREGABLE A: FUNCIÓN ORIENTADA A VALORES (Control de Volatilidad) [cite: 7, 9]
-- Calcula el costo total de stock de un producto específico.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_calcular_valor_inventario(p_producto_id INT)
RETURNS DECIMAL(12,2)
-- STABLE porque consulta las tablas pero no modifica datos (Optimiza CPU) [cite: 10, 32]
STABLE 
AS $$
DECLARE
    v_precio_costo productos.precio_costo%TYPE; -- Robustez de tipos (%TYPE) [cite: 12]
    v_cantidad_total INT;
BEGIN
    -- Obtenemos el precio de costo actual
    SELECT precio_costo INTO v_precio_costo FROM productos WHERE id = p_producto_id;
    
    -- Simulamos la cantidad sumando los detalles (en un caso real leería una tabla stock)
    SELECT COALESCE(SUM(cantidad), 0) INTO v_cantidad_total FROM ventas_detalle WHERE id_producto = p_producto_id;
    
    RETURN (v_precio_costo * v_cantidad_total);
END;
$$ LANGUAGE plpgsql;


-- ----------------------------------------------------------------------------
-- ENTREGABLE A, B y D: PROCEDIMIENTO ALMACENADO COMPLEJO + TRANSACCIONES + HARDENING [cite: 11, 13, 21]
-- Proceso crítico: Reabastecer stock de un proveedor y actualizar costos [cite: 11]
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE pr_registrar_ingreso_stock(
    p_producto_id INT,
    p_cuit_proveedor VARCHAR,
    p_cantidad INT,
    p_nuevo_costo DECIMAL
)
-- HARDENING: Evita escalada de privilegios fijando explícitamente el search_path [cite: 21, 24]
SECURITY DEFINER [cite: 23]
SET search_path = public [cite: 24]
AS $$
DECLARE
    v_prov_record proveedores%ROWTYPE; -- Robustez de tipos (%ROWTYPE) [cite: 12]
    v_costo_viejo productos.precio_costo%TYPE; -- [cite: 12]
    
    -- Variables para captura forense de datos [cite: 17, 20]
    v_err_state TEXT;
    v_err_msg TEXT;
BEGIN
    -- CONTROL DE TRANSACCIÓN: Iniciamos bloque seguro [cite: 13, 14]
    -- Buscamos si el proveedor existe
    SELECT * INTO v_prov_record FROM proveedores WHERE cuit = p_cuit_proveedor;
    
    IF v_prov_record.id IS NULL THEN
        RAISE EXCEPTION 'El proveedor con CUIT % no está registrado.', p_cuit_proveedor;
    END IF;

    -- SAVEPOINT: Punto de recuperación parcial por si falla la actualización del costo [cite: 16]
    SAVEPOINT sp_actualizacion_producto; [cite: 16]

    BEGIN
        -- Guardamos costo viejo para auditoría
        SELECT precio_costo INTO v_costo_viejo FROM productos WHERE id = p_producto_id;

        -- Actualizamos el costo del producto
        UPDATE productos 
        SET precio_costo = p_nuevo_costo 
        WHERE id = p_producto_id;

        -- Registramos en la tabla de auditoría de precios
        INSERT INTO auditoria_precios (id_producto, precio_viejo, precio_nuevo)
        VALUES (p_producto_id, v_costo_viejo, p_nuevo_costo);

    EXCEPTION WHEN OTHERS THEN
        -- ENTREGABLE B: Manejo de errores parciales. Si falla el costo, volvemos atrás pero no abortamos todo [cite: 16]
        ROLLBACK TO SAVEPOINT sp_actualizacion_producto; [cite: 16]
        
        -- CAPTURA FORENSE: Registramos el fallo en la tabla de logs [cite: 17, 20]
        GET STACKED DIAGNOSTICS [cite: 20]
            v_err_state = RETURNED_SQLSTATE, [cite: 20]
            v_err_msg = MESSAGE_TEXT; [cite: 20]
            
        INSERT INTO audit_logs (proceso, sql_state, mensaje_error) [cite: 19]
        VALUES ('INGRESO STOCK - ACTUALIZAR COSTO', v_err_state, v_err_msg);
    END;

    -- Si todo el proceso principal fue exitoso, confirmamos la transacción de forma atómica [cite: 15]
    COMMIT; [cite: 15]

EXCEPTION WHEN OTHERS THEN
    -- Si el error fue catastrófico (ej: no existía el proveedor), deshacemos todo [cite: 15]
    ROLLBACK; [cite: 15]
    
    GET STACKED DIAGNOSTICS [cite: 20]
        v_err_state = RETURNED_SQLSTATE, [cite: 20]
        v_err_msg = MESSAGE_TEXT; [cite: 20]
        
    INSERT INTO audit_logs (proceso, sql_state, mensaje_error) [cite: 19]
    VALUES ('INGRESO STOCK - CRÍTICO', v_err_state, v_err_msg);
    
    RAISE INFO 'Proceso abortado de forma segura. Detalle guardado en audit_logs.';
END;
$$ LANGUAGE plpgsql;


-- ENTREGABLE E: AUTOMATIZACIÓN CON TRIGGERS (Variables de Estado)
-- Trigger BEFORE que valida que las especificaciones JSONB de stock traigan marca
CREATE OR REPLACE FUNCTION fn_trg_validar_proveedor_producto()
RETURNS TRIGGER AS $$
BEGIN
    -- Uso de la pseudovariable NEW para evaluar los datos entrantes 
    IF NEW.especificaciones IS NULL OR NOT (NEW.especificaciones ? 'marca') THEN
        -- Asignamos una marca por defecto si viene vacía para asegurar integridad
        NEW.especificaciones = jsonb_build_object('marca', 'Sin Proveedor Asignado', 'origen', 'Desconocido');
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_validar_producto_stock
BEFORE INSERT OR UPDATE ON productos [cite: 26, 27]
FOR EACH ROW
EXECUTE FUNCTION fn_trg_validar_proveedor_producto();
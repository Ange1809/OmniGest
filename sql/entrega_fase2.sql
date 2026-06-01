-- 1. Creamos la función que ejecutará el trigger
CREATE OR REPLACE FUNCTION fn_trg_validar_consistencia_promo()
RETURNS TRIGGER AS $$
BEGIN
    -- Validación 1: Consistencia de Fechas
    IF NEW.fecha_inicio >= NEW.fecha_limite THEN
        RAISE EXCEPTION 'Inconsistencia DML: La fecha de inicio (%) no puede ser mayor o igual a la fecha límite (%).', 
                        NEW.fecha_inicio, NEW.fecha_limite;
    END IF;

    -- Validación 2: Margen del Descuento
    IF NEW.porcentaje <= 0 OR NEW.porcentaje > 100 THEN
        RAISE EXCEPTION 'Inconsistencia DML: El porcentaje de descuento (%) debe ser un valor entre 1 y 100.', 
                        NEW.porcentaje;
    END IF;

    RETURN NEW; -- Si todo está bien, permite que el registro se inserte/actualice
END;
$$ LANGUAGE plpgsql;

-- 2. Creamos el Trigger propiamente dicho
CREATE TRIGGER trg_before_promociones_validacion
BEFORE INSERT OR UPDATE ON promociones
FOR EACH ROW -- Se ejecuta fila por fila afectada
EXECUTE FUNCTION fn_trg_validar_consistencia_promo();
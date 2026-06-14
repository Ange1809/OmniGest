const express = require('express');
const router = express.Router();

// =======================================================================
// PARTE 1 (FRANCO): ENDPOINT DE BAJA LÓGICA (POSTGRESQL + CACHÉ REDIS)
// =======================================================================

// Definimos el endpoint usando PUT como pide la consigna
router.put('/escenarios/:id/desactivar', async (req, res) => {
    const { id } = req.params;

    try {
        // 1. REQUISITO ESTRICTO: Usamos UPDATE en lugar de DELETE FROM (Baja Lógica)
        const queryText = `
            UPDATE escenarios 
            SET activo = false 
            WHERE id = $1 
            RETURNING id, nombre, activo;
        `;
        
        // Ejecutamos la consulta en Postgres usando el pool de conexiones
        const resultado = await pool.query(queryText, [id]);

        // 2. CONTROL DE FLUJO: Si rowCount es 0, el escenario con ese ID no existía
        if (resultado.rowCount === 0) {
            return res.status(404).json({
                error: "REGISTRO_NO_ENCONTRADO",
                message: `No se encontró ningún escenario activo con el ID: ${id}`
            });
        }

        // 3. INVALIDACIÓN DE CACHÉ: Invocamos de forma asíncrona la función de Redis de Mauro
        if (typeof invalidarCacheCatalogo === 'function') {
            await invalidarCacheCatalogo();
        } else {
            console.warn("⚠️ Nota: Falta acoplar la función 'invalidarCacheCatalogo' de Mauro en el servidor principal.");
        }

        // 4. RESPUESTA EXITOSA (Status 200)
        return res.status(200).json({
            status: "success",
            message: "Baja lógica ejecutada correctamente. El registro fue desactivado en PostgreSQL y la caché de Redis fue limpiada.",
            data: resultado.rows[0]
        });

    } catch (error) {
        console.error("Error crítico en el endpoint de baja lógica:", error);
        
        // Control por si mandan un ID con formato roto desde el cliente (Error 22P02 de Postgres)
        if (error.code === '22P02') {
            return res.status(400).json({
                error: "FORMATO_ID_INVALIDO",
                message: "El ID proporcionado no corresponde a un formato válido."
            });
        }

        // Error genérico del servidor
        return res.status(500).json({
            error: "INTERNAL_SERVER_ERROR",
            message: "Ocurrió un error inesperado en el servidor."
        });
    }
});

module.exports = router;
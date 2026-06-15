const dbService = require('../services/db_service');

// Dejamos esto listo para cuando Mauro arme Redis de verdad
const cacheService = {
    limpiarCacheCatalogo: async () => {
        console.log("🧹 Caché invalidada por Redis");
    }
};

const bajaLogica = async (req, res) => {
    try {
        const { id } = req.params;

        // 1. Validar que el ID sea un número entero (Evita el error 400)
        if (!Number.isInteger(Number(id))) {
            return res.status(400).json({ error: 'ID inválido' });
        }

        // 2. Llamar al servicio para cambiar 'activo' a false
        const producto = await dbService.desactivarProducto(id);

        // 3. Si el producto no existía en la base de datos (Evita el error 404)
        if (!producto) {
            return res.status(404).json({ error: 'Producto no encontrado' });
        }

        // 4. Limpieza de caché obligatoria
        await cacheService.limpiarCacheCatalogo();

        // 5. Respuesta exitosa
        return res.status(200).json({ 
            mensaje: 'Producto desactivado correctamente (Baja Lógica)',
            data: producto 
        });

    } catch (error) {
        console.error("Error en bajaLogica de Franco:", error);
        return res.status(500).json({ error: 'Error interno del servidor' });
    }
};

module.exports = {
    bajaLogica
};
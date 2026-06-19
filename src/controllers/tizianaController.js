const dbService = require('../services/db_service');

const cacheService = {
    limpiarCacheCatalogo: async () => {
        console.log("Caché invalidada por Redis");
    }
};

const modificarProducto = async (req, res) => {
    try {
        const { id } = req.params;

        if (!Number.isInteger(Number(id))) {
            return res.status(400).json({
                error: 'ID inválido'
            });
        }

        const datosActualizados = req.body;

        if (!datosActualizados || Object.keys(datosActualizados).length === 0) {
            return res.status(400).json({
                error: 'Debe enviar datos para actualizar'
            });
        }

        const producto = await dbService.actualizarProducto(
            id,
            datosActualizados
        );

        if (!producto) {
            return res.status(404).json({
                error: 'Producto no encontrado'
            });
        }

        await cacheService.limpiarCacheCatalogo();

        return res.status(200).json({
            mensaje: 'Producto actualizado correctamente',
            data: producto
        });

    } catch (error) {
        console.error("Error en modificarProducto:", error);

        return res.status(500).json({
            error: 'Error interno del servidor'
        });
    }
};

module.exports = {
    modificarProducto
};
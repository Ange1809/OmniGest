// =============================================================================
// ARCHIVO: src/controllers/v1_productos_controller.js
// RESPONSABLE: Angélica (Alta - CREATE)
// DESCRIPCIÓN: Controlador para el alta interactiva de productos y limpieza de caché.
// =============================================================================

const dbService = require('../services/db_service');

// === SOLUCIÓN 3: EL STUB / MOCK DE REDIS ===
// Mantenemos este objeto simulado temporalmente para que tu endpoint funcione.
// Cuando Mauro suba su archivo real, solo cambiarás esta línea por un require.
const cacheService = { 
    limpiarCacheCatalogo: async () => {
        console.log("🧹 [Redis Stub] Alerta recibida: Limpiando las llaves 'catalogo:*' de la RAM...");
    } 
}; 

const crearProducto = async (req, res) => {
    try {
        // 1. Extraer los datos del req.body en JSON
        const nuevoProducto = req.body;

        // Validaciones preventivas básicas
        if (!nuevoProducto.sku || !nuevoProducto.precio_costo) {
            return res.status(400).json({ 
                success: false, 
                error: "Faltan campos obligatorios para el alta (sku, precio_costo)." 
            });
        }

        // 2. Ejecutar el INSERT INTO en PostgreSQL (db_service forzará activo = true)
        const productoInsertado = await dbService.insertarProducto(nuevoProducto);

        // 3. SOLUCIÓN 3 EN ACCIÓN: Gatillar la función de Redis de Mauro
        if (cacheService.limpiarCacheCatalogo) {
            await cacheService.limpiarCacheCatalogo();
        }

        // 4. Responder con Status 201 Created y devolver el registro (Requisito estricto)
        return res.status(201).json({
            success: true,
            message: "Producto creado con éxito e inserción validada.",
            data: productoInsertado
        });

    } catch (error) {
        console.error("🚨 Error en el alta de producto:", error);
        return res.status(500).json({ 
            success: false, 
            error: "Error interno del servidor al crear el registro." 
        });
    }
};

module.exports = {
    crearProducto
};
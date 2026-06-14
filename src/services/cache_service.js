const redisClient = require('./redis_connection'); // Usa el conector que ya armó el grupo

const cacheService = {
    /**
     * Invalida de forma iterativa y segura el catálogo en Redis sin usar flushDb
     */
    limpiarCacheCatalogo: async () => {
        try {
            // 1. Buscamos todas las llaves que empiecen con 'catalogo:*'
            const keys = await redisClient.keys('catalogo:*');
            
            // 2. Si existen llaves, las borramos en bloque
            if (keys && keys.length > 0) {
                await redisClient.del(...keys);
                console.log(`🧹 [Redis Real] Se eliminaron ${keys.length} llaves de caché.`);
            } else {
                console.log("🧹 [Redis Real] No se encontraron llaves para invalidar.");
            }
        } catch (error) {
            console.error("❌ [Redis Real] Error crítico en la invalidación:", error);
        }
    }
};

module.exports = cacheService;
// const redisClient = require('./redis_connection'); // ⚠️ COMENTADO TEMPORAL: Falta el archivo de Mauro

// 🛠️ SIMULADOR TEMPORAL DE REDIS (Evita que el servidor se caiga)
const redisClient = {
    keys: async (patron) => {
        // Simulamos que buscamos llaves y no encuentra nada
        return [];
    },
    del: async (...keys) => {
        return 0;
    }
};

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
                console.log(`🧹 [Redis Simulado] Se eliminaron ${keys.length} llaves de caché.`);
            } else {
                console.log("🧹 [Redis Simulado] No se encontraron llaves para invalidar (Simulación activa).");
            }
        } catch (error) {
            console.error("❌ [Redis Real] Error crítico en la invalidación:", error);
        }
    }
};

module.exports = cacheService;
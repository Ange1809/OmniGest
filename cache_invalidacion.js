// =================================================================
// 🧠 MÓDULO DE ARQUITECTURA DE CACHÉ - FASE FINAL
// Desarrollado por: Mauro
// Consigna: Invalidación Selectiva mediante patrón Cache-Aside (Cirujano)
// =================================================================

const redis = require('redis');

// 🔌 Conexión al Redis de Docker (puerto estándar 6379)
const redisClient = redis.createClient({
    url: 'redis://localhost:6379'
});

/**
 * Función centralizada que borra del caché únicamente los datos del catálogo.
 * REQUISITO ESTRICTO: Prohibido usar flushDb(). Mantiene vivas las sesiones de usuario.
 */
async function invalidarCacheCatalogo() {
    console.log("\n🧹 [MAURO] Iniciando proceso de invalidación selectiva...");
    
    try {
        // Aseguramos que la conexión a tu contenedor 'mi_redis' esté abierta
        if (!redisClient.isOpen) {
            await redisClient.connect();
        }

        // 1. Buscamos SOLO las llaves que empiecen con 'catalogo:'
        const patron = 'catalogo:*';
        const llavesEncontradas = await redisClient.keys(patron);

        if (llavesEncontradas.length > 0) {
            console.log(`📌 Se encontraron ${llavesEncontradas.length} llaves viejas en caché:`, llavesEncontradas);
            
            // 2. Borramos de forma quirúrgica solo esas llaves
            await redisClient.del(llavesEncontradas);
            console.log("✨ ¡CACHÉ INVALIDADA! Datos del catálogo limpiados con éxito.");
            console.log("🔒 Seguridad: Las sesiones activas de los usuarios no sufrieron modificaciones.");
        } else {
            console.log("ℹ️ La caché ya estaba limpia. No hay llaves que coincidan con 'catalogo:*'.");
        }

    } catch (error) {
        console.error("🚨 Error crítico en el módulo de caché de Mauro:", error);
    }
}

// 🚀 CÓDIGO DE PRUEBA LOCAL (Para que Mauro verifique que funciona de verdad)
async function pruebaLocal() {
    console.log("🤖 Inicializando simulación de caché por Mauro...");
    try {
        await redisClient.connect();

        // Simulamos que el sistema guardó datos viejos en la RAM
        console.log("💾 Simulando carga de datos en la RAM...");
        await redisClient.set('catalogo:productos', JSON.stringify([{ id: 1, nombre: 'Producto Viejo' }]));
        await redisClient.set('catalogo:categorias', JSON.stringify(['Electrónica', 'Hogar']));
        
        // Simulamos una sesión de usuario que NO DEBE BORRARSE (Tu seguro contra el flushDb)
        await redisClient.set('session:user_123', 'TOKEN_SECRETO_DE_LOGIN');

        // Ejecutamos tu función cirujana
        await invalidarCacheCatalogo();

        // Verificamos que la sesión siga viva en Docker
        const sesionViva = await redisClient.get('session:user_123');
        if (sesionViva) {
            console.log("🏆 PRUEBA COMPLETA: El catálogo se borró pero la sesión sigue intacta. ¡Perfecto!");
        }

        await redisClient.disconnect();
    } catch (e) {
        console.log("⚠️ Nota: Recordá tener prendido tu Docker con 'docker start mi_redis' para probar.");
    }
}

// Ejecutamos la simulación si corremos este archivo suelto
if (require.main === module) {
    pruebaLocal();
}

// Exportamos la función para que Angélica, Franco y Tizi la usen en index.js
module.exports = { invalidarCacheCatalogo };
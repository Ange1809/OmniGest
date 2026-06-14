// =============================================================================
// ARCHIVO: v1_reportes_controller.js
// RESPONSABLE: Angélica (Integración de Endpoints y Serialización)
// DESCRIPCIÓN: Controlador para exponer los reportes de OmniGest con soporte
//              de caché transparente y transformación de datos.
// =============================================================================

const express = require('express');
// Imaginemos que estos son los servicios que programan tus compañeros
const cacheService = require('../services/cache_service'); // El algoritmo Cache-Aside de Mauro
const dbService = require('../services/db_service');      // Consultas directas a Postgres de Tizi/Mauro

/**
 * Control de Calidad y Serialización Segura (Evita fallos de JSON de forma síncrona)
 */
const deserializarDatos = (datosCrudosRedis) => {
    try {
        // Tu tarea crítica: Transformar la cadena JSON plana de Redis a Objeto Nativo JS
        return JSON.parse(datosCrudosRedis);
    } catch (error) {
        console.error("❌ Error de Deserialización: El string de Redis está corrupto o incompleto.", error);
        return null; 
    }
};

const serializarDatos = (objetoDatosPostgres) => {
    try {
        // Tu tarea crítica: Convertir el array/objeto complejo de Postgres a Texto Plano para Redis
        return JSON.stringify(objetoDatosPostgres);
    } catch (error) {
        console.error("❌ Error de Serialización: No se pudo transformar el objeto a String JSON.", error);
        return null;
    }
};

/**
 * Endpoint: GET /api/v1/reportes/promociones-activas
 * Diseño de Clave (Franco): "promociones:activas:list" | TTL: 120s
 */
const getPromocionesActivas = async (req, res) => {
    const CLAVE_REDIS = 'promociones:activas:list';
    const TTL_SEGUNDOS = 120;

    try {
        // 1. Mauro busca en su servicio si la clave ya existe (Cache HIT)
        const cacheData = await cacheService.obtenerDeCache(CLAVE_REDIS);

        if (cacheData) {
            // TU TRABAJO: Si hay HIT, deserializamos el texto plano y respondemos de inmediato (RAM speed)
            const datosParseados = deserializarDatos(cacheData);
            
            if (datosParseados) {
                return res.status(200).json({
                    source: 'Redis Cache (HIT)',
                    total_records: datosParseados.length,
                    data: datosParseados
                });
            }
        }

        // 2. Si hay Cache MISS, vamos a PostgreSQL (Consulta optimizada de la Fase anterior)
        console.log(`⚠️ Cache MISS para la clave: ${CLAVE_REDIS}. Buscando en PostgreSQL...`);
        const datosPostgres = await dbService.consultarPromocionesVigentes();

        // 3. TU TRABAJO: Serializar el resultado para que Mauro lo guarde en Redis antes de que expire el TTL
        const textoParaCache = serializarDatos(datosPostgres);
        if (textoParaCache) {
            await cacheService.guardarEnCache(CLAVE_REDIS, textoParaCache, TTL_SEGUNDOS);
        }

        // 4. Responder al cliente final con los datos frescos
        return res.status(200).json({
            source: 'PostgreSQL Database (MISS)',
            total_records: datosPostgres.length,
            data: datosPostgres
        });

    } catch (error) {
        // Mecanismo de contingencia global coordinado con el Fallback de Tizi
        console.error("🚨 Fallo crítico en el Endpoint de Facturación/Promociones:", error);
        return res.status(500).json({
            success: false,
            message: "Error interno en el servidor de OmniGest.",
            error: error.message
        });
    }
};

module.exports = {
    getPromocionesActivas,
    serializarDatos,
    deserializarDatos
};
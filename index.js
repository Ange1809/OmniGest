// index.js (Corregido)
require('dotenv').config();
const express = require('express');

// Controladores
const productosController = require('./src/controllers/v1_productos_controller');
const francoController = require('./src/controllers/francoController'); // ✅ CORRECCIÓN: Tu controlador importado

const app = express();
app.use(express.json());

// ==========================================
// RUTAS DE LA API (Endpoints)
// ==========================================

// Alta de Datos (Angélica)
app.post('/api/items', productosController.crearProducto);

// ✅ TU PARTE: Baja Lógica (Franco) - ACTIVADA SIN LAS BARRAS
app.put('/api/items/:id/desactivar', francoController.bajaLogica);

// Las rutas de tus compañeros seguirán comentadas hasta que ellos las creen
// app.put('/api/items/:id', tizianaController.modificarProducto);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🚀 Servidor OmniGest corriendo en http://localhost:${PORT}`);
});
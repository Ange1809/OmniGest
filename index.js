// index.js (Corregido)
require('dotenv').config();
const express = require('express');

// CORRECCIÓN: El nombre del archivo ahora coincide exactamente con el físico
const productosController = require('./src/controllers/v1_productos_controller');

const app = express();
app.use(express.json());

// ==========================================
// RUTAS DE LA API (Endpoints)
// ==========================================

// TU PARTE: Alta de Datos (Angélica)
app.post('/api/items', productosController.crearProducto);

// Las rutas de tus compañeros seguirán comentadas hasta que ellos las creen
// app.put('/api/items/:id', tizianaController.modificarProducto);
// app.put('/api/items/:id/desactivar', francoController.bajaLogica);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🚀 Servidor OmniGest corriendo en http://localhost:${PORT}`);
});
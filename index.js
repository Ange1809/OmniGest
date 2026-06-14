// index.js (Corregido)
require('dotenv').config();
const express = require('express');

// CORRECCIÓN: El nombre del archivo ahora coincide exactamente con el físico
const productosController = require('./src/controllers/v1_productos_controller');


const app = express();

// 1. PRIMERO le decimos a Express que traduzca los JSON (req.body)
app.use(express.json()); 

// 2. DESPUÉS declaramos las rutas que van a usar ese req.body
app.post('/api/items', productosController.crearProducto);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🚀 Servidor OmniGest corriendo en http://localhost:${PORT}`);
});
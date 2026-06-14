require('dotenv').config();
const express = require('express');
const cors = require('cors');
const productosController = require('./src/controllers/v1_productos_controller');
const transaccionesController = require('./src/controllers/v1_transacciones_controller');
const dbService = require('./src/services/db_service');

const app = express();

app.use(cors()); // 2. Habilitamos el puente ANTES de las rutas
app.use(express.json());


// ==========================================
// RUTAS DE LA API (Endpoints)
// ==========================================

// TU PARTE: Alta de Datos (Angélica)
app.post('/api/items', productosController.crearProducto);
app.post('/api/transacciones/procesar', transaccionesController.procesarTransaccion);

// Reportes
app.get('/api/reportes/total-facturado', async (req, res) => {
    try {
        const total = await dbService.obtenerTotalFacturado();
        res.status(200).json({ total });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Las rutas de tus compañeros seguirán comentadas hasta que ellos las creen
// app.put('/api/items/:id', tizianaController.modificarProducto);
// app.put('/api/items/:id/desactivar', francoController.bajaLogica);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🚀 Servidor OmniGest corriendo en http://localhost:${PORT}`);
});
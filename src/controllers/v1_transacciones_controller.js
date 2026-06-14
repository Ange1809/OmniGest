const dbService = require('../services/db_service');

exports.procesarTransaccion = async (req, res) => {
    try {
        const { p_cliente_id, p_id_producto, p_cantidad } = req.body;
        
        if (
            !Number.isInteger(p_cliente_id) ||
            !Number.isInteger(p_id_producto) ||
            !Number.isInteger(p_cantidad)
        ) {
            return res.status(400).json({ error: "Datos de transacción incompletos o inválidos" });
        }

        const resultado = await dbService.procesarVentaCompleta(p_cliente_id, p_id_producto, p_cantidad);
        res.status(200).json(resultado);
    } catch (error) {
        res.status(400).json({ error: error.message });
    }
};
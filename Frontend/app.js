// app.js (Cambia la línea 1 por esta)
const API_BASE_URL = 'http://localhost:3000/api';

// 1. llamada a la función (MÉTRICAS / CÁLCULOS)
async function cargarTotalFacturado() {
    const txtTotal = document.getElementById('txt-total-facturado');
    txtTotal.innerText = "Calculando...";

    try {
        // El backend mapea este endpoint a tu FUNCTION optimizada de PostgreSQL
        const respuesta = await fetch(`${API_BASE_URL}/reportes/total-facturado`);
        
        if (!respuesta.ok) throw new Error('Error al calcular en el servidor');
        
        const datos = await respuesta.json();
        
        // Formateamos el resultado como moneda
        txtTotal.innerText = new Intl.NumberFormat('es-AR', { 
            style: 'currency', 
            currency: 'ARS' 
        }).format(datos.total || 0);

    } catch (error) {
        console.error(error);
        txtTotal.innerText = "Error";
        alert("No se pudo conectar con la función de cálculo del servidor.");
    }
}

// 2. ejecución del procedimiento (FORMULARIO ANIDADO)
document.getElementById('form-transaccion').addEventListener('submit', async (e) => {
    e.preventDefault(); // Evita que la página se recargue

    const msgBox = document.getElementById('msg-transaccion');
    
    // Ocultamos mensajes previos
    msgBox.className = "alert-box hidden"; 

    // Recopilamos los datos del formulario estructurado
    const payload = {
      p_cliente_id: parseInt(document.getElementById('select-cliente').value),
        p_id_producto: parseInt(document.getElementById('select-producto').value),
        p_cantidad: parseInt(document.getElementById('input-cantidad').value)
    };

    try {
        // Enviamos los parámetros requeridos por el PROCEDURE atómico
        const respuesta = await fetch(`${API_BASE_URL}/transacciones/procesar`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });

        const resultado = await respuesta.json();

        msgBox.classList.remove('hidden');

        if (respuesta.ok) {
            // Éxito: El procedimiento hizo COMMIT sin lanzar excepciones
            msgBox.className = "alert-box success";
            msgBox.innerText = resultado.mensaje || "¡Transacción procesada con éxito total en el servidor!";
            document.getElementById('form-transaccion').reset(); // Limpiamos formulario
        } else {
            // Control de Errores: La base de datos atrapó un problema y lo devolvió limpiamente
            msgBox.className = "alert-box error";
            msgBox.innerText = `Control de Consistencia: ${resultado.error || 'Operación rechazada por reglas de negocio.'}`;
        }

    } catch (error) {
        console.error(error);
        msgBox.classList.remove('hidden');
        msgBox.className = "alert-box error";
        msgBox.innerText = "Error crítico de comunicación o red con el servidor.";
    }
});

// 3. visualización de auditoría (AUDIT_LOGS)
async function actualizarLogsAuditoria() {
    const tbody = document.getElementById('tbody-logs');
    tbody.innerHTML = `<tr><td colspan="3" class="text-center">Consultando registros de auditoría...</td></tr>`;

    try {
        // Consulta la tabla audit_logs poblada por tus bloques EXCEPTION y triggers
        const respuesta = await fetch(`${API_BASE_URL}/auditoria/logs`);
        
        if (!respuesta.ok) throw new Error('Error al traer logs');
        
        const logs = await respuesta.json();
        
        if (logs.length === 0) {
            tbody.innerHTML = `<tr><td colspan="3" class="text-center">No hay alertas ni errores registrados en la base de datos.</td></tr>`;
            return;
        }

        // Limpiamos y renderizamos dinámicamente las filas
        tbody.innerHTML = "";
        logs.forEach(log => {
            const fila = document.createElement('tr');
            fila.innerHTML = `
                <td>${new Date(log.fecha_hora).toLocaleString('es-AR')}</td>
                <td><code>${log.sqlstate || 'N/A'}</code></td>
                <td>${log.mensaje_error || 'Error desconocido'}</td>
            `;
            tbody.appendChild(fila);
        });

    } catch (error) {
        console.error(error);
        tbody.innerHTML = `<tr><td colspan="3" class="text-center" style="color: #991b1b;">Error al conectar con el registro de auditoría.</td></tr>`;
    }
}
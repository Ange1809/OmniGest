# Proyecto Integrador - Fase 3: Ecosistema NoSQL (Redis)
## Módulo: Fase de Diseño y Arquitectura de Claves
**Alumno Responsable:** Franco  
**Proyecto:** OmniGest  

Para la tercera fase de nuestro proyecto, el equipo volvió a dividir los requerimientos en cuatro áreas de desarrollo. Mi responsabilidad en esta etapa ha sido la **Fase de Diseño Estratégico e Invalidación de Datos** para la capa de caché. 

Basándome en el millón de registros que manejamos en OmniGest, diseñé la estructura para aliviar la carga de PostgreSQL en los puntos más críticos:

### 1. Endpoints Seleccionados para Cachear
* **Endpoint 1:** `/api/productos/catalogo` (Ruta con alta frecuencia de lectura para el retail).
* **Endpoint 2:** `/api/promociones/vigentes` (Ruta crítica consultada masivamente en las cajas de facturación).

**Soporte de Consistencia Eventual:** Ambos endpoints toleran perfectamente que la información en la memoria RAM de Redis tenga un desfasaje de 1 a 2 minutos respecto a PostgreSQL. Si un administrador edita una especificación JSONB o una promoción, ese pequeño retraso no altera la estabilidad de las ventas concurrentes.

### 2. Estándar de Claves (Namespacing) y Políticas de Expiración (TTL)
Para asegurar que los módulos de desarrollo de Angélica, Mauro y Tizi se integren de forma limpia, definí la siguiente estructura jerárquica plana:

1. **Catálogo de Productos General:**
   * *Clave en Redis:* `productos:catalogo:list`
   * *Tipo de dato:* String (JSON Serializado)
   * *TTL asignado:* `120 segundos` (2 minutos de vida útil).

2. **Módulo de Promociones en Cajas:**
   * *Clave en Redis:* `promociones:vigentes:list`
   * *Tipo de dato:* String (JSON Serializado)
   * *TTL asignado:* `60 segundos` (1 minuto, debido a su criticidad transaccional).

3. **Consulta de un Producto Individual:**
   * *Clave en Redis:* `productos:id:1045` (Simulación de ID dinámico).
   * *Tipo de dato:* String (JSON Objeto)
   * *TTL asignado:* `300 segundos` (5 minutos en caché).
# 📑 Documento de Especificación Técnica: OmniGest

**Materia:** Base de Datos III  
**Equipo de Desarrollo:** Angélica, Mauro, Franco  
**Versión del Documento:** 1.0  

> **📌 RESUMEN EJECUTIVO**
> OmniGest es un sistema de gestión transaccional diseñado para resolver las deficiencias de rendimiento y almacenamiento que sufren los comercios medianos al escalar. El proyecto demuestra la capacidad de **PostgreSQL** para manejar un volumen de **1.000.000 de registros**, aplicando normalización (3NF), indexación avanzada (GIN/GiST) y consultas analíticas complejas (Window Functions, CTE), garantizando velocidad, integridad y escalabilidad.

---

## 1. Contexto y Justificación del Proyecto

### 🔻 El Problema Detectado
En el sector retail (supermercados, ferreterías, grandes despensas), el crecimiento del volumen de ventas expone las fallas de los sistemas de gestión básicos (muchas veces basados en planillas estáticas). Los principales puntos de dolor son:
* **Caída del rendimiento:** Al acumular miles de tickets históricos, las búsquedas por código de barras se vuelven inviables.
* **Rigidez de datos:** Imposibilidad de guardar atributos variables (ej. "peso" en alimentos vs. "cepa" en vinos) sin arruinar la estructura de la base de datos con columnas nulas.
* **Errores humanos en facturación:** Solapamiento de promociones y descuentos por falta de restricciones a nivel de motor de base de datos.

### 🎯 La Solución Propuesta
El desarrollo de **OmniGest** traslada la responsabilidad de la velocidad y la integridad estructural directamente al **motor de base de datos**. Al no depender del código de la aplicación (frontend/backend) para estas validaciones, logramos un sistema a prueba de fallos y altamente optimizado.

---

## 2. Arquitectura y Stack Tecnológico

Para simular un entorno de desarrollo profesional, se implementó la siguiente arquitectura técnica:

| Componente | Tecnología Aplicada | Justificación Técnica |
| :--- | :--- | :--- |
| **Motor Relacional** | PostgreSQL 15+ | Soporte nativo para tipos de datos complejos (JSONB, Rangos), estructuras recursivas y robustez transaccional. |
| **Automatización** | Python 3 (`psycopg2`) | Permite crear scripts de carga masiva y conexión segura mediante variables de entorno, aislando las credenciales. |
| **Entorno de Desarrollo**| VS Code + SQLTools | Centralización del código SQL y Python en un entorno integrado, facilitando pruebas en tiempo real. |
| **Control de Versiones**| Git / GitHub | Implementación de flujo de trabajo por ramas (`feat/carga-masiva`) y protección del código mediante `.gitignore`. |

---

## 3. Diseño y Modelado de Datos (DER)

La base de datos se estructuró bajo la **Tercera Forma Normal (3NF)**. Las innovaciones arquitectónicas clave son:

> **💡 INNOVACIONES ARQUITECTÓNICAS**
> * **Flexibilidad Estructural (Tipado JSONB):** La entidad `productos` incluye la columna `especificaciones`. Esto permite almacenar documentos JSON con atributos dinámicos, manteniendo la integridad relacional del resto de la tabla.
> * **Integridad Temporal (Tipado DATERANGE):** La entidad `promociones` utiliza rangos de fechas. PostgreSQL impide matemáticamente la inserción de fechas superpuestas para un mismo producto.
> * **Navegación Recursiva:** La entidad `categorias` implementa una llave foránea autorreferencial (`id_padre`), permitiendo generar jerarquías infinitas (árboles de categorías).

---

## 4. Fases del Proyecto y Asignación de Roles

Para garantizar la cobertura total de los requerimientos de la cátedra, el proyecto se dividió en tres fases técnicas especializadas:

| Fase | Responsable | Rol Técnico | Tareas Críticas y Herramientas |
| :---: | :--- | :--- | :--- |
| **Fase 1** | **Angélica** | Arquitecta de Datos | **Modelado y Carga Masiva:**<br>• Diseño del DER en 3NF.<br>• Inserción rápida de 1.000.000 de registros usando `generate_series()` encapsulado en transacciones (`BEGIN; COMMIT;`) para optimizar I/O. |
| **Fase 2** | **Franco** | Analista de Performance | **Indexación y Optimización:**<br>• Diagnóstico de cuellos de botella con `EXPLAIN ANALYZE`.<br>• Creación de índices **B-Tree**|
| **Fase 3** | **Tiziana** | Analista de Performance | ** **GIN** (para JSONB) y **GiST** (para rangos de fechas).<br>• Documentación visual con Dalibo. |
| **Fase 4** | **Mauro** | Ingeniero de Datos | **Lógica de Negocio y SQL Avanzado:**<br>• Desarrollo de consultas recursivas (CTE) para mapear el árbol de subcategorías.<br>• Creación de reportes con *Window Functions* (`RANK() OVER`) para estadísticas de ventas. |

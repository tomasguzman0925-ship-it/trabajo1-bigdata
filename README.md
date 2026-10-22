# Trabajo 1: capas Medallion y streaming

Curso SI7006/SI6003 Almacenamiento y Procesamiento de Grandes Datos, Universidad EAFIT, 2026-2.

Integrantes: _completar_

Video (YouTube, no listado): _completar_

## Datos

**Parte A:** catálogo de escenas **Landsat 8-9 OLI/TIRS Collection 2 Level-2** del USGS EROS (producto del proyecto integrador: *Landsat → Landsat Collection 2 Level-2 → Landsat 8-9 OLI/TIRS C2 L2*).

- Fuente: archivo de metadatos masivos del USGS, `LANDSAT_OT_C2_L2.csv.gz`
  (<https://landsat.usgs.gov/landsat/metadata_service/bulk_metadata_files/LANDSAT_OT_C2_L2.csv.gz>), descargado el 22 de octubre de 2026.
- Una fila por escena (imagen) adquirida entre 2013 y 2026.
- **4.180.681 filas, 50 columnas, 2,4 GB en CSV (479 MB comprimido).** No se requirió aumento de datos.
- Tipos: identificadores y URL (texto), fechas y horas, categorías (T1/T2, satélite 8/9, proyección), enteros (WRS path/row, calidad de imagen) y decimales (nubosidad %, ángulos solares, RMSE, coordenadas).

**Parte B:** eventos con escenas reales de 2026 tomadas del mismo catálogo (`parteB_streaming/scripts/escenas_semilla.csv`), publicados como mensajes de una estación terrestre.

## Estructura

| Carpeta | Contenido |
|---|---|
| `parteA_medallion/` | SQL de Athena: bronce, hallazgos, plata (Iceberg), oro (Iceberg) y comparación |
| `parteB_streaming/lambda/` | Función Lambda que consume SQS y escribe en DynamoDB |
| `parteB_streaming/scripts/` | Publicación de eventos en IoT Core y conteo/retraso |
| `docs/` | Guía de la consola paso a paso y guion del video |

## Parte A: capas Medallion (Athena + S3 + Iceberg)

1. **Bronce:** `landsat_bronce`, tabla externa sobre el CSV comprimido, 50 columnas `string`.
2. **Hallazgos:** `02_hallazgos.sql` (una sola lectura del archivo).

   | Hallazgo | Filas |
   |---|---|
   | Escenas repetidas | 0 |
   | Fecha inválida | 0 |
   | Nubosidad terrestre −1 (sin dato) | 232.169 |
   | Error geométrico (RMSE) vacío | 1.239.139 |
   | Calidad de imagen < 9 | 717 |
   | Zona UTM vacía (escenas polares, informativo) | 406.346 |
   | Coordenadas inválidas | 0 |

3. **Plata:** 5 reglas (duplicado, fecha, nubosidad 0–100, RMSE presente, calidad 9). Iceberg `landsat_plata_validas` (tipada, particionada por año) y `landsat_plata_rechazadas` (con motivo).
   **4.180.681 = 2.937.126 válidas + 1.243.555 rechazadas.**
4. **Oro:** `landsat_oro_colombia_mensual`: escenas y escenas despejadas (< 20 % nubes) sobre Colombia por año, mes y satélite.
5. **Comparación:** la misma consulta en las tres capas (`05_comparacion.sql`), con bytes escaneados y tiempo.

## Parte B: IoT Core → SQS → Lambda → DynamoDB

- Regla IoT `landsat_a_sqs`: `SELECT * FROM 'landsat/escenas'` → cola `landsat-escenas-cola`.
- Lambda `landsat-consumidor`: valida el esquema; guarda los válidos en `landsat_eventos` con `received_at_ms` y `delay_ms`; registra los descartados en CloudWatch Logs con su motivo.
- DynamoDB `landsat_eventos`, llave de partición `event_id`: única por evento (conteo exacto), idempotente ante reentregas de SQS y con escrituras uniformes entre particiones.
- `publicar_eventos.py --n 10000` publica con la API de IoT Core; `contar_resultados.py` verifica publicados = guardados + descartados y mide el retraso promedio y máximo.

Todos los recursos de AWS se crearon manualmente en la consola (sin infraestructura como código).

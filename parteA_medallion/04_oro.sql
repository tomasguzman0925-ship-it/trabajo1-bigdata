-- Trabajo 1, Parte A, paso 5: capa ORO.
-- Pregunta de negocio: ¿cuántas escenas Landsat 8-9 despejadas (nubosidad terrestre < 20 %)
-- hay sobre Colombia cada mes y con qué satélite? Sirve para planear en qué meses buscar
-- imágenes útiles para el proyecto y cuánto aporta Landsat 9 desde 2022.
-- Colombia se aproxima con un rectángulo: latitud -4.3 a 12.6, longitud -79.1 a -66.8.

-- Sentencia 1: tabla Iceberg agregada
CREATE TABLE trabajo1_landsat.landsat_oro_colombia_mensual
WITH (
    table_type  = 'ICEBERG',
    is_external = false,
    location    = 's3://trabajo1-landsat-531640467230/oro/colombia_mensual/'
) AS
SELECT anio,
       mes,
       satelite,
       count(*)                                   AS escenas,
       count_if(nubosidad_terrestre < 20)         AS escenas_despejadas,
       round(100.0 * count_if(nubosidad_terrestre < 20) / count(*), 1) AS pct_despejadas,
       round(avg(nubosidad_terrestre), 1)         AS nubosidad_promedio
FROM trabajo1_landsat.landsat_plata_validas
WHERE latitud_centro  BETWEEN -4.3  AND 12.6
  AND longitud_centro BETWEEN -79.1 AND -66.8
GROUP BY anio, mes, satelite;

-- Sentencia 2: ¿qué meses tienen más escenas despejadas sobre Colombia? (todos los años)
SELECT mes,
       sum(escenas)            AS escenas,
       sum(escenas_despejadas) AS escenas_despejadas,
       round(100.0 * sum(escenas_despejadas) / sum(escenas), 1) AS pct_despejadas
FROM trabajo1_landsat.landsat_oro_colombia_mensual
GROUP BY mes
ORDER BY pct_despejadas DESC;

-- Sentencia 3: aporte de cada satélite por año
SELECT anio, satelite, sum(escenas) AS escenas, sum(escenas_despejadas) AS escenas_despejadas
FROM trabajo1_landsat.landsat_oro_colombia_mensual
GROUP BY anio, satelite
ORDER BY anio, satelite;

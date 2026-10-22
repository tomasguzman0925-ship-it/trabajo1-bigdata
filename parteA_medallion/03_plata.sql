-- Trabajo 1, Parte A, paso 4: capa PLATA.
-- Reglas de calidad (justificadas con los hallazgos de 02_hallazgos.sql).
-- Cada fila de bronce recibe UN motivo: el de la primera regla que incumple (en este orden).
-- Si no incumple ninguna, motivo = NULL y la fila es válida.
--
--   R1 duplicado            -> H1: una escena (product_id_l2) debe aparecer una sola vez.
--   R2 fecha_invalida       -> H2: sin fecha de adquisición no se puede ubicar la escena en el tiempo.
--   R3 nubosidad_invalida   -> H3: el valor -1 significa "sin dato"; si se dejara, una escena sin
--                              dato contaría como "despejada" (-1 < 20) y falsearía el análisis de nubes.
--   R4 sin_rmse_geometrico  -> H4: sin puntos de control la posición de los píxeles no es confiable
--                              (escenas Tier 2), no sirven para comparar la misma zona en el tiempo.
--   R5 calidad_baja         -> H5: calidad de imagen menor a 9 indica defectos del sensor o de la escena.
--
-- Ejecutar UNA sentencia a la vez.

-- Sentencia 1: vista con el motivo de rechazo de cada fila
CREATE OR REPLACE VIEW trabajo1_landsat.landsat_bronce_reglas AS
SELECT b.*,
       CASE
           WHEN row_number() OVER (PARTITION BY b.product_id_l2
                                   ORDER BY b.date_generated_l2 DESC) > 1
                THEN 'R1 duplicado'
           WHEN try(date_parse(b.date_acquired, '%Y/%m/%d')) IS NULL
                THEN 'R2 fecha_invalida'
           WHEN try_cast(b.land_cloud_cover AS double) IS NULL
                OR try_cast(b.land_cloud_cover AS double) NOT BETWEEN 0 AND 100
                THEN 'R3 nubosidad_invalida'
           WHEN b.geometric_rmse IS NULL OR trim(b.geometric_rmse) = ''
                THEN 'R4 sin_rmse_geometrico'
           WHEN try_cast(b.image_quality AS integer) IS NULL
                OR try_cast(b.image_quality AS integer) < 9
                THEN 'R5 calidad_baja'
           ELSE NULL
       END AS motivo
FROM trabajo1_landsat.landsat_bronce b;

-- Sentencia 2: tabla Iceberg con las filas VÁLIDAS, con tipos correctos
CREATE TABLE trabajo1_landsat.landsat_plata_validas
WITH (
    table_type   = 'ICEBERG',
    is_external  = false,
    location     = 's3://trabajo1-landsat-531640467230/plata/validas/',
    partitioning = ARRAY['anio']
) AS
SELECT product_id_l2,
       scene_id,
       CAST(date_parse(date_acquired, '%Y/%m/%d') AS date)        AS fecha_adquisicion,
       year(date_parse(date_acquired, '%Y/%m/%d'))                AS anio,
       month(date_parse(date_acquired, '%Y/%m/%d'))               AS mes,
       collection_category                                        AS categoria,
       CAST(wrs_path AS integer)                                  AS wrs_path,
       CAST(wrs_row AS integer)                                   AS wrs_row,
       CAST(satellite AS integer)                                 AS satelite,
       CAST(land_cloud_cover AS double)                           AS nubosidad_terrestre,
       try_cast(scene_cloud_cover AS double)                      AS nubosidad_escena,
       CAST(image_quality AS integer)                             AS calidad_imagen,
       try_cast(geometric_rmse AS double)                         AS rmse_geometrico,
       try_cast(sun_elevation AS double)                          AS elevacion_solar,
       try_cast(sun_azimuth AS double)                            AS azimut_solar,
       try_cast(roll_angle AS double)                             AS angulo_roll,
       map_projection                                             AS proyeccion,
       try_cast(center_lat AS double)                             AS latitud_centro,
       try_cast(center_lon AS double)                             AS longitud_centro
FROM trabajo1_landsat.landsat_bronce_reglas
WHERE motivo IS NULL;

-- Sentencia 3: tabla Iceberg con las filas RECHAZADAS y su motivo (columnas originales en texto)
CREATE TABLE trabajo1_landsat.landsat_plata_rechazadas
WITH (
    table_type  = 'ICEBERG',
    is_external = false,
    location    = 's3://trabajo1-landsat-531640467230/plata/rechazadas/'
) AS
SELECT motivo,
       product_id_l2, scene_id, date_acquired, collection_category,
       wrs_path, wrs_row, satellite, land_cloud_cover, scene_cloud_cover,
       gcp_model, geometric_rmse, image_quality, center_lat, center_lon
FROM trabajo1_landsat.landsat_bronce_reglas
WHERE motivo IS NOT NULL;

-- Sentencia 4: rechazadas por motivo
SELECT motivo, count(*) AS filas
FROM trabajo1_landsat.landsat_plata_rechazadas
GROUP BY motivo
ORDER BY motivo;

-- Sentencia 5: los conteos deben cuadrar: bronce = válidas + rechazadas
SELECT bronce,
       validas,
       rechazadas,
       validas + rechazadas                  AS validas_mas_rechazadas,
       IF(bronce = validas + rechazadas, 'CUADRA', 'NO CUADRA') AS verificacion
FROM (SELECT count(*) AS bronce     FROM trabajo1_landsat.landsat_bronce),
     (SELECT count(*) AS validas    FROM trabajo1_landsat.landsat_plata_validas),
     (SELECT count(*) AS rechazadas FROM trabajo1_landsat.landsat_plata_rechazadas);

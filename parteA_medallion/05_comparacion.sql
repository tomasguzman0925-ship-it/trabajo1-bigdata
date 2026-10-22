-- Trabajo 1, Parte A, paso 6: COMPARACIÓN de la misma consulta en las tres capas.
-- Pregunta: escenas despejadas (nubosidad terrestre < 20 %) sobre Colombia, por mes, en 2024.
-- Ejecutar cada sentencia por separado y anotar en la pestaña "Query stats":
--   "Data scanned" (bytes escaneados) y "Run time" (tiempo de respuesta).
-- Desactivar "Reuse query results" para que cada ejecución lea los datos de verdad.

-- BRONCE: texto, hay que convertir tipos en cada consulta y se lee el CSV comprimido completo.
-- Ojo: en bronce las escenas con nubosidad -1 (sin dato) cuentan como "despejadas" (-1 < 20).
SELECT month(date_parse(date_acquired, '%Y/%m/%d'))                    AS mes,
       count_if(try_cast(land_cloud_cover AS double) < 20)             AS escenas_despejadas
FROM trabajo1_landsat.landsat_bronce
WHERE year(date_parse(date_acquired, '%Y/%m/%d')) = 2024
  AND try_cast(center_lat AS double) BETWEEN -4.3  AND 12.6
  AND try_cast(center_lon AS double) BETWEEN -79.1 AND -66.8
GROUP BY 1
ORDER BY 1;

-- PLATA: Parquet en columnas, particionado por año: solo lee 2024 y solo las columnas usadas.
SELECT mes,
       count_if(nubosidad_terrestre < 20) AS escenas_despejadas
FROM trabajo1_landsat.landsat_plata_validas
WHERE anio = 2024
  AND latitud_centro  BETWEEN -4.3  AND 12.6
  AND longitud_centro BETWEEN -79.1 AND -66.8
GROUP BY mes
ORDER BY mes;

-- ORO: la respuesta ya está agregada; solo suma unas pocas filas.
SELECT mes,
       sum(escenas_despejadas) AS escenas_despejadas
FROM trabajo1_landsat.landsat_oro_colombia_mensual
WHERE anio = 2024
GROUP BY mes
ORDER BY mes;

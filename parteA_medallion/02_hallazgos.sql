-- Trabajo 1, Parte A, paso 3: HALLAZGOS de calidad sobre bronce.
-- Una sola lectura del archivo: se cuentan todos los defectos a la vez y se presentan como tabla.

WITH conteos AS (
    SELECT
        count(*) AS total,
        count(*) - count(DISTINCT product_id_l2) AS h1_repetidas,
        count_if(try(date_parse(date_acquired, '%Y/%m/%d')) IS NULL) AS h2_fecha_invalida,
        count_if(try_cast(land_cloud_cover AS double) IS NULL
                 OR try_cast(land_cloud_cover AS double) NOT BETWEEN 0 AND 100) AS h3_nubosidad_invalida,
        count_if(geometric_rmse IS NULL OR trim(geometric_rmse) = '') AS h4_rmse_vacio,
        count_if(try_cast(image_quality AS integer) IS NULL
                 OR try_cast(image_quality AS integer) < 9) AS h5_calidad_baja,
        count_if(utm_zone IS NULL OR trim(utm_zone) = '') AS h6_utm_vacia,
        count_if(try_cast(center_lat AS double) IS NULL
                 OR try_cast(center_lon AS double) IS NULL
                 OR try_cast(center_lat AS double) NOT BETWEEN -90 AND 90
                 OR try_cast(center_lon AS double) NOT BETWEEN -180 AND 180) AS h7_coordenadas
    FROM trabajo1_landsat.landsat_bronce
)
SELECT h.hallazgo,
       h.filas,
       round(100.0 * h.filas / c.total, 2) AS porcentaje
FROM conteos c
CROSS JOIN UNNEST(
    ARRAY['H1 Escenas repetidas (mismo product_id_l2)',
          'H2 Fecha de adquisición vacía o inválida',
          'H3 Nubosidad terrestre fuera de 0-100 (valor -1 = sin dato)',
          'H4 Error geométrico (RMSE) vacío: escena sin puntos de control',
          'H5 Calidad de imagen menor a 9 (escala 0-9)',
          'H6 Zona UTM vacía (escenas polares en proyección PS, informativo)',
          'H7 Coordenadas del centro vacías o fuera de rango'],
    ARRAY[c.h1_repetidas, c.h2_fecha_invalida, c.h3_nubosidad_invalida, c.h4_rmse_vacio,
          c.h5_calidad_baja, c.h6_utm_vacia, c.h7_coordenadas]
) AS h (hallazgo, filas)
ORDER BY h.hallazgo;

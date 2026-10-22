-- Trabajo 1, Parte A, paso 2: capa BRONCE.
-- Datos: catálogo de escenas Landsat 8-9 OLI/TIRS Collection 2 Level-2 (USGS EROS).
-- Archivo en S3: s3://trabajo1-landsat-531640467230/bronce/landsat_ot_c2_l2/LANDSAT_OT_C2_L2.csv.gz
-- Ejecutar en el editor de Athena, UNA sentencia a la vez.

-- Sentencia 1: la base de datos del trabajo
CREATE DATABASE IF NOT EXISTS trabajo1_landsat;

-- Sentencia 2: tabla externa sobre el archivo tal como llega, con TODAS las columnas como texto.
-- Elegir la base de datos trabajo1_landsat en el panel izquierdo antes de ejecutarla.
CREATE EXTERNAL TABLE IF NOT EXISTS trabajo1_landsat.landsat_bronce (
    browse_link          string,
    display_id           string,
    ordering_id          string,
    product_id_l2        string,
    product_id_l1        string,
    scene_id             string,
    date_acquired        string,
    collection_category  string,
    collection_number    string,
    wrs_path             string,
    wrs_row              string,
    target_wrs_path      string,
    target_wrs_row       string,
    nadir_off_nadir      string,
    roll_angle           string,
    date_generated_l2    string,
    date_generated_l1    string,
    start_time           string,
    stop_time            string,
    station_id           string,
    day_night            string,
    land_cloud_cover     string,
    scene_cloud_cover    string,
    gcp_model            string,
    gcp_version          string,
    geometric_rmse       string,
    geometric_rmse_x     string,
    geometric_rmse_y     string,
    image_quality        string,
    processing_software  string,
    sun_elevation        string,
    sun_azimuth          string,
    tirs_ssm_model       string,
    data_type_l2         string,
    sensor_id            string,
    satellite            string,
    map_projection       string,
    utm_zone             string,
    datum                string,
    ellipsoid            string,
    center_lat           string,
    center_lon           string,
    ul_lat               string,
    ul_lon               string,
    ur_lat               string,
    ur_lon               string,
    ll_lat               string,
    ll_lon               string,
    lr_lat               string,
    lr_lon               string
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION 's3://trabajo1-landsat-531640467230/bronce/landsat_ot_c2_l2/'
TBLPROPERTIES ('skip.header.line.count' = '1');

-- Sentencia 3: comprobar que se lee bien
SELECT product_id_l2, date_acquired, collection_category, wrs_path, wrs_row,
       satellite, land_cloud_cover, image_quality
FROM trabajo1_landsat.landsat_bronce
LIMIT 10;

-- Sentencia 4: cuántas filas tiene bronce (esperado: 4180681)
SELECT count(*) AS filas_bronce FROM trabajo1_landsat.landsat_bronce;

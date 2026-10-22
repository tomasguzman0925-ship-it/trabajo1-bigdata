# Resultados de la Parte A (ejecutados el 22 de octubre de 2026)

Cuenta AWS, región us-east-1, workgroup `primary`, base de datos `trabajo1_landsat`.

## Bronce
- Archivo: `s3://trabajo1-landsat-531640467230/bronce/landsat_ot_c2_l2/LANDSAT_OT_C2_L2.csv.gz` (479.377.263 bytes).
- `landsat_bronce`: **4.180.681 filas**, 50 columnas `string`.

## Hallazgos (`02_hallazgos.sql`)

| Hallazgo | Filas | % |
|---|---|---|
| H1 Escenas repetidas (mismo product_id_l2) | 0 | 0,00 |
| H2 Fecha de adquisición vacía o inválida | 0 | 0,00 |
| H3 Nubosidad terrestre fuera de 0–100 (−1 = sin dato) | 232.169 | 5,55 |
| H4 Error geométrico (RMSE) vacío | 1.239.139 | 29,64 |
| H5 Calidad de imagen menor a 9 | 717 | 0,02 |
| H6 Zona UTM vacía (escenas polares, informativo) | 406.346 | 9,72 |
| H7 Coordenadas vacías o fuera de rango | 0 | 0,00 |

## Plata (`03_plata.sql`)

| Concepto | Filas |
|---|---|
| Bronce | 4.180.681 |
| Válidas (`landsat_plata_validas`, Iceberg, partición por año) | 2.937.126 |
| Rechazadas (`landsat_plata_rechazadas`, Iceberg, con motivo) | 1.243.555 |
| Válidas + rechazadas | 4.180.681 → **CUADRA** |

Rechazadas por motivo: R3 nubosidad_invalida 232.169 · R4 sin_rmse_geometrico 1.010.938 · R5 calidad_baja 448.
(Cada fila se rechaza por la primera regla que incumple; por eso R4 < H4 y R5 < H5.)

## Oro (`04_oro.sql`)
Pregunta: ¿en qué meses hay más escenas Landsat 8-9 despejadas (< 20 % nubes) sobre Colombia?

| Mes | Escenas | Despejadas | % despejadas |
|---|---|---|---|
| 1 | 2.346 | 670 | 28,6 |
| 2 | 2.045 | 475 | 23,2 |
| 12 | 2.268 | 464 | 20,5 |
| 9 | 2.556 | 406 | 15,9 |
| 8 | 2.423 | 376 | 15,5 |
| 3 | 2.226 | 336 | 15,1 |
| 10 | 2.379 | 318 | 13,4 |
| 11 | 2.114 | 226 | 10,7 |
| 7 | 2.036 | 200 | 9,8 |
| 4 | 2.116 | 193 | 9,1 |
| 5 | 1.946 | 147 | 7,6 |
| 6 | 1.930 | 134 | 6,9 |

Conclusión: diciembre–febrero (temporada seca) concentra las imágenes útiles; de abril a junio menos de 1 de cada 10 escenas sirve.

## Comparación (`05_comparacion.sql`)
Misma pregunta: escenas despejadas sobre Colombia por mes en 2024. "Reuse query results" desactivado.

| Capa | Data scanned | Tiempo total | Suma de escenas despejadas |
|---|---|---|---|
| Bronce | 457,17 MB (479.377.263 B) | 25,1 s | 584 |
| Plata | 3,03 MB (3.180.763 B) | 2,3 s | 546 |
| Oro | 847 B | 0,69 s | 546 |

Interpretación:
- Bronce lee todo el CSV comprimido: un `.gz` no se puede leer por partes ni por columnas.
- Plata (Parquet columnar + partición por año) lee solo 2024 y las 4 columnas usadas: ≈ 150 veces menos datos y ≈ 11 veces más rápido.
- Oro ya está agregado: lee 847 bytes (≈ 560.000 veces menos que bronce).
- Bronce además da un resultado incorrecto: cuenta 38 escenas con nubosidad −1 (sin dato) como despejadas. La limpieza de plata hace la respuesta correcta, no solo más barata.

# Guion del video (máximo 10 minutos)

Reglas que anulan el trabajo si no se cumplen:
- **Máximo 10:00.** El guion suma ≈ 9:30 para dejar margen.
- **Todos los integrantes hablan y se ve su cara mientras hablan** (cámara activa en la grabación, por ejemplo con Zoom/Teams compartiendo pantalla y la cámara de quien habla visible).
- **CloudFormation vacío en us-east-1**, mostrado en pantalla.
- **Nada de credenciales**: no abrir `aws.env`, la pantalla de access keys, ni el menú de la cuenta con datos de pago.

Consejos:
- Ejecuten las consultas largas **antes** de grabar; en el video muestren los resultados (pestaña *Recent queries* de Athena) y vuelvan a correr solo las rápidas.
- Hagan zoom en el navegador (**Ctrl +**) para que las tablas se lean bien. La legibilidad vale 5 puntos.
- Integrantes: **P1**, **P2**, **P3** (si son dos, P3 lo hace P1).

---

| Tiempo | Quién | Pantalla | Qué decir (resumen) |
|---|---|---|---|
| 0:00–0:20 | Todos | Cámaras | Nombres de los integrantes, curso y que el trabajo usa datos de Landsat del proyecto integrador. |
| 0:20–1:20 | P1 | Página de EarthExplorer / USGS y VS Code con el perfil | **Descripción**: catálogo de escenas Landsat 8-9 OLI/TIRS Collection 2 Level-2 del USGS EROS (el mismo producto del proyecto). Una fila = una imagen capturada (2013–2026). **4.180.681 filas, 50 columnas, 2,4 GB en CSV (479 MB comprimido).** Tipos: identificadores (texto), fechas y horas, categorías (T1/T2, satélite 8/9), enteros (path/row, calidad) y decimales (nubosidad %, ángulos, coordenadas). No se necesitó aumento de datos. |
| 1:20–2:00 | P1 | S3 (archivo en `bronce/…`) y Athena tabla `landsat_bronce` | **Bronce**: el archivo tal cual en S3, tabla externa con las 50 columnas como `string`. Mostrar el `count(*)` = 4.180.681. |
| 2:00–2:50 | P1 | Athena, resultado de `02_hallazgos.sql` | **Hallazgos**: 0 repetidas, 0 fechas inválidas, 232.169 con nubosidad −1 (sin dato), 1.239.139 sin error geométrico (escenas Tier 2 sin puntos de control), 717 con calidad < 9; 406.346 sin zona UTM son escenas polares (informativo, no es error). |
| 2:50–3:50 | P2 | `03_plata.sql` (vista y CTAS) y resultados | **Plata**: 5 reglas en SQL justificadas con los hallazgos (R1 duplicado, R2 fecha, R3 nubosidad fuera de 0–100, R4 sin RMSE, R5 calidad < 9). Cada fila recibe el motivo de la primera regla que incumple. Tablas Iceberg de válidas (tipadas, particionadas por año) y rechazadas con motivo. Mostrar conteo por motivo y la verificación **4.180.681 = 2.937.126 + 1.243.555 → CUADRA**. |
| 3:50–4:30 | P2 | `04_oro.sql` y resultado | **Oro**: pregunta de negocio: ¿cuántas escenas despejadas (< 20 % nubes) hay sobre Colombia cada mes y con qué satélite? Sirve para saber en qué meses buscar imágenes útiles para el proyecto y cuánto aportó Landsat 9 desde 2022. Mostrar la consulta por mes ordenada. |
| 4:30–5:20 | P2 | Athena *Query stats* de las 3 consultas de `05_comparacion.sql` | **Comparación**: la misma pregunta (escenas despejadas sobre Colombia en 2024). Leer Data scanned y Run time de cada capa. Interpretación: bronce lee el CSV comprimido completo (no se puede leer solo una columna ni solo un año); plata es Parquet en columnas y particionado por año → lee solo 2024 y las columnas usadas; oro ya está agregado → casi no lee nada. Además bronce da **584** y plata **546**: las 38 de más son escenas con nubosidad −1 contadas como despejadas. Plata no solo es más rápida: es **correcta**. |
| 5:20–6:00 | P1 | Cámara | **Pregunta final A** (ver respuesta abajo). |
| 6:00–7:00 | P3 | Consola: IoT rule, SQS, Lambda (código y trigger), DynamoDB | **Parte B, recursos**: flujo IoT Core → SQS → Lambda → DynamoDB. Mostrar la regla `SELECT * FROM 'landsat/escenas'` con acción SQS, la cola, la Lambda con su trigger SQS y el código (validación del esquema y escritura). **Llave de DynamoDB `event_id`**: es única por evento, así cada publicación es exactamente un ítem (los conteos cuadran), y como SQS puede entregar un mensaje más de una vez, volver a escribir el mismo `event_id` no duplica (idempotencia); además reparte las escrituras de forma uniforme entre particiones. |
| 7:00–8:10 | P3 | CloudShell, DynamoDB items, Logs Insights | **Publicación y resultados**: `publicar_eventos.py --n 10000` (escenas reales de 2026; ≈ 3 % dañadas a propósito). Mostrar ítems en DynamoDB con `delay_ms`, Logs Insights con descartados por motivo y `contar_resultados.py`: **10.000 = guardados + descartados → CUADRA**, retraso promedio y máximo. |
| 8:10–8:30 | P3 | CloudFormation → Stacks (us-east-1) | "No hay stacks: todos los recursos se crearon a mano en la consola." |
| 8:30–9:15 | P3 | Cámara | **Pregunta final B** (ver respuesta abajo). |
| 9:15–9:30 | Todos | Cámaras | Cierre. |

---

## Respuestas a las preguntas finales (para preparar con sus palabras)

### Parte A: si los datos fueran mil veces mayores, ¿qué cambiarían?
Serían ≈ 4.200 millones de filas: ≈ 2,4 TB en CSV (≈ 480 GB comprimido).
- **No consultaríamos bronce directamente.** Un solo `.gz` no se puede dividir: Athena lo lee con un solo trabajador, y escanear 2,4 TB cuesta ≈ 12 USD por consulta (5 USD/TB).
- **Ingesta en muchos archivos** y conversión inmediata a **Parquet/Iceberg particionado** (por año/mes y, por ejemplo, por zona path/row), con compactación de archivos pequeños.
- **Transformaciones con Spark (AWS Glue o EMR)** en vez de CTAS de Athena: el CTAS tiene límites (100 particiones por escritura, 30 min por consulta).
- **Cargas incrementales** (`MERGE INTO` en Iceberg) en lugar de recrear plata y oro completos.
- **Control de costos**: límites de datos escaneados por workgroup y consultas siempre sobre plata/oro.
- **Calidad de datos automatizada** (AWS Glue Data Quality o Deequ) en vez de reglas manuales.

### Parte B: ¿a partir de qué volumen dejarían esta forma de streaming y cuál usarían? ¿Por qué?
- Este flujo cobra y procesa **mensaje por mensaje**: IoT Core (publicación + regla + acción), SQS, una invocación de Lambda por lote de 10 y **una escritura en DynamoDB por evento**.
- Funciona bien hasta unos **miles de eventos por segundo** sostenidos (del orden de cientos de millones de eventos al mes). Por encima, el costo por evento y los límites (cuota de publicaciones de IoT Core, concurrencia de Lambda, capacidad de escritura de DynamoDB) lo vuelven caro y frágil.
- Además, SQS **no guarda orden** (cola estándar), **no permite releer** los datos y cada mensaje lo consume un solo lector.
- Lo cambiaríamos por **Amazon Kinesis Data Streams** (o Kafka con Amazon MSK): particiona por llave con orden, guarda los datos días para **reprocesar**, admite **varios consumidores** y lotes de hasta 10.000 registros. Para analítica, **Kinesis Data Firehose** hacia S3/Iceberg (como en el lab 5) en vez de un ítem de DynamoDB por evento.

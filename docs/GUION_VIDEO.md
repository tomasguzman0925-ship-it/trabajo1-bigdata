# Guion del video (máximo 10 minutos)

Integrantes: **P1** Tomás Guzmán Tapias · **P2** Cristian Miguel Gómez Salazar · **P3** Alejandro Jimenez Lopera.

## Lo que anula el trabajo (revisar antes de subir)
- [ ] Dura **menos de 10:00** (apuntar a 9:00–9:30).
- [ ] **Los tres hablan y se ve su cara mientras hablan.**
- [ ] Se muestra **CloudFormation sin stacks** en us-east-1.
- [ ] **No se ven credenciales**: ni `aws.env`, ni la pantalla de access keys de IAM, ni nada de facturación/pago.
- [ ] Se sube a YouTube como **No listado** y se entrega antes del **viernes 23 de octubre, 23:59**.

## Cómo grabar
1. Hagan una reunión de **Zoom o Teams** con los tres y la **cámara encendida**.
2. Quien comparte pantalla (P1) abre las pestañas antes de empezar (ver lista abajo). Activen **"Grabar"** (en la nube o en el computador).
3. Vista: pantalla compartida + **miniaturas de cámara visibles** (en Zoom: "Vista de orador" con las miniaturas; en Teams: no ocultar el panel de participantes). Quien habla debe verse en su miniatura.
4. Si se equivocan, **sigan** y corten en la edición, o graben por bloques (Parte A, Parte B, preguntas) y únanlos. Cada bloque debe mostrar la cara de quien habla.
5. Al terminar revisen la duración. Si pasa de 10:00, recorten pausas (YouTube Studio → Editor → Recortar).

## Preparación (10 minutos antes)
- Navegador con **zoom al 125–150 %** (Ctrl +) para que las tablas se lean.
- Cerrar avisos y banners azules de la consola.
- Pestañas abiertas, en este orden:
  1. S3: `trabajo1-landsat-531640467230/bronce/landsat_ot_c2_l2/` (se ve el archivo .gz).
  2. Athena → **Recent queries** (todas las consultas de la Parte A ya ejecutadas: abrir cada una muestra su resultado y sus stats sin volver a correrla).
  3. IoT Core → Rules → `landsat_a_sqs`.
  4. SQS → `landsat-escenas-cola`.
  5. Lambda → `landsat-consumidor` (pestaña Code y diagrama con el trigger).
  6. DynamoDB → `landsat_eventos` → **Explore table items**.
  7. CloudWatch → **Logs Insights** con la consulta de descartados lista.
  8. CloudShell con la salida de `contar_resultados.py` en pantalla (o ejecutarlo en vivo: tarda segundos).
  9. CloudFormation → Stacks (us-east-1).
- VS Code con `docs/RESULTADOS_PARTE_A.md` abierto como respaldo.

Consulta para Logs Insights (grupo `/aws/lambda/landsat-consumidor`, rango "1 día"):
```
filter tipo = "DESCARTADO" | stats count(*) as eventos by motivo
```

---

## Guion con tiempos

### 0:00–0:20 · Todos · cámaras
**P1:** "Hola, somos Tomás Guzmán, Cristian Gómez y Alejandro Jiménez. Este es el Trabajo 1 de Almacenamiento y Procesamiento de Grandes Datos: capas Medallion y streaming, con datos de Landsat 8 y 9 de nuestro proyecto integrador."
(Cada uno dice "hola" con su cámara visible.)

### 0:20–1:10 · P1 · Descripción del conjunto de datos
Pantalla: EarthExplorer con *Landsat Collection 2 Level-2 → Landsat 8-9 OLI/TIRS C2 L2* seleccionado, luego el README.
- "Nuestro proyecto usa Landsat Collection 2 Level-2 de Landsat 8 y 9. Las imágenes son GeoTIFF, así que para trabajar con SQL usamos el **catálogo oficial de escenas del USGS**: una fila por cada imagen capturada entre 2013 y 2026."
- "Son **4.180.681 filas y 50 columnas**: 2,4 GB en CSV y **479 MB comprimido**. No necesitamos aumentar datos."
- "Tiene identificadores, fechas y horas, categorías como el nivel T1/T2 y el satélite 8 o 9, enteros como path/row y calidad, y decimales como la nubosidad, ángulos solares y coordenadas."

### 1:10–1:40 · P1 · Bronce
Pantalla: S3 con el archivo; Athena con `CREATE EXTERNAL TABLE` y el `count(*)`.
- "Subimos el archivo tal cual a S3, en la carpeta bronce, y creamos una tabla externa en Athena con las 50 columnas como texto. El conteo da 4.180.681 filas."

### 1:40–2:30 · P1 · Hallazgos
Pantalla: resultado de `02_hallazgos.sql` (tabla de 7 filas).
- "Con una sola consulta cuantificamos los defectos: **0 escenas repetidas y 0 fechas inválidas**; **232.169 escenas con nubosidad −1**, que significa 'sin dato'; **1.239.139 sin error geométrico**, escenas Tier 2 sin puntos de control; y **717 con calidad de imagen menor a 9**."
- "Las 406.346 sin zona UTM no son un error: son escenas polares en otra proyección, por eso no tienen regla."

### 2:30–3:30 · P2 · Plata
Pantalla: vista `landsat_bronce_reglas`, rechazadas por motivo y verificación CUADRA.
- "Escribimos **5 reglas** a partir de los hallazgos: duplicado, fecha inválida, nubosidad fuera de 0–100, sin error geométrico y calidad menor a 9. Cada fila recibe el motivo de la **primera regla que incumple**."
- "Las válidas van a una tabla **Iceberg** con tipos correctos y particionada por año; las rechazadas a otra tabla Iceberg con su motivo."
- "Rechazadas: 232.169 por nubosidad, 1.010.938 por error geométrico y 448 por calidad. Y cuadra: **4.180.681 = 2.937.126 válidas + 1.243.555 rechazadas**."

### 3:30–4:15 · P2 · Oro
Pantalla: `CREATE TABLE landsat_oro_colombia_mensual` y la consulta por mes.
- "La pregunta de negocio: **¿en qué meses hay más imágenes despejadas sobre Colombia?** Creamos una tabla Iceberg agregada por año, mes y satélite."
- "**Enero (28,6 %), febrero (23,2 %) y diciembre (20,5 %)** son los mejores: la temporada seca. De abril a junio menos de 1 de cada 10 escenas sirve. Para el proyecto, conviene buscar imágenes entre diciembre y febrero."

### 4:15–5:15 · P2 · Comparación
Pantalla: las 3 consultas de `05_comparacion.sql`, mostrando **Data scanned** (recuadro verde) y **Query stats**.
- "Misma pregunta en las tres capas: escenas despejadas sobre Colombia por mes en 2024."
- "**Bronce: 457 MB escaneados y 25 segundos. Plata: 3 MB y 2,3 segundos. Oro: 847 bytes y 0,7 segundos.**"
- "Bronce lee el CSV comprimido completo; un .gz no se puede leer por partes. Plata es Parquet en columnas y particionado por año: lee solo 2024 y 4 columnas, unas 150 veces menos. Oro ya está agregado."
- "Y algo más importante: **bronce responde 584 y plata 546**. Las 38 de más son escenas con nubosidad −1 que bronce cuenta como despejadas. Plata no solo es más barata: **es correcta**."

### 5:15–6:00 · P1 · Pregunta final A (cámara)
"Si los datos fueran mil veces mayores, unos 2,4 TB:
- No consultaríamos bronce: escanear 2,4 TB cuesta unos 12 dólares por consulta y un solo .gz lo lee un solo trabajador.
- Recibiríamos los datos en muchos archivos y los convertiríamos de inmediato a Parquet/Iceberg particionado por fecha y zona, con compactación.
- Haríamos las transformaciones con Spark en Glue o EMR, porque el CTAS de Athena tiene límites de particiones y de tiempo.
- Cargaríamos de forma incremental con MERGE en Iceberg en vez de recrear las tablas, y pondríamos límites de escaneo por workgroup."

### 6:00–7:00 · P3 · Parte B: recursos
Pantalla: IoT rule → SQS → Lambda (diagrama, trigger y código) → DynamoDB.
- "El flujo es **IoT Core → SQS → Lambda → DynamoDB**. La regla `landsat_a_sqs` toma todo lo del tema `landsat/escenas` y lo manda a la cola estándar `landsat-escenas-cola`."
- "La Lambda lee lotes de 10 mensajes, **valida el esquema** (campos obligatorios, satélite 8 o 9, path y row en rango, nubosidad de 0 a 100) y guarda los válidos con la hora de llegada y el retraso. Los inválidos se registran en CloudWatch con su motivo."
- "La llave de DynamoDB es **`event_id`**: es única por evento, así cada publicación es exactamente un ítem; como SQS puede entregar un mensaje más de una vez, reescribir el mismo `event_id` no duplica; y al ser aleatoria reparte las escrituras de forma pareja."

### 7:00–8:10 · P3 · Publicación, conteos y retraso
Pantalla: CloudShell (`publicar_eventos.py` y `contar_resultados.py`), ítems de DynamoDB, Logs Insights.
- "Publicamos **10.000 eventos** con la API de IoT Core desde CloudShell: escenas reales de 2026, y dañamos 290 a propósito para probar los descartes."
- "Resultado: **9.710 guardados + 290 descartados = 10.000, cuadra**. Descartes: 79 por path inválido, 73 por nubosidad fuera de rango, 69 sin scene_id y 69 por satélite inválido."
- "El retraso del envío a DynamoDB fue de **2,45 segundos en promedio y 5,7 segundos como máximo**; crece porque publicamos más rápido de lo que la Lambda consume y los mensajes esperan en la cola."

### 8:10–8:25 · P3 · CloudFormation
Pantalla: CloudFormation → Stacks, us-east-1, vacío.
- "CloudFormation está vacío en us-east-1: todo se creó a mano en la consola."

### 8:25–9:15 · P3 · Pregunta final B (cámara)
"Dejaríamos este flujo desde unos **miles de eventos por segundo sostenidos**, del orden de cientos de millones al mes:
- Aquí se paga y procesa **mensaje por mensaje**: IoT, SQS, una invocación de Lambda cada 10 y una escritura de DynamoDB por evento. A gran volumen eso es caro y choca con límites de IoT, la concurrencia de Lambda y la capacidad de DynamoDB.
- Además SQS estándar no garantiza orden, no permite releer y cada mensaje tiene un solo consumidor.
- Usaríamos **Kinesis Data Streams** o Kafka con MSK: orden por llave, retención para reprocesar, varios consumidores y lotes grandes; y para analítica, **Firehose hacia S3/Iceberg**, como en el laboratorio 5."

### 9:15–9:30 · Todos · Cierre
"El código y los resultados están en GitHub. Gracias."

---

## Después de grabar
1. Subir a YouTube como **No listado**, comprobar que dure menos de 10:00 y copiar el enlace.
2. Poner el enlace en el README (Claude lo hace y lo sube a GitHub).
3. Borrar los recursos de AWS (ver `GUIA_PASO_A_PASO.md`, sección final).
4. Entregar en Eafit Interactiva (Asignaciones → Trabajo1) con los tres integrantes y un archivo con el enlace de GitHub y el de YouTube.

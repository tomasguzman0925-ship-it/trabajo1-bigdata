# Guía paso a paso en la consola de AWS

Todo se crea **a mano en la consola** (condición eliminatoria 1). Región: **us-east-1 (N. Virginia)** en todo momento.

> ⚠️ Nunca uses opciones que desplieguen CloudFormation: en Lambda **no** uses "Create application", SAM ni "Serverless Application Repository"; en IoT **no** uses asistentes de "Connect device" que creen stacks. Antes de grabar, revisa que CloudFormation esté vacío.

Nombres que usan los scripts (si cambias uno, avísale a Claude para ajustar el código):

| Recurso | Nombre |
|---|---|
| Bucket S3 | `trabajo1-landsat-531640467230` |
| Base de datos Athena/Glue | `trabajo1_landsat` |
| Tema IoT | `landsat/escenas` |
| Regla IoT | `landsat_a_sqs` |
| Cola SQS | `landsat-escenas-cola` |
| Función Lambda | `landsat-consumidor` |
| Tabla DynamoDB | `landsat_eventos` (llave `event_id`) |

---

## Parte A

### A1. Crear el bucket y subir el archivo (≈10 min, depende de tu internet)
1. Consola → **S3** → **Create bucket**.
2. Bucket name: `trabajo1-landsat-531640467230`. Región: **us-east-1**. Deja todo lo demás por defecto → **Create bucket**.
3. Entra al bucket → **Create folder** → `bronce` → dentro, **Create folder** → `landsat_ot_c2_l2`.
4. Dentro de `bronce/landsat_ot_c2_l2/` → **Upload** → **Add files** → `C:\Users\Usuario\trabajo1-bigdata\data\raw\LANDSAT_OT_C2_L2.csv.gz` (479 MB) → **Upload**. Espera a que diga *Upload succeeded*.
   - Se sube **comprimido**: Athena lee `.gz` directamente.

### A2. Configurar Athena
1. Consola → **Athena** → **Query editor**.
2. Workgroup: `primary`. Si aparece "Set up a query result location", pulsa **Edit settings** → `s3://trabajo1-landsat-531640467230/athena-resultados/` → **Save**.
3. Abre `parteA_medallion/01_bronce.sql` en VS Code. Copia **una sentencia a la vez**, pégala en Athena y pulsa **Run**.
4. Después de la sentencia 1, en el panel izquierdo elige **Database = `trabajo1_landsat`**.

### A3. Ejecutar los archivos en orden

| Archivo | Qué esperar |
|---|---|
| `01_bronce.sql` | Tabla `landsat_bronce`; 10 filas de muestra; **4.180.681** filas |
| `02_hallazgos.sql` | Tabla de 7 hallazgos (ver abajo) |
| `03_plata.sql` | Vista + 2 tablas Iceberg; rechazadas por motivo; verificación **CUADRA** |
| `04_oro.sql` | Tabla Iceberg `landsat_oro_colombia_mensual` y 2 consultas de negocio |
| `05_comparacion.sql` | La misma pregunta en bronce, plata y oro |

Hallazgos esperados (archivo completo):

| Hallazgo | Filas |
|---|---|
| H1 Escenas repetidas | 0 |
| H2 Fecha inválida | 0 |
| H3 Nubosidad -1 | 232.169 |
| H4 RMSE vacío | 1.239.139 |
| H5 Calidad < 9 | 717 |
| H6 Zona UTM vacía (informativo) | 406.346 |
| H7 Coordenadas inválidas | 0 |

Plata esperada: **2.937.126 válidas + 1.243.555 rechazadas = 4.180.681** (R3 232.169, R4 1.010.938, R5 448).
Una fila puede tener varios defectos; se cuenta solo el primero que incumple, por eso R4 y R5 son menores que H4 y H5.

### A4. Comparación (paso 6)
1. Arriba del editor, **desactiva "Reuse query results"** si está activado.
2. Ejecuta cada una de las 3 consultas de `05_comparacion.sql`.
3. En cada resultado abre la pestaña **Query stats** y anota **Data scanned** y **Run time**. Haz captura.
4. Resultado esperado de escenas despejadas sobre Colombia en 2024: bronce **584** vs plata/oro **546**. Las 38 de diferencia son escenas con nubosidad `-1` (sin dato) que bronce cuenta como despejadas.

Tabla para anotar:

| Capa | Data scanned | Run time | Escenas despejadas 2024 |
|---|---|---|---|
| Bronce | | | 584 |
| Plata | | | 546 |
| Oro | | | 546 |

---

## Parte B

### B1. Tabla DynamoDB
1. Consola → **DynamoDB** → **Create table**.
2. Table name: `landsat_eventos`. Partition key: `event_id` (**String**). Sin sort key.
3. Table settings: **Customize settings** → Capacity mode **On-demand** → **Create table**.

### B2. Cola SQS
1. Consola → **SQS** → **Create queue** → tipo **Standard**.
2. Name: `landsat-escenas-cola`. Visibility timeout: **60 seconds**. Lo demás por defecto → **Create queue**.

### B3. Función Lambda
1. Consola → **Lambda** → **Create function** → **Author from scratch**.
2. Name: `landsat-consumidor`. Runtime: **Python 3.13**. Architecture: x86_64.
3. Permissions: **Create a new role with basic Lambda permissions** → **Create function**.
4. Pestaña **Code**: borra el contenido de `lambda_function.py`, pega `parteB_streaming/lambda/lambda_function.py` → **Deploy**.
5. **Configuration → General configuration → Edit**: Timeout **30 sec** → Save.
6. **Configuration → Environment variables → Edit → Add**: `TABLE_NAME` = `landsat_eventos` → Save.
7. **Configuration → Permissions** → clic en el nombre del rol (abre IAM) → **Add permissions → Attach policies**:
   - `AWSLambdaSQSQueueExecutionRole`
   - `AmazonDynamoDBFullAccess`
   → **Add permissions**.
8. De vuelta en Lambda → **Add trigger** → **SQS** → cola `landsat-escenas-cola` → Batch size **10** → **Add**.

### B4. Regla de IoT Core
1. Consola → **IoT Core** → menú **Message routing → Rules** → **Create rule**.
2. Rule name: `landsat_a_sqs` → Next.
3. SQL statement (versión 2016-03-23):
   ```sql
   SELECT * FROM 'landsat/escenas'
   ```
   → Next.
4. Rule actions → **Simple Queue Service (SQS)** → cola `landsat-escenas-cola`. **No** marques "Base64".
5. IAM role → **Create new role** → nombre `iot-landsat-a-sqs` → Next → **Create**.

### B5. Publicar 10.000 eventos (CloudShell)
1. En la barra inferior de la consola pulsa **CloudShell** (región us-east-1).
2. **Actions → Upload file** y sube estos 3 archivos de `parteB_streaming/scripts/`:
   `publicar_eventos.py`, `contar_resultados.py`, `escenas_semilla.csv`.
3. Ejecuta:
   ```bash
   python3 publicar_eventos.py --n 10000
   ```
   Tarda 1–3 minutos. Al final muestra cuántos se dañaron a propósito (≈3 %).
4. Espera 1 minuto y ejecuta:
   ```bash
   python3 contar_resultados.py
   ```
   Debe decir **CUADRA** y mostrar el retraso promedio y máximo. Si dice NO CUADRA, espera otro minuto y repite.

Para mostrar en el video:
- **DynamoDB** → `landsat_eventos` → **Explore table items** (se ven los eventos con `delay_ms`).
- **CloudWatch → Logs Insights** → grupo `/aws/lambda/landsat-consumidor` →
  ```
  filter tipo = "DESCARTADO" | stats count(*) as eventos by motivo
  ```
- **SQS** → la cola con 0 mensajes disponibles (todos procesados).

### B6. CloudFormation vacío (evidencia obligatoria)
Consola → **CloudFormation** → región us-east-1 → **Stacks**: debe decir que no hay stacks. Grábalo.

---

## Después de grabar: borrar todo (para cuidar los créditos)
1. **IoT Core** → Rules → `landsat_a_sqs` → Delete.
2. **Lambda** → `landsat-consumidor` → Delete.
3. **SQS** → `landsat-escenas-cola` → Delete.
4. **DynamoDB** → `landsat_eventos` → Delete.
5. **Athena**: `DROP TABLE` de las tablas Iceberg (borra sus datos) y `DROP DATABASE trabajo1_landsat CASCADE`.
6. **S3** → bucket → **Empty** → luego **Delete**.
7. **IAM → Roles**: borra `landsat-consumidor-role-…` y `iot-landsat-a-sqs`.
8. **CloudWatch → Log groups**: borra `/aws/lambda/landsat-consumidor`.

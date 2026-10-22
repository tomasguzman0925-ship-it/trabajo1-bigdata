# Resultados de la Parte B (ejecutados el 22 de octubre de 2026)

Flujo: IoT Core (tema `landsat/escenas`) → regla `landsat_a_sqs` → SQS `landsat-escenas-cola` → Lambda `landsat-consumidor` → DynamoDB `landsat_eventos`.

## Recursos (creados a mano en la consola, us-east-1)

| Recurso | Configuración |
|---|---|
| Regla IoT `landsat_a_sqs` | `SELECT * FROM 'landsat/escenas'` (SQL 2016-03-23), acción SQS sin Base64, rol `iot-landsat-a-sqs` (solo `sqs:SendMessage` sobre la cola) |
| Cola SQS `landsat-escenas-cola` | Standard, visibility timeout 60 s |
| Lambda `landsat-consumidor` | Python 3.14, x86_64, timeout 30 s, variable `TABLE_NAME=landsat_eventos`, trigger SQS con lote de 10 y sin filtros; rol con `AWSLambdaBasicExecutionRole`, `AWSLambdaSQSQueueExecutionRole` y `AmazonDynamoDBFullAccess` |
| DynamoDB `landsat_eventos` | Llave de partición `event_id` (String), sin llave de ordenamiento, modo On-demand |

## Publicación
`python3 publicar_eventos.py --n 10000` en AWS CloudShell: 10.000 escenas reales de Landsat 8-9 de 2026; 290 dañadas a propósito (≈ 3 %).

## Conteos (`contar_resultados.py`)

| Concepto | Eventos |
|---|---|
| Publicados en IoT Core | 10.000 |
| Guardados en DynamoDB | 9.710 |
| Descartados por la Lambda | 290 |
| Guardados + descartados | 10.000 → **CUADRA** |

Descartados por motivo: wrs_path_invalido 79 · nubosidad_fuera_de_rango 73 · falta_campo:scene_id 69 · satelite_invalido 69 (coinciden con los 290 dañados a propósito). Errores de la Lambda: 0.

## Retraso envío → llegada a DynamoDB

| Métrica | ms |
|---|---|
| Promedio | 2.450 |
| Mediana | 2.465 |
| p95 | 4.240 |
| Máximo | 5.664 |

El retraso incluye IoT Core, la espera en la cola, el tiempo hasta que Lambda toma el lote de 10 y la escritura en DynamoDB; crece cuando la publicación es más rápida que el consumo y los mensajes se acumulan en la cola.

## Evidencia de recursos manuales
CloudFormation en us-east-1: 0 stacks.

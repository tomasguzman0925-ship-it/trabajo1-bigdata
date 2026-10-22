"""Trabajo 1, Parte B: Lambda que consume la cola SQS y guarda los eventos en DynamoDB.

Flujo: IoT Core (tema landsat/escenas) -> regla -> SQS -> esta Lambda -> DynamoDB.

Cada mensaje de SQS trae en su cuerpo el JSON publicado en IoT Core:
{
  "event_id": "uuid",                       # identificador único del evento
  "scene_id": "LC09_L2SP_009058_20260101_...",
  "satellite": 9,                           # 8 o 9
  "wrs_path": 9, "wrs_row": 58,             # 1-233 y 1-248
  "date_acquired": "2026-01-01",
  "land_cloud_cover": 12.3,                 # 0-100
  "station": "LGN",
  "sent_at_ms": 1792000000000               # hora de envío (epoch en milisegundos)
}

Los eventos válidos se guardan en DynamoDB con la hora de llegada y el retraso.
Los inválidos NO se guardan: se escribe una línea JSON en CloudWatch Logs con
"tipo": "DESCARTADO" y el motivo, para poder contarlos.
"""
import json
import os
import time
from decimal import Decimal

import boto3

TABLE_NAME = os.environ.get("TABLE_NAME", "landsat_eventos")
table = boto3.resource("dynamodb").Table(TABLE_NAME)

REQUIRED = ("event_id", "scene_id", "satellite", "wrs_path", "wrs_row",
            "date_acquired", "land_cloud_cover", "sent_at_ms")


def validate(event):
    """Return None if the event follows the schema, otherwise the reason it is discarded."""
    if not isinstance(event, dict):
        return "no_es_objeto_json"
    missing = [f for f in REQUIRED if event.get(f) in (None, "")]
    if missing:
        return "falta_campo:" + ",".join(missing)
    if event["satellite"] not in (8, 9):
        return "satelite_invalido"
    if not (isinstance(event["wrs_path"], int) and 1 <= event["wrs_path"] <= 233):
        return "wrs_path_invalido"
    if not (isinstance(event["wrs_row"], int) and 1 <= event["wrs_row"] <= 248):
        return "wrs_row_invalido"
    cloud = event["land_cloud_cover"]
    if not (isinstance(cloud, (int, float)) and 0 <= cloud <= 100):
        return "nubosidad_fuera_de_rango"
    if not isinstance(event["sent_at_ms"], int):
        return "sent_at_ms_invalido"
    return None


def discard(event_id, reason, message_id):
    print(json.dumps({"tipo": "DESCARTADO", "event_id": event_id,
                      "motivo": reason, "sqs_message_id": message_id}))


def lambda_handler(event, context):
    saved = discarded = 0
    with table.batch_writer(overwrite_by_pkeys=["event_id"]) as batch:
        for record in event["Records"]:
            try:
                body = json.loads(record["body"])
            except (ValueError, TypeError):
                discard(None, "json_invalido", record.get("messageId"))
                discarded += 1
                continue

            reason = validate(body)
            if reason:
                event_id = body.get("event_id") if isinstance(body, dict) else None
                discard(event_id, reason, record.get("messageId"))
                discarded += 1
                continue

            received_at_ms = int(time.time() * 1000)
            batch.put_item(Item={
                "event_id": body["event_id"],
                "scene_id": body["scene_id"],
                "satellite": body["satellite"],
                "wrs_path": body["wrs_path"],
                "wrs_row": body["wrs_row"],
                "date_acquired": body["date_acquired"],
                "land_cloud_cover": Decimal(str(body["land_cloud_cover"])),
                "station": body.get("station", ""),
                "sent_at_ms": body["sent_at_ms"],
                "received_at_ms": received_at_ms,
                "delay_ms": received_at_ms - body["sent_at_ms"],
            })
            saved += 1

    print(json.dumps({"tipo": "LOTE", "guardados": saved, "descartados": discarded}))
    return {"guardados": saved, "descartados": discarded}

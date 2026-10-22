"""Trabajo 1, Parte B: publica eventos en IoT Core con la API (boto3, iot-data:Publish).

Uso (en AWS CloudShell, después de subir este archivo y escenas_semilla.csv):
    python3 publicar_eventos.py --n 10000

Cada evento es una escena real del catálogo Landsat 8-9 (escenas_semilla.csv).
Un porcentaje pequeño (--invalidos, 3 % por defecto) se daña a propósito para
probar que la Lambda los descarta con su motivo.
Al terminar escribe publicados.json con el conteo, que usa contar_resultados.py.
"""
import argparse
import csv
import json
import random
import time
import uuid
from concurrent.futures import ThreadPoolExecutor

import boto3

TOPIC = "landsat/escenas"

DAMAGES = [
    ("falta scene_id", lambda e: e.pop("scene_id")),
    ("satelite 7", lambda e: e.update(satellite=7)),
    ("nubosidad -1", lambda e: e.update(land_cloud_cover=-1.0)),
    ("wrs_path 999", lambda e: e.update(wrs_path=999)),
]


def load_seed(path):
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def build_event(row):
    return {
        "event_id": str(uuid.uuid4()),
        "scene_id": row["product_id_l2"],
        "satellite": int(row["satellite"]),
        "wrs_path": int(row["wrs_path"]),
        "wrs_row": int(row["wrs_row"]),
        "date_acquired": row["date_acquired"].replace("/", "-"),
        "land_cloud_cover": float(row["land_cloud_cover"]),
        "station": row["station_id"],
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--n", type=int, default=10000)
    parser.add_argument("--invalidos", type=float, default=0.03)
    parser.add_argument("--semilla", default="escenas_semilla.csv")
    parser.add_argument("--hilos", type=int, default=16)
    args = parser.parse_args()

    endpoint = boto3.client("iot").describe_endpoint(endpointType="iot:Data-ATS")["endpointAddress"]
    iot_data = boto3.client("iot-data", endpoint_url="https://" + endpoint)
    rows = load_seed(args.semilla)
    random.seed(42)

    events, damaged = [], {}
    for i in range(args.n):
        event = build_event(rows[i % len(rows)])
        if random.random() < args.invalidos:
            name, damage = random.choice(DAMAGES)
            damage(event)
            damaged[name] = damaged.get(name, 0) + 1
        events.append(event)

    def publish(event):
        event["sent_at_ms"] = int(time.time() * 1000)
        iot_data.publish(topic=TOPIC, qos=1, payload=json.dumps(event))

    print(f"Publicando {args.n} eventos en el tema '{TOPIC}' ({endpoint}) ...")
    start = time.time()
    with ThreadPoolExecutor(max_workers=args.hilos) as pool:
        for i, _ in enumerate(pool.map(publish, events), start=1):
            if i % 1000 == 0:
                print(f"  {i} publicados")
    elapsed = time.time() - start

    summary = {
        "publicados": args.n,
        "danados_a_proposito": sum(damaged.values()),
        "danados_por_tipo": damaged,
        "inicio_ms": int(start * 1000),
        "segundos": round(elapsed, 1),
    }
    with open("publicados.json", "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2, ensure_ascii=False)
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    print(f"Listo: {args.n} eventos en {elapsed:.1f} s ({args.n / elapsed:.0f} eventos/s)")


if __name__ == "__main__":
    main()

"""Trabajo 1, Parte B: cuadra los conteos y mide el retraso.

Uso (en AWS CloudShell, en la misma carpeta donde se corrió publicar_eventos.py):
    python3 contar_resultados.py

- Guardados: se leen todos los ítems de la tabla DynamoDB (landsat_eventos).
- Descartados: se cuentan con CloudWatch Logs Insights en el log de la Lambda,
  agrupados por motivo.
- Verifica: publicados = guardados + descartados.
- Retraso (envío -> llegada a DynamoDB): promedio, mediana, p95 y máximo.
"""
import argparse
import json
import time

import boto3


def scan_delays(table_name):
    table = boto3.resource("dynamodb").Table(table_name)
    # ConsistentRead: the scan sees every write that already succeeded
    delays, kwargs = [], {"ProjectionExpression": "delay_ms", "ConsistentRead": True}
    while True:
        page = table.scan(**kwargs)
        delays += [int(item["delay_ms"]) for item in page["Items"]]
        if "LastEvaluatedKey" not in page:
            return delays
        kwargs["ExclusiveStartKey"] = page["LastEvaluatedKey"]


def discarded_by_reason(log_group, start_ms):
    logs = boto3.client("logs")
    query = ('filter tipo = "DESCARTADO" '
             '| stats count(*) as eventos by motivo | sort eventos desc')
    qid = logs.start_query(logGroupName=log_group, startTime=start_ms // 1000 - 60,
                           endTime=int(time.time()) + 60, queryString=query)["queryId"]
    while True:
        result = logs.get_query_results(queryId=qid)
        if result["status"] in ("Complete", "Failed", "Cancelled", "Timeout"):
            break
        time.sleep(1)
    rows = {}
    for row in result["results"]:
        fields = {f["field"]: f["value"] for f in row}
        rows[fields["motivo"]] = int(fields["eventos"])
    return rows


def percentile(sorted_values, p):
    return sorted_values[min(len(sorted_values) - 1, int(p / 100 * len(sorted_values)))]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--tabla", default="landsat_eventos")
    parser.add_argument("--funcion", default="landsat-consumidor")
    args = parser.parse_args()

    with open("publicados.json", encoding="utf-8") as f:
        published = json.load(f)

    delays = sorted(scan_delays(args.tabla))
    discarded = discarded_by_reason(f"/aws/lambda/{args.funcion}", published["inicio_ms"])
    total_discarded = sum(discarded.values())

    print("=" * 60)
    print(f"Eventos publicados en IoT Core : {published['publicados']:>7}")
    print(f"Guardados en DynamoDB          : {len(delays):>7}")
    print(f"Descartados por la Lambda      : {total_discarded:>7}")
    for reason, count in discarded.items():
        print(f"    - {reason:<26}: {count:>7}")
    print(f"Guardados + descartados        : {len(delays) + total_discarded:>7}")
    ok = published["publicados"] == len(delays) + total_discarded
    print("Verificación                   :", "CUADRA" if ok else "NO CUADRA")
    print(f"(dañados a propósito al publicar: {published['danados_a_proposito']})")
    print("-" * 60)
    if delays:
        print("Retraso envío -> llegada a DynamoDB")
        print(f"    promedio : {sum(delays) / len(delays):>8.0f} ms")
        print(f"    mediana  : {percentile(delays, 50):>8} ms")
        print(f"    p95      : {percentile(delays, 95):>8} ms")
        print(f"    máximo   : {delays[-1]:>8} ms")
    print("=" * 60)
    if not ok:
        print("Si no cuadra todavía, espera 1-2 minutos (la cola puede tener mensajes"
              " en proceso o los logs pueden tardar) y vuelve a ejecutar.")


if __name__ == "__main__":
    main()

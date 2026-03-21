# Kibana Watcher → Shuffle Webhook Setup

## Create the watcher
Kibana → Stack Management → Watcher → Create Watch → Advanced Watch
```json
{
  "trigger": { "schedule": { "interval": "30s" } },
  "input": {
    "search": {
      "request": {
        "indices": ["suricata-*"],
        "body": {
          "query": {
            "bool": {
              "must": [
                {"term": {"event_type": "alert"}},
                {"range": {"@timestamp": {"gte": "now-1m"}}}
              ]
            }
          },
          "size": 1,
          "sort": [{"@timestamp": {"order": "desc"}}]
        }
      }
    }
  },
  "condition": { "compare": { "ctx.payload.hits.total.value": { "gt": 0 } } },
  "actions": {
    "notify_shuffle": {
      "webhook": {
        "method": "POST",
        "host": "shuffle-backend.soar.svc.cluster.local",
        "port": 5001,
        "path": "/api/v1/hooks/radiant-alert",
        "headers": { "Content-Type": "application/json" },
        "body": "{{#toJson}}ctx.payload.hits.hits.0._source{{/toJson}}"
      }
    }
  }
}
```

## Manual trigger for demo
```bash
ALERT=$(curl -s "http://localhost:9200/suricata-*/_search?q=event_type:alert&size=1" | \
  python3 -c "import sys,json; h=json.load(sys.stdin)['hits']['hits']; print(json.dumps(h[0]['_source']) if h else '{}')")
curl -s -X POST "http://192.168.10.90:3001/api/v1/hooks/radiant-alert" \
  -H "Content-Type: application/json" -d "$ALERT"
echo "Shuffle triggered"
```

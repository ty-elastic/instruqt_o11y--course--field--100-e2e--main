# tracing

FROM traces-* 
| WHERE service.name == "recorder-java" OR service.name == "recorder-go"
| FORK (WHERE transaction.name == "POST /record"
| EVAL t_duration_ms = transaction.duration.us / 1000
| STATS t_latency = AVG(t_duration_ms) BY service.name)
(WHERE span.type == "db"
| EVAL s_duration_ms = span.duration.us / 1000
| STATS db_latency_per_trace = SUM(s_duration_ms) BY trace.id, service.name
| STATS db_latency = AVG(db_latency_per_trace) BY service.name)
| KEEP t_latency, db_latency, service.name

# load average

FROM metrics-*
| WHERE `metrics.system.cpu.load_average.1m` IS NOT NULL OR `metrics.system.cpu.logical.count` IS NOT NULL OR `service_transaction.1m.otel` IS NOT NULL
| EVAL duration = TO_TDIGEST(http.client.request.duration)
| STATS max_cpu_logical_count = MAX(`metrics.system.cpu.logical.count`), avg_cpu_load_average = AVG(`metrics.system.cpu.load_average.1m`), avg_latency = AVG(duration) BY TBUCKET(5m)
| EVAL load_average = (avg_cpu_load_average / max_cpu_logical_count) * 100

FROM metrics-*
| WHERE `metrics.system.cpu.load_average.1m` IS NOT NULL OR `metrics.system.cpu.logical.count` IS NOT NULL OR (`service.name` == "trader" AND `transaction.duration.histogram` IS NOT NULL AND `transaction.name` == "POST /trade/request")
| EVAL latency_tdigest = TO_TDIGEST(transaction.duration.histogram)
| STATS max_cpu_logical_count = MAX(`metrics.system.cpu.logical.count`), avg_cpu_load_average = AVG(`metrics.system.cpu.load_average.1m`), avg_latency = AVG(latency_tdigest) BY TBUCKET(1m), host.name
| EVAL load_average = (avg_cpu_load_average / max_cpu_logical_count) * 100
| EVAL latency = avg_latency / 1000
| KEEP load_average, latency, `TBUCKET(1m)`

# user breakdown

FROM traces-* | WHERE attributes.com.example.customer_id == "q.bert"

FROM traces-* | WHERE attributes.com.example.customer_id == "q.bert" | STATS avg = AVG(span.duration.us) BY span.name | WHERE avg IS NOT NULL | SORT avg DESC

# db breakdown

FROM traces-* | WHERE attributes.span.type == "db" | WHERE attributes.db.operation IS NOT NULL | STATS avg = AVG(span.duration.us) BY TBUCKET(1m), attributes.db.operation, attributes.db.system
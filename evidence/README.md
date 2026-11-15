# Evidence

Every file here is text, JSON, or a log. The screen capture of the failure drill is a GitHub Release asset, because video is never committed to history.

| File | What it shows |
|---|---|
| `terraform-show-before-destroy.txt` | Every resource the stack held, captured from state just before the destroy |
| `destroy.log` | The destroy run, ending in the count of resources removed |
| `ci-run.txt` | The URL of the last green CI run before the destroy |
| `bench-aws-raw.json` | The raw per-event timings from the 1,000-event AWS run |
| `bench-aws-latencies.txt` | The AWS latency for each event, one per line |
| `bench-aws-summary.txt` | The AWS p50 and p95, which include the queue wait |
| `bench-compose-latencies.txt` | The Compose latency for each event, one per line |
| `bench-compose-summary.txt` | The Compose p50 and p95, a floor because requests were sent one at a time |
| `cost-explorer.txt` | Three AWS Cost Explorer readings with credits excluded: the first two days, the whole run, and the stack's services by day. It also holds the stack's cost per 1,000 events |
| `sp8-throttling.txt` | What the concurrency caps did to the queue during the burst |

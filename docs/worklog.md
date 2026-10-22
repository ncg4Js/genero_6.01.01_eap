# Worklog - Genero 6.01.01 EAP

Problem being tackled: Genero 6.01.01 EAP setup and testing (GAS 6.01.01 and FGL 6.01.01).

## 1 - 2026-10-22 10:31 PT - Initial setup checklist

- [x] GAS 6.01.01 installed and active
- [x] FGL 6.01.01 installed and active
- [x] GST running both GAS and FGL
- [x] GST reconfigured and versions checked
- [x] Version check (OfficeStore sample folder):
  - gasadmin 6.01.00 build-202610161714 (nightly build), Target w64v143, built Oct 19 2026
  - fglcomp 6.01.00 rev-47fe2d4 (nightly build), Target w64v143
  - fglrun 6.01.00 rev-47fe2d4 (nightly build), Target w64v143
- [x] Folder C:\work\6.01.01_EAP added to project folders

## 2 - 2026-10-22 10:35 PT - OpenTelemetry quickstart (opentelemetry-quickstart.pdf): facts

- Applies to GAS 6.01.00 and later. 4GL function and SQL spans need fglrun 6.01.00 or later; with an older runtime only the GAS spans appear.
- Every HTTP request handled by GAS becomes one distributed trace: dispatcher (gas-httpdispatch), proxy (gas-uaproxy or gas-gwsproxy), DVM (fgl).
- Export: OTLP over HTTP, JSON encoding, /v1/traces endpoint, port 4318 by convention. OTLP over gRPC is not supported.
- Only traces are exported: no metrics, no logs.
- Endpoint is given as the base URL; GAS adds /v1/traces itself.
- Tracing is off by default.
- Option A (quick test): httpdispatch -E res.otel.enabled=TRUE, plus -E res.otel.endpoint=http://collector-host:4318 if the collector is remote.
- Option B (permanent): res.otel.enabled and res.otel.endpoint resources in $FGLASDIR/etc/as.xcf. The <OPENTELEMETRY> element under <INTERFACE_TO_CONNECTOR> must stay; if removed, tracing is off completely.
- Option C (recommended): keep res.otel.enabled FALSE and enable per session (?otel=1 in the start URL), per application or service (<OPENTELEMETRY Enabled="TRUE"/> before <EXECUTION> in the .xcf), or on a running dispatcher with gasadmin application enable-otel / service enable-otel (forgotten on dispatcher restart; disable-otel turns it off).
- Priority when settings conflict, first found wins: 1) ?otel=1 or ?otel=0, 2) gasadmin enable-otel / disable-otel, 3) <OPENTELEMETRY Enabled> in the .xcf, 4) res.otel.enabled in as.xcf.
- Collector used in the guide: Jaeger (docker run ... -p 16686:16686 -p 4318:4318 jaegertracing/jaeger:2.20.0). UI on port 16686. Traces are kept in memory only.
- File output for tests, no collector: GAS_OTEL_ENDPOINT=file:///tmp/traces.jsonl (takes precedence over res.otel.endpoint; never cleaned up).
- HTTPS collector: certificate checked against system CAs (Windows certificate store on Windows). res.otel.ca_file for a company CA (dispatcher does not start if the file cannot be read). res.otel.insecure=TRUE for self-signed certificates, tests only.
- Settings (res.otel.* in as.xcf, or attributes of <OPENTELEMETRY> in the .xcf): Sanitize (default TRUE), CaptureValues (default FALSE, needs Sanitize="FALSE"), ContentMaxBytes (default 128), ExcludeFunctions (regular expression, default <builtin>).
- First request of an application (GET /ua/r/myapp) has no fgl spans; they appear from the next requests.
- If a web service client sends a W3C traceparent header, GAS continues the client's trace.
- Known limit: non-UTF-8 text in SQL statements cannot be recorded and is replaced.
- A collector that accepts connections but does not answer delays each request by up to 2 seconds per process.
- Production: enable only where needed (option C), keep Sanitize TRUE, do not enable the DEBUG log category while tracing is on.

## 3 - 2026-10-22 10:48 PT - Jaeger collector setup

- Prometheus is not usable as the trace collector: it scrapes metrics (pull), while GAS only exports traces and pushes them over OTLP/HTTP. A trace back end is needed; the quickstart uses Jaeger.
- Jaeger: open source distributed tracing system (created at Uber, CNCF project). Receives spans, builds traces, shows them in a web UI. Traces are kept in memory only (lost when the container stops).
- Span: one timed step of work (name, start time, duration, attributes, parent, status). Spans of one request share a trace ID and form a tree through parent links.
- Decision: add Jaeger to the existing Docker Compose file (project name uscancc, network internal) instead of a native Windows install.
- Backups made in C:\docker_compose before the change: docker-compose.yml.20261021 and .env.20261021 (verified identical to the originals).
- Added service to docker-compose.yml, between prometheus and process-exporter:
  - image jaegertracing/jaeger:2.20.0, container_name Jaeger, network internal
  - ports 127.0.0.1:16686:16686 (UI) and 127.0.0.1:4318:4318 (OTLP over HTTP)
  - no volume
- Start command: docker compose up -d jaeger (from C:\docker_compose).
- Endpoints: GAS on the Windows host sends to http://localhost:4318; a GAS inside a container on the internal network would use http://jaeger:4318. UI at http://localhost:16686.
- Added a Jaeger link (http://localhost:16686) to the Docker group in C:\Users\ncgod\scripts\myHomePage.html.
- Result: Jaeger UI reachable.
- Next: turn tracing on in GAS (option A or C from the quickstart) and send a first request.


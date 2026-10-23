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

## 4 - 2026-10-22 11:25 PT - GST build error -4448 on gslint.42m (northwind project)

- Project: eap_6.01.01_ix_northwind.4pw, in C:\work\6.01.01_EAP\tests\ifx_northwind. Genero configuration: 6.01.01 Web_EAP.
- Error when building:
  ERROR(-4448): Cannot open the file 'C:\Users\ncgod\AppData\Roaming\FourJs\Genero Studio 6.00.03-202601281102\tools\FGL 6.01.00\gslint\gslint.42m' for reading or writing.
- Linter is enabled through the environment set "Studio Linter Tool": GSLINTENABLED=1, GSLINTRULES=$(GSTDIR)\tools\gslint\src\default.gslint.
- Environment of the node uses FGLLDPATH and FGLRESOURCEPATH ending in ...\tools\FGL 6.01.01_EAP (not 6.01.00).
- gslint exists in the GST install: C:\FourJs\Products\6.00\gst-6.00.03\gst\tools\gslint\bin (gslint.42m, .42r and modules).
- GST keeps per-FGL copies of gslint in the user folder, under tools\: FGL 6.00.01, 6.00.01 - Imported, 6.00.02, 6.00.02.snapdev, 6.00.03 and 6.01.01_EAP, each complete. There is no tools\FGL 6.01.00 folder, which is the one in the error.
- The project files (.4pw, .4pwvs) contain no FGL version or configuration name, so the 6.01.00 name comes from GST, not from the project.
- The Genero configuration list has no entry named 6.01.00. The origin of the 6.01.00 name is not confirmed. Possible reason: the version GST uses for that FGL (all EAP tools report 6.01.00 with --version). Not verified.
- Genero Portal answer: fastest solution is to disable the linter.
- Workaround applied: linter disabled (Studio Linter Tool / GSLINTENABLED=0).
- Result: the project compiles.

## 5 - 2026-10-22 11:26 PT - Test material: ifx_northwind modules and tests project (logged later; happened before entry 4)

- Source reviewed: C:\docker_compose\workspace\GeneroV6\work\tripwires\ifx_northwind_test (README, Makefile, fglprofile, setenv.sh, schema, src). Described as a Northwind order desk: four screen programs (nw_orders, nw_catalog, nw_staff, nw_customers) and three batch reports (nw_reports: sales, inventory, statement). Genero BDL 6.00.02 per README. Database: Informix 14.10, database northwind on server informix, driver dbmifx_9 (CSDK 4.50). User and password from NW_USER and NW_PASSWORD.
- Assessment for testing OpenTelemetry tracing on the EAP: suitable.
  - Nested function calls (MAIN, show_*, ord_*, cat_*, ...) give module.function spans.
  - Wide mix of SQL: static SQL, DECLARE CURSOR FROM with built strings, PREPARE/EXECUTE with ? parameters, SQL ... END SQL blocks, transactions, FOR UPDATE, MERGE, temp tables, Informix-specific syntax.
  - SQL with values (CONSTRUCT searches, UPDATE of freight and prices) allows comparing Sanitize and CaptureValues.
  - Error paths (lock error -244 in Ship, TRY/CATCH) should give spans with ERROR status.
- Gaps noted, to be handled later by Nuno:
  - No .xcf application files in the folder (needed for GAS, and for the <OPENTELEMETRY> element of option C).
  - Built for 6.00.02: modules must be recompiled with 6.01.01.
  - setenv.sh is Linux and points to Informix CSDK in /opt/informix and server informix: it matches the GeneroV6 container, not the Windows GST. Open question: where does GAS 6.01.01 run (container or Windows)?
  - nw_reports is batch (fglrun from the command line, not GAS): no traces expected, since the guide describes traces for requests handled by GAS (not confirmed for batch).
- Nuno created C:\work\6.01.01_EAP\tests\ifx_northwind, with the GST project eap_6.01.01_ix_northwind.4pw and its .4pwvs file (project group northwind, application node nw_customers at first look). Nuno will rebuild the programs and create the .xcf later, step by step.
- Memory set for this project: when given a folder with no other instruction, check it exists and list what is inside; log relevant facts to the worklog automatically.

## 6 - 2026-10-22 11:29 PT - Tracing: option C chosen, application .xcf created

- Nuno chose option C (tracing per application) using the application .xcf file.
- Created C:\work\6.01.01_EAP\tests\ifx_northwind\resources\nw_customers.xcf (the only application node of the GST project is nw_customers).
  - Parent defaultgwc, schema cfextwa.xsd 6.00, as in the quickstart example.
  - <OPENTELEMETRY Enabled="TRUE"/> placed before <EXECUTION>, as the guide requires. Sanitize, CaptureValues, ContentMaxBytes and ExcludeFunctions left at their defaults.
  - EXECUTION: PATH C:\work\6.01.01_EAP\tests\ifx_northwind\bin, MODULE nw_customers.
- Not in the .xcf yet: environment for the database (NW_USER, NW_PASSWORD, FGLPROFILE, Informix client). nw_connect() exits with code 1 if NW_USER or NW_PASSWORD is missing.
- The .xcf must be found by the dispatcher (copy or reference in the GAS application folder) before the first request.
- XML well-formedness of the file checked.

## 7 - 2026-10-22 11:50 PT - GAS dispatcher log of the day (httpdispatch, 20261022)

- Folder: C:\ProgramData\FourJs\gas\6.01.00-202610161714\log\httpdispatch\20261022. One file, httpdispatch.log (210 lines, last write 10/22 11:40 PT). Log times are local (PT).
- Log level: WARNING ERROR INFO.
- Dispatcher: component httpdispatch, Version 6.01.00, Build 202610161714, target w64v143 (same 6.01.00 version string as the other EAP tools). HTTP port 6394, admin service port 6999.
- Five startup headers in the file: the dispatcher was started five times today; first startup at 10:07:44 PT.
- Demo services (Calculator, RestBook, ...) are "skipped" at startup.
- Two requests to /ua/r/nw_customers_ncgod_studio failed with HTTP 404 (11:37:59 and 11:40:44 PT, from 10.0.0.90, host desktop-l1e9mjj:6394):
  - Configuration ERROR Code:1871 Message: Element 'RESOURCE': This element is not expected. Expected is one of ( EXECUTION, AUTO_LOGOUT, UA_OUTPUT, END_URL, HTTP ).
  - Config file: C:\ProgramData\FourJs\gas\6.01.00-202610161714\app\nw_customers_ncgod_studio.xcf (not yet read).
  - Cause not known yet. This is not the .xcf created in entry 6 (nw_customers.xcf); the application name nw_customers_ncgod_studio suggests a file generated by GST.
- No OpenTelemetry-related lines in the log so far.

## 8 - 2026-10-22 11:51 PT - GAS app folder: generated .xcf files and the error 1871

- Folder: C:\ProgramData\FourJs\gas\6.01.00-202610161714\app. Three files, all written 10/22 18:40 UTC (11:40 PT), generated by GST:
  - nw_customers_ncgod.xcf and nw_customers_ncgod_nw_customers.xcf: identical; header "for use with a browser only"; DVM fglrun.exe, MODULE C:\work\6.01.01_EAP\tests\ifx_northwind\bin\nw_customers, PARAMETER -d.
  - nw_customers_ncgod_studio.xcf: header "for use with Genero Studio only"; DVM gsproxy.exe (C:\FourJs\Products\6.00\gst-6.00.03\gst\bin) with parameters --host 127.0.0.1 --port 58389 --read-subprocess-streams --console -- fglrun.exe -d <path>\nw_customers; MODULE empty.
  - All three also carry the full environment of the GST configuration as ENVIRONMENT_VARIABLE entries (FGLDIR = fgl-6.01-.00.eap, FGLASDIR = gas-6.01.00.eap, GSLINTENABLED=0, PATH to bin of the project).
- All three start with <OPENTELEMETRY Enabled="TRUE"/>, then <RESOURCE Id="res.gbc"> and <RESOURCE Id="res.fgldir">, then <EXECUTION>. The OPENTELEMETRY element is the one from resources\nw_customers.xcf (entry 6): GST appears to merge it in, ahead of the RESOURCE elements (inference, not confirmed).
- Probable cause of Code:1871 (RESOURCE element not expected; expected EXECUTION, AUTO_LOGOUT, UA_OUTPUT, END_URL, HTTP): element order. GI (GAS manual): "Element order. If child elements are present, they must be set in the order listed or as shown." RESOURCE should come first; here OPENTELEMETRY comes before it. The exact order for OPENTELEMETRY in a web application .xcf was not found in GI. Not yet tested.
- Options considered: (a) remove OPENTELEMETRY from resources\nw_customers.xcf and enable tracing with ?otel=1 or gasadmin application enable-otel (both are higher in the priority list than the .xcf); (b) find out where GST places the element.
- Open point: with GST the program is started through gsproxy.exe, then fglrun -d. Not known whether the fgl spans are produced in this mode.

## 9 - 2026-10-22 11:54 PT - Confirmed: OPENTELEMETRY element breaks the GST-generated .xcf

- Nuno removed <OPENTELEMETRY> from resources\nw_customers.xcf: the program then runs fine from GST. Confirmed cause of Code:1871 (entry 8).
- The quickstart example (OPENTELEMETRY before EXECUTION) has no RESOURCE elements, so it is valid when the file is written by hand. It does not say where OPENTELEMETRY goes relative to RESOURCE.
- GST 6.00.03 generates the deployed .xcf with its own RESOURCE elements after the OPENTELEMETRY element it copies from the project .xcf. Result: invalid order for GAS 6.01.00.
- Possible points to raise (not decided): the quickstart could state the position of OPENTELEMETRY relative to RESOURCE; GST 6.00.03 predates the element and does not place it correctly.
- Next: enable tracing without the .xcf element (?otel=1 in the start URL, or gasadmin application enable-otel).

## 10 - 2026-10-22 11:55 PT - Scope of the OPENTELEMETRY / GST finding

- Nuno confirms as fact (tested: removing the element makes the program run) that GST 6.00.03 generates a .xcf with OPENTELEMETRY before the RESOURCE elements, which GAS 6.01.00 rejects (Code:1871).
- The 6.01.01 EAP delivers only GAS and FGL, not GST. GST 6.00.03 is the released version and predates the OpenTelemetry element, so it cannot be expected to place it correctly.
- Nuno's guess: the quickstart example was probably not developed with GST. Not verified.
- Consequence for testing: with GST, enable tracing without the .xcf element (?otel=1 or gasadmin enable-otel). The .xcf option works for a hand-written file deployed in the GAS app folder.

## 11 - 2026-10-22 11:56 PT - Status at pause

- Done: GAS and FGL 6.01.01 EAP active in GST (tools report 6.01.00 nightly); quickstart read; Jaeger 2.20.0 added to the uscancc compose file and reachable at http://localhost:16686; GST project eap_6.01.01_ix_northwind compiles (linter disabled); .xcf created in resources and found to break GST-generated deployment.
- Current state: resources\nw_customers.xcf no longer contains the OPENTELEMETRY element; tracing is not enabled yet; no trace seen in Jaeger yet.
- Next steps:
  - Database environment for the program (NW_USER, NW_PASSWORD, FGLPROFILE with dbmifx_9, Informix client).
  - Enable tracing with ?otel=1 on the start URL (/ua/r/nw_customers_ncgod_studio?otel=1), or gasadmin application enable-otel.
  - Check that the dispatcher reaches the collector (default endpoint assumed to be localhost:4318; not stated in the quickstart) and look for the trace in Jaeger (service gas-httpdispatch).
  - Check whether fgl spans appear when the program runs through gsproxy.
  - Decide whether to raise the OPENTELEMETRY position / GST point with Four Js.

## 12 - 2026-10-22 11:57 PT - Git remote of the project folder

- C:\work\6.01.01_EAP is a git repository. Remote origin (fetch and push): https://github.com/ncg4Js/genero_6.01.01_eap.git

## 13 - 2026-10-23 10:40 PT - Northwind code duplicated under tests; linter problem gone

- Nuno duplicated all the ifx_northwind code under C:\work\6.01.01_EAP\tests (previously the project used the sources in C:\docker_compose\workspace\GeneroV6\work\tripwires\ifx_northwind_test via relative paths).
- After this, the linter problem (error -4448 on gslint.42m, entries 4 and 8) is gone.
- Cause not established. Not verified whether the linter is enabled again or still disabled.


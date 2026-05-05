# SNOW ITSM Emulator

A self-contained ServiceNow ITSM API emulator purpose-built for demoing Elastic Security's ServiceNow integration — alerts *and* cases — without needing a real ServiceNow instance.

No PDI, no developer account, no waiting for instance hibernation to end. Just `npm start`.

<img width="2164" height="1040" alt="image" src="https://github.com/user-attachments/assets/17a0fc2e-b63f-47e6-ac6c-1fb87348c818" />

<img width="2305" height="1403" alt="image" src="https://github.com/user-attachments/assets/0d271236-2c42-4ba9-bce1-11748cd4a0a3" />


---

## Quick Start

```bash
git clone git@github.com:elastic/james-s-snow-emulator.git
cd james-s-snow-emulator
npm install
npm run dev
```

This starts:
- **HTTPS API server** on `https://localhost:3000` (auto-generates a local CA + server cert with SANs)
- **Portal UI** on `http://localhost:5173` (Vite dev server with hot reload, proxies API calls)

For a single production-like server:
```bash
npm run build
npm start
```

---

## Connecting to Elastic Security

### 1. Create the connector

In Kibana, go to **Stack Management > Connectors > Create connector > ServiceNow ITSM**:

| Field | Value |
|-------|-------|
| ServiceNow instance URL | `https://localhost:3000` |
| Username | `admin` (any value works) |
| Password | `admin` (any value works) |

### 2. Trust the TLS certificate

The emulator generates a local CA on first run. Add to `kibana.yml`:

```yaml
xpack.actions.customHostSettings:
  - url: "https://localhost:3000"
    ssl:
      certificateAuthoritiesFiles: ["/path/to/snow-emulator/.certs/ca.crt"]
```

The exact path is printed at startup. Or skip verification for quick demos:

```yaml
xpack.actions.customHostSettings:
  - url: "https://localhost:3000"
    ssl:
      verificationMode: none
```

### 3. Use with alerts

Add the connector as a **rule action** on any detection rule. When the rule fires, the emulator receives the incident and displays it in the portal.

### 4. Use with cases

Attach the connector to a case via **Cases > Settings > External incident management system**. Push cases and comments — they appear as incidents with a full work notes journal in the portal.

---

## Portal UI

The web portal gives you a live view into what the connector is doing — perfect for customer demos.

| Page | What it shows |
|------|---------------|
| **Dashboard** | Open/closed counts, connector config reference, recent API hits |
| **Incidents** | Table of all incidents with state badges, priority, timestamps |
| **Incident Detail** | Full field view + work notes/comments journal history |
| **Activity Log** | Real-time feed of every API request received (method, path, status, body) |

---

## Emulated API Surface

Built by reading the [actual Kibana connector source](https://github.com/elastic/kibana/blob/main/x-pack/platform/plugins/shared/stack_connectors/server/connector_types/lib/servicenow/service.ts). These are the endpoints the connector hits:

| Endpoint | Purpose |
|----------|---------|
| `GET /api/x_elas2_inc_int/elastic_api/health` | "Elastic for ITSM" app health check |
| `POST /api/now/import/x_elas2_inc_int_elastic_incident` | Create/update incident (Import Set API) |
| `GET /api/now/v2/table/incident/:sys_id` | Get incident by sys_id |
| `GET /api/now/v2/table/incident?sysparm_query=...` | Query incidents (correlation_id lookup) |
| `PATCH /api/now/v2/table/incident/:sys_id` | Update/close incident (Table API) |
| `GET /api/now/table/sys_dictionary` | Get field metadata (getFields) |
| `GET /api/now/table/sys_choice` | Get choice values (getChoices) |

Any other `/api/*` path returns `{ "result": [] }` gracefully — no 404s that break the connector.

---

## How It Works

```
Elastic Alert Rule
    → fires → ServiceNow ITSM Connector
                  → POST /api/now/import/... (u_short_description, u_urgency, etc.)
                       → Emulator strips u_ prefix, creates incident INC0010001
                            → GET /api/now/v2/table/incident/:id (connector reads it back)
                                 → Returns { result: { number, sys_id, ... } }
```

Key behaviors:
- **Import Set API** — accepts `u_`-prefixed fields (as the real Elastic for ITSM app does), strips the prefix, stores them
- **Journal fields** — `work_notes` and `comments` are append-only (like real SNOW), preserving full comment history from Cases
- **Incident numbers** — auto-increment from INC0010001
- **correlation_id** — indexed for the close-incident flow (alerts with grouping)
- **Choices** — returns realistic urgency/severity/impact/priority/state/category/subcategory values
- **Auth** — accepts any credentials (Basic or OAuth headers); no rejection

Data lives in memory and resets on restart (by design — clean slate for each demo).

---

## Options

| Flag / Env | Effect |
|------------|--------|
| `--no-tls` | Run plain HTTP (use behind ngrok/cloudflared) |
| `NO_TLS=1` | Same as above, via environment variable |
| `PORT=8443` | Change the listen port (default: 3000) |

---

## Project Structure

```
src/
  server/
    index.ts              Express app + HTTPS cert generation
    store.ts              In-memory incident store with journal support
    routes/
      health.ts           /api/x_elas2_inc_int/elastic_api/health
      importSet.ts        /api/now/import/:table
      table.ts            Table API + sys_dictionary + sys_choice
      internal.ts         /_internal/* portal data endpoints
    middleware/
      auth.ts             Permissive auth (logs but never rejects)
      logger.ts           Activity logging for the portal feed
  client/
    App.tsx               React app with react-router
    pages/
      Dashboard.tsx       Stats + config reference
      IncidentList.tsx    Sortable incident table
      IncidentDetail.tsx  Field view + journal entries
      ActivityLog.tsx     Live API request inspector
    components/
      Layout.tsx          ServiceNow-style nav bar
      IncidentTable.tsx   Reusable incident table
      StatusBadge.tsx     State/priority badges
```

---

## FAQ

**Q: Do I need to install the "Elastic for ITSM" app?**
No. This emulator *is* that app (from the connector's perspective). The health endpoint reports the app as installed.

**Q: Does this work with ServiceNow SecOps (SIR) connectors too?**
The SIR health endpoint (`/api/x_elas2_sir_int/elastic_api/health`) is also emulated. The SIR connector uses the same Import Set pattern but targets a different table — it should work for basic flows, though some SIR-specific fields may not render in the portal.

**Q: Can I use this with Elastic Cloud?**
Yes — expose the emulator via ngrok or cloudflared so your cloud deployment can reach it:
```bash
ngrok http https://localhost:3000
```
Then use the ngrok URL as your ServiceNow instance URL in the connector config.

**Q: The connector says "Unable to get choices"**
Make sure the TLS is configured (see step 2 above). The emulator never rejects on auth, so this is almost always a cert trust issue.

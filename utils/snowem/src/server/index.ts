import http from 'node:http';
import https from 'node:https';
import fs from 'node:fs';
import path from 'node:path';
import { execSync } from 'node:child_process';
import express from 'express';
import cors from 'cors';
import healthRoutes from './routes/health.js';
import importSetRoutes from './routes/importSet.js';
import tableRoutes from './routes/table.js';
import internalRoutes from './routes/internal.js';
import { basicAuth } from './middleware/auth.js';
import { activityLogger } from './middleware/logger.js';

const app = express();
const PORT = parseInt(process.env.PORT || '3000');
const CERT_DIR = path.resolve(process.cwd(), '.certs');
const NO_TLS = process.argv.includes('--no-tls') || process.env.NO_TLS === '1';

app.use(cors());
app.use(express.json());
app.use(basicAuth);
app.use(activityLogger);

app.use(healthRoutes);
app.use(importSetRoutes);
app.use(tableRoutes);
app.use(internalRoutes);

// Catch-all for any /api/* routes we haven't explicitly handled
app.all('/api/*', (req, res) => {
  console.log(`[unhandled] ${req.method} ${req.originalUrl}`);
  console.log(`  Headers: ${JSON.stringify(req.headers, null, 2)}`);
  if (req.body && Object.keys(req.body).length > 0) {
    console.log(`  Body: ${JSON.stringify(req.body)}`);
  }
  // Return empty result set (not null) to avoid checkInstance failures
  res.json({ result: [] });
});

// Serve static client build in production
const clientDist = path.resolve(process.cwd(), 'dist/client');
if (fs.existsSync(clientDist)) {
  app.use(express.static(clientDist));
  app.get('*', (_req, res) => {
    res.sendFile(path.join(clientDist, 'index.html'));
  });
}

function ensureCerts(): { key: string; cert: string; caPath: string } {
  const caKeyPath = path.join(CERT_DIR, 'ca.key');
  const caCertPath = path.join(CERT_DIR, 'ca.crt');
  const keyPath = path.join(CERT_DIR, 'server.key');
  const certPath = path.join(CERT_DIR, 'server.crt');
  const csrPath = path.join(CERT_DIR, 'server.csr');
  const extPath = path.join(CERT_DIR, 'san.ext');

  if (!fs.existsSync(certPath) || !fs.existsSync(keyPath)) {
    fs.mkdirSync(CERT_DIR, { recursive: true });
    console.log('Generating CA + server certificate with SANs...');

    // Generate a local CA
    execSync(
      `openssl req -x509 -newkey rsa:2048 -keyout "${caKeyPath}" -out "${caCertPath}" -days 3650 -nodes -subj "/CN=SNOW Emulator Local CA"`,
      { stdio: 'pipe' }
    );

    // Write SAN extension file
    fs.writeFileSync(extPath, [
      '[v3_req]',
      'authorityKeyIdentifier=keyid,issuer',
      'basicConstraints=CA:FALSE',
      'keyUsage=digitalSignature,nonRepudiation,keyEncipherment,dataEncipherment',
      'subjectAltName=@alt_names',
      '',
      '[alt_names]',
      'DNS.1=localhost',
      'DNS.2=*.localhost',
      'IP.1=127.0.0.1',
      'IP.2=::1',
    ].join('\n'));

    // Generate server key + CSR
    execSync(
      `openssl req -newkey rsa:2048 -keyout "${keyPath}" -out "${csrPath}" -nodes -subj "/CN=localhost"`,
      { stdio: 'pipe' }
    );

    // Sign with our CA, including SANs
    execSync(
      `openssl x509 -req -in "${csrPath}" -CA "${caCertPath}" -CAkey "${caKeyPath}" -CAcreateserial -out "${certPath}" -days 365 -extfile "${extPath}" -extensions v3_req`,
      { stdio: 'pipe' }
    );

    // Clean up intermediate files
    try { fs.unlinkSync(csrPath); } catch {}
    try { fs.unlinkSync(extPath); } catch {}
    try { fs.unlinkSync(path.join(CERT_DIR, 'ca.srl')); } catch {}

    console.log('Certificates generated at .certs/');
    console.log(`  CA cert: .certs/ca.crt  (add this to Kibana's CA trust)`);
  }

  return {
    key: fs.readFileSync(keyPath, 'utf-8'),
    cert: fs.readFileSync(certPath, 'utf-8') + fs.readFileSync(caCertPath, 'utf-8'),
    caPath: caCertPath,
  };
}

function startServer() {
  const protocol = NO_TLS ? 'http' : 'https';
  let server: http.Server | https.Server;

  if (NO_TLS) {
    server = http.createServer(app);
  } else {
    const { key, cert, caPath } = ensureCerts();
    server = https.createServer({ key, cert }, app);
    console.log(`\n  TLS CA certificate: ${caPath}`);
    console.log(`  To trust in Kibana, add to kibana.yml:`);
    console.log(`    xpack.actions.customHostSettings:`);
    console.log(`      - url: "https://localhost:${PORT}"`);
    console.log(`        ssl:`);
    console.log(`          certificateAuthoritiesFiles: ["${path.resolve(caPath)}"]`);
    console.log(`\n  Or disable verification (less secure):`);
    console.log(`    xpack.actions.customHostSettings:`);
    console.log(`      - url: "https://localhost:${PORT}"`);
    console.log(`        ssl:`);
    console.log(`          verificationMode: none`);
  }

  server.listen(PORT, () => {
    console.log(`\n  SNOW ITSM Emulator running at:`);
    console.log(`    ${protocol}://localhost:${PORT}\n`);
    console.log(`  Configure your Elastic ServiceNow connector with:`);
    console.log(`    URL: ${protocol}://localhost:${PORT}`);
    console.log(`    Username: any`);
    console.log(`    Password: any`);
    console.log(`    Uses Table API: false`);
    if (NO_TLS) {
      console.log(`\n  Running without TLS (--no-tls mode).`);
      console.log(`  Note: Kibana connectors require HTTPS by default.`);
      console.log(`  Use a reverse proxy with TLS termination, or remove --no-tls.`);
    }
    console.log('');
  });
}

startServer();

/*app.ts*/
import express, { Express } from 'express';
import type { Request, Response } from 'express';

import { createProxyMiddleware } from 'http-proxy-middleware';

import { Logger } from "tslog";
const logger = new Logger({ name: "router", type: "json" });

const promClient = require('prom-client');
// Create a Registry to register metrics
const promRegistry = new promClient.Registry();
const metricTransactions = new promClient.Counter({
  name: 'transactions',
  help: 'number of transactions routed',
  registers: [promRegistry]
});

const PORT: number = parseInt(process.env.PORT || '9000');
const app: Express = express();

function getRandomBoolean() {
  return Math.random() < 0.5;
}

function customRouter(req: any) {
  var host = "";
  var method = ""

  const requestBody = req.body;
  metricTransactions.inc();

  if (req.query.service != null) {
    method = "service";
    host = `http://${req.query.service}:9003`;
  }
  else {
    if (req.query.canary === 'true') {
      method = "canary";
      host = `http://${process.env.RECORDER_HOST_CANARY}:9003`;
    }
    else {
      if (process.env.RECORDER_HOST_2 == null) {
        method = "default";
        host = `http://${process.env.RECORDER_HOST_1}:9003`;
      }
      else
      {
        method = "random";
        if (getRandomBoolean())
          host = `http://${process.env.RECORDER_HOST_1}:9003`;
        else
          host = `http://${process.env.RECORDER_HOST_2}:9003`;
      }
    }
  }

  logger.info(`routing request to ${host}`);
  return host;
};

const proxyMiddleware = createProxyMiddleware<Request, Response>({
  router: customRouter,
  changeOrigin: true,
  proxyTimeout: 5000
})

app.use(express.json());

app.get('/health', (req, res) => {
  res.send("KERNEL OK")
});

// The metrics endpoint
app.get('/metrics', async (req, res) => {
  try {
    // Set the appropriate content type header for Prometheus
    res.setHeader('Content-Type', promRegistry.contentType);
    // Respond with the metrics data
    res.end(await promRegistry.metrics());
  } catch (err) {
    res.status(500).end(err);
  }
})

app.use('/', proxyMiddleware);

app.listen(PORT, () => {
  logger.info(`Listening for requests on http://localhost:${PORT}`);
});

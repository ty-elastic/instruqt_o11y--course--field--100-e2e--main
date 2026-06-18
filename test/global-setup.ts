import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { defaultResource, resourceFromAttributes } from '@opentelemetry/resources';
import 'dotenv/config'

import {
  ConsoleMetricExporter,
  PeriodicExportingMetricReader,
} from '@opentelemetry/sdk-metrics';
import { NodeSDK } from '@opentelemetry/sdk-node';
import { ConsoleSpanExporter } from '@opentelemetry/sdk-trace-node';
import {
  ATTR_SERVICE_NAME,
  ATTR_SERVICE_VERSION,
} from '@opentelemetry/semantic-conventions';
import { FullConfig } from '@playwright/test';

const sdk = new NodeSDK({
  resource: defaultResource().merge(resourceFromAttributes({
    [ ATTR_SERVICE_NAME ]: 'superdemo-reporter',
    [ ATTR_SERVICE_VERSION ]: '0.1.0',
  })),
  traceExporter: new OTLPTraceExporter(),
  metricReader: new PeriodicExportingMetricReader({
    exporter: new ConsoleMetricExporter(),
  }),
});

export default async function globalSetup(_config: FullConfig) {
  sdk.start();

  return async () => {
    await sdk.shutdown();
  };
}
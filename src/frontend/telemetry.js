/*
npm install @opentelemetry/api\
      @opentelemetry/core\
      @opentelemetry/resources\
      @opentelemetry/opentelemetry-browser-detector\
      @opentelemetry/sdk-trace-base\
      @opentelemetry/sdk-trace-web\
      @opentelemetry/context-zone\
      @opentelemetry/exporter-trace-otlp-http\
      @opentelemetry/sdk-metrics\
      @opentelemetry/exporter-metrics-otlp-http\
      @opentelemetry/api-logs\
      @opentelemetry/sdk-logs\
      @opentelemetry/exporter-logs-otlp-http\
      @opentelemetry/instrumentation\
      @opentelemetry/auto-instrumentations-web\
      @opentelemetry/instrumentation-long-task
  */

import { diag, DiagConsoleLogger, trace, metrics } from '@opentelemetry/api';
import { diagLogLevelFromString, SDK_INFO } from '@opentelemetry/core';
import { resourceFromAttributes, detectResources } from '@opentelemetry/resources';
import { browserDetector } from '@opentelemetry/opentelemetry-browser-detector';
import { ZoneContextManager } from '@opentelemetry/context-zone';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { BatchSpanProcessor } from '@opentelemetry/sdk-trace-base';
import { WebTracerProvider } from '@opentelemetry/sdk-trace-web';
import { MeterProvider, PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-http';
import { logs, SeverityNumber } from '@opentelemetry/api-logs';
import { BatchLogRecordProcessor, LoggerProvider } from '@opentelemetry/sdk-logs';
import { OTLPLogExporter } from '@opentelemetry/exporter-logs-otlp-http';
import { registerInstrumentations } from '@opentelemetry/instrumentation';
import { getWebAutoInstrumentations } from '@opentelemetry/auto-instrumentations-web';
import { LongTaskInstrumentation } from '@opentelemetry/instrumentation-long-task';

const initDone = Symbol('OTEL initialized');

// Expected properties of the config object:
// - logLevel
// - endpoint
// - resourceAttributes
export function initOpenTelemetry(config) {
  // To avoid multiple calls
  if (window[initDone]) {
    return;
  }
  window[initDone] = true;
  diag.setLogger(
    new DiagConsoleLogger(),
    { logLevel: diagLogLevelFromString(config.logLevel) },
  );
  diag.info('OTEL bootstrap', config);

  // Resource definition
  const resourceAttributes = { ...config.resourceAttributes, ...SDK_INFO };
  const detectedResources = detectResources({ detectors: [browserDetector] });
  const resource = resourceFromAttributes(resourceAttributes)
                              .merge(detectedResources);

  // Trace signal setup
  const tracesEndpoint = `${config.endpoint}/v1/traces`;
  const tracerProvider = new WebTracerProvider({
    resource,
    spanProcessors: [
      new BatchSpanProcessor(new OTLPTraceExporter({
        url: tracesEndpoint,
      })),
    ],
  });
  tracerProvider.register({ contextManager: new ZoneContextManager() })

  // Metrics signal setup
  const metricsEndpoint = `${config.endpoint}/v1/metrics`;
  const metricReader = new PeriodicExportingMetricReader({
    exporter: new OTLPMetricExporter({ url: metricsEndpoint }),
  });
  const meterProvider = new MeterProvider({
    resource: resource,
    readers: [metricReader],
  });
  metrics.setGlobalMeterProvider(meterProvider);

  // Logs signal setup
  const logsEndpoint = `${config.endpoint}/v1/logs`;
  const logExporter = new OTLPLogExporter({ url: logsEndpoint });

  const loggerProvider = new LoggerProvider({
    resource: resource,
    processors: [new BatchLogRecordProcessor(logExporter)]
  });
  logs.setGlobalLoggerProvider(loggerProvider);

  // Register instrumentations
  registerInstrumentations({
    instrumentations: [
    getWebAutoInstrumentations({
      // load custom configuration for xml-http-request instrumentation
      '@opentelemetry/instrumentation-user-interaction': {
        eventNames: ['submit', 'click'],
      },
    }),
      new LongTaskInstrumentation(),
    ],
  });
}



const apm = initOpenTelemetry({
  logLevel: 'info',
  endpoint: '/telemetry',
  resourceAttributes: {
    'service.name': '${SERVICE_NAME}',
    'service.version': '${SERVICE_VERSION}',
    'deployment.environment.name': '${NAMESPACE}'
  }
});
export default apm;

import { test, expect } from '@playwright/test';
import 'dotenv/config'
import { trace, context } from '@opentelemetry/api';

function getTraceParent() {
  const span = trace.getSpan(context.active());
  if (!span) return null;
  
  const spanContext = span.spanContext();
  // Format: version-traceId-spanId-traceFlags]
  //return `00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01`
  return `00-${spanContext.traceId}-${spanContext.spanId}-01`;
}

test.beforeEach(async ({ page }) => {

  const traceparent = getTraceParent();
  
  if (traceparent) {
    await page.setExtraHTTPHeaders({ traceparent });
  }

  await page.goto(process.env.INSTRUQT_INVITE);

  const primaryBtn = page.getByRole('button', { name: 'Start' });
  const secondaryBtn = page.getByRole('button', { name: 'Continue' });
  await primaryBtn.or(secondaryBtn).click();

  // Use await inside the condition because isVisible() returns a Promise
  if (await primaryBtn.isVisible()) {
    await expect(page.getByRole('main')).toContainText('Please wait while we set up the challenge.');
    await expect(page.getByRole('button', { name: 'Start' })).toBeVisible({ timeout: 1800000 });
    await page.getByRole('button', { name: 'Start' }).click();
  }

  await expect(page.getByRole('main')).toContainText('Elastic');
});

test('promql', async ({ page }) => {
  const page1Promise = page.waitForEvent('popup');
  await page.locator('span').filter({ hasText: 'Elastic-Breakout' }).click();
  const page1 = await page1Promise;
  await page1.waitForLoadState();

  await page1.getByRole('link', { name: 'Discover' }).click();
  await page1.getByRole('button', { name: 'Query in ES|QL' }).click();

  await page1.getByRole('textbox', { name: 'Editor content;Press Alt+F1' }).press('ControlOrMeta+a');
  await page1.getByRole('textbox', { name: 'Editor content;Press Alt+F1' }).fill('PROMQL index=metrics-* start=?_tstart end=?_tend step=5m sum by (region) (rate(metrics.http_requests_total[5m]))');

  await page1.getByRole('button', { name: 'Search', exact: true }).click({ timeout: 10000 });

  await expect(page1.getByTestId('echChart').locator('canvas')).toBeVisible({ timeout: 10000 });
  await expect(page1.getByTestId('echChart').locator('canvas')).toHaveScreenshot('promql_chart.png', { maxDiffPixelRatio: 0.05 });

  await page1.close();
});


test('saved_searches', async ({ page }) => {
  const page1Promise = page.waitForEvent('popup');
  await page.locator('span').filter({ hasText: 'Elastic-Breakout' }).click();
  const page1 = await page1Promise;
  await page1.waitForLoadState();

  await page1.getByRole('link', { name: 'Discover' }).click();
  await page1.getByRole('button', { name: 'Query in ES|QL' }).click();
  await page1.getByLabel('More').click();
  await page1.getByRole('menuitem', { name: 'Open session' }).click();
  await page1.getByRole('button', { name: 'Tags Selection' }).click();
  await page1.getByText('metrics', { exact: true }).click();
  await page1.getByRole('button', { name: 'Prometheus' }).click();
  await page1.getByText('PROMQL').click();

  await page1.getByRole('button', { name: 'Search', exact: true }).click({ timeout: 10000 });

  await expect(page1.getByTestId('echChart').locator('canvas')).toBeVisible({ timeout: 10000 });
  await expect(page1.getByTestId('echChart').locator('canvas')).toHaveScreenshot('promql_chart.png', { maxDiffPixelRatio: 0.05 });

  await page1.close();
});

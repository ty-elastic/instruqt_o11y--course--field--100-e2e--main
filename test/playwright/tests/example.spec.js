// @ts-check
import { test, expect } from '@playwright/test';
import dotenv from 'dotenv';
import path from 'path';

console.log(__dirname)

// Read from the ".env" file located in your root directory
dotenv.config({ path: path.resolve(__dirname, '.env') });

test.beforeEach(async ({ page }) => {

  await page.setExtraHTTPHeaders({
    'Authorization': `Basic ${process.env.ELASTICSEARCH_AUTH_BASE64}`
  });
});


test('initial', async ({ page }) => {
  await page.goto(process.env.ELASTICSEARCH_URL);
});

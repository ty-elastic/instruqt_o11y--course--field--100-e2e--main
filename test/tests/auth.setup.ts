import { test as setup, expect } from '@playwright/test';
import 'dotenv/config'

setup('authenticate user', async ({ page }) => {

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

  // End of authentication steps.
  await page.context().storageState({ path: './.auth/session.json' });
});

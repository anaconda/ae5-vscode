import { chromium } from 'playwright';
import { expect } from 'playwright/test';

async function waitForTextAnywhere(page, needles, timeout = 90_000) {
  const wanted = Array.isArray(needles) ? needles : [needles];
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    for (const frame of page.frames()) {
      try {
        if (await frame.evaluate(
          list => list.some(s => document.documentElement.outerHTML.includes(s)),
          wanted
        )) return frame;
      } catch {}
    }
    await page.waitForTimeout(250);
  }
  throw new Error(`Timed out ${timeout}ms waiting for any of ${JSON.stringify(wanted)}`);
}

async function runScript() {
  const expected_version = process.argv[2];
  const expected_env = process.argv[3];
  const browser = await chromium.launch();
  const page = await browser.newPage();
  let reachedPage = false;
  try {
    await page.goto('http://localhost:8086');
    reachedPage = true;
    await expect(page.getByText('route_chord.ipynb')).toBeVisible({ timeout: 10000 });
    await page.getByRole('button', { name: /Toggle Secondary Side Bar/ }).click();
    await page.waitForTimeout(500);
    await page.getByText('route_chord.ipynb').click();
    await page.waitForTimeout(500);
    await page.getByText('Select Kernel').click();
    await page.waitForTimeout(500);
    await page.getByText('Python Environments...').click();
    await page.waitForTimeout(500);
    await page.getByText(expected_env).click();
    await page.waitForTimeout(500);
    await page.getByText('Run All').click();
    await waitForTextAnywhere(page, [
      'Salt Lake City', 'Seattle', 'Houston', 'Washington',
      'Los Angeles', 'San Francisco', 'Detroit', 'Fort Worth',
    ]);
    await page.locator('.menubar-menu-button').click();
    await page.waitForTimeout(500);
    await page.getByRole('menuitem', { name: 'Help' }).click();
    await page.waitForTimeout(500);
    await page.getByRole('menuitem', { name: 'About' }).click();
    await expect(page.getByText('code-server: v' + expected_version)).toBeVisible({ timeout: 5000 });
  } finally {
    if (reachedPage) {
      try {
        await page.screenshot({path: './test_screenshot.png', scale: 'css', type: 'png'});
      } catch (err) {
        console.error(err);
      }
    }
    await browser.close();
  }
}

runScript().catch((err) => {
  console.error(err);
  process.exit(1);
});

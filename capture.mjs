import { chromium } from 'playwright';
import { expect } from 'playwright/test';

async function waitForTextAnywhere(page, needle, timeout = 30_000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    for (const frame of page.frames()) {
      try {
        if (await frame.evaluate(
          s => document.documentElement.outerHTML.includes(s), needle
        )) return frame;
      } catch {}
    }
    await page.waitForTimeout(250);
  }
  throw new Error(`Timed out ${timeout}ms waiting for ${JSON.stringify(needle)}`);
}

async function runScript() {
  const expected_version = process.argv[2];
  const expected_env = process.argv[3];
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto('http://localhost:8086');
  await expect(page.getByText('route_chord.ipynb')).toBeVisible({ timeout: 10000 });
  await page.getByRole('button',{name:'Toggle Secondary Side Bar (⌥⌘B)'}).click();
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
  await waitForTextAnywhere(page, 'Salt Lake City');
  await page.locator('.menubar-menu-button').click();
  await page.waitForTimeout(500);
  await page.getByRole('menuitem',{name:'Help'}).click();
  await page.waitForTimeout(500);
  await page.getByRole('menuitem',{name:'About'}).click();
  await expect(page.getByText('code-server: v' + expected_version)).toBeVisible({ timeout: 5000 });
  await page.screenshot({path: './test_screenshot.png', scale: 'css', type: 'png'});
  await browser.close();
}

runScript().catch((err) => {
  console.error(err);
  process.exit(1);
});

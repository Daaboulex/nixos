#!/usr/bin/env node
/**
 * Browser scraping script to extract Antigravity version from download page
 * Uses Playwright with bundled Chrome for reliable version detection
 */

const { chromium } = require('playwright-chromium');

async function scrapeVersion() {
  console.error('[INFO] Launching browser...');

  // On NixOS, use system Chrome if available
  // In CI/other environments, let Playwright use bundled Chromium
  const chromePath = process.env.CHROME_BIN ||
                     process.env.CHROME_PATH ||
                     '/run/current-system/sw/bin/google-chrome-stable';

  // Check if the Chrome path exists before using it
  const fs = require('fs');
  const useSystemChrome = fs.existsSync(chromePath);

  const browser = await chromium.launch({
    headless: true,
    ...(useSystemChrome && { executablePath: chromePath }),
  });

  try {
    const page = await browser.newPage();

    console.error('[INFO] Navigating to Antigravity download page...');
    await page.goto('https://antigravity.google/download/linux', {
      waitUntil: 'networkidle',
      timeout: 30000,
    });

    console.error('[INFO] Waiting for page to render...');
    await page.waitForTimeout(3000); // Give JavaScript time to render

    // Try multiple strategies to extract version
    const version = await page.evaluate(() => {
      // Strategy 1: Look for download link with version pattern
      const downloadLinks = Array.from(document.querySelectorAll('a[href*="antigravity/stable/"]'));
      for (const link of downloadLinks) {
        const href = link.getAttribute('href') || '';
        const match = href.match(/antigravity\/stable\/([0-9.]+-[0-9]+)/);
        if (match) return match[1];
      }

      // Strategy 2: Look in any element containing version pattern
      const allText = document.body.innerText;
      const match = allText.match(/\b([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}-[0-9]+)\b/);
      if (match) return match[1];

      // Strategy 3: Look in meta tags
      const metas = Array.from(document.querySelectorAll('meta'));
      for (const meta of metas) {
        const content = meta.getAttribute('content') || '';
        const versionMatch = content.match(/([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}-[0-9]+)/);
        if (versionMatch) return versionMatch[1];
      }

      return null;
    });

    if (version) {
      console.error(`[SUCCESS] Found version: ${version}`);
      console.log(version); // Output ONLY version to stdout for script consumption
      return version;
    } else {
      console.error('[ERROR] Could not extract version from page');
      process.exit(1);
    }
  } catch (error) {
    console.error(`[ERROR] ${error.message}`);
    process.exit(1);
  } finally {
    await browser.close();
  }
}

scrapeVersion().catch(error => {
  console.error(`[FATAL] ${error.message}`);
  process.exit(1);
});

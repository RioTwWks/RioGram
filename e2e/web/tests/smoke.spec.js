// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('RioGram Web smoke (§8.6)', () => {
  test('loads index and Flutter bootstrap', async ({ page }) => {
    const response = await page.goto('/');
    expect(response?.status()).toBe(200);
    await expect(page).toHaveTitle(/RioGram/);

    await page.waitForFunction(
      () => typeof window.flutter !== 'undefined' || document.querySelector('flutter-view') !== null,
      { timeout: 45_000 },
    );
  });

  test('WSS transport hook is installed', async ({ page }) => {
    await page.goto('/');
    const hasHook = await page.evaluate(() => {
      return (
        typeof window.RioGramWssProxy === 'object' &&
        typeof window.RioGramWssProxy.rewriteUrl === 'function'
      );
    });
    expect(hasHook).toBe(true);

    const rewritten = await page.evaluate(() => {
      window.RioGramWssProxy.writeConfig({
        enabled: true,
        url: 'wss://proxy.example.ru',
      });
      return window.RioGramWssProxy.rewriteUrl(
        'wss://venus.web.telegram.org/apiws',
      );
    });
    expect(rewritten).toBe(
      'wss://proxy.example.ru/venus.web.telegram.org/apiws',
    );
  });

  test('flutter app shell renders (CanvasKit)', async ({ page }) => {
    await page.goto('/');
    const flutterView = page.locator('flutter-view');
    await expect(flutterView).toBeVisible({ timeout: 45_000 });
    const box = await flutterView.boundingBox();
    expect(box?.width ?? 0).toBeGreaterThan(200);
    expect(box?.height ?? 0).toBeGreaterThan(200);
    // CanvasKit не экспонирует текст в DOM — экран входа проверяется вручную (WEB_E2E.md)
  });

  test('static assets respond 200', async ({ page, request }) => {
    const base = process.env.E2E_BASE_URL || 'http://127.0.0.1:8080';
    for (const path of ['/main.dart.js', '/js/wss_proxy_hook.js', '/manifest.json']) {
      const resp = await request.get(`${base}${path}`);
      expect(resp.status(), path).toBe(200);
    }
  });
});

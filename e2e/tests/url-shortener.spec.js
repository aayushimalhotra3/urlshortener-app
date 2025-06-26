const { test, expect } = require('@playwright/test');

test.describe('URL Shortener Application', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('should load the homepage successfully', async ({ page }) => {
    await expect(page).toHaveTitle(/URL Shortener/);
    await expect(page.locator('h1')).toContainText('URL Shortener');
    await expect(page.locator('#urlInput')).toBeVisible();
    await expect(page.locator('#shortenBtn')).toBeVisible();
  });

  test('should shorten a valid URL', async ({ page }) => {
    const testUrl = 'https://www.example.com';
    
    // Fill in the URL input
    await page.fill('#urlInput', testUrl);
    
    // Click the shorten button
    await page.click('#shortenBtn');
    
    // Wait for the result to appear
    await expect(page.locator('#result')).toBeVisible();
    await expect(page.locator('#shortUrl')).toBeVisible();
    
    // Verify the shortened URL format
    const shortUrl = await page.locator('#shortUrl').textContent();
    expect(shortUrl).toMatch(/http:\/\/localhost:8081\/[a-zA-Z0-9]+/);
    
    // Verify copy button is visible
    await expect(page.locator('#copyBtn')).toBeVisible();
  });

  test('should show error for invalid URL', async ({ page }) => {
    const invalidUrl = 'not-a-valid-url';
    
    // Fill in invalid URL
    await page.fill('#urlInput', invalidUrl);
    
    // Click the shorten button
    await page.click('#shortenBtn');
    
    // Wait for error message
    await expect(page.locator('#error')).toBeVisible();
    await expect(page.locator('#error')).toContainText('please provide a valid URL');
  });

  test('should show error for empty URL', async ({ page }) => {
    // Click the shorten button without entering URL
    await page.click('#shortenBtn');
    
    // Wait for error message
    await expect(page.locator('#error')).toBeVisible();
    await expect(page.locator('#error')).toContainText('URL is required');
  });

  test('should copy shortened URL to clipboard', async ({ page, context }) => {
    // Grant clipboard permissions
    await context.grantPermissions(['clipboard-read', 'clipboard-write']);
    
    const testUrl = 'https://www.google.com';
    
    // Shorten a URL
    await page.fill('#urlInput', testUrl);
    await page.click('#shortenBtn');
    
    // Wait for result and copy
    await expect(page.locator('#result')).toBeVisible();
    await page.click('#copyBtn');
    
    // Verify clipboard content
    const clipboardText = await page.evaluate(() => navigator.clipboard.readText());
    expect(clipboardText).toMatch(/http:\/\/localhost:8081\/[a-zA-Z0-9]+/);
  });

  test('should redirect to original URL when accessing short code', async ({ page, context }) => {
    const testUrl = 'https://www.github.com';
    
    // Shorten a URL
    await page.fill('#urlInput', testUrl);
    await page.click('#shortenBtn');
    
    // Wait for result
    await expect(page.locator('#result')).toBeVisible();
    
    // Extract the short code from the URL
    const shortUrl = await page.locator('#shortUrl').textContent();
    const shortCode = shortUrl.split('/').pop();
    
    // Navigate to the short URL in a new page to test redirect
    const newPage = await context.newPage();
    
    // Navigate to the short code and expect redirect
    const response = await newPage.goto(`/${shortCode}`);
    
    // Check if we were redirected (status should be 200 after redirect)
    expect(response.status()).toBe(200);
    
    // Verify we're on the target domain
    expect(newPage.url()).toContain('github.com');
    
    await newPage.close();
  });

  test('should show 404 page for non-existent short code', async ({ page }) => {
    // Navigate to a non-existent short code
    await page.goto('/nonexistent123');
    
    // Should show 404 page
    await expect(page.locator('h1')).toContainText('Page Not Found');
    await expect(page.locator('body')).toContainText('shortened URL does not exist');
  });

  test('should maintain URL history', async ({ page }) => {
    const urls = [
      'https://www.example.com',
      'https://www.google.com',
      'https://www.github.com'
    ];
    
    // Shorten multiple URLs
    for (const url of urls) {
      await page.fill('#urlInput', url);
      await page.click('#shortenBtn');
      await expect(page.locator('#result')).toBeVisible();
      
      // Clear the input for next URL
      await page.fill('#urlInput', '');
    }
    
    // Check if history section is visible and contains entries
    await expect(page.locator('#history')).toBeVisible();
    
    // Verify history contains the URLs we shortened
    const historyItems = page.locator('#history .history-item');
    await expect(historyItems).toHaveCount(urls.length);
  });

  test('should handle network errors gracefully', async ({ page }) => {
    // Intercept network requests and simulate failure
    await page.route('/shorten', route => {
      route.abort('failed');
    });
    
    const testUrl = 'https://www.example.com';
    
    // Try to shorten URL
    await page.fill('#urlInput', testUrl);
    await page.click('#shortenBtn');
    
    // Should show network error
    await expect(page.locator('#error')).toBeVisible();
    await expect(page.locator('#error')).toContainText('Network error');
  });

  test('should be responsive on mobile devices', async ({ page }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });
    
    // Verify elements are still visible and functional
    await expect(page.locator('#urlInput')).toBeVisible();
    await expect(page.locator('#shortenBtn')).toBeVisible();
    
    // Test functionality on mobile
    const testUrl = 'https://www.example.com';
    await page.fill('#urlInput', testUrl);
    await page.click('#shortenBtn');
    
    await expect(page.locator('#result')).toBeVisible();
  });
});

test.describe('Health Check and Metrics', () => {
  test('should have working health check endpoint', async ({ request }) => {
    const response = await request.get('/health');
    expect(response.status()).toBe(200);
    
    const body = await response.json();
    expect(body.status).toBe('healthy');
  });

  test('should have working metrics endpoint', async ({ request }) => {
    const response = await request.get('/metrics');
    expect(response.status()).toBe(200);
    
    const body = await response.text();
    expect(body).toContain('# HELP');
    expect(body).toContain('# TYPE');
  });
});
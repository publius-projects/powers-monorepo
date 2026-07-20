import { test, expect, type Page, type Locator } from '@playwright/test';
import { VIEWPORTS } from './viewports';

// Mirrors public/organisations/DeployedExamples.ts. Inlined rather than
// imported: that file pulls in `@wagmi/core/chains`, which breaks when
// loaded through Playwright's test loader (works fine inside Next.js's
// bundler, but not standalone) - see arbitrumSepolia.id=421614, sepolia.id=11155111.
const DeployedExamples = [
  { id: 'staking-pool-governance', chainId: 421614, address: '0x1625eB24df6571Ae13ebD9Cc3bd82b5F1E38405a' },
  { id: 'bicameralism', chainId: 421614, address: '0x9b16B31FF15535F871d8017b1Cca682E65E49ee1' },
  { id: 'optimistic-execution', chainId: 421614, address: '0x455810765b497519869187eCf57424611a83709E' },
  { id: 'nested-governance-parent', chainId: 421614, address: '0x0CE0eB29E56cead1499061991de07Cf86658740a' },
  { id: 'open-elections', chainId: 421614, address: '0x5F44F12114d352eF191557Fb7a7202D96035d883' },
  { id: 'token-delegates', chainId: 421614, address: '0xc80A4747AA3562E23497e7E3570B10dA3A0F706D' },
  { id: 'account-abstraction', chainId: 421614, address: '0x2D95D1b1562a12C4220F29414837b238Dcf3430c' },
  { id: 'powers101', chainId: 421614, address: '0x6D5A3A936bb1e5434ad60E58E58848Bd67Afb79B' },
];

// The same sentence list rendered by CyclingTypewriter (app/CyclingTypewriter.tsx).
// Duplicated here (rather than imported) so this test asserts against the
// user-visible contract, not an implementation detail.
const TYPEWRITER_SENTENCES = [
  'to ensure privacy for netizens.',
  'to be accessible to all.',
  'to coordinate across borders.',
  'to separate powers by design.',
  'to make governance verifiable.',
  'to enable anonymous participation.',
  'to govern without intermediaries.',
];

async function getOpacity(locator: Locator): Promise<number> {
  return locator.evaluate((el) => parseFloat(getComputedStyle(el).opacity));
}

// HeroSection / SectionIntro reveal their paragraphs via a scroll listener
// that reads `scrollContainer.scrollTop` directly (no IntersectionObserver,
// no GSAP). Rather than computing the exact pixel offsets the components use
// internally, we nudge the scroll container forward in small steps and poll
// the target paragraphs' opacity until the predicate is satisfied.
async function scrollMainUntil(
  page: Page,
  main: Locator,
  predicate: () => Promise<boolean>,
  { maxSteps = 80 }: { maxSteps?: number } = {}
): Promise<boolean> {
  const viewportHeight = page.viewportSize()?.height ?? 800;
  const stepPx = Math.round(viewportHeight * 0.15);
  for (let i = 0; i < maxSteps; i++) {
    if (await predicate()) return true;
    await main.evaluate((el, step) => {
      el.scrollTop += step;
    }, stepPx);
    await page.waitForTimeout(20);
  }
  return predicate();
}

for (const viewport of VIEWPORTS) {
  test.describe(`landing page @ ${viewport.label}`, () => {
    test.use({ viewport: { width: viewport.width, height: viewport.height } });

    test('renders hero and footer', async ({ page }) => {
      await page.goto('/');
      await expect(page.locator('main').first()).toBeVisible();
      await expect(page.locator('#page-footer')).toBeVisible();
    });

    test.describe('HeroSection', () => {
      test('typewriter cycles through multiple distinct sentences', async ({ page }) => {
        await page.goto('/');
        await page.waitForLoadState('networkidle');
        const typewriter = page.locator('main > div').first().locator('div.text-muted-foreground').first();
        await expect(typewriter).toBeVisible();

        const seen = new Set<string>();
        const deadline = Date.now() + 20_000;
        while (Date.now() < deadline && seen.size < 2) {
          const raw = (await typewriter.innerText()).trim();
          // strip the trailing blinking-cursor character ("|") appended by CyclingTypewriter
          const text = raw.endsWith('|') ? raw.slice(0, -1) : raw;
          if (TYPEWRITER_SENTENCES.includes(text)) seen.add(text);
          await page.waitForTimeout(300);
        }

        expect(seen.size, 'expected at least 2 distinct full sentences to be typed out in sequence').toBeGreaterThanOrEqual(2);
      });

      test('all paragraphs fade fully in before the section scrolls away', async ({ page }) => {
        await page.goto('/');
        const main = page.locator('main').first();
        const heroSection = page.locator('main > div').first().locator('section');
        const paragraphs = heroSection.locator('p');
        await expect(paragraphs).toHaveCount(3);

        const allOpaque = async () => {
          const opacities = await Promise.all((await paragraphs.all()).map(getOpacity));
          return opacities.every((o) => o >= 0.95);
        };

        const reached = await scrollMainUntil(page, main, allOpaque);
        expect(reached, 'all 3 hero paragraphs should reach full opacity').toBe(true);

        // Still "before the page scrolls away": the sticky hero section must
        // still be the thing on screen, not already scrolled past.
        await expect(heroSection).toBeInViewport();
      });
    });

    test.describe('SectionIntro', () => {
      test('all paragraphs fade fully in before the section scrolls away', async ({ page }) => {
        await page.goto('/');
        const main = page.locator('main').first();
        const intro = page.locator('#intro');
        const paragraphs = intro.locator('p');
        await expect(paragraphs).toHaveCount(4);

        const allOpaque = async () => {
          const opacities = await Promise.all((await paragraphs.all()).map(getOpacity));
          return opacities.every((o) => o >= 0.95);
        };

        const reached = await scrollMainUntil(page, main, allOpaque, { maxSteps: 140 });
        expect(reached, 'all 4 intro paragraphs should reach full opacity').toBe(true);
        await expect(intro).toBeInViewport();
      });

      test('"Read the documentation" button is visible and clickable at the bottom of the screen', async ({ page }) => {
        await page.goto('/');
        const intro = page.locator('#intro');
        await intro.scrollIntoViewIfNeeded();

        const button = intro.getByRole('link', { name: /read the documentation/i });
        await expect(button).toBeVisible();
        await expect(button).toBeEnabled();
        await expect(button).toHaveAttribute('href', 'https://powers-docs.vercel.app/welcome');
        await expect(button).toHaveAttribute('target', '_blank');

        // "at the bottom of screen": the button's box should sit in the
        // lower half of the viewport once the section is in view.
        const box = await button.boundingBox();
        expect(box).not.toBeNull();
        expect(box!.y).toBeGreaterThan(viewport.height / 2);
      });
    });

    test.describe('SectionDemo', () => {
      test('all flow nodes are visible and draggable', async ({ page }) => {
        await page.goto('/');
        const demo = page.locator('#demo');
        await demo.scrollIntoViewIfNeeded();
        await expect(demo).toBeVisible();

        const nodes = demo.locator('.react-flow__node');
        // 1 flow-group node + 3 mandate nodes, see app/DemoFlow.tsx
        await expect(nodes).toHaveCount(4);
        for (const node of await nodes.all()) {
          await expect(node).toBeVisible();
        }

        const draggableNode = demo.locator('.react-flow__node[data-id="1"]');
        const before = await draggableNode.boundingBox();
        expect(before).not.toBeNull();

        await draggableNode.hover();
        await page.mouse.down();
        await page.mouse.move(before!.x + before!.width / 2 + 60, before!.y + before!.height / 2 + 60, { steps: 10 });
        await page.mouse.up();

        const after = await draggableNode.boundingBox();
        expect(after).not.toBeNull();
        const moved = Math.abs(after!.x - before!.x) + Math.abs(after!.y - before!.y);
        expect(moved, 'dragging a node should change its rendered position').toBeGreaterThan(20);
      });
    });

    test.describe('SectionExamples', () => {
      test('page title is visible', async ({ page }) => {
        await page.goto('/');
        const examples = page.locator('#examples');
        await examples.scrollIntoViewIfNeeded();
        await expect(examples.getByText('Explore', { exact: true })).toBeVisible();
      });

      test('navigation buttons are visible and clickable for every carousel item', async ({ page }) => {
        await page.goto('/');
        const examples = page.locator('#examples');
        await examples.scrollIntoViewIfNeeded();

        const prevBtn = examples.getByRole('button', { name: 'Previous' });
        const nextBtn = examples.getByRole('button', { name: 'Next' });
        const dots = examples.locator('button[aria-label^="Go to example"]');
        await expect(dots).toHaveCount(DeployedExamples.length);

        for (let i = 0; i < DeployedExamples.length; i++) {
          const dot = examples.locator(`button[aria-label="Go to example ${i + 1}"]`);
          await expect(dot).toBeVisible();
          await expect(dot).toBeEnabled();
          await dot.click();

          await expect(prevBtn).toBeVisible();
          await expect(prevBtn).toBeEnabled();
          await expect(nextBtn).toBeVisible();
          await expect(nextBtn).toBeEnabled();

          const forumBtn = examples.getByRole('button', { name: /^(Forum|Coming Soon)$/ });
          const overviewBtn = examples.getByRole('button', { name: /^(Overview|Coming Soon)$/ });
          await expect(forumBtn).toBeVisible();
          await expect(overviewBtn).toBeVisible();
        }
      });

      test('links in the carousel items are correct', async ({ page }) => {
        // Mock RPC so navigating to /forum and /overview doesn't depend on
        // live testnet calls (Alchemy WSS, then HTTP fallback) - this test
        // only checks that the URL is correct after navigation, not that
        // on-chain org data renders.
        await page.routeWebSocket(/g\.alchemy\.com/, (ws) => ws.close());
        await page.route(/g\.alchemy\.com\/v2\//, async (route) => {
          let body: unknown;
          try {
            body = JSON.parse(route.request().postData() ?? '{}');
          } catch {
            body = {};
          }
          const toResult = (entry: any) => ({ jsonrpc: '2.0', id: entry?.id, result: '0x' });
          const payload = Array.isArray(body) ? body.map(toResult) : toResult(body);
          await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(payload) });
        });

        await page.goto('/');
        const examples = page.locator('#examples');

        for (let i = 0; i < DeployedExamples.length; i++) {
          const org = DeployedExamples[i];
          const isComingSoon = org.address === '0x0000000000000000000000000000000000000000';

          await examples.scrollIntoViewIfNeeded();
          await examples.locator(`button[aria-label="Go to example ${i + 1}"]`).click();

          if (isComingSoon) {
            await expect(examples.getByRole('button', { name: 'Coming Soon' }).first()).toBeDisabled();
            continue;
          }

          await examples.getByRole('button', { name: 'Forum', exact: true }).click();
          await expect(page).toHaveURL(`/forum/${org.chainId}/${org.address}`, { timeout: 15_000 });
          await page.goBack();

          await examples.scrollIntoViewIfNeeded();
          await examples.locator(`button[aria-label="Go to example ${i + 1}"]`).click();
          await examples.getByRole('button', { name: 'Overview', exact: true }).click();
          await expect(page).toHaveURL(`/overview/${org.chainId}/${org.address}/organisation`, { timeout: 15_000 });
          await page.goBack();
        }
      });
    });

    test.describe('Footer', () => {
      test('internal links are clickable and navigate to the correct pages', async ({ page }) => {
        await page.goto('/');
        const footer = page.locator('#page-footer');
        await footer.scrollIntoViewIfNeeded();
        await expect(footer).toBeVisible();

        const internalLinks: Array<[string, string]> = [
          ['Home', '/'],
          ['Forum', '/forum'],
          ['Overview', '/overview'],
        ];

        for (const [name, href] of internalLinks) {
          const link = footer.getByRole('link', { name, exact: true });
          await expect(link).toBeVisible();
          await expect(link).toHaveAttribute('href', href);
          await link.click();
          await expect(page).toHaveURL(href, { timeout: 15_000 });
          // Use goto rather than goBack: clicking "Home" while already on
          // "/" doesn't push a new history entry, which makes goBack()
          // overshoot to about:blank. goto deterministically resets state
          // regardless of whether a history entry was created.
          await page.goto('/');
          await footer.scrollIntoViewIfNeeded();
        }
      });

      test('external links point to the correct destinations', async ({ page }) => {
        await page.goto('/');
        const footer = page.locator('#page-footer');
        await footer.scrollIntoViewIfNeeded();

        const externalHrefs = [
          'https://discordapp.com/users/1006928106487021638',
          'https://t.me/thd83',
          'https://github.com/7Cedars',
          'https://powers-docs.vercel.app/for-developers/litepaper',
          'https://powers-docs.vercel.app/welcome',
          'https://github.com/7Cedars/powers/tree/main/solidity',
        ];

        for (const href of externalHrefs) {
          const link = footer.locator(`a[href="${href}"]`);
          await expect(link).toHaveAttribute('target', '_blank');
          await expect(link).toBeVisible();
        }
      });
    });
  });
}

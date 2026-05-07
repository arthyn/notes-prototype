// One-shot cleanup: deletes (or leaves) every e2e-prefixed notebook on
// both ships. Run via `npm run test:e2e:wipe`. Useful when prior failing
// runs left state behind before the cleanup-tracker fixture existed.
//
// Reads HOST_URL/HOST_CODE/SUB_URL/SUB_CODE from tests/e2e/.env.

import { chromium } from "@playwright/test";
import dotenv from "dotenv";
import path from "path";
import fs from "fs/promises";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, ".env") });

async function loginAndStoreState(name: string, url: string, code: string) {
  const browser = await chromium.launch();
  const ctx = await browser.newContext({ baseURL: url });
  const r = await ctx.request.post("/~/login", { form: { password: code } });
  if (![200, 204, 302].includes(r.status())) {
    throw new Error(`${name} login failed: ${r.status()}`);
  }
  const stateFile = path.join(__dirname, ".auth", `${name}.json`);
  await fs.mkdir(path.dirname(stateFile), { recursive: true });
  await ctx.storageState({ path: stateFile });
  await ctx.close();
  await browser.close();
  return stateFile;
}

async function listNotebooks(url: string, stateFile: string): Promise<Array<{ host: string; flagName: string; title: string }>> {
  const browser = await chromium.launch();
  const ctx = await browser.newContext({ baseURL: url, storageState: stateFile });
  const r = await ctx.request.get("/~/scry/notes/v0/notebooks.json");
  const data = (await r.json()) as Array<{ host: string; flagName: string; notebook: { title: string } }>;
  await ctx.close();
  await browser.close();
  return data.map((n) => ({ host: n.host, flagName: n.flagName, title: n.notebook.title }));
}

async function listInvites(url: string, stateFile: string): Promise<Array<{ host: string; flagName: string; title: string }>> {
  const browser = await chromium.launch();
  const ctx = await browser.newContext({ baseURL: url, storageState: stateFile });
  const r = await ctx.request.get("/~/scry/notes/v0/invites.json");
  if (!r.ok()) { await ctx.close(); await browser.close(); return []; }
  const data = (await r.json()) as Array<{ host: string; flagName: string; title: string }>;
  await ctx.close();
  await browser.close();
  return data;
}

async function wipeShip(name: string, url: string, code: string) {
  console.log(`\n=== ${name} (${url}) ===`);
  const stateFile = await loginAndStoreState(name, url, code);
  const allInvites = await listInvites(url, stateFile);
  const inviteTargets = allInvites.filter((i) => i.title.startsWith("e2e-"));
  const all = await listNotebooks(url, stateFile);
  const targets = all.filter((n) => n.title.startsWith("e2e-"));
  if (targets.length === 0 && inviteTargets.length === 0) {
    console.log("  no e2e- notebooks or invites to wipe");
    return;
  }
  if (inviteTargets.length > 0) {
    console.log(`  declining ${inviteTargets.length} e2e- invite(s)…`);
    const browser = await chromium.launch();
    const ctx = await browser.newContext({ baseURL: url, storageState: stateFile });
    const page = await ctx.newPage();
    await page.goto("/notes/");
    await page.evaluate(() => {
      try { localStorage.setItem("alpha-disclaimer-acknowledged", "1"); } catch {}
    });
    await page.reload();
    await page.waitForFunction(
      () => typeof (window as any).__notesGetShip === "function" && (window as any).__notesGetShip() !== "",
      { timeout: 15_000 },
    ).catch(() => {});
    for (const inv of inviteTargets) {
      try {
        await page.evaluate((flag) => {
          // declineInvite is a top-level function in the FE
          return (window as any).declineInvite?.(flag);
        }, `${inv.host}/${inv.flagName}`);
        console.log(`    declined: ${inv.title}`);
        await page.waitForTimeout(200);
      } catch (e) {
        console.log(`    error declining ${inv.title}: ${(e as Error).message}`);
      }
    }
    await ctx.close();
    await browser.close();
  }
  if (targets.length === 0) return;
  console.log(`  wiping ${targets.length} e2e- notebook(s) via UI…`);

  const browser = await chromium.launch();
  const ctx = await browser.newContext({ baseURL: url, storageState: stateFile });
  const page = await ctx.newPage();
  page.on("console", (msg) => console.log(`    [browser ${msg.type()}] ${msg.text()}`));
  page.on("pageerror", (err) => console.log(`    [browser error] ${err.message}`));
  await page.goto("/notes/");
  // dismiss disclaimer if present
  await page.evaluate(() => {
    try { localStorage.setItem("alpha-disclaimer-acknowledged", "1"); } catch {}
  });
  await page.reload();
  // Give the boot a moment to load notebooks into the sidebar
  await page.waitForTimeout(1500);
  console.log(`  page loaded; iterating targets…`);

  for (const target of targets) {
    const item = page.locator(`.nb-item:has-text('${target.title}')`).first();
    if ((await item.count()) === 0) continue;
    try {
      // Items past the sidebar fold aren't visible to .click()/isVisible.
      // dispatchEvent fires a synthetic click without actionability checks.
      await item.dispatchEvent("click");
      await page.waitForTimeout(300);
      // Walk back to root if needed
      const up = page.locator("#folder-up-btn");
      while ((await up.count()) > 0 && (await up.isVisible({ timeout: 200 }).catch(() => false))) {
        await up.dispatchEvent("click");
        await page.waitForTimeout(100);
      }
      const gear = page.locator("#notebook-settings-btn");
      if ((await gear.count()) === 0) {
        console.log(`    skipped (no gear): ${target.title}`);
        continue;
      }
      await gear.dispatchEvent("click");
      page.once("dialog", (d) => d.accept().catch(() => {}));
      const del = page.locator("#nb-menu-delete");
      const leave = page.locator("#nb-menu-leave");
      // After dispatchEvent on the gear, both delete and leave nodes
      // exist; one is display:none. Pick by computed style.
      const delShown = await del.evaluate((el) => getComputedStyle(el).display !== "none").catch(() => false);
      const leaveShown = await leave.evaluate((el) => getComputedStyle(el).display !== "none").catch(() => false);
      if (delShown) {
        await del.dispatchEvent("click");
        console.log(`    deleted: ${target.title}`);
      } else if (leaveShown) {
        await leave.dispatchEvent("click");
        console.log(`    left:    ${target.title}`);
      } else {
        console.log(`    skipped (neither shown): ${target.title}`);
      }
      await page.waitForTimeout(500);
    } catch (e) {
      console.log(`    error wiping ${target.title}: ${(e as Error).message}`);
    }
  }
  await ctx.close();
  await browser.close();
}

async function main() {
  const hostUrl = process.env.HOST_URL || "http://localhost:8082";
  const hostCode = process.env.HOST_CODE || "";
  const subUrl = process.env.SUB_URL || "http://localhost:8083";
  const subCode = process.env.SUB_CODE || "";
  if (!hostCode) throw new Error("HOST_CODE not set in tests/e2e/.env");
  await wipeShip("host", hostUrl, hostCode);
  if (subCode) await wipeShip("sub", subUrl, subCode);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

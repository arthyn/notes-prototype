import { test as base, expect, Page, BrowserContext, Browser } from "@playwright/test";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Per-test helpers built on top of the standard `test` fixture. The
// host page lands at /notes/ pre-authenticated via storageState.

export const test = base.extend<{
  notes: NotesPage;
}>({
  notes: async ({ page }, use) => {
    await page.goto("/notes/");
    await dismissDisclaimer(page);
    await use(new NotesPage(page));
  },
});

export { expect };

export async function dismissDisclaimer(page: Page) {
  // Alpha disclaimer is modal-locked on first visit; ack persists in localStorage.
  const ack = page.locator('[data-testid="alpha-disclaimer-ack"], #alpha-disclaimer-ack, button:has-text("I understand")');
  if (await ack.count()) {
    await ack.first().click({ trial: false }).catch(() => {});
  }
  // Best-effort: also pre-set the localStorage flag in case the button selector drifts
  await page.evaluate(() => {
    try { localStorage.setItem("alpha-disclaimer-acknowledged", "1"); } catch {}
  });
}

export class NotesPage {
  constructor(public readonly page: Page) {}

  // ── Notebook actions ────────────────────────────────────────────────────
  async createNotebook(title: string): Promise<string> {
    // Sidebar "Add notebook" opens a Create/Join chooser modal …
    await this.page.locator("button.sidebar-action:has-text('Add notebook')").first().click();
    // … click "Create new" to advance to the title prompt …
    await this.page.locator(".modal-choice:has-text('Create new')").click();
    // … wait for the title prompt to actually be in the DOM before we
    // type into it (the chooser → new-notebook swap is sync but reads
    // can race the next selector if we don't wait).
    await expect(this.page.locator("#m-title")).toBeVisible({ timeout: 5000 });
    await this.page.locator("#m-title").fill(title);
    await this.page.locator(".modal-actions button.btn-primary:has-text('Create')").click();
    // Modal-backdrop "open" class is removed synchronously by createNotebook(),
    // then a 300ms setTimeout fires loadNotebooks(). Allow up to 15s for the
    // poke-ack + scry round-trip on a slow ship.
    await expect(this.page.locator("#modal-backdrop.open")).toHaveCount(0, { timeout: 5000 });
    const item = this.page.locator(`.nb-item:has-text('${title}')`).first();
    // Bump to 30s — on a slow nomlux compile the create-notebook
    // poke-ack + loadNotebooks scry + sidebar render can take a while.
    await expect(item).toBeVisible({ timeout: 30_000 });
    // Return the global flag (~ship/numeric-id) for the just-created
    // notebook. Callers that need to construct cross-ship URLs use this
    // — the title is NOT the flag name (the flag name is the host's
    // local numeric next-id).
    const flag = (await item.locator(".nb-flag").textContent()) || "";
    return flag.trim();
  }

  async selectNotebook(title: string) {
    const item = this.page.locator(`.nb-item:has-text('${title}')`).first();
    await item.click();
    // Wait for the click's side-effects to settle before returning:
    //   - .nb-item gains "active" class
    //   - #new-note-btn becomes visible (notebook is set)
    //   - #notes-list has *some* content — either an "Empty folder"
    //     placeholder or actual rows. renderItems renders either of
    //     those only after activeFolderId is set (the async loadFolders
    //     completes). Without this wait, createNote races ahead and
    //     hits the "No folder selected" alert.
    await expect(item).toHaveClass(/active/, { timeout: 10_000 });
    await expect(this.page.locator("#new-note-btn")).toBeVisible({ timeout: 10_000 });
    await this.page.waitForFunction(() => {
      const list = document.getElementById("notes-list");
      return !!list && list.children.length > 0;
    }, { timeout: 15_000 });
  }

  async renameNotebook(newTitle: string) {
    await this.openNotebookSettings();
    await this.page.locator("#nb-menu-rename").click();
    await this.page.locator("#m-title").fill(newTitle);
    await this.page.locator(".modal-actions button.btn-primary:has-text('Rename')").click();
    await expect(this.page.locator(`.nb-item:has-text('${newTitle}')`)).toBeVisible();
  }

  async deleteNotebook() {
    // Notebook gear is only rendered when at the root folder of the
    // active notebook. If the test descended into a subfolder, walk
    // back via the up-button until we're at root and gear is visible.
    await this.navigateToRoot();
    await this.openNotebookSettings();
    this.page.once("dialog", (d) => d.accept());
    await this.page.locator("#nb-menu-delete").click();
  }

  async navigateToRoot() {
    // #folder-up-btn is shown only when activeFolderId !== root. Click
    // it until it disappears.
    const up = this.page.locator("#folder-up-btn");
    while (await up.isVisible().catch(() => false)) {
      await up.click();
      // Brief wait for the click to take effect; the button hides
      // once we're back at root.
      await this.page.waitForTimeout(150);
    }
  }

  // ── Invites ─────────────────────────────────────────────────────────────
  async sendInvite(toPatp: string) {
    await this.page.locator("#notebook-invite-btn").click();
    await this.page.locator("#m-ship").fill(toPatp);
    await this.page.locator("#m-ship-submit:not([disabled])").click();
  }

  async acceptInvite(title: string) {
    await this.page
      .locator(`.invite-item:has-text('${title}') button[data-action="accept"]`)
      .click();
  }

  async declineInvite(title: string) {
    await this.page
      .locator(`.invite-item:has-text('${title}') button[data-action="decline"]`)
      .click();
  }

  // ── Leave a remote notebook ─────────────────────────────────────────────
  async leaveNotebook() {
    await this.openNotebookSettings();
    this.page.once("dialog", (d) => d.accept());
    await this.page.locator("#nb-menu-leave").click();
  }

  // ── Publish / unpublish ─────────────────────────────────────────────────
  // publishNote opens a new tab via window.open; the caller can wait for
  // the popup via context.waitForEvent("page") if it needs the URL.
  async openOverflow() {
    await this.page.locator("button[onclick='toggleOverflow()']").click();
  }

  async publishNote() {
    await this.openOverflow();
    await this.page.locator("#publish-btn").click();
  }

  async unpublishNote() {
    await this.openOverflow();
    await this.page.locator("#unpublish-btn").click();
  }

  async toggleVisibility(): Promise<"public" | "private"> {
    await this.openNotebookSettings();
    const btn = this.page.locator("#nb-menu-visibility");
    // Button label describes the *action*: "Make public" when currently
    // private, "Make private" when currently public. After click, state
    // flips to the opposite of what the label said it was.
    const labelBefore = (await btn.textContent()) || "";
    const currentlyPrivate = labelBefore.includes("Make public");
    await btn.click();
    return currentlyPrivate ? "public" : "private";
  }

  async ensureVisibility(target: "public" | "private") {
    await this.openNotebookSettings();
    const btn = this.page.locator("#nb-menu-visibility");
    const labelBefore = (await btn.textContent()) || "";
    const currently: "public" | "private" =
      labelBefore.includes("Make public") ? "private" : "public";
    if (currently === target) {
      // Close menu without changing visibility
      await this.page.keyboard.press("Escape");
      return;
    }
    await btn.click();
  }

  async openNotebookSettings() {
    await this.page.locator("#notebook-settings-btn").click();
  }

  // ── Folder actions ──────────────────────────────────────────────────────
  async createFolder(name: string) {
    await this.page.locator("#new-folder-btn").click();
    await this.page.locator("#m-name").fill(name);
    await this.page.locator(".modal-actions button.btn-primary:has-text('Create')").click();
    await expect(this.page.locator(`.item-row:has-text('${name}')`)).toBeVisible();
  }

  // ── Note actions ────────────────────────────────────────────────────────
  async createNote(title?: string) {
    // newNote() in app pokes create-note + setTimeout(300) → loadNotes +
    // selectNote(newest). On a remote-host notebook, the note may not
    // propagate back in time for selectNote to find it, so the title
    // input never gets populated. Robust approach: count existing notes,
    // wait for the count to increase (regardless of whether selectNote
    // ran), then explicitly click the newest row to select it.
    const countBefore = await this.page.locator(".item-row.is-note").count();
    await this.page.locator("#new-note-btn").click();
    await expect(this.page.locator(".item-row.is-note")).toHaveCount(countBefore + 1, { timeout: 30_000 });
    // renderItems sorts by updatedAt desc, so newest is .first().
    await this.page.locator(".item-row.is-note").first().click();
    await expect(this.page.locator("#note-title-input")).toHaveValue("Untitled", { timeout: 10_000 });
    if (title) {
      await this.page.locator("#note-title-input").fill(title);
    }
  }

  async editNoteBody(text: string) {
    await this.page.locator("#editor").fill(text);
  }

  async forceSave() {
    // Ctrl/Cmd+S triggers autoSave, which fires update then rename pokes
    // sequentially. Status transitions: blank → "Saving…" → "Saved" →
    // (after 2s) blank again. Wait for the "Saved" peak; matching blank
    // would return either pre-save or post-save-clear.
    await this.page.keyboard.press(process.platform === "darwin" ? "Meta+s" : "Control+s");
    await expect(this.page.locator("#save-status")).toHaveText("Saved", { timeout: 15_000 });
  }

  // ── Assertions ──────────────────────────────────────────────────────────
  async expectNotebookExists(title: string) {
    await expect(this.page.locator(`.nb-item:has-text('${title}')`)).toBeVisible();
  }

  async expectLockVisible(title: string, visible: boolean) {
    const item = this.page.locator(`.nb-item:has-text('${title}')`);
    const lock = item.locator(".nb-lock");
    if (visible) await expect(lock).toBeVisible();
    else         await expect(lock).toHaveCount(0);
  }
}

// ── Cross-ship helpers ────────────────────────────────────────────────────
// Open a second browser context (the subscriber) using the SUB_* env vars.
// Returns the context + a NotesPage rooted at the subscriber's UI, plus
// the underlying page for ad-hoc selectors. Tag specs that use this with
// @cross-ship so they only run when SUB_CODE is configured.
export async function openSubscriberContext(browser: Browser): Promise<{
  context: BrowserContext;
  page: Page;
  notes: NotesPage;
  patp: string;
  url: string;
}> {
  const url = process.env.SUB_URL || "http://localhost:8083";
  const patp = process.env.SUB_PATP || "";
  const authPath = path.resolve(__dirname, "..", ".auth/sub.json");
  const context = await browser.newContext({
    baseURL: url,
    storageState: authPath,
  });
  const page = await context.newPage();
  await page.goto("/notes/");
  await dismissDisclaimer(page);
  return { context, page, notes: new NotesPage(page), patp, url };
}

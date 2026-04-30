import { test, expect } from "../fixtures/notes";

// Core editing loop: type into a note WITHOUT pressing Cmd+S, trigger
// the autoSave path via the visibilitychange flush (matches what the
// app does on tab-switch / pagehide), reload the page, verify the
// content persisted.

test.describe("auto-save core loop", () => {
  test("typing + tab-hidden flush persists the body across reload", async ({ notes, page }) => {
    test.setTimeout(60_000);

    const nb = `e2e-auto-${Date.now()}`;
    const noteTitle = "Drafty";
    const body = "First sentence.\n\nSecond sentence after blank line.";

    await notes.createNotebook(nb);
    await notes.selectNotebook(nb);
    await notes.createNote(noteTitle);
    // Type the body — sets `dirty = true`. Don't force-save.
    await notes.editNoteBody(body);

    // Simulate the user backgrounding the tab. The app's
    // visibilitychange handler clears the autoSave debounce timer and
    // fires autoSave immediately.
    await page.evaluate(() => {
      Object.defineProperty(document, "visibilityState", { value: "hidden", configurable: true });
      document.dispatchEvent(new Event("visibilitychange"));
    });

    // The save should land within a few seconds.
    await expect(page.locator("#save-status")).toHaveText("Saved", { timeout: 15_000 });

    // Reload — the body must persist.
    await page.reload();
    await notes.selectNotebook(nb);
    await page.locator(`.item-row.is-note:has-text('${noteTitle}')`).dispatchEvent("click");
    await expect(page.locator("#editor")).toHaveValue(body, { timeout: 10_000 });

    await notes.deleteNotebook();
  });
});

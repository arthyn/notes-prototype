import { test, expect } from "../fixtures/notes";

// Folder delete asks "delete X items inside?" via a confirm dialog.
// Deny → folder stays. Accept → folder + children gone.

test.describe("folder delete with children", () => {
  test("non-recursive delete on empty folder succeeds; populated folder asks for confirmation", async ({ notes, page }) => {
    test.setTimeout(60_000);

    const nb = `e2e-fd-${Date.now()}`;
    const folder = "Populated";
    const noteTitle = "Inside note";

    await notes.createNotebook(nb);
    await notes.selectNotebook(nb);
    await notes.createFolder(folder);

    // Navigate into the folder, create a note, then go back to root.
    await page.locator(`.item-row.is-folder:has-text('${folder}')`).dispatchEvent("click");
    await notes.createNote(noteTitle);
    await notes.editNoteBody("body");
    await notes.forceSave();
    await notes.navigateToRoot();

    // Open the folder action menu via the icon, click Delete.
    // The handler must be registered BEFORE the click that triggers
    // the native confirm() — Playwright auto-handles dialogs that
    // arrive without a registered listener.

    // First attempt: dismiss → folder stays.
    page.once("dialog", (d) => d.dismiss());
    await page.locator(`.item-row.is-folder:has-text('${folder}') .item-icon`).hover();
    await page.locator(`.item-row.is-folder:has-text('${folder}') .item-icon`).dispatchEvent("click");
    await page.locator(".folder-action-menu button.danger:has-text('Delete folder')").click();
    await expect(page.locator(`.item-row.is-folder:has-text('${folder}')`)).toBeVisible();

    // Second attempt: accept → folder + child note removed.
    page.once("dialog", (d) => d.accept());
    await page.locator(`.item-row.is-folder:has-text('${folder}') .item-icon`).hover();
    await page.locator(`.item-row.is-folder:has-text('${folder}') .item-icon`).dispatchEvent("click");
    await page.locator(".folder-action-menu button.danger:has-text('Delete folder')").click();
    await expect(page.locator(`.item-row.is-folder:has-text('${folder}')`)).toHaveCount(0, { timeout: 10_000 });

    await notes.deleteNotebook();
  });
});

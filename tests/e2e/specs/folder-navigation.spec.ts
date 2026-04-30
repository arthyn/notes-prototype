import { test, expect } from "../fixtures/notes";

// Navigate into a nested folder and back out via the up button.
// Header label tracks the active folder.

test.describe("folder navigation", () => {
  test("up button walks back to root; header label updates", async ({ notes, page }) => {
    test.setTimeout(60_000);

    const nb = `e2e-fn-${Date.now()}`;
    const parent = "Parent";
    const child = "Child";

    await notes.createNotebook(nb);
    await notes.selectNotebook(nb);
    await notes.createFolder(parent);
    await page.locator(`.item-row.is-folder:has-text('${parent}')`).dispatchEvent("click");

    // Inside Parent. Header label should read "Parent". Up button visible.
    await expect(page.locator("#folder-label")).toHaveText(parent);
    await expect(page.locator("#folder-up-btn")).toBeVisible();

    // Create a child folder; navigate into it.
    await notes.createFolder(child);
    await page.locator(`.item-row.is-folder:has-text('${child}')`).dispatchEvent("click");
    await expect(page.locator("#folder-label")).toHaveText(child);

    // Up once → back to Parent.
    await page.locator("#folder-up-btn").click();
    await expect(page.locator("#folder-label")).toHaveText(parent);

    // Up again → back to root. Up button hides; header reads notebook title.
    await page.locator("#folder-up-btn").click();
    await expect(page.locator("#folder-up-btn")).not.toBeVisible();
    await expect(page.locator("#folder-label")).toHaveText(nb);

    await notes.deleteNotebook();
  });
});

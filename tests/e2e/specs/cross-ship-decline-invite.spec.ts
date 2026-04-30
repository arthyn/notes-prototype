import { test, expect } from "../fixtures/notes";
import { openSubscriberContext } from "../fixtures/notes";

// Counterpart to accept-invite. Decline removes the invite from the
// recipient's inbox and does NOT join the notebook.

test.describe("@cross-ship decline invite", () => {
  test.skip(!process.env.SUB_CODE, "SUB_CODE not set — skipping cross-ship spec");

  test("decline removes the invite and doesn't join", async ({ notes, browser }) => {
    test.setTimeout(120_000);

    const title = `e2e-decline-${Date.now()}`;
    const subPatp = process.env.SUB_PATP || "";

    const sub = await openSubscriberContext(browser);

    // Host: create + publicize + invite sub
    await notes.createNotebook(title);
    await notes.selectNotebook(title);
    await notes.ensureVisibility("public");
    await notes.sendInvite(subPatp);

    // Sub: invite shows up live
    const inviteRow = sub.page.locator(`.invite-item:has-text('${title}')`);
    await expect(inviteRow).toBeVisible({ timeout: 15_000 });

    // Sub: decline — invite disappears, notebook is NOT in sidebar
    await sub.notes.declineInvite(title);
    await expect(inviteRow).toHaveCount(0, { timeout: 10_000 });
    await expect(sub.page.locator(`.nb-item:has-text('${title}')`)).toHaveCount(0);

    // Cleanup
    await sub.context.close();
    await notes.deleteNotebook();
  });
});

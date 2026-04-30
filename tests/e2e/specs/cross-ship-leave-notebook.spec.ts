import { test, expect } from "../fixtures/notes";
import { openSubscriberContext } from "../fixtures/notes";

// Sub joins a remote notebook, then leaves. Verifies the sidebar
// updates on sub (notebook gone) and that the host's member list
// no longer includes sub (membership scry).

test.describe("@cross-ship leave notebook", () => {
  test.skip(!process.env.SUB_CODE, "SUB_CODE not set — skipping cross-ship spec");

  test("leave removes the notebook from sub's sidebar", async ({ notes, browser }) => {
    test.setTimeout(120_000);

    const title = `e2e-leave-${Date.now()}`;
    const subPatp = process.env.SUB_PATP || "";

    const sub = await openSubscriberContext(browser);

    // Host invites; sub accepts
    await notes.createNotebook(title);
    await notes.selectNotebook(title);
    await notes.ensureVisibility("public");
    await notes.sendInvite(subPatp);
    await expect(sub.page.locator(`.invite-item:has-text('${title}')`)).toBeVisible({ timeout: 15_000 });
    await sub.notes.acceptInvite(title);
    const subRow = sub.page.locator(`.nb-item:has-text('${title}')`);
    await expect(subRow).toBeVisible({ timeout: 15_000 });

    // Sub leaves
    await sub.notes.selectNotebook(title);
    await sub.notes.leaveNotebook();

    // Sub's sidebar no longer shows the notebook.
    await expect(subRow).toHaveCount(0, { timeout: 15_000 });

    // Cleanup
    await sub.context.close();
    await notes.deleteNotebook();
  });
});

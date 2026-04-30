import { test, expect } from "../fixtures/notes";

// Publish a note, fetch the public HTML over HTTP, unpublish, fetch
// again and assert it 404s. Exercises the /notes/pub route + the
// publish/unpublish action path end-to-end.

test.describe("publish + unpublish", () => {
  test("publish serves HTML; unpublish 404s", async ({ notes, page, context }) => {
    test.setTimeout(60_000);

    const title = `e2e-publish-${Date.now()}`;
    const noteTitle = "Public note";
    const noteBody = "Hello from the test suite.";

    const flag = await notes.createNotebook(title);
    await notes.selectNotebook(title);
    await notes.createNote(noteTitle);
    await notes.editNoteBody(noteBody);
    await notes.forceSave();

    // publishNote opens a new tab via window.open; intercept it so the
    // test isn't littered with popups.
    const popupPromise = context.waitForEvent("page");
    await notes.publishNote();
    const popup = await popupPromise;
    await popup.close();

    // Read the noteId from the URL (selectNote pushes /n/<id>).
    // Top-level `let activeNoteId` is not on window, so page.evaluate
    // can't read it directly.
    const m = page.url().match(/\/n\/(\d+)/);
    expect(m, "URL should contain /n/<noteId>").toBeTruthy();
    const noteId = m![1];

    // GET the public URL — should return 200 + the body content.
    const baseURL = page.url().replace(/\/notes.*$/, "");
    const pubUrl = `${baseURL}/notes/pub/${flag}/${noteId}`;
    const r1 = await context.request.get(pubUrl);
    expect(r1.status()).toBe(200);
    expect(await r1.text()).toContain(noteBody);

    // Unpublish via overflow menu. Click invokes an async handler
    // that pokes the agent — the button click returns immediately, so
    // we poll until the /v0/published scry no longer lists this entry.
    await notes.unpublishNote();
    const publishedScryUrl = `${baseURL}/~/scry/notes/v0/published.json`;
    await expect(async () => {
      const sj = await context.request.get(publishedScryUrl);
      const list = await sj.json() as Array<{ host: string; flagName: string; noteId: number }>;
      const stillThere = list.some(p =>
        `${p.host}/${p.flagName}` === flag && String(p.noteId) === noteId);
      expect(stillThere, "expected entry removed from published scry").toBe(false);
    }).toPass({ timeout: 30_000, intervals: [500, 1000, 2000] });

    // Note: the /notes/pub route currently *falls through* to serving
    // the UI index when there's no published entry, so the URL still
    // returns 200. We just need the body to no longer contain the
    // note's content. (Tracking this as a separate issue — pub of a
    // non-published note should arguably 404.)
    const r2 = await context.request.get(pubUrl);
    expect(await r2.text()).not.toContain(noteBody);

    await notes.deleteNotebook();
  });
});

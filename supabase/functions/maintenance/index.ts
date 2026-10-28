// Hourly housekeeping (pg_cron):
//  - group messages live 48 hours (pinned ones stay): rows and their files are removed
//  - files of deleted messages are removed from storage
//  - accounts whose "forgot code" wait (48 h) is over are deleted with everything they created
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false, autoRefreshToken: false },
});

async function removeFiles(paths: string[]) {
  for (let i = 0; i < paths.length; i += 100) {
    const { error } = await admin.storage.from("chat-media").remove(paths.slice(i, i + 100));
    if (error) console.error("storage remove failed", error.message);
  }
}

async function expireGroupMessages() {
  const cutoff = new Date(Date.now() - 48 * 3600_000).toISOString();
  const { data: old } = await admin.from("group_messages").select("id, media_path, thumb_path").lt("created_at", cutoff).is("pinned_at", null).limit(2000);
  const rows = old ?? [];
  await removeFiles(rows.flatMap((r) => [r.media_path, r.thumb_path]).filter((p): p is string => !!p));
  for (let i = 0; i < rows.length; i += 500) {
    const ids = rows.slice(i, i + 500).map((r) => r.id);
    // replies keep working: reply_to_id is set to null by the foreign key
    const { error } = await admin.from("group_messages").delete().in("id", ids);
    if (error) console.error("group delete failed", error.message);
  }
  // deleted by their author / admin within the last two days: drop the files now
  const { data: gone } = await admin.from("group_messages").select("id, media_path, thumb_path").not("deleted_at", "is", null).not("media_path", "is", null).limit(1000);
  const files = (gone ?? []).flatMap((r) => [r.media_path, r.thumb_path]).filter((p): p is string => !!p);
  if (files.length) {
    await removeFiles(files);
    await admin.from("group_messages").update({ media_path: null, thumb_path: null }).in("id", (gone ?? []).map((r) => r.id));
  }
  return rows.length;
}

async function purgeExpiredResets() {
  const cutoff = new Date(Date.now() - 48 * 3600_000).toISOString();
  const { data } = await admin.from("profiles").select("id").not("reset_requested_at", "is", null).lte("reset_requested_at", cutoff).limit(200);
  let n = 0;
  for (const p of data ?? []) {
    const { error } = await admin.auth.admin.deleteUser(p.id);
    if (error) console.error("reset purge failed", p.id, error.message);
    else n++;
  }
  return n;
}

Deno.serve(async () => {
  const [messages, accounts] = await Promise.allSettled([expireGroupMessages(), purgeExpiredResets()]);
  return Response.json({
    expiredMessages: messages.status === "fulfilled" ? messages.value : String(messages.reason),
    purgedAccounts: accounts.status === "fulfilled" ? accounts.value : String(accounts.reason),
  });
});

// Web Push sender (spec 0060 Increment B; unified by spec 0136).
//
// Called by a database trigger (net.http_post) after a row is inserted into
// public.notifications (one push per in-app notification — recipients,
// dedup and wording decided once by the spec-0094 fan-out) or into
// forum_threads (new-thread alerts to the moderators, which have no
// notifications-row equivalent). Loads the recipients' push subscriptions
// (service role — bypasses RLS) and sends an encrypted web push to each,
// pruning subscriptions the push service has dropped (404/410).
//
// Auth: the trigger sends a shared secret in the `x-notify-secret` header; this
// function is deployed with `verify_jwt = false` (no end-user JWT) and trusts
// only that secret. Configure via `supabase secrets set` — see docs/dev/deploy.md.

import { createClient } from "npm:@supabase/supabase-js@2";
import webpush from "npm:web-push@3.6.7";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const notifySecret = Deno.env.get("NOTIFY_SECRET") ?? "";
const vapidPublic = Deno.env.get("VAPID_PUBLIC_KEY") ?? "";
const vapidPrivate = Deno.env.get("VAPID_PRIVATE_KEY") ?? "";
const vapidSubject = Deno.env.get("VAPID_SUBJECT") ?? "mailto:noreply@treffpunkt";

if (vapidPublic && vapidPrivate) {
  webpush.setVapidDetails(vapidSubject, vapidPublic, vapidPrivate);
}

const admin = createClient(supabaseUrl, serviceRole);

interface PushMessage {
  title: string;
  body: string;
  tag: string;
  url: string;
}

Deno.serve(async (req: Request): Promise<Response> => {
  // Trust only calls carrying the shared secret from the database trigger.
  if (notifySecret && req.headers.get("x-notify-secret") !== notifySecret) {
    return new Response("forbidden", { status: 401 });
  }

  let payload: { table?: string; record?: Record<string, unknown> };
  try {
    payload = await req.json();
  } catch {
    return new Response("bad request", { status: 400 });
  }

  const record = payload.record ?? {};
  try {
    if (payload.table === "notifications") {
      await handleNotification(record);
    } else if (payload.table === "forum_threads") {
      await handleForumThread(record);
    }
  } catch (error) {
    console.error("notify failed", error);
    return new Response("error", { status: 500 });
  }
  return new Response("ok");
});

// One push per in-app notification row (spec 0136): every kind —
// invitations, chat messages, forum replies and mentions — arrives here
// with the recipient, title and body already decided by the spec-0094
// fan-out, so OS pushes and in-app varsler can never disagree.
async function handleNotification(
  record: Record<string, unknown>,
): Promise<void> {
  const userId = record.user_id as string | undefined;
  if (!userId) return;
  await sendToUsers([userId], {
    title: (record.title ?? "Treffpunkt").toString(),
    body: (record.body ?? "").toString(),
    tag: `notification-${record.id}`,
    url: "./",
  });
}



const CATEGORY_LABELS: Record<string, string> = {
  bug: "Bug",
  idea: "Ønske",
  general: "Generelt",
};

async function handleForumThread(
  record: Record<string, unknown>,
): Promise<void> {
  const authorId = record.author_id as string;
  const admins = await adminRecipients(authorId);
  if (admins.length === 0) return;

  const author = await displayName(authorId);
  const category = CATEGORY_LABELS[record.category as string] ?? "Forum";
  await sendToUsers(admins, {
    title: `Nytt i forumet: ${category}`,
    body: `${author}: ${(record.title ?? "").toString()}`,
    tag: `forum-thread-${record.id}`,
    url: "./",
  });
}


// The app admins, minus the author (you do not get notified about your own
// forum activity).
async function adminRecipients(excludeId: string): Promise<string[]> {
  const { data } = await admin.from("app_admins").select("user_id");
  return (data ?? [])
    .map((a) => a.user_id as string)
    .filter((id) => id !== excludeId);
}

async function displayName(userId: string): Promise<string> {
  const { data } = await admin
    .from("profiles")
    .select("display_name")
    .eq("id", userId)
    .maybeSingle();
  return (data?.display_name as string) ?? "Noen";
}

async function sendToUsers(
  userIds: string[],
  message: PushMessage,
): Promise<void> {
  const { data: subs } = await admin
    .from("push_subscriptions")
    .select("endpoint, p256dh, auth")
    .in("user_id", userIds);
  if (!subs || subs.length === 0) return;

  const json = JSON.stringify(message);
  await Promise.all(
    subs.map(async (s) => {
      const subscription = {
        endpoint: s.endpoint as string,
        keys: { p256dh: s.p256dh as string, auth: s.auth as string },
      };
      try {
        await webpush.sendNotification(subscription, json);
      } catch (error) {
        const status = (error as { statusCode?: number }).statusCode;
        // The push service has dropped this subscription — prune it.
        if (status === 404 || status === 410) {
          await admin
            .from("push_subscriptions")
            .delete()
            .eq("endpoint", subscription.endpoint);
        } else {
          console.error("push failed", status, error);
        }
      }
    }),
  );
}

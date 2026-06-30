// Web Push sender (spec 0060, Increment B).
//
// Called by a database trigger (net.http_post) after a row is inserted into
// competition_messages or competition_invitations. Computes the recipients,
// loads their push subscriptions (service role — bypasses RLS), and sends an
// encrypted web push to each, pruning subscriptions the push service has
// dropped (404/410).
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
    if (payload.table === "competition_messages") {
      await handleMessage(record);
    } else if (payload.table === "competition_invitations") {
      await handleInvitation(record);
    } else if (payload.table === "forum_threads") {
      await handleForumThread(record);
    } else if (payload.table === "forum_posts") {
      await handleForumPost(record);
    }
  } catch (error) {
    console.error("notify failed", error);
    return new Response("error", { status: 500 });
  }
  return new Response("ok");
});

async function handleMessage(record: Record<string, unknown>): Promise<void> {
  const competitionId = record.competition_id as string;
  const senderId = record.user_id as string;
  const body = (record.body ?? "").toString();

  const [members, comp, sender] = await Promise.all([
    admin
      .from("competition_members")
      .select("user_id")
      .eq("competition_id", competitionId)
      .neq("user_id", senderId),
    admin
      .from("competitions")
      .select("name")
      .eq("id", competitionId)
      .maybeSingle(),
    admin
      .from("profiles")
      .select("display_name")
      .eq("id", senderId)
      .maybeSingle(),
  ]);

  const userIds = (members.data ?? []).map((m) => m.user_id as string);
  if (userIds.length === 0) return;

  const senderName = (sender.data?.display_name as string) ?? "Noen";
  const text = body.length > 80 ? `${body.slice(0, 79)}…` : body;
  await sendToUsers(userIds, {
    title: (comp.data?.name as string) ?? "Ny melding",
    body: `${senderName}: ${text}`,
    tag: `competition-${competitionId}`,
    url: "./",
  });
}

async function handleInvitation(
  record: Record<string, unknown>,
): Promise<void> {
  const competitionId = record.competition_id as string;
  const email = record.invited_email as string;
  const status = record.status as string | undefined;
  if (status && status !== "pending") return;

  // Map the invited email to a user (service-role-only helper). A not-yet-
  // registered invitee has no account, so there is nobody to notify.
  const { data: userId } = await admin.rpc("user_id_for_email", {
    p_email: email,
  });
  if (!userId) return;

  const { data: comp } = await admin
    .from("competitions")
    .select("name")
    .eq("id", competitionId)
    .maybeSingle();

  await sendToUsers([userId as string], {
    title: "Ny invitasjon",
    body: comp?.name
      ? `Du er invitert til ${comp.name}.`
      : "Du har fått en ny invitasjon.",
    tag: `invite-${competitionId}`,
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

async function handleForumPost(
  record: Record<string, unknown>,
): Promise<void> {
  const authorId = record.author_id as string;
  const admins = await adminRecipients(authorId);
  if (admins.length === 0) return;

  const author = await displayName(authorId);
  const body = (record.body ?? "").toString();
  const text = body.length > 80 ? `${body.slice(0, 79)}…` : body;
  await sendToUsers(admins, {
    title: "Nytt svar i forumet",
    body: `${author}: ${text}`,
    tag: `forum-post-${record.thread_id}`,
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

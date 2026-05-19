/**
 * Windmill runnable: call_api
 *
 * Called from the React bundle as `backend.call_api({path, method, body, query})`.
 * Forwards to the Cloud Run FastAPI service with auth attached server-side.
 *
 * Windmill variables required (set once per workspace):
 *   f/__WMILL_APP_PATH_PARENT__/cloud_run_url
 *   f/__WMILL_APP_PATH_PARENT__/frontend_service_secret
 *   (replace __WMILL_APP_PATH_PARENT__ with your repo's folder, e.g. `f/my_app/`)
 *
 * Auth chain:
 *   1. Cloud Run is deployed --no-allow-unauthenticated, so the caller must
 *      present a Google-signed ID token. We fetch one from the GCP metadata
 *      server (works because Windmill itself runs in Cloud Run with a SA
 *      that has roles/run.invoker on this app's Cloud Run service).
 *   2. FastAPI's middleware then validates the shared service secret in
 *      X-Service-Secret. The browser never sees that secret.
 *   3. X-Windmill-User / X-Windmill-Username carry the viewer's identity
 *      for audit stamping. Read directly from WM_USERNAME — see whoami.ts
 *      for why we don't use HTTP /whoami or WM_EMAIL.
 *
 * Binary responses (PDFs, XLSX, etc.) are base64-encoded with
 * `encoding: "base64"` because Windmill stores job results as JSONB; a
 * binary blob accidentally decoded as text would contain null bytes that
 * PostgreSQL JSONB rejects.
 */

import * as wmill from "windmill-client";

function isBinaryContentType(ct: string): boolean {
  return (
    ct.includes("application/pdf") ||
    ct.includes("application/octet-stream") ||
    ct.includes("spreadsheetml") ||
    ct.includes("wordprocessingml") ||
    ct.includes("ms-excel") ||
    ct.includes("ms-word") ||
    ct.includes("zip") ||
    ct.startsWith("image/")
  );
}

async function getGcpIdToken(audience: string): Promise<string> {
  const res = await fetch(
    `http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity?audience=${encodeURIComponent(audience)}`,
    { headers: { "Metadata-Flavor": "Google" } },
  );
  if (!res.ok) {
    throw new Error(
      `Failed to obtain GCP ID token from metadata server: ${res.status} ${await res.text()}`,
    );
  }
  return (await res.text()).trim();
}

export async function main(
  path: string,
  method: "GET" | "POST" | "PUT" | "DELETE" = "GET",
  body?: unknown,
  query?: Record<string, string>,
): Promise<{
  status: number;
  body: unknown;
  encoding?: "base64";
  content_type?: string;
}> {
  // ⚠️ Update these two variable paths to match your repo's Windmill folder.
  const baseUrl = await wmill.getVariable("f/__PROJECT_SLUG_SNAKE__/cloud_run_url");
  const secret = await wmill.getVariable("f/__PROJECT_SLUG_SNAKE__/frontend_service_secret");
  if (!baseUrl) throw new Error("Windmill variable cloud_run_url is unset");
  if (!secret) throw new Error("Windmill variable frontend_service_secret is unset");

  const url = new URL(path, baseUrl);
  if (query) {
    for (const [k, v] of Object.entries(query)) {
      url.searchParams.set(k, v);
    }
  }

  // Audience must be the Cloud Run service URL (without path/query).
  const audience = new URL(baseUrl).origin;
  const idToken = await getGcpIdToken(audience);

  const username = process.env.WM_USERNAME ?? "";

  const res = await fetch(url.toString(), {
    method,
    headers: {
      "Authorization": `Bearer ${idToken}`,
      "X-Service-Secret": secret,
      "X-Windmill-User": username,
      "X-Windmill-Username": username,
      ...(body !== undefined ? { "Content-Type": "application/json" } : {}),
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });

  const contentType = res.headers.get("Content-Type") ?? "";
  const isBinary = isBinaryContentType(contentType);

  if (isBinary) {
    const buf = await res.arrayBuffer();
    const b64 = Buffer.from(buf).toString("base64");
    return {
      status: res.status,
      body: b64,
      encoding: "base64",
      content_type: contentType,
    };
  }

  const isJson = contentType.includes("application/json");
  return {
    status: res.status,
    body: isJson ? await res.json() : await res.text(),
  };
}

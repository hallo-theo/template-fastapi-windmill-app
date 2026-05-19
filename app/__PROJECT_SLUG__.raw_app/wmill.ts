/**
 * Local-dev stub for the auto-generated `./wmill` module.
 *
 * Windmill's bundler replaces this file at `wmill app push` time with typed
 * bindings for every `backend/*.ts` runnable. We commit a stub so Vite dev
 * (which never runs the Windmill bundler) has something to import.
 *
 * In dev:
 *   `backend.call_api` does a plain fetch through the Vite proxy. The proxy
 *   (vite.config.ts) injects X-Service-Secret + X-Windmill-User so FastAPI's
 *   middleware authenticates the request.
 *   `backend.whoami` returns a hardcoded dev user.
 *
 * In Windmill prod:
 *   Both functions are auto-generated. `call_api` routes through
 *   `backend/call_api.ts`; `whoami` through `backend/whoami.ts`.
 */

type CallApiArgs = {
  path: string;
  method?: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
  body?: unknown;
  query?: Record<string, string>;
};

type CallApiResult = {
  status: number;
  body: unknown;
  encoding?: "base64";
  content_type?: string;
};

export interface WmUser {
  username: string;
  email: string | null;
}

const DEV_USER: WmUser = {
  username: "dev",
  email: "dev@hallotheo.local",
};

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

async function devCallApi(args: CallApiArgs): Promise<CallApiResult> {
  const { path, method = "GET", body, query } = args;
  const url = new URL(path, window.location.origin);
  if (query) {
    for (const [k, v] of Object.entries(query)) {
      url.searchParams.set(k, v);
    }
  }
  const res = await fetch(url.toString(), {
    method,
    headers: body ? { "Content-Type": "application/json" } : {},
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  const contentType = res.headers.get("Content-Type") ?? "";
  const isBinary = isBinaryContentType(contentType);
  const isJson = contentType.includes("application/json");

  if (isBinary) {
    const buf = await res.arrayBuffer();
    const b64 = btoa(String.fromCharCode(...new Uint8Array(buf)));
    return { status: res.status, body: b64, encoding: "base64", content_type: contentType };
  }

  return {
    status: res.status,
    body: isJson ? await res.json() : await res.text(),
  };
}

async function devWhoami(): Promise<WmUser> {
  return DEV_USER;
}

export const backend = {
  call_api: devCallApi,
  whoami: devWhoami,
};

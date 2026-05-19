/**
 * Windmill runnable: whoami
 *
 * Returns the viewer's identity for sidebar display + audit-log stamping.
 *
 * We trust WM_USERNAME and only WM_USERNAME — it's the only env var that
 * reliably rebinds per viewer in raw_apps. WM_EMAIL and WM_TOKEN are both
 * deployer-scoped (the latter would also make calling HTTP /whoami return
 * the deployer's identity for every viewer; worse, Windmill's app-layer
 * result caching can cause the first caller's response to be returned to
 * everyone). Email isn't reliably available from inside a runnable.
 */

export interface WhoamiResult {
  username: string;
  email: string | null;
}

export async function main(): Promise<WhoamiResult> {
  return {
    username: process.env.WM_USERNAME ?? "",
    email: null,
  };
}

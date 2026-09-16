// Only used by plaid_sync_import_map.json. Capture the actual Edge Function
// handlers so tests exercise their HTTP contracts without starting a server.
export const handlers: Array<(req: Request) => Promise<Response>> = [];

export function serve(handler: (req: Request) => Promise<Response>) {
  handlers.push(handler);
}

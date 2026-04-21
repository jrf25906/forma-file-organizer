/**
 * Turns an ISO date string into an MM·DD folio revision label, e.g. "04·20".
 * Returns a stable placeholder if the input cannot be parsed.
 */
export function formatFolioRevision(iso: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "—·—";
  const mm = String(date.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(date.getUTCDate()).padStart(2, "0");
  return `${mm}·${dd}`;
}

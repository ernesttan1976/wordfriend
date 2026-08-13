export function normalizeForCompare(input: string): string {
  return input
    .trim()
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[^a-z]/g, '');
}

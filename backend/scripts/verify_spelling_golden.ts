import { readFile } from 'node:fs/promises';
import path from 'node:path';

import { normalizeForCompare } from '../src/spelling/normalize';

type Golden = {
  cases: Array<{ input: string; normalized: string }>;
};

async function main(): Promise<void> {
  const filePath = path.resolve(__dirname, '../../tests/spelling_golden.json');
  const raw = await readFile(filePath, 'utf8');
  const data = JSON.parse(raw) as Golden;

  if (!data.cases?.length) {
    throw new Error('No cases found in tests/spelling_golden.json');
  }

  const failures: string[] = [];
  for (const c of data.cases) {
    const got = normalizeForCompare(c.input);
    if (got !== c.normalized) {
      failures.push(
        `input=${JSON.stringify(c.input)} expected=${JSON.stringify(c.normalized)} got=${JSON.stringify(got)}`,
      );
    }
  }

  if (failures.length) {
    for (const f of failures) console.error(`[FAIL] ${f}`);
    process.exitCode = 1;
    return;
  }

  console.log(`[OK] ${data.cases.length} spelling normalization cases`);
}

void main();

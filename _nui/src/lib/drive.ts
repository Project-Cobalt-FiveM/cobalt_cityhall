import type { DriveStrike, SpeedUnit } from './types';

export function strikeReason(strike: DriveStrike, unit: SpeedUnit): string {
  if (strike.kind === 'crash') return 'Hit something';

  return `${strike.speed} ${unit} in a ${strike.limit} ${unit} leg`;
}

export function strikeToast(strike: DriveStrike, count: number, max: number, unit: SpeedUnit): string {
  const tally = `Strike ${count} of ${max}.`;

  if (strike.kind === 'crash') return `Hit something. ${tally}`;

  return `Over the ${strike.limit} ${unit} limit. ${tally}`;
}

export function startToast(total: number): string {
  return `Follow the blue route through ${total} checkpoints.`;
}

export function checkpointToast(cleared: number, finishNext: boolean, limit: number, unit: SpeedUnit): string {
  if (finishNext) return `Checkpoint ${cleared} cleared. Next stop is the finish.`;

  return `Checkpoint ${cleared} cleared. Next limit ${limit} ${unit}.`;
}

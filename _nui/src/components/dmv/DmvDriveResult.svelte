<script lang="ts">
  import ArrowClockwiseIcon from 'phosphor-svelte/lib/ArrowClockwiseIcon';
  import BankIcon from 'phosphor-svelte/lib/BankIcon';
  import ClockIcon from 'phosphor-svelte/lib/ClockIcon';
  import CheckCircleIcon from 'phosphor-svelte/lib/CheckCircleIcon';
  import XCircleIcon from 'phosphor-svelte/lib/XCircleIcon';
  import Confetti from './Confetti.svelte';
  import DmvError from './DmvError.svelte';
  import GpsButton from '../GpsButton.svelte';
  import { countdown, elapsed, money } from '../../lib/format';
  import { strikeReason } from '../../lib/drive';
  import { pop } from '../../lib/motion';
  import { fetchNui } from '../../lib/nui';
  import type { DmvNotice, DmvView, DriveResult } from '../../lib/types';

  let {
    result,
    dmv,
    wait,
    error,
    pending,
    onretake,
    onclose,
  }: {
    result: DriveResult;
    dmv: DmvView;
    wait: number;
    error: DmvNotice | null;
    pending: boolean;
    onretake: () => void;
    onclose: () => void;
  } = $props();

  const stats = $derived([
    { label: 'Checkpoints', value: `${result.reached}/${result.total}` },
    { label: 'Strikes', value: `${result.strikes.length}/${result.maxStrikes}` },
    { label: 'Time', value: elapsed(result.seconds) },
  ]);
</script>

<div class="flex flex-col gap-5 p-6">
  {#if result.passed}
    <Confetti />
    <div class="flex items-center gap-4">
      <span class="shrink-0 text-success" in:pop={{ duration: 300 }}><CheckCircleIcon size={56} /></span>
      <div class="flex flex-col gap-1.5">
        <h2 class="text-2xl font-semibold tracking-tight">You passed the driving test</h2>
        <p class="text-sm text-muted-foreground">Your driver licence is on your record. Police see it when they look you up.</p>
      </div>
    </div>
    <dl class="grid grid-cols-3 gap-2">
      {#each stats as stat (stat.label)}
        <div class="flex flex-col rounded-lg border border-border px-4 py-3">
          <dt class="text-xs text-muted-foreground">{stat.label}</dt>
          <dd class="text-xl font-semibold tabular-nums">{stat.value}</dd>
        </div>
      {/each}
    </dl>
    <div class="flex items-center gap-3 rounded-lg bg-muted py-3 pr-3 pl-4">
      <BankIcon size={20} class="shrink-0" />
      <span class="flex grow flex-col">
        <span class="text-xs text-muted-foreground">Next step</span>
        <span class="text-sm font-medium tabular-nums">Buy the card at City Hall for {money(dmv.practical.cardPrice)}</span>
      </span>
      <GpsButton request={() => fetchNui('gpsPlace', { place: 'cityhall' })} />
    </div>
  {:else}
    <div class="flex items-start gap-4">
      <span class="shrink-0 text-destructive-solid" in:pop={{ duration: 300 }}><XCircleIcon size={56} /></span>
      <div class="flex grow flex-col gap-1.5">
        <h2 class="text-2xl font-semibold tracking-tight">You failed the practical</h2>
        <p class="text-sm text-muted-foreground">{result.reason ?? 'The test stopped.'}</p>
      </div>
      <div class="flex shrink-0 flex-col items-end">
        <span class="text-4xl font-semibold text-destructive tabular-nums">{result.strikes.length}/{result.maxStrikes}</span>
        <span class="text-xs text-muted-foreground">Strikes</span>
      </div>
    </div>
    {#if result.strikes.length > 0}
      <ol class="flex flex-col divide-y divide-border rounded-lg border border-border">
        {#each result.strikes as strike, index (index)}
          <li class="flex h-11 items-center gap-3 px-4">
            <span class="w-5 shrink-0 text-xs font-medium text-muted-foreground tabular-nums">{index + 1}</span>
            <span class="grow text-sm tabular-nums">{strikeReason(strike, result.unit)}</span>
            <span class="shrink-0 text-xs text-muted-foreground tabular-nums">Checkpoint {strike.checkpoint}</span>
          </li>
        {/each}
      </ol>
    {/if}
    <div class="flex items-center gap-3 rounded-lg bg-muted px-4 py-3">
      <ClockIcon size={20} class="shrink-0 text-muted-foreground" />
      <span class="flex flex-col">
        <span class="text-sm font-medium tabular-nums">{wait > 0 ? `Retake in ${countdown(wait)}` : 'You can retake it now'}</span>
        <span class="text-xs text-muted-foreground tabular-nums">
          Your theory pass lasts until you log off. Each retake of the practical costs {money(dmv.practical.fee)}.
        </span>
      </span>
    </div>
  {/if}
</div>

<footer class="flex items-center gap-3 border-t border-border px-6 py-4">
  {#if error}
    <DmvError notice={error} />
  {:else}
    <p class="grow text-xs text-muted-foreground">
      {result.passed ? 'Police can ask to see the card when you drive.' : 'Talk to the DMV clerk to retake it.'}
    </p>
  {/if}
  {#if result.passed}
    <button type="button" class="button button-primary" onclick={onclose}>Done</button>
  {:else}
    <button type="button" class="button button-secondary" onclick={onclose}>Close</button>
    <button type="button" class="button button-primary" disabled={pending || wait > 0} onclick={onretake}>
      <ArrowClockwiseIcon size={16} />
      Retake for {money(dmv.practical.fee)}
    </button>
  {/if}
</footer>

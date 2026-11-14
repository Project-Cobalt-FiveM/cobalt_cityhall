<script lang="ts">
  import ArrowClockwiseIcon from 'phosphor-svelte/lib/ArrowClockwiseIcon';
  import ArrowRightIcon from 'phosphor-svelte/lib/ArrowRightIcon';
  import CheckCircleIcon from 'phosphor-svelte/lib/CheckCircleIcon';
  import XCircleIcon from 'phosphor-svelte/lib/XCircleIcon';
  import DmvError from './DmvError.svelte';
  import { money } from '../../lib/format';
  import type { DmvNotice, TheoryQuestion, TheoryResult } from '../../lib/types';

  let {
    result,
    questions,
    error,
    pending,
    onpractical,
    onretake,
    onclose,
  }: {
    result: TheoryResult;
    questions: TheoryQuestion[];
    error: DmvNotice | null;
    pending: boolean;
    onpractical: () => void;
    onretake: () => void;
    onclose: () => void;
  } = $props();
</script>

<div class="flex flex-col gap-5 p-6">
  <div class="flex items-start gap-6">
    <div class="flex grow flex-col gap-1.5">
      <h2 class="text-2xl font-semibold tracking-tight">
        {result.passed ? 'You passed the theory test' : 'You did not pass this time'}
      </h2>
      <p class="text-sm text-muted-foreground">
        {result.passed
          ? 'Head to the car park when you are ready. The practical starts there.'
          : 'Read the questions you missed, then try again.'}
      </p>
    </div>
    <div class="flex shrink-0 flex-col items-end">
      <span class={['text-4xl font-semibold tabular-nums', !result.passed && 'text-destructive']}>
        {result.score}/{result.total}
      </span>
      <span class="text-xs text-muted-foreground tabular-nums">Pass mark {result.dmv.theory.passMark}/{result.total}</span>
    </div>
  </div>
  <ol class="flex flex-col divide-y divide-border rounded-lg border border-border">
    {#each questions as entry, index (entry.question)}
      <li class="flex h-11 items-center gap-3 px-4">
        <span class="w-5 shrink-0 text-xs font-medium text-muted-foreground tabular-nums">{index + 1}</span>
        <span class="grow truncate text-sm">{entry.question}</span>
        {#if result.review[index]}
          <CheckCircleIcon size={16} class="shrink-0 text-success" aria-label="Right" />
        {:else}
          <XCircleIcon size={16} class="shrink-0 text-destructive" aria-label="Wrong" />
        {/if}
      </li>
    {/each}
  </ol>
</div>

<footer class="flex items-center gap-3 border-t border-border px-6 py-4">
  {#if error}
    <DmvError notice={error} />
  {:else}
    <p class="grow text-xs text-muted-foreground">
      {result.passed
        ? 'Your pass lasts until you log off. Start the practical before then.'
        : 'A retake costs the fee again. The answers are shuffled each time.'}
    </p>
  {/if}
  {#if result.passed}
    <button type="button" class="button button-primary" onclick={onpractical}>
      Go to the practical
      <ArrowRightIcon size={16} />
    </button>
  {:else}
    <button type="button" class="button button-secondary" onclick={onclose}>Close</button>
    <button type="button" class="button button-primary" disabled={pending} onclick={onretake}>
      <ArrowClockwiseIcon size={16} />
      Retake for {money(result.dmv.theory.fee)}
    </button>
  {/if}
</footer>

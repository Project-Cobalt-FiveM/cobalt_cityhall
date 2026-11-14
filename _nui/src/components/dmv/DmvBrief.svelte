<script lang="ts">
  import MapPinIcon from 'phosphor-svelte/lib/MapPinIcon';
  import SpeedometerIcon from 'phosphor-svelte/lib/SpeedometerIcon';
  import SteeringWheelIcon from 'phosphor-svelte/lib/SteeringWheelIcon';
  import WarningIcon from 'phosphor-svelte/lib/WarningIcon';
  import DmvError from './DmvError.svelte';
  import { countdown, money } from '../../lib/format';
  import type { DmvNotice, DmvView } from '../../lib/types';

  let {
    dmv,
    wait,
    error,
    pending,
    onstart,
  }: { dmv: DmvView; wait: number; error: DmvNotice | null; pending: boolean; onstart: () => void } = $props();

  const practical = $derived(dmv.practical);

  const rules = $derived([
    {
      Icon: MapPinIcon,
      name: 'Follow the checkpoints',
      text: `Drive through each marker in order. There are ${practical.checkpoints}.`,
    },
    {
      Icon: SpeedometerIcon,
      name: "Keep under each leg's speed limit",
      text: 'The limit changes between checkpoints and shows on screen.',
    },
    {
      Icon: WarningIcon,
      name: `${practical.maxStrikes} strikes and you fail`,
      text: 'Speeding or hitting something adds a strike. Leaving the car for too long ends the test.',
    },
  ]);
</script>

<div class="flex flex-col gap-5 p-6">
  <div class="flex flex-col gap-1.5">
    <h2 class="text-2xl font-semibold tracking-tight">Practical driving test</h2>
    <p class="text-sm text-muted-foreground">
      You get a Panto from the DMV car park. Drive it through the checkpoints and bring it back here.
    </p>
  </div>
  <ul class="flex flex-col divide-y divide-border rounded-lg border border-border">
    {#each rules as rule (rule.name)}
      <li class="flex items-center gap-3 px-4 py-3">
        <span class="flex size-9 shrink-0 items-center justify-center rounded-md bg-secondary"><rule.Icon size={20} /></span>
        <span class="flex flex-col">
          <span class="text-sm font-medium">{rule.name}</span>
          <span class="text-13 text-muted-foreground">{rule.text}</span>
        </span>
      </li>
    {/each}
  </ul>
</div>

<footer class="flex items-center gap-3 border-t border-border px-6 py-4">
  {#if error}
    <DmvError notice={error} />
  {:else}
    <p class="grow text-xs text-muted-foreground">The Panto is waiting in the DMV car park.</p>
  {/if}
  <button type="button" class="button button-primary" disabled={pending || wait > 0} onclick={onstart}>
    <SteeringWheelIcon size={16} />
    {#if wait > 0}
      <span class="tabular-nums">Retake in {countdown(wait)}</span>
    {:else if practical.fee > 0}
      Pay {money(practical.fee)} and start
    {:else}
      Start the practical
    {/if}
  </button>
</footer>

<script lang="ts">
  import ArrowRightIcon from 'phosphor-svelte/lib/ArrowRightIcon';
  import ExamIcon from 'phosphor-svelte/lib/ExamIcon';
  import IdentificationCardIcon from 'phosphor-svelte/lib/IdentificationCardIcon';
  import SteeringWheelIcon from 'phosphor-svelte/lib/SteeringWheelIcon';
  import DmvError from './DmvError.svelte';
  import { money } from '../../lib/format';
  import type { DmvNotice, DmvView } from '../../lib/types';

  let {
    dmv,
    error,
    pending,
    onstart,
    onclose,
  }: { dmv: DmvView; error: DmvNotice | null; pending: boolean; onstart: () => void; onclose: () => void } = $props();

  const steps = $derived([
    {
      Icon: ExamIcon,
      name: 'Theory',
      text: `${dmv.theory.questions} questions on the road rules. Get ${dmv.theory.passMark} right to pass.`,
    },
    {
      Icon: SteeringWheelIcon,
      name: 'Practical',
      text: `Drive a test car through the checkpoints. ${dmv.practical.maxStrikes} strikes and you fail.`,
    },
    { Icon: IdentificationCardIcon, name: 'Licence', text: 'The licence goes on your record. Buy the card at City Hall.' },
  ]);
</script>

<div class="flex flex-col gap-5 p-6">
  <div class="flex flex-col gap-1.5">
    <h2 class="text-2xl font-semibold tracking-tight">Pass two tests to get your driver licence</h2>
    <p class="text-sm text-muted-foreground">
      Answer a few road rules questions first. Pass, and you take a test car out on the streets for the practical.
    </p>
  </div>
  <ul class="flex flex-col divide-y divide-border rounded-lg border border-border">
    {#each steps as step (step.name)}
      <li class="flex items-center gap-3 px-4 py-3">
        <span class="flex size-9 shrink-0 items-center justify-center rounded-md bg-secondary"><step.Icon size={20} /></span>
        <span class="flex flex-col">
          <span class="text-sm font-medium">{step.name}</span>
          <span class="text-13 text-muted-foreground">{step.text}</span>
        </span>
      </li>
    {/each}
  </ul>
</div>

<footer class="flex items-center gap-3 border-t border-border px-6 py-4">
  {#if error}
    <DmvError notice={error} />
  {:else}
    <div class="flex grow flex-col">
      <span class="text-xs text-muted-foreground">Theory test fee</span>
      <span class="text-xl font-semibold tabular-nums">{money(dmv.theory.fee)}</span>
    </div>
  {/if}
  <button type="button" class="button button-secondary" onclick={onclose}>Not now</button>
  <button type="button" class="button button-primary" disabled={pending} onclick={onstart}>
    Pay and start the theory test
    <ArrowRightIcon size={16} />
  </button>
</footer>

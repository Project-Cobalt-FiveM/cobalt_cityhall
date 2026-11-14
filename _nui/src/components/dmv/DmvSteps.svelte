<script lang="ts">
  import CheckCircleIcon from 'phosphor-svelte/lib/CheckCircleIcon';
  import XCircleIcon from 'phosphor-svelte/lib/XCircleIcon';

  export type StepState = 'current' | 'upcoming' | 'done' | 'failed';

  let { states }: { states: [StepState, StepState, StepState] } = $props();

  const labels = ['Theory', 'Practical', 'Licence'];

  const circles: Record<'current' | 'upcoming', string> = {
    current: 'bg-primary text-primary-foreground',
    upcoming: 'border border-input bg-muted text-muted-foreground',
  };
</script>

<ol class="flex items-center gap-3 border-b border-border px-6 pb-5">
  {#each labels as label, index (label)}
    {@const state = states[index] ?? 'upcoming'}
    {#if index > 0}
      <li class="h-px grow bg-border" aria-hidden="true"></li>
    {/if}
    <li class="flex shrink-0 items-center gap-2" aria-current={state === 'current' ? 'step' : undefined}>
      {#if state === 'done'}
        <CheckCircleIcon size={24} class="text-success" />
      {:else if state === 'failed'}
        <XCircleIcon size={24} class="text-destructive-solid" />
      {:else}
        <span class={['flex size-6 items-center justify-center rounded-full text-xs font-semibold', circles[state]]}>
          {index + 1}
        </span>
      {/if}
      <span class={['text-sm font-medium', state === 'upcoming' && 'text-muted-foreground']}>{label}</span>
    </li>
  {/each}
</ol>

<script lang="ts">
  import type { CookBar } from './types';

  let { label, bar }: { label: string; bar: CookBar } = $props();

  const fill = $derived(
    bar.value >= 2 ? 'bg-destructive-solid' : bar.value >= 1.7 ? 'bg-warning-solid' : bar.value >= 1 ? 'bg-success-solid' : 'bg-primary',
  );

  const textColour = $derived(bar.value >= 2 ? 'text-destructive' : bar.value >= 1 ? 'text-success' : 'text-muted-foreground');
</script>

<div class="grid grid-cols-[4.5rem_1fr_4.5rem] items-center gap-2 text-sm">
  <span class="flex items-center gap-1.5 {bar.live ? 'font-medium text-foreground' : 'text-muted-foreground'}">
    <span class="size-1.5 rounded-full transition-colors duration-150 ease-standard {bar.live ? 'bg-primary' : 'bg-secondary'}"></span>
    {label}
  </span>
  <div class="relative h-2.5 overflow-hidden rounded-full bg-secondary" role="meter" aria-label={label} aria-valuenow={bar.value}>
    <span class="absolute inset-y-0 right-0 left-1/2 bg-input"></span>
    <div
      class="relative h-full rounded-full transition-[width,background-color] duration-150 ease-standard {fill}"
      style:width="{Math.min(bar.value, 2) * 50}%"
    ></div>
    <span class="absolute inset-y-0 left-1/2 w-0.5 bg-success"></span>
  </div>
  <span class="text-right text-xs font-medium tabular-nums {textColour}">{bar.text}</span>
</div>

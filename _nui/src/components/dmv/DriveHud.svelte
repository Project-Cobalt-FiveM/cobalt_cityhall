<script lang="ts">
  import CheckCircleIcon from 'phosphor-svelte/lib/CheckCircleIcon';
  import FlagCheckeredIcon from 'phosphor-svelte/lib/FlagCheckeredIcon';
  import MapPinIcon from 'phosphor-svelte/lib/MapPinIcon';
  import NavigationArrowIcon from 'phosphor-svelte/lib/NavigationArrowIcon';
  import WarningIcon from 'phosphor-svelte/lib/WarningIcon';
  import { distance } from '../../lib/format';
  import { checkpointToast, startToast, strikeToast } from '../../lib/drive';
  import { pop, rise } from '../../lib/motion';
  import type { DriveHud } from '../../lib/types';

  type Tone = 'info' | 'success' | 'danger';
  type Toast = { text: string; tone: Tone; at: number };

  const TOAST_MS = 3000;

  const tones: Record<Tone, string> = {
    info: 'bg-primary text-primary-foreground',
    success: 'bg-success-solid text-foreground',
    danger: 'bg-destructive-solid text-foreground',
  };

  let { hud, speed, meters }: { hud: DriveHud; speed: number; meters: number } = $props();

  let toast = $state<Toast | null>(null);
  let seenStrikes = 0;
  let seenCheckpoint = 0;
  let timer: ReturnType<typeof setTimeout> | undefined;

  const view = $derived(hud.view);
  const over = $derived(speed > hud.limit);
  const finish = $derived(view.checkpoint === view.total);

  function show(text: string, tone: Tone) {
    clearTimeout(timer);
    toast = { text, tone, at: Date.now() };
    timer = setTimeout(() => (toast = null), TOAST_MS);
  }

  $effect(() => {
    const count = view.strikes.length;
    const latest = view.strikes[count - 1];
    const fresh = count > seenStrikes;

    seenStrikes = count;

    if (fresh && latest) show(strikeToast(latest, count, view.maxStrikes, view.unit), 'danger');
  });

  $effect(() => {
    const checkpoint = view.checkpoint;
    const previous = seenCheckpoint;

    seenCheckpoint = checkpoint;

    if (previous === 0) show(startToast(view.total), 'info');
    else if (checkpoint > previous) show(checkpointToast(previous, checkpoint === view.total, hud.limit, view.unit), 'success');
  });

  $effect(() => () => clearTimeout(timer));

  const away = $derived(
    view.returnSeconds != null ? `Get back in the car within ${view.returnSeconds} seconds.` : null,
  );

  const banner = $derived<Toast | null>(away ? { text: away, tone: 'danger', at: 0 } : toast);

  function segment(index: number): string {
    if (index < view.checkpoint - 1) return 'bg-success';
    if (index === view.checkpoint - 1) return 'bg-primary';

    return 'bg-secondary';
  }
</script>

<div class="pointer-events-none fixed top-6 left-1/2 flex -translate-x-1/2 flex-col items-center gap-3" transition:rise>
  <div class="flex flex-col gap-2">
    <div class="flex h-11 items-center rounded-lg border border-border bg-card px-1 text-13 leading-4">
      <div class="flex items-center gap-2 px-3">
        {#if finish}
          <FlagCheckeredIcon size={14} class="text-muted-foreground" />
          <span class="font-semibold">Finish</span>
        {:else}
          <MapPinIcon size={14} class="text-muted-foreground" />
          {#key view.checkpoint}
            <span class="font-semibold tabular-nums" in:pop={{ duration: 250 }}>{view.checkpoint}/{view.total}</span>
          {/key}
        {/if}
        <span class="text-muted-foreground tabular-nums">{distance(meters)}</span>
      </div>
      <span class="h-5 w-px shrink-0 bg-border"></span>
      <div class="flex items-center gap-2 px-3">
        <span
          class="flex size-7 shrink-0 items-center justify-center rounded-full border-3 border-destructive-solid bg-foreground text-[11px] leading-3 font-bold text-background tabular-nums"
          aria-label="Speed limit {hud.limit} {view.unit}"
        >
          {hud.limit}
        </span>
        <span class={['w-14 font-semibold tabular-nums transition-colors duration-150', over && 'text-destructive']}>
          {speed} {view.unit}
        </span>
      </div>
      <span class="h-5 w-px shrink-0 bg-border"></span>
      <div class="flex items-center gap-2 px-3">
        <span class="text-muted-foreground">Strikes</span>
        <span class="flex gap-1">
          {#each { length: view.maxStrikes }, index (index)}
            {@const struck = index < view.strikes.length}
            {#key struck}
              <span
                class={['size-2.5 rounded-xs', struck ? 'bg-destructive' : 'bg-secondary']}
                in:pop={{ duration: 250 }}
              ></span>
            {/key}
          {/each}
        </span>
      </div>
    </div>
    <div class="flex gap-1 px-1" aria-label="Checkpoint {view.checkpoint} of {view.total}">
      {#each { length: view.total }, index (index)}
        <span class={['h-1 grow rounded-full transition-colors duration-300', segment(index)]}></span>
      {/each}
    </div>
  </div>

  {#if banner}
    {#key banner.at}
      <div
        class={['flex h-9 items-center gap-2 rounded-lg px-3.5 text-13 leading-4 font-semibold tabular-nums', tones[banner.tone]]}
        role="status"
        in:rise
      >
        {#if banner.tone === 'success'}
          <CheckCircleIcon size={14} />
        {:else if banner.tone === 'info'}
          <NavigationArrowIcon size={14} />
        {:else}
          <WarningIcon size={14} />
        {/if}
        {banner.text}
      </div>
    {/key}
  {/if}
</div>

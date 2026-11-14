<script lang="ts">
  import Check from 'phosphor-svelte/lib/Check';
  import IconContext from 'phosphor-svelte/lib/IconContext';
  import MeterBar from './MeterBar.svelte';
  import { fit } from './fit';
  import { meter } from './state.svelte';
  import { SAUCES, type KitchenStage } from './types';

  const STAGES: Record<KitchenStage, { title: string; step: number }> = {
    sausage: { title: 'Fry the sausage', step: 1 },
    bun: { title: 'Toast the bun or keep it plain', step: 2 },
    assemble: { title: 'Put it together', step: 3 },
    sauce: { title: 'Sauce it and serve', step: 4 },
  };

  const stage = $derived(STAGES[meter.stage]);
  const urgent = $derived(meter.sausage.value >= 1.7 || meter.bun.value >= 1.7);

  const wanted = $derived.by(() => {
    const order = meter.order;

    if (!order) return undefined;

    const sauces = SAUCES.filter((sauce) => order.sauces[sauce.id]).map((sauce) => sauce.label);

    return [order.toasted ? 'Toasted' : 'Plain', ...sauces].join(' · ');
  });
</script>

<IconContext values={{ weight: 'fill' }}>
  <div class="flex h-screen flex-col justify-center overflow-hidden p-2">
    <section class="flex origin-center flex-col gap-3 rounded-lg border border-border bg-card p-3 shadow-lg" use:fit>
      <header class="flex items-baseline justify-between gap-2">
        <h1 class="text-base font-semibold">{stage.title}</h1>
        <span class="text-xs text-muted-foreground tabular-nums">Step {stage.step} of 4</span>
      </header>

      <p class="text-sm font-medium tabular-nums {urgent ? 'text-warning' : 'text-foreground'}">{meter.hint}</p>

      <div class="flex flex-col gap-1.5">
        <MeterBar label="Sausage" bar={meter.sausage} />
        <MeterBar label="Bun" bar={meter.bun} />
      </div>

      <ul class="grid grid-cols-5 gap-1">
        {#each SAUCES as sauce, index (sauce.id)}
          {@const selected = meter.stage === 'sauce' && meter.sauce === sauce.id}
          <li
            class="flex flex-col items-center gap-0.5 rounded-md border py-1.5 text-xs font-medium transition-colors duration-150 ease-standard {selected
              ? 'border-primary bg-primary text-primary-foreground'
              : 'border-border bg-secondary text-foreground'}"
          >
            <span class="flex h-4 items-center gap-1 tabular-nums {selected ? '' : 'text-muted-foreground'}">
              {index + 1}
              {#if meter.added[sauce.id]}
                <Check size="0.9em" class={selected ? 'text-primary-foreground' : 'text-success'} />
              {/if}
            </span>
            {sauce.label}
          </li>
        {/each}
      </ul>

      <p class="text-xs {wanted ? 'text-foreground' : 'text-muted-foreground'}">
        {wanted ? `Order: ${wanted}` : 'Nobody at the counter yet'}
      </p>
    </section>
  </div>
</IconContext>

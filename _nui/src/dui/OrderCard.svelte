<script lang="ts">
  import Check from 'phosphor-svelte/lib/Check';
  import Fire from 'phosphor-svelte/lib/Fire';
  import IconContext from 'phosphor-svelte/lib/IconContext';
  import X from 'phosphor-svelte/lib/X';
  import { rise } from '../lib/motion';
  import { fit } from './fit';
  import { order } from './state.svelte';
  import { SAUCES } from './types';

  const patienceColour = $derived(
    order.patience > 0.35 ? 'bg-primary' : order.patience > 0.15 ? 'bg-warning-solid' : 'bg-destructive-solid',
  );
</script>

<IconContext values={{ weight: 'fill' }}>
  <div class="flex h-screen items-end justify-center overflow-hidden p-2">
    <div class="w-full origin-bottom" use:fit>
      <article
        class="w-full rounded-lg border border-border bg-card p-3 shadow-lg"
        in:rise={{ y: 12, duration: 220 }}
      >
        <header class="flex items-center justify-between gap-2">
          <h1 class="text-base font-semibold">Hot dog</h1>
          {#if order.next}
            <span class="rounded-sm bg-primary px-2 py-0.5 text-xs font-medium text-primary-foreground">Next</span>
          {/if}
        </header>

        <p class="mt-1 flex items-center gap-1.5 text-sm {order.order.toasted ? 'text-foreground' : 'text-muted-foreground'}">
          <Fire size="0.9em" class={order.order.toasted ? 'text-warning' : 'text-muted-foreground'} />
          {order.order.toasted ? 'Toasted bun' : 'Plain bun'}
        </p>

        <ul class="mt-2 flex flex-col gap-0.5 border-t border-border pt-2">
          {#each SAUCES as sauce (sauce.id)}
            {@const wanted = order.order.sauces[sauce.id] === true}
            <li class="flex items-center justify-between text-sm {wanted ? 'font-medium text-foreground' : 'text-muted-foreground'}">
              <span>{sauce.label}</span>
              {#if wanted}
                <Check size="0.95em" class="text-success" />
              {:else}
                <X size="0.8em" />
              {/if}
            </li>
          {/each}
        </ul>

        <div class="mt-3 h-1.5 overflow-hidden rounded-full bg-secondary" role="meter" aria-label="Patience" aria-valuenow={order.patience}>
          <div
            class="h-full rounded-full transition-[width,background-color] duration-300 ease-standard {patienceColour}"
            style:width="{order.patience * 100}%"
          ></div>
        </div>
      </article>
    </div>
  </div>
</IconContext>

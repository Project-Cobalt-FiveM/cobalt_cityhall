<script lang="ts">
  import type { Snippet } from 'svelte';

  let { lead, title, subtitle, onclose }: { lead: Snippet; title: Snippet; subtitle: string; onclose: () => void } =
    $props();
</script>

<header class="flex items-center gap-3 border-b border-border px-5 pt-5 pb-4">
  {@render lead()}
  <div class="flex min-w-0 grow flex-col gap-0.5">
    <h1 class="flex items-center gap-2 text-xl font-semibold tracking-tight">{@render title()}</h1>
    <p class="truncate text-13 text-muted-foreground">{subtitle}</p>
  </div>
  <button
    type="button"
    class="flex shrink-0 items-center gap-1.5 self-start rounded-md text-xs text-muted-foreground transition-colors hover:text-foreground"
    onclick={onclose}
  >
    <span class="kbd font-medium">Esc</span>
    Close
  </button>
</header>

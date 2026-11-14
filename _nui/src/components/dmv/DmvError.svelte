<script lang="ts">
  import WarningCircleIcon from 'phosphor-svelte/lib/WarningCircleIcon';
  import type { DmvNotice } from '../../lib/types';

  let { notice }: { notice: DmvNotice } = $props();
</script>

<div class="flex min-w-0 grow items-center gap-3" role="alert">
  <WarningCircleIcon size={20} class="shrink-0 text-destructive" />
  {#if notice.title}
    <div class="flex flex-col">
      <p class="text-sm font-medium">{notice.title}</p>
      <p class="text-xs text-muted-foreground tabular-nums">{notice.text}</p>
    </div>
  {:else}
    <p class="text-xs text-destructive">{notice.text}</p>
  {/if}
</div>

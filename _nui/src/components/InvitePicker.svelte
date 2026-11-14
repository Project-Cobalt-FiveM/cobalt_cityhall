<script lang="ts">
  import CheckCircle from 'phosphor-svelte/lib/CheckCircle';
  import Users from 'phosphor-svelte/lib/Users';
  import X from 'phosphor-svelte/lib/X';
  import { initials } from '../lib/format';
  import { rise } from '../lib/motion';
  import { fetchNui } from '../lib/nui';
  import type { NearbyPlayer } from '../lib/types';

  let { spots, onclose }: { spots: number; onclose: () => void } = $props();

  let players = $state<NearbyPlayer[] | null>(null);
  let sent = $state<Record<number, true>>({});
  let errors = $state<Record<number, string>>({});

  $effect(() => {
    fetchNui('nearby').then((reply) => (players = Array.isArray(reply.players) ? reply.players : []));
  });

  async function invite(player: NearbyPlayer) {
    const result = await fetchNui('invite', { id: player.id });

    if (result.ok) sent[player.id] = true;
    else errors[player.id] = result.reason ?? 'Could not invite';
  }
</script>

<div
  class="absolute right-[calc(100%+2rem)] bottom-0 flex w-[23rem] flex-col rounded-lg border border-border bg-popover shadow-lg"
  role="dialog"
  aria-label="Invite nearby"
  transition:rise={{ y: 4, duration: 200 }}
>
  <div class="flex items-start gap-3 px-4 pt-4 pb-3">
    <div class="flex grow flex-col gap-0.5">
      <h2 class="text-base font-semibold">Invite nearby</h2>
      <p class="text-13 text-muted-foreground">{spots} {spots === 1 ? 'spot' : 'spots'} left in your crew.</p>
    </div>
    <button
      type="button"
      aria-label="Close"
      class="flex size-7 shrink-0 items-center justify-center rounded-md text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
      onclick={onclose}
    >
      <X size={16} />
    </button>
  </div>

  {#if players && players.length === 0}
    <div class="flex flex-col items-center gap-2 px-6 pt-5 pb-6 text-center">
      <span class="flex size-10 items-center justify-center rounded-full bg-secondary text-muted-foreground">
        <Users size={20} />
      </span>
      <p class="text-sm font-medium">No one is close enough</p>
      <p class="text-13 text-muted-foreground">Ask a friend to walk up to you, then open this list again.</p>
    </div>
  {:else if players}
    <ul class="flex flex-col gap-0.5 px-2 pb-2">
      {#each players as player (player.id)}
        <li class="group flex h-13 items-center gap-3 rounded-md px-2 transition-colors hover:bg-muted">
          <span class="flex size-8 shrink-0 items-center justify-center rounded-full bg-secondary text-xs font-semibold">
            {initials(player.name)}
          </span>
          <span class="flex min-w-0 grow flex-col">
            <span class="truncate text-sm font-medium">{player.name}</span>
            <span class={['truncate text-xs tabular-nums', errors[player.id] ? 'text-destructive' : 'text-muted-foreground']}>
              {errors[player.id] ?? `${player.distance} m away`}
            </span>
          </span>
          <span class="flex w-18 shrink-0 justify-end">
            {#if sent[player.id]}
              <span class="flex items-center gap-1.5 text-xs font-medium text-muted-foreground">
                <CheckCircle size={14} class="text-success" />
                Sent
              </span>
            {:else}
              <button
                type="button"
                class="h-8 rounded-md border border-input bg-secondary px-3 text-xs font-medium transition-colors group-hover:border-primary group-hover:bg-primary group-hover:text-primary-foreground focus-visible:border-primary focus-visible:bg-primary focus-visible:text-primary-foreground"
                onclick={() => invite(player)}
              >
                Invite
              </button>
            {/if}
          </span>
        </li>
      {/each}
    </ul>
  {/if}
</div>

<script lang="ts">
  import Bank from 'phosphor-svelte/lib/Bank';
  import CaretRight from 'phosphor-svelte/lib/CaretRight';
  import Lock from 'phosphor-svelte/lib/Lock';
  import CenterTabs from './CenterTabs.svelte';
  import JobIcon from './JobIcon.svelte';
  import PanelHeader from './PanelHeader.svelte';
  import { app, isOpen, jobById } from '../lib/store.svelte';
  import type { JobCard } from '../lib/types';

  let { onclose }: { onclose: () => void } = $props();

  type Row = { job: JobCard; kind: 'open' | 'mine' | 'locked' | 'closed' };

  const current = $derived(app.shift ? jobById(app.shift.job) : undefined);

  const rows: Row[] = $derived(
    app.catalogue.map((job) => {
      if (current?.id === job.id) return { job, kind: 'mine' };
      if (!isOpen(job.id)) return { job, kind: 'closed' };
      if (current) return { job, kind: 'locked' };
      return { job, kind: 'open' };
    }),
  );

  const usable = $derived(rows.filter((row) => row.kind === 'open' || row.kind === 'mine'));
  const largestCrew = $derived(Math.max(1, ...app.catalogue.map((job) => job.crewSize)));
  const payNote = $derived(
    app.payAccount === 'bank' ? 'Pay goes to your bank account.' : 'Pay is handed to you in cash.',
  );

  let selected = $state<string | null>(null);

  function choose(row: Row) {
    if (row.kind === 'mine') app.screen = { kind: 'shift' };
    else if (row.kind === 'open') app.screen = { kind: 'detail', job: row.job.id };
  }

  function onkeydown(event: KeyboardEvent) {
    if (usable.length === 0) return;

    const index = usable.findIndex((row) => row.job.id === selected);

    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault();
      const step = event.key === 'ArrowDown' ? 1 : -1;
      const next = index < 0 ? 0 : (index + step + usable.length) % usable.length;
      selected = usable[next]?.job.id ?? null;
    } else if (event.key === 'Enter' && index >= 0) {
      const row = usable[index];
      if (row) choose(row);
    }
  }
</script>

<svelte:window {onkeydown} />

<PanelHeader {onclose} subtitle={current ? `Your job is ${current.label}. Quit it to pick another.` : 'Pick a job. It lasts until you quit or log off.'}>
  {#snippet lead()}
    <div class="flex size-9 shrink-0 items-center justify-center rounded-md bg-secondary">
      <Bank size={20} />
    </div>
  {/snippet}
  {#snippet title()}City Hall{/snippet}
</PanelHeader>

{#if app.cards}
  <CenterTabs />
{/if}

<ul class="flex flex-col gap-0.5 px-3 py-2" role="listbox" aria-label="Jobs">
  {#each rows as row (row.job.id)}
    {@const active = selected === row.job.id && (row.kind === 'open' || row.kind === 'mine')}
    {@const dim = row.kind === 'locked' || row.kind === 'closed'}
    <li>
      <button
        type="button"
        role="option"
        aria-selected={active}
        aria-disabled={dim}
        tabindex={dim ? -1 : 0}
        class={[
          'flex h-16 w-full items-center gap-3 rounded-md px-3 text-left transition-colors duration-150',
          active && row.kind === 'open' && 'bg-primary text-primary-foreground',
          active && row.kind === 'mine' && 'bg-muted',
          !active && row.kind === 'mine' && 'bg-muted',
          !active && row.kind === 'open' && 'hover:bg-muted',
          dim && 'cursor-default',
        ]}
        onmouseenter={() => {
          if (!dim) selected = row.job.id;
        }}
        onfocus={() => {
          if (!dim) selected = row.job.id;
        }}
        onclick={() => choose(row)}
      >
        <span
          class={[
            'flex size-10 shrink-0 items-center justify-center rounded-md',
            active && row.kind === 'open' ? 'bg-cobalt-hover' : dim ? 'bg-muted text-muted-foreground' : 'bg-secondary',
          ]}
        >
          <JobIcon icon={row.job.icon} />
        </span>
        <span class="flex min-w-0 grow flex-col gap-0.5">
          <span class="flex items-baseline gap-3">
            <span class={['shrink-0 text-sm font-medium', dim && 'text-muted-foreground']}>{row.job.label}</span>
            {#if row.kind === 'open'}
              <span class="min-w-0 grow truncate text-right text-13 font-medium tabular-nums">{row.job.pay}</span>
            {:else if row.kind === 'mine'}
              <span class="ml-auto shrink-0 rounded-sm bg-primary px-2 py-0.5 text-xs font-medium text-primary-foreground">Your job</span>
            {:else if row.kind === 'locked'}
              <span class="min-w-0 grow truncate text-right text-13 text-muted-foreground">Quit {current?.label} first</span>
            {:else}
              <span class="min-w-0 grow truncate text-right text-13 text-muted-foreground">Closed by staff</span>
            {/if}
          </span>
          <span class={['truncate text-13', active && row.kind === 'open' ? 'text-primary-foreground' : 'text-muted-foreground']}>
            {row.job.description}
          </span>
        </span>
        <span class="flex size-4 shrink-0 items-center justify-center">
          {#if dim}
            <Lock size={14} class="text-muted-foreground" />
          {:else}
            <CaretRight size={14} class={active || row.kind === 'mine' ? '' : 'text-muted-foreground'} />
          {/if}
        </span>
      </button>
    </li>
  {/each}
</ul>

<footer class="flex items-center gap-2 border-t border-border px-5 py-3.5 text-xs text-muted-foreground">
  <Bank size={16} class="shrink-0" />
  {payNote} Work alone or in a crew of up to {largestCrew}.
</footer>

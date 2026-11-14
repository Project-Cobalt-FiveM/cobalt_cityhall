<script lang="ts">
  import Briefcase from 'phosphor-svelte/lib/Briefcase';
  import JobIcon from './JobIcon.svelte';
  import PanelHeader from './PanelHeader.svelte';
  import { elapsed, money } from '../lib/format';
  import { pop } from '../lib/motion';
  import { fetchNui } from '../lib/nui';
  import { app, jobById, normaliseAdmin } from '../lib/store.svelte';
  import type { AdminView, AdminWorker } from '../lib/types';

  let { admin, onclose }: { admin: AdminView; onclose: () => void } = $props();

  let now = $state(Date.now() / 1000);
  let confirming = $state<AdminWorker | null>(null);

  $effect(() => {
    const timer = setInterval(() => (now = Date.now() / 1000), 1000);
    return () => clearInterval(timer);
  });

  const paidToday = $derived(admin.jobs.reduce((sum, job) => sum + job.paidToday, 0));
  const summary = $derived(
    `${admin.workers.length} ${admin.workers.length === 1 ? 'person' : 'people'} working now, ${money(paidToday)} paid today`,
  );

  function update(next: AdminView | undefined) {
    const parsed = normaliseAdmin(next);
    if (parsed) app.admin = parsed;
  }

  async function endShift(worker: AdminWorker) {
    confirming = null;
    update((await fetchNui('adminEnd', { id: worker.id })).admin);
  }

  async function toggle(job: string, open: boolean) {
    update((await fetchNui('adminToggle', { job, open })).admin);
  }

  function firstName(name: string): string {
    return name.split(' ')[0] ?? name;
  }

  export function dismiss(): boolean {
    if (!confirming) return false;
    confirming = null;
    return true;
  }
</script>

<PanelHeader {onclose} subtitle={summary}>
  {#snippet lead()}
    <div class="flex size-9 shrink-0 items-center justify-center rounded-md bg-secondary">
      <Briefcase size={20} />
    </div>
  {/snippet}
  {#snippet title()}City Hall admin{/snippet}
</PanelHeader>

<div class="flex min-h-0 grow">
  <section class="flex min-w-0 grow flex-col gap-4 p-6">
    <div class="flex items-baseline justify-between gap-4">
      <h2 class="text-base font-semibold">Working now</h2>
      <p class="text-xs text-muted-foreground">Ending a shift removes the player's job. They keep what they earned.</p>
    </div>

    <div class="flex min-h-0 flex-col rounded-lg border border-border">
      <div class="flex h-10 shrink-0 items-center gap-4 border-b border-border px-4 text-xs font-medium text-muted-foreground">
        <span class="grow">Player</span>
        <span class="w-[9.375rem] shrink-0">Job</span>
        <span class="w-[8.75rem] shrink-0">Crew</span>
        <span class="w-[5.625rem] shrink-0 text-right">Shift</span>
        <span class="w-[6.875rem] shrink-0 text-right">Earned this shift</span>
        <span class="w-[5.75rem] shrink-0"></span>
      </div>
      {#if admin.workers.length === 0}
        <p class="px-4 py-6 text-center text-sm text-muted-foreground">Nobody is working a job right now.</p>
      {:else}
        <ul class="flex max-h-[38rem] flex-col divide-y divide-border overflow-y-auto">
          {#each admin.workers as worker (worker.id)}
            {@const job = jobById(worker.job)}
            <li class="group flex h-14 shrink-0 items-center gap-4 px-4 transition-colors hover:bg-muted">
              <span class="flex min-w-0 grow flex-col">
                <span class="truncate text-sm font-medium">{worker.name}</span>
                <span class="text-xs text-muted-foreground tabular-nums">{worker.citizenid}</span>
              </span>
              <span class="flex w-[9.375rem] shrink-0 items-center gap-2 text-sm">
                {#if job}<JobIcon icon={job.icon} size={16} class="text-muted-foreground" />{/if}
                {job?.label ?? worker.job}
              </span>
              <span class={['w-[8.75rem] shrink-0 text-sm', worker.crew > 1 ? '' : 'text-muted-foreground']}>
                {worker.crew > 1 ? `Crew of ${worker.crew}` : 'Solo'}
              </span>
              <span class="w-[5.625rem] shrink-0 text-right text-sm tabular-nums">{elapsed(now - worker.startedAt)}</span>
              <span class="w-[6.875rem] shrink-0 text-right text-sm font-medium tabular-nums">{money(worker.earned)}</span>
              <span class="flex w-[5.75rem] shrink-0 justify-end">
                <button
                  type="button"
                  class="h-8 rounded-md border border-input bg-secondary px-3 text-xs font-medium transition-colors group-hover:border-destructive-solid group-hover:bg-destructive-solid group-hover:text-primary-foreground"
                  onclick={() => (confirming = worker)}
                >
                  End shift
                </button>
              </span>
            </li>
          {/each}
        </ul>
      {/if}
    </div>
  </section>

  <aside class="flex w-[25rem] shrink-0 flex-col gap-3 border-l border-border p-6">
    <div class="flex flex-col gap-0.5">
      <h2 class="text-base font-semibold">Jobs today</h2>
      <p class="text-xs text-muted-foreground">Closing a job stops new sign-ups. People already working keep it.</p>
    </div>
    <ul class="flex flex-col divide-y divide-border">
      {#each admin.jobs as entry (entry.id)}
        {@const job = jobById(entry.id)}
        <li class="flex h-14 items-center gap-3 px-1">
          <span
            class={[
              'flex size-8 shrink-0 items-center justify-center rounded-md',
              entry.open ? 'bg-secondary' : 'bg-muted text-muted-foreground',
            ]}
          >
            {#if job}<JobIcon icon={job.icon} size={16} />{/if}
          </span>
          <span class="flex min-w-0 grow flex-col">
            <span class={['text-sm font-medium', !entry.open && 'text-muted-foreground']}>{job?.label ?? entry.id}</span>
            <span class="text-xs text-muted-foreground tabular-nums">
              {entry.workers} working, {money(entry.paidToday)} paid today
            </span>
          </span>
          <span class="text-xs text-muted-foreground">{entry.open ? 'Open' : 'Closed'}</span>
          <button
            type="button"
            role="switch"
            aria-checked={entry.open}
            aria-label={`${job?.label ?? entry.id} open for sign-ups`}
            class={[
              'flex h-5 w-9 shrink-0 items-center rounded-full p-0.5 transition-colors',
              entry.open ? 'justify-end bg-primary' : 'justify-start border border-input bg-secondary',
            ]}
            onclick={() => toggle(entry.id, !entry.open)}
          >
            <span class={['size-4 rounded-full', entry.open ? 'bg-primary-foreground' : 'bg-muted-foreground']}></span>
          </button>
        </li>
      {/each}
    </ul>
  </aside>
</div>

{#if confirming}
  {@const worker = confirming}
  {@const job = jobById(worker.job)}
  <div class="fixed inset-0 flex items-center justify-center">
    <div
      class="flex w-full max-w-md flex-col gap-2 rounded-lg border border-border bg-popover p-6 shadow-lg"
      role="alertdialog"
      aria-labelledby="end-shift-title"
      transition:pop
    >
      <h2 id="end-shift-title" class="text-base font-semibold">End {worker.name}'s shift?</h2>
      <p class="text-sm text-muted-foreground">
        {firstName(worker.name)} loses the {job?.label ?? worker.job} job. The {money(worker.earned)} they earned stays theirs.
      </p>
      <div class="flex justify-end gap-2 pt-4">
        <button
          type="button"
          class="h-9 rounded-md border border-input bg-secondary px-4 text-sm font-medium transition-colors hover:bg-input"
          onclick={() => (confirming = null)}
        >
          Cancel
        </button>
        <button
          type="button"
          class="h-9 rounded-md bg-destructive-solid px-4 text-sm font-medium text-primary-foreground transition-colors hover:bg-destructive-hover"
          onclick={() => endShift(worker)}
        >
          End shift
        </button>
      </div>
    </div>
  </div>
{/if}

<script lang="ts">
  import ArrowLeft from 'phosphor-svelte/lib/ArrowLeft';
  import MapPin from 'phosphor-svelte/lib/MapPin';
  import Truck from 'phosphor-svelte/lib/Truck';
  import Users from 'phosphor-svelte/lib/Users';
  import GpsButton from './GpsButton.svelte';
  import JobIcon from './JobIcon.svelte';
  import PanelHeader from './PanelHeader.svelte';
  import { capitalise } from '../lib/format';
  import { fetchNui } from '../lib/nui';
  import { app } from '../lib/store.svelte';
  import type { JobCard } from '../lib/types';

  let { job, onclose }: { job: JobCard; onclose: () => void } = $props();

  let pending = $state(false);
  let error = $state<string | null>(null);

  const crew = $derived(job.crewSize > 1 ? `Solo or crew of up to ${job.crewSize}` : 'Solo');
  const payNote = $derived(
    app.payAccount === 'bank' ? 'Pay goes to your bank account.' : 'Pay is handed to you in cash.',
  );

  function back() {
    app.screen = { kind: 'list' };
  }

  async function signUp() {
    pending = true;
    error = null;

    const result = await fetchNui('signUp', { job: job.id });

    pending = false;

    if (result.ok) app.screen = { kind: 'shift' };
    else error = result.reason ?? 'You could not sign up. Try again.';
  }
</script>

<PanelHeader {onclose} subtitle="City Hall">
  {#snippet lead()}
    <button
      type="button"
      aria-label="Back to jobs"
      class="flex size-9 shrink-0 items-center justify-center rounded-md border border-input bg-secondary transition-colors hover:bg-input"
      onclick={back}
    >
      <ArrowLeft size={16} />
    </button>
  {/snippet}
  {#snippet title()}{job.label}{/snippet}
</PanelHeader>

<div class="flex flex-col gap-6 p-5">
  <div class="flex items-start gap-4">
    <span class="flex size-14 shrink-0 items-center justify-center rounded-lg bg-secondary">
      <JobIcon icon={job.icon} size={28} />
    </span>
    <p class="text-sm">{job.description} You keep the job until you quit or log off.</p>
  </div>

  <dl class="flex flex-col divide-y divide-border rounded-lg border border-border">
    <div class="flex h-13 items-center gap-3 px-4">
      <MapPin size={16} class="shrink-0 text-muted-foreground" />
      <dt class="w-24 shrink-0 text-sm text-muted-foreground">Where</dt>
      <dd class="grow truncate text-sm font-medium">{job.site}</dd>
      <GpsButton request={() => fetchNui('gps', { job: job.id })} />
    </div>
    <div class="flex h-13 items-center gap-3 px-4">
      <Truck size={16} class="shrink-0 text-muted-foreground" />
      <dt class="w-24 shrink-0 text-sm text-muted-foreground">Vehicle</dt>
      <dd class="text-sm font-medium">{job.vehicle ? `${capitalise(job.vehicle)} provided` : 'None needed'}</dd>
    </div>
    <div class="flex h-13 items-center gap-3 px-4">
      <Users size={16} class="shrink-0 text-muted-foreground" />
      <dt class="w-24 shrink-0 text-sm text-muted-foreground">Crew</dt>
      <dd class="text-sm font-medium">{crew}</dd>
    </div>
  </dl>

  <section class="flex flex-col">
    <h2 class="pb-1 text-base font-semibold">Pay</h2>
    <dl class="flex flex-col divide-y divide-border">
      {#each job.payRows as row (row.label)}
        <div class="flex h-9 items-center justify-between gap-4">
          <dt class="text-sm text-muted-foreground">{row.label}</dt>
          <dd class="text-sm font-medium tabular-nums">{row.value}</dd>
        </div>
      {/each}
    </dl>
    <p class="pt-1 text-xs text-muted-foreground">{payNote}</p>
  </section>
</div>

<footer class="flex flex-col gap-2 border-t border-border px-5 py-4">
  <button
    type="button"
    class="h-10 w-full rounded-md bg-primary px-6 text-sm font-medium text-primary-foreground transition-colors hover:bg-cobalt-hover disabled:bg-secondary disabled:text-muted-foreground"
    disabled={pending}
    onclick={signUp}
  >
    Sign up
  </button>
  {#if error}
    <p class="text-xs text-destructive" role="alert">{error}</p>
  {/if}
</footer>

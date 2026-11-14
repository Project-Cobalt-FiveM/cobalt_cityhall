<script lang="ts">
  import Clock from 'phosphor-svelte/lib/Clock';
  import CurrencyDollar from 'phosphor-svelte/lib/CurrencyDollar';
  import MapPin from 'phosphor-svelte/lib/MapPin';
  import Package from 'phosphor-svelte/lib/Package';
  import SignOut from 'phosphor-svelte/lib/SignOut';
  import UserPlus from 'phosphor-svelte/lib/UserPlus';
  import GpsButton from './GpsButton.svelte';
  import InvitePicker from './InvitePicker.svelte';
  import JobIcon from './JobIcon.svelte';
  import PanelHeader from './PanelHeader.svelte';
  import { distance, elapsed, initials, money } from '../lib/format';
  import { fetchNui } from '../lib/nui';
  import { app } from '../lib/store.svelte';
  import type { JobCard, ShiftView } from '../lib/types';

  let { job, shift, onclose }: { job: JobCard; shift: ShiftView; onclose: () => void } = $props();

  let now = $state(Date.now() / 1000);
  let picking = $state(false);
  let quitting = $state(false);

  $effect(() => {
    const timer = setInterval(() => (now = Date.now() / 1000), 1000);
    return () => clearInterval(timer);
  });

  const full = $derived(shift.crew.length >= job.crewSize);
  const inCrew = $derived(shift.crew.length > 1);
  const payNote = $derived(
    app.payAccount === 'bank' ? 'What you earned stays in your bank account.' : 'You keep the cash you earned.',
  );

  function caption(member: ShiftView['crew'][number]): string {
    if (member.id === app.me) return member.leader ? 'You, crew leader' : 'You';
    return member.leader ? 'Crew leader' : 'Crew member';
  }

  async function quit() {
    quitting = true;
    await fetchNui('quit');
    quitting = false;
  }
</script>

<PanelHeader {onclose} subtitle="City Hall">
  {#snippet lead()}
    <div class="flex size-9 shrink-0 items-center justify-center rounded-md bg-secondary">
      <JobIcon icon={job.icon} />
    </div>
  {/snippet}
  {#snippet title()}
    {job.label}
    <span class="rounded-sm bg-primary px-2 py-0.5 text-xs font-medium tracking-normal text-primary-foreground">Your job</span>
  {/snippet}
</PanelHeader>

<div class="flex flex-col gap-6 p-5">
  <div class="grid grid-cols-3 gap-2">
    <div class="flex flex-col gap-1 rounded-lg border border-border px-4 py-3">
      <span class="flex items-center gap-1.5 text-xs text-muted-foreground"><Clock size={14} />Shift time</span>
      <span class="text-xl font-semibold tracking-tight tabular-nums">{elapsed(now - shift.startedAt)}</span>
    </div>
    <div class="flex flex-col gap-1 rounded-lg border border-border px-4 py-3">
      <span class="flex items-center gap-1.5 text-xs text-muted-foreground"><CurrencyDollar size={14} />Earned this shift</span>
      <span class="text-xl font-semibold tracking-tight tabular-nums">{money(shift.earned)}</span>
    </div>
    <div class="flex flex-col gap-1 rounded-lg border border-border px-4 py-3">
      <span class="flex items-center gap-1.5 text-xs text-muted-foreground"><Package size={14} />{job.doneLabel}</span>
      <span class="text-xl font-semibold tracking-tight tabular-nums">{shift.done}</span>
    </div>
  </div>

  {#if shift.task}
    <div class="flex items-center gap-3 rounded-lg border border-border bg-muted py-3 pr-3 pl-4">
      <MapPin size={20} class="shrink-0 text-primary" />
      <div class="flex min-w-0 grow flex-col">
        <span class="text-xs text-muted-foreground">{shift.task.step ?? 'Current task'}</span>
        <span class="truncate text-sm font-medium tabular-nums">
          {shift.task.title}{shift.task.distance !== undefined ? `, ${distance(shift.task.distance)}` : ''}
        </span>
      </div>
      {#key shift.task.title}
        <GpsButton request={() => fetchNui('gpsTask')} />
      {/key}
    </div>
  {/if}

  <section class="flex flex-col gap-2">
    <div class="flex items-baseline justify-between">
      <h2 class="text-base font-semibold">Crew</h2>
      <span class="text-xs text-muted-foreground tabular-nums">{shift.crew.length} of {job.crewSize}</span>
    </div>
    <ul class="flex flex-col divide-y divide-border rounded-lg border border-border">
      {#each shift.crew as member (member.id)}
        <li class="flex h-14 items-center gap-3 px-4">
          <span class="flex size-8 shrink-0 items-center justify-center rounded-full bg-secondary text-xs font-semibold">
            {initials(member.name)}
          </span>
          <span class="flex min-w-0 grow flex-col">
            <span class="truncate text-sm font-medium">{member.name}</span>
            <span class="text-xs text-muted-foreground">{caption(member)}</span>
          </span>
          <span class="text-13 font-medium tabular-nums">{money(member.earned)}</span>
        </li>
      {/each}
    </ul>

    <div class="relative flex gap-2">
      {#if full}
        <p class="grow text-xs text-muted-foreground">Your crew is full.</p>
      {:else}
        <button
          type="button"
          class={[
            'flex h-9 grow items-center justify-center gap-2 rounded-md border border-input px-4 text-sm font-medium transition-colors',
            picking ? 'bg-input' : 'bg-secondary hover:bg-input',
          ]}
          aria-expanded={picking}
          onclick={() => (picking = !picking)}
        >
          <UserPlus size={16} />
          Invite nearby
        </button>
      {/if}
      {#if inCrew}
        <button
          type="button"
          class="flex h-9 shrink-0 items-center justify-center rounded-md border border-input bg-secondary px-4 text-sm font-medium transition-colors hover:bg-input"
          onclick={() => fetchNui('leaveCrew')}
        >
          Leave crew
        </button>
      {/if}
      {#if picking}
        <InvitePicker spots={job.crewSize - shift.crew.length} onclose={() => (picking = false)} />
      {/if}
    </div>
  </section>
</div>

<footer class="flex items-center gap-4 border-t border-border px-5 py-4">
  <p class="grow text-xs text-muted-foreground">Quitting ends your shift. {payNote}</p>
  <button
    type="button"
    class="flex h-9 shrink-0 items-center gap-2 rounded-md bg-destructive-solid px-4 text-sm font-medium text-primary-foreground transition-colors hover:bg-destructive-hover disabled:bg-secondary disabled:text-muted-foreground"
    disabled={quitting}
    onclick={quit}
  >
    <SignOut size={16} />
    Quit job
  </button>
</footer>

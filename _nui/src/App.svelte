<script lang="ts">
  import IconContext from 'phosphor-svelte/lib/IconContext';
  import Admin from './components/Admin.svelte';
  import CurrentJob from './components/CurrentJob.svelte';
  import IncomingInvite from './components/IncomingInvite.svelte';
  import JobDetail from './components/JobDetail.svelte';
  import JobList from './components/JobList.svelte';
  import Licences from './components/Licences.svelte';
  import Dmv from './components/dmv/Dmv.svelte';
  import DriveHud from './components/dmv/DriveHud.svelte';
  import { crossfade, rise } from './lib/motion';
  import { fetchNui, onMessage, sendMockOpen } from './lib/nui';
  import { app, apply, jobById } from './lib/store.svelte';

  let admin = $state<ReturnType<typeof Admin> | null>(null);
  let licences = $state<ReturnType<typeof Licences> | null>(null);

  const shiftJob = $derived(app.shift ? jobById(app.shift.job) : undefined);
  const detailJob = $derived(app.screen.kind === 'detail' ? jobById(app.screen.job) : undefined);

  function close() {
    app.visible = false;
    fetchNui('close');
  }

  function onkeydown(event: KeyboardEvent) {
    if (!app.visible || event.key !== 'Escape') return;
    if (admin?.dismiss() || licences?.dismiss()) return;

    close();
  }

  $effect(() => {
    const stop = onMessage(apply);
    sendMockOpen();
    return stop;
  });
</script>

<svelte:window {onkeydown} />

<IconContext values={{ weight: 'fill' }}>
  {#if app.visible && app.view === 'admin' && app.admin}
    <div class="fixed inset-0 flex items-center justify-center">
      <div
        class="flex max-h-[52.5rem] w-[90rem] flex-col rounded-lg border border-border bg-card"
        transition:rise={{ duration: 200 }}
      >
        <Admin bind:this={admin} admin={app.admin} onclose={close} />
      </div>
    </div>
  {:else if app.visible && app.view === 'dmv' && app.dmv}
    <div class="fixed inset-0 flex items-center justify-center">
      <div transition:rise={{ duration: 200 }}>
        <Dmv dmv={app.dmv} result={app.result} onclose={close} />
      </div>
    </div>
  {:else if app.visible}
    <div class="fixed top-1/2 right-6 w-[35rem] -translate-y-1/2">
      <div class="flex flex-col rounded-lg border border-border bg-card" transition:rise={{ duration: 200 }}>
        {#key app.screen.kind === 'detail' ? `detail:${app.screen.job}` : `${app.screen.kind}:${app.tab}`}
          <div class="flex flex-col" in:crossfade>
            {#if app.screen.kind === 'shift' && app.shift && shiftJob}
              <CurrentJob job={shiftJob} shift={app.shift} onclose={close} />
            {:else if detailJob}
              <JobDetail job={detailJob} onclose={close} />
            {:else if app.tab === 'licences' && app.cards}
              <Licences bind:this={licences} cards={app.cards} onclose={close} />
            {:else}
              <JobList onclose={close} />
            {/if}
          </div>
        {/key}
      </div>
    </div>
  {/if}

  {#if app.drive}
    <DriveHud hud={app.drive} speed={app.speed} meters={app.distance} />
  {/if}

  {#if app.invite}
    {#key app.inviteAt}
      <IncomingInvite invite={app.invite} receivedAt={app.inviteAt} />
    {/key}
  {/if}
</IconContext>

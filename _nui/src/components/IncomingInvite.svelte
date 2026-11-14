<script lang="ts">
  import JobIcon from './JobIcon.svelte';
  import { slideIn } from '../lib/motion';
  import { fetchNui } from '../lib/nui';
  import { app, jobById } from '../lib/store.svelte';
  import type { Invite } from '../lib/types';

  let { invite, receivedAt }: { invite: Invite; receivedAt: number } = $props();

  let now = $state(Date.now());
  let draining = $state(false);

  const job = $derived(jobById(invite.job));
  const label = $derived(job?.label ?? invite.job);
  const remaining = $derived(Math.max(0, Math.ceil(invite.seconds - (now - receivedAt) / 1000)));
  const people = $derived(invite.crew === 1 ? '1 person' : `${invite.crew} people`);

  $effect(() => {
    const timer = setInterval(() => (now = Date.now()), 1000);
    requestAnimationFrame(() => (draining = true));
    return () => clearInterval(timer);
  });

  function respond(accept: boolean) {
    app.invite = null;
    fetchNui('respond', { accept });
  }
</script>

<div
  class="fixed top-6 right-6 flex w-[22.5rem] flex-col gap-4 rounded-lg border border-border bg-popover p-4 shadow-lg"
  role="alert"
  transition:slideIn
>
  <div class="flex items-start gap-3">
    <span class="flex size-9 shrink-0 items-center justify-center rounded-md bg-secondary">
      {#if job}<JobIcon icon={job.icon} />{/if}
    </span>
    <div class="flex flex-col gap-1">
      <p class="text-sm font-medium">{invite.from} invited you to a {label} crew</p>
      <p class="text-13 text-muted-foreground">Accepting signs you up for {label}. The crew has {people}.</p>
    </div>
  </div>

  <div class="grid grid-cols-2 gap-2">
    <button
      type="button"
      class="flex h-9 items-center justify-center gap-2 rounded-md border border-input bg-secondary px-4 text-sm font-medium transition-colors hover:bg-input"
      onclick={() => respond(false)}
    >
      Decline
      <span class="rounded-sm border border-input bg-muted px-1.5 text-xs font-medium text-muted-foreground">{invite.declineKey}</span>
    </button>
    <button
      type="button"
      class="flex h-9 items-center justify-center gap-2 rounded-md bg-primary px-4 text-sm font-medium text-primary-foreground transition-colors hover:bg-cobalt-hover"
      onclick={() => respond(true)}
    >
      Accept
      <span class="rounded-sm bg-cobalt-hover px-1.5 text-xs font-medium">{invite.acceptKey}</span>
    </button>
  </div>

  <div class="flex flex-col gap-1.5">
    <div class="h-1 overflow-hidden rounded-full bg-secondary">
      <div
        class="countdown h-full rounded-full bg-primary"
        style:width={draining ? '0%' : '100%'}
        style:transition={`width ${invite.seconds}s linear`}
      ></div>
    </div>
    <span class="text-xs text-muted-foreground tabular-nums">Closes in {remaining}s</span>
  </div>
</div>

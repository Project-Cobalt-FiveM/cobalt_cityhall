<script lang="ts">
  import CheckCircleIcon from 'phosphor-svelte/lib/CheckCircleIcon';
  import NavigationArrowIcon from 'phosphor-svelte/lib/NavigationArrowIcon';
  import { pop } from '../lib/motion';

  let {
    request,
    label = 'Set GPS',
    done = 'GPS set',
  }: { request: () => Promise<{ ok?: boolean }>; label?: string; done?: string } = $props();

  let set = $state(false);
  let pending = $state(false);

  async function click() {
    if (pending) return;

    pending = true;

    const reply = await request();

    pending = false;
    set = reply.ok === true;
  }
</script>

<button
  type="button"
  class={[
    'flex h-8 shrink-0 items-center rounded-md border px-3 text-xs font-medium transition-colors duration-200',
    set ? 'border-success-solid bg-success-solid text-foreground' : 'border-input bg-secondary hover:bg-input',
  ]}
  disabled={pending}
  onclick={click}
>
  {#key set}
    <span class="flex items-center gap-1.5" role="status" in:pop={{ duration: 250 }}>
      {#if set}
        <CheckCircleIcon size={14} />
        {done}
      {:else}
        <NavigationArrowIcon size={14} />
        {label}
      {/if}
    </span>
  {/key}
</button>

<script lang="ts">
  import BriefcaseIcon from 'phosphor-svelte/lib/BriefcaseIcon';
  import IdentificationCardIcon from 'phosphor-svelte/lib/IdentificationCardIcon';
  import { app, type Tab } from '../lib/store.svelte';

  const tabs = [
    { id: 'jobs', label: 'Jobs', Icon: BriefcaseIcon },
    { id: 'licences', label: 'Licences', Icon: IdentificationCardIcon },
  ] satisfies { id: Tab; label: string; Icon: unknown }[];
</script>

<div class="flex gap-1 border-b border-border px-5 py-3" role="tablist" aria-label="City Hall">
  {#each tabs as tab (tab.id)}
    {@const active = app.tab === tab.id}
    <button
      type="button"
      role="tab"
      aria-selected={active}
      class={[
        'flex h-8 items-center gap-2 rounded-md px-3 text-sm font-medium transition-colors duration-150',
        active ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:bg-muted',
      ]}
      onclick={() => (app.tab = tab.id)}
    >
      <tab.Icon size={16} />
      {tab.label}
    </button>
  {/each}
</div>

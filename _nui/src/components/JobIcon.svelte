<script lang="ts">
  import FishSimple from 'phosphor-svelte/lib/FishSimple';
  import ForkKnife from 'phosphor-svelte/lib/ForkKnife';
  import HardHat from 'phosphor-svelte/lib/HardHat';
  import Mountains from 'phosphor-svelte/lib/Mountains';
  import Plant from 'phosphor-svelte/lib/Plant';
  import Recycle from 'phosphor-svelte/lib/Recycle';
  import Taxi from 'phosphor-svelte/lib/Taxi';
  import Trash from 'phosphor-svelte/lib/Trash';
  import Truck from 'phosphor-svelte/lib/Truck';
  import type { JobIcon } from '../lib/types';

  let { icon, size = 20, class: className = '' }: { icon: JobIcon; size?: number; class?: string } = $props();

  const icons = {
    taxi: Taxi,
    truck: Truck,
    trash: Trash,
    hardHat: HardHat,
    fish: FishSimple,
    mountains: Mountains,
    plant: Plant,
    recycle: Recycle,
    hotdog: ForkKnife,
  } satisfies Record<JobIcon, unknown>;

  const Icon = $derived(icons[icon]);
</script>

<Icon {size} class={className} />

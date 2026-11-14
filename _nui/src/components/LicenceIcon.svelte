<script lang="ts">
  import CarIcon from 'phosphor-svelte/lib/CarIcon';
  import CertificateIcon from 'phosphor-svelte/lib/CertificateIcon';
  import CrosshairIcon from 'phosphor-svelte/lib/CrosshairIcon';
  import IdentificationCardIcon from 'phosphor-svelte/lib/IdentificationCardIcon';

  let { card, size = 20 }: { card: string; size?: number } = $props();

  const icons: Record<string, typeof CertificateIcon> = {
    id: IdentificationCardIcon,
    driver: CarIcon,
    weapon: CrosshairIcon,
  };

  const Icon = $derived(icons[card] ?? CertificateIcon);
</script>

<Icon {size} />

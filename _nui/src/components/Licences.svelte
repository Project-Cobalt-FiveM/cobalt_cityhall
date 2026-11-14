<script lang="ts">
  import BankIcon from 'phosphor-svelte/lib/BankIcon';
  import CheckCircleIcon from 'phosphor-svelte/lib/CheckCircleIcon';
  import LockIcon from 'phosphor-svelte/lib/LockIcon';
  import ShoppingCartIcon from 'phosphor-svelte/lib/ShoppingCartIcon';
  import WarningCircleIcon from 'phosphor-svelte/lib/WarningCircleIcon';
  import CenterTabs from './CenterTabs.svelte';
  import GpsButton from './GpsButton.svelte';
  import LicenceIcon from './LicenceIcon.svelte';
  import PanelHeader from './PanelHeader.svelte';
  import { capitalise, money, shortDate } from '../lib/format';
  import { crossfade, pop } from '../lib/motion';
  import { fetchNui } from '../lib/nui';
  import { app, normaliseCards } from '../lib/store.svelte';
  import type { CardOffer, CardsView } from '../lib/types';

  let { cards, onclose }: { cards: CardsView; onclose: () => void } = $props();

  type Group = { label: string; kind: 'ready' | 'carried' | 'locked'; offers: CardOffer[] };
  type Issued = { name: string; price: number; account: 'cash' | 'bank' };

  const ISSUED_MS = 5000;

  let selected = $state<string | null>(null);
  let pending = $state(false);
  let error = $state<string | null>(null);
  let issued = $state<Issued | null>(null);
  let issuedTimer: ReturnType<typeof setTimeout> | undefined;

  $effect(() => () => clearTimeout(issuedTimer));

  const groups: Group[] = $derived(
    [
      {
        label: 'Ready to buy',
        kind: 'ready' as const,
        offers: cards.offers.filter((offer) => offer.held && (offer.key === 'id' || offer.carried === 0)),
      },
      {
        label: 'In your inventory',
        kind: 'carried' as const,
        offers: cards.offers.filter((offer) => offer.key !== 'id' && offer.held && offer.carried > 0),
      },
      { label: 'Not granted yet', kind: 'locked' as const, offers: cards.offers.filter((offer) => !offer.held) },
    ].filter((group) => group.offers.length > 0),
  );

  const choice = $derived(cards.offers.find((offer) => offer.key === selected) ?? null);
  const account = $derived(choice && (cards.cash >= choice.price ? 'cash' : cards.bank >= choice.price ? 'bank' : null));

  function cardName(offer: CardOffer): string {
    return offer.key === 'id' ? 'an ID card' : `a ${offer.label} card`;
  }

  function detail(offer: CardOffer, kind: Group['kind']): string {
    if (kind === 'carried') return 'You carry this card. Lose it and you can buy it again.';
    if (offer.key === 'id') return 'Proves who you are. Police can ask to see it.';
    if (kind === 'ready') return granted(offer);
    if (offer.key === 'driver') return 'Pass the theory and driving test at the DMV.';

    return 'Ask the police. An officer grants it after a check.';
  }

  function granted(offer: CardOffer): string {
    const by = offer.grantedBy ? ` by ${offer.grantedBy}` : '';
    const on = offer.grantedAt != null ? ` on ${shortDate(offer.grantedAt)}` : '';

    return by || on ? `Granted${by}${on}.` : 'Granted to you. Buy the card to carry it.';
  }

  function select(offer: CardOffer) {
    selected = offer.key;
    error = null;
    issued = null;
  }

  function showIssued(offer: CardOffer, paidFrom: 'cash' | 'bank') {
    clearTimeout(issuedTimer);
    issued = { name: offer.key === 'id' ? 'ID card' : `${offer.label} card`, price: offer.price, account: paidFrom };
    issuedTimer = setTimeout(() => (issued = null), ISSUED_MS);
  }

  export function dismiss(): boolean {
    if (!selected) return false;

    selected = null;
    error = null;

    return true;
  }

  async function buy() {
    if (!choice || !account || pending) return;

    const bought = choice;
    const paidFrom = account;

    pending = true;

    const reply = await fetchNui('buyCard', { key: choice.key });

    pending = false;

    if (!reply.ok) {
      error = reply.reason ?? 'The card could not be bought';
      return;
    }

    app.cards = normaliseCards(reply.cards) ?? app.cards;
    selected = null;
    showIssued(bought, paidFrom);
  }
</script>

<PanelHeader {onclose} subtitle="Buy your ID card and the cards for licences you hold.">
  {#snippet lead()}
    <div class="flex size-9 shrink-0 items-center justify-center rounded-md bg-secondary">
      <BankIcon size={20} />
    </div>
  {/snippet}
  {#snippet title()}City Hall{/snippet}
</PanelHeader>

<CenterTabs />

<div class="flex flex-col gap-0.5 px-3 py-2">
  {#each groups as group, index (group.kind)}
    <h2 class={['px-3 pb-1 text-xs font-medium text-muted-foreground', index === 0 ? 'pt-2' : 'pt-3']}>{group.label}</h2>
    {#each group.offers as offer (offer.key)}
      {@const active = selected === offer.key}
      {@const locked = group.kind === 'locked'}
      <div
        class={[
          'group flex h-16 shrink-0 items-center gap-3 rounded-md px-3 transition-colors duration-150',
          active ? 'bg-primary text-primary-foreground' : group.kind === 'ready' && 'focus-within:bg-muted hover:bg-muted',
        ]}
      >
        <span
          class={[
            'flex size-10 shrink-0 items-center justify-center rounded-md',
            active ? 'bg-cobalt-hover' : locked ? 'bg-muted text-muted-foreground' : 'bg-secondary',
          ]}
        >
          <LicenceIcon card={offer.key} />
        </span>
        <span class="flex min-w-0 grow flex-col gap-0.5">
          <span class="flex items-center gap-3">
            <span class={['grow truncate text-sm font-medium', locked && 'text-muted-foreground']}>{offer.label}</span>
            {#if group.kind !== 'carried'}
              <span class={['shrink-0 text-13 tabular-nums', locked ? 'text-muted-foreground' : 'font-medium']}>
                {money(offer.price)}
              </span>
            {/if}
          </span>
          <span class={['truncate text-13', active ? 'text-primary-foreground' : 'text-muted-foreground']}>
            {detail(offer, group.kind)}
          </span>
        </span>
        <span class="flex w-18 shrink-0 items-center justify-end gap-1.5">
          {#if group.kind === 'ready' && !active}
            <button
              type="button"
              class="h-8 rounded-md border border-input bg-secondary px-3 text-xs font-medium transition-colors duration-150 group-hover:border-primary group-hover:bg-primary group-focus-within:border-primary group-focus-within:bg-primary"
              onclick={() => select(offer)}
            >
              Buy
            </button>
          {:else if group.kind === 'carried'}
            <CheckCircleIcon size={14} class="text-success" />
            <span class="text-xs font-medium text-muted-foreground">Carried</span>
          {:else if locked && offer.key === 'driver'}
            <GpsButton request={() => fetchNui('gpsPlace', { place: 'dmv' })} label="DMV" done="Set" />
          {:else if locked}
            <LockIcon size={14} class="text-muted-foreground" />
          {/if}
        </span>
      </div>
    {/each}
  {/each}
</div>

{#if choice && account}
  <footer class="flex items-center gap-3 border-t border-border px-5 py-4" in:crossfade>
    <div class="flex min-w-0 grow flex-col">
      <p class="text-sm font-medium">Buy {cardName(choice)} for <span class="tabular-nums">{money(choice.price)}</span>?</p>
      {#if error}
        <p class="text-xs text-destructive" role="alert">{error}</p>
      {:else}
        <p class="text-xs text-muted-foreground tabular-nums">
          {account === 'cash'
            ? `Paid from cash. You have ${money(cards.cash)}.`
            : `Paid from your bank. You have ${money(cards.bank)}.`}
        </p>
      {/if}
    </div>
    <button
      type="button"
      class="h-9 shrink-0 rounded-md border border-input bg-secondary px-4 text-sm font-medium transition-colors hover:bg-input"
      onclick={dismiss}
    >
      Cancel
    </button>
    <button
      type="button"
      class="flex h-9 shrink-0 items-center gap-2 rounded-md bg-primary px-4 text-sm font-medium text-primary-foreground transition-colors hover:bg-cobalt-hover disabled:bg-secondary disabled:text-muted-foreground"
      disabled={pending}
      onclick={buy}
    >
      <ShoppingCartIcon size={16} />
      Buy
    </button>
  </footer>
{:else if choice}
  <footer class="flex items-center gap-3 border-t border-border px-5 py-4" in:crossfade>
    <WarningCircleIcon size={20} class="shrink-0 text-destructive" />
    <div class="flex min-w-0 grow flex-col">
      <p class="text-sm font-medium">Not enough money</p>
      <p class="text-xs text-muted-foreground tabular-nums">
        The card costs {money(choice.price)}. You have {money(cards.cash)} in cash and {money(cards.bank)} in the bank.
      </p>
    </div>
    <button
      type="button"
      class="h-9 shrink-0 rounded-md border border-input bg-secondary px-4 text-sm font-medium transition-colors hover:bg-input"
      onclick={dismiss}
    >
      Back
    </button>
  </footer>
{:else if issued}
  <footer class="flex items-center gap-3 border-t border-border px-5 py-4" role="status" in:crossfade>
    <span class="shrink-0 text-success" in:pop={{ duration: 250 }}><CheckCircleIcon size={36} /></span>
    <div class="flex min-w-0 grow flex-col">
      <p class="text-sm font-medium">{capitalise(issued.name)} issued</p>
      <p class="text-xs text-muted-foreground tabular-nums">
        It is in your inventory. Paid {money(issued.price)} from {issued.account === 'cash' ? 'cash' : 'your bank'}.
      </p>
    </div>
  </footer>
{:else}
  <footer class="flex items-center gap-2 border-t border-border px-5 py-3.5 text-xs text-muted-foreground">
    <BankIcon size={16} class="shrink-0" />
    Lost a card? Buy it again here. Cards are paid from cash first, then your bank.
  </footer>
{/if}

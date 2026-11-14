import { mount } from 'svelte';
import '../app.css';
import Meter from './Meter.svelte';
import OrderCard from './OrderCard.svelte';
import { apply } from './state.svelte';
import type { DuiMessage } from './types';

const ROOT_SIZE = { order: '22px', meter: '20px' } as const;

const mode: 'order' | 'meter' = new URLSearchParams(location.search).get('mode') === 'meter' ? 'meter' : 'order';

function isMessage(value: unknown): value is DuiMessage {
  return typeof value === 'object' && value !== null && 'type' in value;
}

function parse(data: unknown): DuiMessage | undefined {
  try {
    const value: unknown = typeof data === 'string' ? JSON.parse(data) : data;

    return isMessage(value) ? value : undefined;
  } catch {
    return undefined;
  }
}

function fromAddress(): DuiMessage | undefined {
  try {
    const fields: unknown = JSON.parse(decodeURIComponent(location.hash.slice(1)));

    return typeof fields === 'object' && fields !== null ? ({ ...fields, type: mode } as DuiMessage) : undefined;
  } catch {
    return undefined;
  }
}

document.documentElement.style.fontSize = ROOT_SIZE[mode];

const first = fromAddress();

if (first) apply(first);

window.addEventListener('message', (event: MessageEvent<unknown>) => {
  const message = parse(event.data);

  if (message) apply(message);
});

const target = document.getElementById('app');

if (target) mount(mode === 'meter' ? Meter : OrderCard, { target });

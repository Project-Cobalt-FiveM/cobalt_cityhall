import type { DuiMessage, MeterView, OrderView } from './types';

export const order: OrderView = $state({ order: { toasted: false, sauces: {} }, next: false, patience: 1 });

export const meter: MeterView = $state({
  stage: 'sausage',
  hint: '',
  sausage: { value: 0, live: false, text: 'Waiting' },
  bun: { value: 0, live: false, text: 'Plain' },
  sauce: 'mustard',
  added: {},
});

export function apply({ type, ...view }: DuiMessage): void {
  Object.assign(type === 'meter' ? meter : order, view);
}

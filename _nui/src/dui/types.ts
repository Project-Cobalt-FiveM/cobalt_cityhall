export type SauceId = 'mustard' | 'ketchup' | 'mayo' | 'relish' | 'onions';

export type Order = { toasted: boolean; sauces: Partial<Record<SauceId, boolean>> };

export type KitchenStage = 'sausage' | 'bun' | 'assemble' | 'sauce';

export type OrderView = { order: Order; next: boolean; patience: number };

export type CookBar = { value: number; live: boolean; text: string };

export type MeterView = {
  stage: KitchenStage;
  hint: string;
  sausage: CookBar;
  bun: CookBar;
  sauce: SauceId;
  added: Partial<Record<SauceId, boolean>>;
  order?: Order;
};

export type DuiMessage = ({ type: 'order' | 'patience' } & Partial<OrderView>) | ({ type: 'meter' } & Partial<MeterView>);

export const SAUCES: { id: SauceId; label: string }[] = [
  { id: 'mustard', label: 'Mustard' },
  { id: 'ketchup', label: 'Ketchup' },
  { id: 'mayo', label: 'Mayo' },
  { id: 'relish', label: 'Relish' },
  { id: 'onions', label: 'Onions' },
];

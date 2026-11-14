import { list } from './format';
import type {
  AdminView,
  CardsView,
  DmvView,
  DriveHud,
  DriveResult,
  DriveStrike,
  Invite,
  JobCard,
  JobState,
  Messages,
  PayAccount,
  ShiftView,
  View,
} from './types';

export type Screen = { kind: 'list' } | { kind: 'detail'; job: string } | { kind: 'shift' };

export type Tab = 'jobs' | 'licences';

type Store = {
  visible: boolean;
  view: View;
  screen: Screen;
  me: number;
  payAccount: PayAccount;
  catalogue: JobCard[];
  states: JobState[];
  shift: ShiftView | null;
  admin: AdminView | null;
  invite: Invite | null;
  inviteAt: number;
  tab: Tab;
  cards: CardsView | null;
  dmv: DmvView | null;
  result: DriveResult | null;
  drive: DriveHud | null;
  speed: number;
  distance: number;
};

export const app: Store = $state({
  visible: false,
  view: 'center',
  screen: { kind: 'list' },
  me: 0,
  payAccount: 'bank',
  catalogue: [],
  states: [],
  shift: null,
  admin: null,
  invite: null,
  inviteAt: 0,
  tab: 'jobs',
  cards: null,
  dmv: null,
  result: null,
  drive: null,
  speed: 0,
  distance: 0,
});

export function normaliseShift(shift: ShiftView | undefined): ShiftView | null {
  if (!shift) return null;

  return { ...shift, crew: list(shift.crew) };
}

export function normaliseAdmin(admin: AdminView | undefined): AdminView | null {
  if (!admin) return null;

  return { workers: list(admin.workers), jobs: list(admin.jobs) };
}

export function normaliseCards(cards: CardsView | undefined): CardsView | null {
  if (!cards) return null;

  return { ...cards, offers: list(cards.offers) };
}

function strikes(value: DriveStrike[] | Record<string, never>): DriveStrike[] {
  return list(value);
}

export function apply(message: Messages): void {
  switch (message.action) {
    case 'open':
      app.view = message.view;
      app.me = message.me;
      app.payAccount = message.payAccount;
      app.catalogue = list(message.catalogue).map((job) => ({ ...job, payRows: list(job.payRows) }));
      app.states = list(message.states);
      app.shift = normaliseShift(message.shift);
      app.admin = normaliseAdmin(message.admin);
      app.screen = message.view === 'shift' ? { kind: 'shift' } : { kind: 'list' };
      app.cards = normaliseCards(message.cards);
      app.dmv = message.dmv ?? null;
      app.result = message.result ? { ...message.result, strikes: strikes(message.result.strikes) } : null;
      app.tab = 'jobs';
      app.visible = true;
      break;
    case 'close':
      app.visible = false;
      break;
    case 'shift':
      app.shift = normaliseShift(message.shift);
      if (!app.shift && app.screen.kind === 'shift') {
        if (app.view === 'center') app.screen = { kind: 'list' };
        else app.visible = false;
      }
      break;
    case 'invite':
      app.invite = message.invite || null;
      app.inviteAt = Date.now();
      break;
    case 'drive': {
      const drive = message.drive;
      app.drive = drive ? { ...drive, view: { ...drive.view, strikes: strikes(drive.view.strikes) } } : null;
      break;
    }
    case 'driveTick':
      app.speed = message.speed;
      app.distance = message.distance;
      break;
    default: {
      const exhaustive: never = message;
      return exhaustive;
    }
  }
}

export function jobById(id: string): JobCard | undefined {
  return app.catalogue.find((job) => job.id === id);
}

export function isOpen(id: string): boolean {
  return app.states.find((state) => state.id === id)?.open ?? true;
}

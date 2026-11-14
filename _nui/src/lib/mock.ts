import type { MockHandlers } from './nui';
import { app } from './store.svelte';
import type {
  AdminView,
  CardsView,
  DmvView,
  DriveResult,
  JobCard,
  Messages,
  ShiftView,
  TheoryQuestion,
} from './types';

const catalogue: JobCard[] = [
  {
    id: 'taxi',
    label: 'Taxi',
    description: 'Pick up fares around the city and drive them to their stop.',
    icon: 'taxi',
    pay: '$30 per fare + $2 per 100 m',
    site: 'Downtown Cab Co.',
    vehicle: 'cab',
    crewSize: 2,
    payRows: [
      { label: 'Each fare', value: '$30' },
      { label: 'Distance', value: '$2 per 100 m' },
      { label: 'A 3 km fare pays', value: '$90' },
    ],
    doneLabel: 'Fares done',
  },
  {
    id: 'trucking',
    label: 'Trucking',
    description: 'Haul cargo from the dock to drop-offs across the state.',
    icon: 'truck',
    pay: '$50 per drop + $2.50 per 100 m',
    site: 'Cypress Flats Dock',
    vehicle: 'box truck',
    crewSize: 2,
    payRows: [
      { label: 'Each drop', value: '$50' },
      { label: 'Distance', value: '$2.50 per 100 m' },
      { label: 'A 3 km drop pays', value: '$125' },
    ],
    doneLabel: 'Drops done',
  },
  {
    id: 'sanitation',
    label: 'Sanitation',
    description: 'Empty a route of 10 bins with the garbage truck.',
    icon: 'trash',
    pay: '$40 per bin, $200 for a full route',
    site: 'Cypress Flats Sanitation Yard',
    vehicle: 'garbage truck',
    crewSize: 4,
    payRows: [
      { label: 'Each bin', value: '$40' },
      { label: 'Full route of 10 bins', value: '$200' },
    ],
    doneLabel: 'Bins emptied',
  },
  {
    id: 'construction',
    label: 'Construction',
    description: 'Drill, frame and fit out a building site, one task at a time.',
    icon: 'hardHat',
    pay: '$20 per task, $100 when the site is done',
    site: 'Construction Office',
    crewSize: 4,
    payRows: [
      { label: 'Each task', value: '$20' },
      { label: 'Finished site', value: '$100' },
    ],
    doneLabel: 'Tasks done',
  },
  {
    id: 'fishing',
    label: 'Fishing',
    description: 'Fish off Del Perro Pier and sell your catch at the fish market.',
    icon: 'fish',
    pay: 'Fish sells for $12–$35',
    site: 'Fish market',
    crewSize: 4,
    payRows: [{ label: 'Fish', value: '$12–$35 each' }],
    doneLabel: 'Catches',
  },
  {
    id: 'mining',
    label: 'Mining',
    description: 'Break ore at Davis Quarry and sell it to the foreman.',
    icon: 'mountains',
    pay: 'Ore sells for $2–$20',
    site: 'Davis Quarry',
    crewSize: 4,
    payRows: [{ label: 'Ore', value: '$2–$20 each' }],
    doneLabel: 'Ore mined',
  },
  {
    id: 'farming',
    label: 'Farming',
    description: 'Harvest crops at the Grapeseed farm and sell them at the stand.',
    icon: 'plant',
    pay: 'Crops sell for $10–$25',
    site: 'Grapeseed Farm',
    crewSize: 4,
    payRows: [{ label: 'Crops', value: '$10–$25 each' }],
    doneLabel: 'Crops harvested',
  },
  {
    id: 'recycling',
    label: 'Recycling',
    description: 'Sort crates in the recycling warehouse and sell what you find.',
    icon: 'recycle',
    pay: 'Materials sell for $6–$18',
    site: 'Cypress Flats Recycling',
    crewSize: 4,
    payRows: [{ label: 'Materials', value: '$6–$18 each' }],
    doneLabel: 'Crates sorted',
  },
];

const now = Math.floor(Date.now() / 1000);

const shift: ShiftView = {
  job: 'trucking',
  startedAt: now - 2530,
  earned: 860,
  done: 6,
  crew: [
    { id: 1, name: 'Ahmad Saleh', leader: true, earned: 860 },
    { id: 7, name: 'Maya Chen', leader: false, earned: 410 },
  ],
  task: {
    title: 'Next drop: Sandy Shores Yard',
    label: 'Sandy Shores Yard',
    coords: { x: 0, y: 0, z: 0 },
    radius: 8,
    distance: 3200,
  },
};

const admin: AdminView = {
  workers: [
    { id: 1, name: 'Ahmad Saleh', citizenid: 'LKR20311', job: 'trucking', crew: 2, startedAt: now - 2530, earned: 860 },
    { id: 7, name: 'Maya Chen', citizenid: 'QTM84520', job: 'trucking', crew: 2, startedAt: now - 1085, earned: 410 },
    { id: 9, name: 'Leon Park', citizenid: 'BNX10477', job: 'taxi', crew: 1, startedAt: now - 4320, earned: 646 },
    { id: 12, name: 'Rosa Delgado', citizenid: 'PZE55102', job: 'fishing', crew: 1, startedAt: now - 3340, earned: 312 },
  ],
  jobs: catalogue.map((job, index) => ({
    id: job.id,
    open: job.id !== 'sanitation',
    workers: index % 3,
    paidToday: 246 + index * 310,
  })),
};

let cards: CardsView = {
  cash: 1240,
  bank: 90,
  offers: [
    { key: 'id', label: 'ID card', price: 50, held: true, carried: 1 },
    { key: 'driver', label: 'Driver licence', price: 150, held: false, carried: 0 },
    { key: 'weapon', label: 'Weapon licence', price: 500, held: true, carried: 1, grantedAt: 1793181600, grantedBy: 'LSPD' },
  ],
};

function dmv(theoryPassed: boolean, retakeSeconds = 0, cash = 1240): DmvView {
  return {
    cash,
    bank: 90,
    theory: { fee: 250, passMark: 4, questions: 5, passed: theoryPassed },
    practical: {
      fee: retakeSeconds > 0 ? 100 : 0,
      retakeSeconds,
      checkpoints: 10,
      maxStrikes: 3,
      unit: 'mph',
      available: theoryPassed,
      licensed: false,
      active: false,
      cardPrice: 150,
    },
  };
}

const questions: TheoryQuestion[] = [
  {
    question: 'What does a red traffic light mean?',
    answers: ['Speed up to clear the junction', 'Stop and wait for green', 'Slow down and carry on', 'Sound the horn and go'],
  },
  {
    question: 'An ambulance comes up behind you with its siren on. What do you do?',
    answers: ['Keep driving at the same speed', 'Brake hard where you are', 'Pull over to the right and let it pass', 'Race it to the next junction'],
  },
  {
    question: 'Who has priority at a marked pedestrian crossing?',
    answers: ['Pedestrians on the crossing', 'The fastest vehicle', 'Buses and taxis', 'Whoever arrived first'],
  },
  {
    question: 'When must your headlights be on?',
    answers: ['Only on the freeway', 'At night and when it is hard to see', 'Only when it rains', 'Never inside the city'],
  },
  {
    question: 'Can you drive after drinking alcohol?',
    answers: ['Yes, if you feel fine', 'Yes, for short trips', 'No. Never drink and drive', 'Yes, at night when roads are quiet'],
  },
];

const correct = [2, 3, 1, 2, 3];

const passedDrive: DriveResult = {
  passed: true,
  reached: 10,
  total: 10,
  strikes: [{ kind: 'speed', checkpoint: 4, speed: 36, limit: 30 }],
  maxStrikes: 3,
  seconds: 252,
  unit: 'mph',
};

const failedDrive: DriveResult = {
  passed: false,
  reason: 'You reached 3 strikes at checkpoint 6.',
  reached: 5,
  total: 10,
  strikes: [
    { kind: 'speed', checkpoint: 2, speed: 41, limit: 30 },
    { kind: 'crash', checkpoint: 4 },
    { kind: 'speed', checkpoint: 6, speed: 52, limit: 40 },
  ],
  maxStrikes: 3,
  seconds: 198,
  unit: 'mph',
};

function dmvMessage(hash: string): Messages {
  const base = { action: 'open', view: 'dmv', me: 1, payAccount: 'bank', catalogue, states: [] } satisfies Messages;

  if (hash === 'dmv-passed') {
    const view = dmv(true);
    return { ...base, dmv: { ...view, practical: { ...view.practical, licensed: true } }, result: passedDrive };
  }

  if (hash === 'dmv-failed') return { ...base, dmv: dmv(true, 582), result: failedDrive };

  return { ...base, dmv: dmv(hash === 'dmv-brief', 0, hash === 'dmv-broke' ? 120 : 1240) };
}

export function openMessage(hash: string): Messages {
  if (hash.startsWith('dmv')) return dmvMessage(hash);

  const view = hash === 'admin' ? 'admin' : hash === 'shift' ? 'shift' : 'center';
  const hasShift = hash === 'shift' || hash === 'locked';

  return {
    action: 'open',
    view,
    me: 1,
    payAccount: 'bank',
    catalogue,
    states: catalogue.map((job) => ({ id: job.id, open: job.id !== 'sanitation' || hash !== 'locked' })),
    ...(hasShift ? { shift } : {}),
    ...(view === 'admin' ? { admin } : {}),
    ...(view === 'center' ? { cards } : {}),
  };
}

const CHECKPOINT_DELAY_MS = 800;

function driveAt(checkpoint: number, limit: number): Messages {
  return {
    action: 'drive',
    drive: { limit, view: { checkpoint, total: 10, strikes: [], maxStrikes: 3, unit: 'mph' } },
  };
}

export function mockMessages(hash: string): Messages[] {
  if (hash === 'checkpoint') return [driveAt(3, 35), { action: 'driveTick', speed: 32, distance: 40 }];
  if (hash !== 'hud') return [openMessage(hash)];

  return [
    {
      action: 'drive',
      drive: {
        limit: 35,
        view: {
          checkpoint: 4,
          total: 10,
          strikes: [
            { kind: 'speed', checkpoint: 2, speed: 41, limit: 30 },
            { kind: 'speed', checkpoint: 4, speed: 44, limit: 35 },
          ],
          maxStrikes: 3,
          unit: 'mph',
        },
      },
    },
    { action: 'driveTick', speed: 41, distance: 410 },
  ];
}

export function afterOpen(hash: string): void {
  if (hash === 'licences') app.tab = 'licences';

  if (hash === 'checkpoint') {
    setTimeout(() => {
      window.postMessage(driveAt(4, 45), '*');
      window.postMessage({ action: 'driveTick', speed: 34, distance: 310 }, '*');
    }, CHECKPOINT_DELAY_MS);
  }
}

export const handlers: MockHandlers = {
  close: () => ({}),
  signUp: () => ({ ok: true }),
  quit: () => ({}),
  gps: () => ({ ok: true }),
  gpsTask: () => ({ ok: true }),
  respond: () => ({}),
  nearby: () => ({
    players: [
      { id: 9, name: 'Leon Park', distance: 4 },
      { id: 12, name: 'Sofia Reyes', distance: 9 },
    ],
  }),
  invite: () => ({ ok: true }),
  leaveCrew: () => ({}),
  buyCard: ({ key }) => {
    const offer = cards.offers.find((entry) => entry.key === key);
    if (!offer) return { ok: false, reason: 'That card does not exist' };
    if (cards.cash < offer.price && cards.bank < offer.price) return { ok: false, reason: 'Not enough money' };

    const account = cards.cash >= offer.price ? 'cash' : 'bank';
    cards = {
      ...cards,
      [account]: cards[account] - offer.price,
      offers: cards.offers.map((entry) => (entry.key === key ? { ...entry, carried: entry.carried + 1 } : entry)),
    };

    return { ok: true, cards };
  },
  startTheory: () => ({ ok: true, questions }),
  submitTheory: ({ answers }) => {
    const review = answers.map((answer, index) => answer === correct[index]);
    const score = review.filter(Boolean).length;

    return { ok: true, result: { passed: score >= 4, score, total: questions.length, review, dmv: dmv(score >= 4) } };
  },
  startPractical: () => ({ ok: true }),
  gpsPlace: () => ({ ok: true }),
  adminEnd: ({ id }) => ({ admin: { ...admin, workers: admin.workers.filter((worker) => worker.id !== id) } }),
  adminToggle: ({ job, open }) => ({
    admin: { ...admin, jobs: admin.jobs.map((entry) => (entry.id === job ? { ...entry, open } : entry)) },
  }),
};

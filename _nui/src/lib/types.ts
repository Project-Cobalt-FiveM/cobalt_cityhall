export type JobIcon = 'taxi' | 'truck' | 'trash' | 'hardHat' | 'fish' | 'mountains' | 'plant' | 'recycle' | 'hotdog';

export type PayRow = { label: string; value: string };

export type JobCard = {
  id: string;
  label: string;
  description: string;
  icon: JobIcon;
  pay: string;
  site: string;
  vehicle?: string;
  crewSize: number;
  payRows: PayRow[];
  doneLabel: string;
};

export type JobState = { id: string; open: boolean };

export type TaskView = {
  title: string;
  label: string;
  coords: { x: number; y: number; z: number };
  radius: number;
  step?: string;
  stage?: string;
  progress?: { done: number; total: number };
  distance?: number;
};

export type CrewMember = { id: number; name: string; leader: boolean; earned: number };

export type ShiftView = {
  job: string;
  startedAt: number;
  earned: number;
  done: number;
  crew: CrewMember[];
  task?: TaskView;
  vehicle?: number;
};

export type AdminWorker = {
  id: number;
  name: string;
  citizenid: string;
  job: string;
  crew: number;
  startedAt: number;
  earned: number;
};

export type AdminJob = { id: string; open: boolean; workers: number; paidToday: number };

export type AdminView = { workers: AdminWorker[]; jobs: AdminJob[] };

export type NearbyPlayer = { id: number; name: string; distance: number };

export type Invite = {
  from: string;
  job: string;
  crew: number;
  seconds: number;
  acceptKey: string;
  declineKey: string;
};

export type PayAccount = 'bank' | 'cash';

export type View = 'center' | 'shift' | 'admin' | 'dmv';

export type CardOffer = {
  key: string;
  label: string;
  price: number;
  held: boolean;
  carried: number;
  grantedAt?: number;
  grantedBy?: string;
};

export type CardsView = { offers: CardOffer[]; cash: number; bank: number };

export type SpeedUnit = 'mph' | 'kmh';

export type DmvView = {
  theory: { fee: number; passMark: number; questions: number; passed: boolean };
  practical: {
    fee: number;
    retakeSeconds: number;
    checkpoints: number;
    maxStrikes: number;
    unit: SpeedUnit;
    available: boolean;
    licensed: boolean;
    active: boolean;
    cardPrice: number;
  };
  cash: number;
  bank: number;
};

export type DmvNotice = { title?: string; text: string };

export type TheoryQuestion = { question: string; answers: string[] };

export type TheoryResult = { passed: boolean; score: number; total: number; review: boolean[]; dmv: DmvView };

export type DriveStrike =
  | { kind: 'speed'; checkpoint: number; speed: number; limit: number }
  | { kind: 'crash'; checkpoint: number };

export type DriveView = {
  checkpoint: number;
  total: number;
  strikes: DriveStrike[];
  maxStrikes: number;
  unit: SpeedUnit;
  returnSeconds?: number;
};

export type DriveHud = { view: DriveView; limit: number };

export type DriveResult = {
  passed: boolean;
  reason?: string;
  reached: number;
  total: number;
  strikes: DriveStrike[];
  maxStrikes: number;
  seconds: number;
  unit: SpeedUnit;
};

export type Place = 'dmv' | 'cityhall';

export type Messages =
  | {
      action: 'open';
      view: View;
      me: number;
      payAccount: PayAccount;
      catalogue: JobCard[];
      states: JobState[];
      shift?: ShiftView;
      admin?: AdminView;
      cards?: CardsView;
      dmv?: DmvView;
      result?: DriveResult;
    }
  | { action: 'close' }
  | { action: 'shift'; shift?: ShiftView }
  | { action: 'invite'; invite: Invite | false }
  | { action: 'drive'; drive: DriveHud | false }
  | { action: 'driveTick'; speed: number; distance: number };

type Result = { ok: boolean; reason?: string };

export type Requests = {
  close: [void, unknown];
  signUp: [{ job: string }, Result];
  quit: [void, unknown];
  gps: [{ job: string }, Result];
  gpsTask: [void, Result];
  respond: [{ accept: boolean }, unknown];
  nearby: [void, { players: NearbyPlayer[] }];
  invite: [{ id: number }, Result];
  leaveCrew: [void, unknown];
  buyCard: [{ key: string }, Result & { cards?: CardsView }];
  startTheory: [void, Result & { questions?: TheoryQuestion[] }];
  submitTheory: [{ answers: number[] }, Result & { result?: TheoryResult }];
  startPractical: [void, Result];
  gpsPlace: [{ place: Place }, Result];
  adminEnd: [{ id: number }, { admin?: AdminView }];
  adminToggle: [{ job: string; open: boolean }, { admin?: AdminView }];
};

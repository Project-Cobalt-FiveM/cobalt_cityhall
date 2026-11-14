<script lang="ts">
  import CobaltMark from './CobaltMark.svelte';
  import DmvBrief from './DmvBrief.svelte';
  import DmvDriveResult from './DmvDriveResult.svelte';
  import DmvIntro from './DmvIntro.svelte';
  import DmvQuestion from './DmvQuestion.svelte';
  import DmvSteps, { type StepState } from './DmvSteps.svelte';
  import DmvTheoryResult from './DmvTheoryResult.svelte';
  import { list, money } from '../../lib/format';
  import { crossfade } from '../../lib/motion';
  import { fetchNui } from '../../lib/nui';
  import { app } from '../../lib/store.svelte';
  import type { DmvNotice, DmvView, DriveResult, TheoryQuestion, TheoryResult } from '../../lib/types';

  type Screen =
    | { kind: 'intro' }
    | { kind: 'question'; questions: TheoryQuestion[] }
    | { kind: 'theory'; result: TheoryResult; questions: TheoryQuestion[] }
    | { kind: 'brief' }
    | { kind: 'drive'; result: DriveResult };

  let { dmv, result, onclose }: { dmv: DmvView; result: DriveResult | null; onclose: () => void } = $props();

  let screen = $state<Screen>(firstScreen());
  let error = $state<DmvNotice | null>(null);
  let pending = $state(false);
  let wait = $state(0);

  function firstScreen(): Screen {
    if (result) return { kind: 'drive', result };
    if (dmv.theory.passed) return { kind: 'brief' };

    return { kind: 'intro' };
  }

  const steps = $derived.by((): [StepState, StepState, StepState] => {
    switch (screen.kind) {
      case 'intro':
      case 'question':
        return ['current', 'upcoming', 'upcoming'];
      case 'theory':
        return screen.result.passed ? ['done', 'current', 'upcoming'] : ['failed', 'upcoming', 'upcoming'];
      case 'brief':
        return ['done', 'current', 'upcoming'];
      case 'drive':
        return screen.result.passed ? ['done', 'done', 'done'] : ['done', 'failed', 'upcoming'];
    }
  });

  $effect(() => {
    wait = dmv.practical.retakeSeconds;

    if (wait <= 0) return;

    const timer = setInterval(() => {
      wait = Math.max(0, wait - 1);
      if (wait === 0) clearInterval(timer);
    }, 1000);

    return () => clearInterval(timer);
  });

  function show(next: Screen) {
    screen = next;
    error = null;
  }

  async function run<T>(request: () => Promise<T & { ok: boolean; reason?: string }>, done: (reply: T) => void) {
    if (pending) return;

    pending = true;
    error = null;

    const reply = await request();

    pending = false;

    if (reply.ok) done(reply);
    else error = { text: reply.reason ?? 'Something went wrong. Try again.' };
  }

  function shortfall(fee: number): DmvNotice | null {
    if (fee <= 0 || dmv.cash >= fee || dmv.bank >= fee) return null;

    return {
      title: 'Not enough money',
      text: `The test costs ${money(fee)}. You have ${money(dmv.cash)} in cash and ${money(dmv.bank)} in the bank.`,
    };
  }

  function startTheory() {
    error = shortfall(dmv.theory.fee);

    if (error) return;

    void run(
      () => fetchNui('startTheory'),
      (reply) => {
        const questions = list(reply.questions).map((entry) => ({ ...entry, answers: list(entry.answers) }));

        show({ kind: 'question', questions });
      },
    );
  }

  function finishTheory(questions: TheoryQuestion[], answers: number[]) {
    void run(
      () => fetchNui('submitTheory', { answers }),
      (reply) => {
        if (!reply.result) return;

        app.dmv = reply.result.dmv;
        show({ kind: 'theory', result: { ...reply.result, review: list(reply.result.review) }, questions });
      },
    );
  }

  function startPractical() {
    error = shortfall(dmv.practical.fee);

    if (error) return;

    void run(
      () => fetchNui('startPractical'),
      () => (app.visible = false),
    );
  }
</script>

<div class="flex w-160 flex-col overflow-clip rounded-lg border border-border bg-card">
  <header class="flex items-center gap-3.5 px-6 pt-6 pb-5">
    <CobaltMark />
    <div class="flex grow flex-col gap-0.5">
      <h1 class="text-xl font-semibold tracking-tight">Los Santos DMV</h1>
      <p class="text-13 text-muted-foreground">Driver licence test</p>
    </div>
    <button
      type="button"
      class="flex shrink-0 items-center gap-1.5 rounded-md text-xs text-muted-foreground transition-colors hover:text-foreground"
      onclick={onclose}
    >
      <span class="kbd font-medium">Esc</span>
      Close
    </button>
  </header>

  <DmvSteps states={steps} />

  {#key screen}
    <div class="flex flex-col" in:crossfade>
      {#if screen.kind === 'intro'}
        <DmvIntro {dmv} {error} {pending} onstart={startTheory} {onclose} />
      {:else if screen.kind === 'question'}
        {@const questions = screen.questions}
        <DmvQuestion
          {questions}
          passMark={dmv.theory.passMark}
          {error}
          {pending}
          onfinish={(answers) => finishTheory(questions, answers)}
        />
      {:else if screen.kind === 'theory'}
        <DmvTheoryResult
          result={screen.result}
          questions={screen.questions}
          {error}
          {pending}
          onpractical={() => show({ kind: 'brief' })}
          onretake={startTheory}
          {onclose}
        />
      {:else if screen.kind === 'brief'}
        <DmvBrief {dmv} {wait} {error} {pending} onstart={startPractical} />
      {:else}
        <DmvDriveResult result={screen.result} {dmv} {wait} {error} {pending} onretake={startPractical} {onclose} />
      {/if}
    </div>
  {/key}
</div>

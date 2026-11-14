<script lang="ts">
  import ArrowRightIcon from 'phosphor-svelte/lib/ArrowRightIcon';
  import CheckCircleIcon from 'phosphor-svelte/lib/CheckCircleIcon';
  import DmvError from './DmvError.svelte';
  import { crossfade } from '../../lib/motion';
  import type { DmvNotice, TheoryQuestion } from '../../lib/types';

  let {
    questions,
    passMark,
    error,
    pending,
    onfinish,
  }: {
    questions: TheoryQuestion[];
    passMark: number;
    error: DmvNotice | null;
    pending: boolean;
    onfinish: (answers: number[]) => void;
  } = $props();

  const LETTERS = ['A', 'B', 'C', 'D', 'E', 'F'];

  let index = $state(0);
  let answers = $state<(number | null)[]>([]);

  const question = $derived(questions[index]);
  const picked = $derived(answers[index] ?? null);
  const last = $derived(index === questions.length - 1);

  function pick(choice: number) {
    answers[index] = choice;
  }

  function next() {
    if (picked === null || pending) return;

    if (!last) {
      index += 1;
      return;
    }

    const chosen = answers.filter((answer): answer is number => answer !== null);

    if (chosen.length === questions.length) onfinish(chosen.map((answer) => answer + 1));
  }

  function onkeydown(event: KeyboardEvent) {
    const letter = LETTERS.indexOf(event.key.toUpperCase());

    if (question && letter >= 0 && letter < question.answers.length) {
      event.preventDefault();
      pick(letter);
    } else if (event.key === 'Enter') {
      event.preventDefault();
      next();
    }
  }
</script>

<svelte:window {onkeydown} />

<div class="flex flex-col gap-5 p-6">
  <div class="flex flex-col gap-2">
    <div class="flex items-center justify-between">
      <span class="text-sm font-medium tabular-nums">Question {index + 1} of {questions.length}</span>
      <span class="text-xs text-muted-foreground tabular-nums">{passMark} right to pass</span>
    </div>
    <div class="flex gap-1">
      {#each questions as entry, position (entry.question)}
        <span
          class={[
            'h-1.5 grow rounded-[3px] transition-colors duration-200',
            position <= index ? 'bg-primary' : 'bg-secondary',
          ]}
        ></span>
      {/each}
    </div>
  </div>
  {#if question}
    {#key index}
      <div class="flex flex-col gap-5" in:crossfade>
        <h2 class="text-xl font-semibold tracking-tight">{question.question}</h2>
        <div class="flex flex-col gap-2" role="radiogroup" aria-label={question.question}>
          {#each question.answers as answer, choice (answer)}
            {@const chosen = picked === choice}
            <button
              type="button"
              role="radio"
              aria-checked={chosen}
              class={[
                'group flex h-13 shrink-0 items-center gap-3 rounded-lg border px-4 text-left transition-colors duration-150',
                chosen ? 'border-primary bg-primary' : 'border-border hover:bg-muted',
              ]}
              onclick={() => pick(choice)}
            >
              <span
                class={[
                  'flex size-6 shrink-0 items-center justify-center rounded-sm text-xs font-medium',
                  chosen
                    ? 'bg-cobalt-hover'
                    : 'border border-input bg-muted text-muted-foreground group-hover:bg-secondary group-hover:text-foreground',
                ]}
              >
                {LETTERS[choice]}
              </span>
              <span class="grow text-sm font-medium tabular-nums">{answer}</span>
              {#if chosen}
                <CheckCircleIcon size={16} class="shrink-0" />
              {/if}
            </button>
          {/each}
        </div>
      </div>
    {/key}
  {/if}
</div>

<footer class="flex items-center gap-3 border-t border-border px-6 py-4">
  {#if error}
    <DmvError notice={error} />
  {:else}
    <p class="grow text-xs text-muted-foreground">Press A to D or click an answer. You can change it until you press Next.</p>
  {/if}
  <button type="button" class="button button-primary" disabled={picked === null || pending} onclick={next}>
    {last ? 'Finish test' : 'Next question'}
    <ArrowRightIcon size={16} />
  </button>
</footer>

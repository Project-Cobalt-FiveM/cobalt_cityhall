<script lang="ts">
  type Piece = {
    left: number;
    width: number;
    height: number;
    round: boolean;
    colour: string;
    delay: number;
    duration: number;
    drift: number;
    spin: number;
  };

  const COLOURS = ['#5078d7', '#7c9be4', '#22c55e', '#fafafa', '#eab308', '#ef4444'];
  const COUNT = 90;
  const SIZES: [number, number][] = [
    [10, 4],
    [8, 8],
    [12, 5],
    [6, 12],
    [9, 9],
  ];

  const reduced = typeof matchMedia === 'function' && matchMedia('(prefers-reduced-motion: reduce)').matches;

  function between(min: number, max: number): number {
    return min + Math.random() * (max - min);
  }

  function pick<T>(items: readonly T[]): T {
    return items[Math.floor(Math.random() * items.length)] as T;
  }

  function piece(): Piece {
    const [width, height] = pick(SIZES);

    return {
      left: between(20, 80),
      width,
      height,
      round: width === height && Math.random() < 0.5,
      colour: pick(COLOURS),
      delay: between(0, 400),
      duration: between(1800, 2800),
      drift: between(-160, 160),
      spin: between(-540, 540),
    };
  }

  const pieces: Piece[] = reduced ? [] : Array.from({ length: COUNT }, piece);

  function portal(node: HTMLElement) {
    document.body.appendChild(node);

    return { destroy: () => node.remove() };
  }
</script>

<div class="pointer-events-none fixed inset-0 overflow-hidden" aria-hidden="true" use:portal>
  {#each pieces as entry, index (index)}
    <span
      class="confetti"
      style:left="{entry.left}%"
      style:width="{entry.width}px"
      style:height="{entry.height}px"
      style:border-radius={entry.round ? '50%' : '1px'}
      style:background-color={entry.colour}
      style:animation-delay="{entry.delay}ms"
      style:animation-duration="{entry.duration}ms"
      style:--drift="{entry.drift}px"
      style:--spin="{entry.spin}deg"
    ></span>
  {/each}
</div>

<style>
  .confetti {
    position: absolute;
    top: 0;
    opacity: 0;
    animation-name: fall;
    animation-timing-function: cubic-bezier(0.3, 0.4, 0.6, 1);
    animation-fill-mode: both;
  }

  @keyframes fall {
    0% {
      opacity: 1;
      transform: translate3d(0, -4vh, 0) rotate(0deg);
    }

    80% {
      opacity: 1;
    }

    100% {
      opacity: 0;
      transform: translate3d(var(--drift), 104vh, 0) rotate(var(--spin));
    }
  }
</style>

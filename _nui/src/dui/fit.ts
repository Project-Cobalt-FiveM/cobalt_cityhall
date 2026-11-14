import type { Action } from 'svelte/action';

export const fit: Action<HTMLElement, number | undefined> = (node, margin = 8) => {
  const update = () => {
    node.style.transform = 'none';

    const { width, height } = node.getBoundingClientRect();
    const scale = Math.min(1, (window.innerWidth - margin * 2) / width, (window.innerHeight - margin * 2) / height);

    node.style.transform = `scale(${scale})`;
  };

  const observer = new ResizeObserver(update);

  observer.observe(node);
  window.addEventListener('resize', update);
  update();

  return {
    destroy() {
      observer.disconnect();
      window.removeEventListener('resize', update);
    },
  };
};

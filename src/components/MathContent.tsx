'use client';

import katex from 'katex';
import 'katex/dist/katex.min.css';

type MathContentProps = {
  html?: string | null;
  className?: string;
};

function renderMath(html: string) {
  const render = (expression: string, displayMode: boolean) => {
    try {
      return katex.renderToString(expression.trim(), {
        displayMode,
        throwOnError: false,
        trust: false,
        strict: 'ignore',
      });
    } catch {
      return expression;
    }
  };

  return html
    .replace(/\\\[([\s\S]*?)\\\]/g, (_, expression) => render(expression, true))
    .replace(/\\\(([\s\S]*?)\\\)/g, (_, expression) => render(expression, false))
    .replace(/\$\$([\s\S]*?)\$\$/g, (_, expression) => render(expression, true))
    .replace(/\$([^$\n]+?)\$/g, (_, expression) => render(expression, false));
}

export default function MathContent({ html, className }: MathContentProps) {
  if (!html) return null;
  return <div className={className} dangerouslySetInnerHTML={{ __html: renderMath(html) }} />;
}

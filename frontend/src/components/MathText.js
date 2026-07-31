import React from "react";
import { InlineMath, BlockMath } from "react-katex";
import "katex/dist/katex.min.css";

/**
 * Render text that may contain HTML (from Tiptap) and LaTeX ($...$ inline, $$...$$ block).
 * If value starts with an HTML tag, we render it as HTML and walk text-node LaTeX inline.
 * Otherwise plain text with regex-based LaTeX substitution.
 */
export default function MathText({ text = "", className = "" }) {
  if (!text) return null;
  const isHtml = /^\s*</.test(text);
  if (isHtml) {
    // Render HTML directly. LaTeX inside HTML text is left as-is (rare from Tiptap).
    return <span className={className} dangerouslySetInnerHTML={{ __html: text }} />;
  }

  const nodes = [];
  const regex = /\$\$([\s\S]+?)\$\$|\$([^$\n]+?)\$/g;
  let last = 0;
  let match;
  let key = 0;
  while ((match = regex.exec(text)) !== null) {
    if (match.index > last) nodes.push(<span key={key++}>{text.slice(last, match.index)}</span>);
    if (match[1] != null) {
      try { nodes.push(<BlockMath key={key++} math={match[1]} />); }
      catch { nodes.push(<span key={key++}>{match[0]}</span>); }
    } else if (match[2] != null) {
      try { nodes.push(<InlineMath key={key++} math={match[2]} />); }
      catch { nodes.push(<span key={key++}>{match[0]}</span>); }
    }
    last = match.index + match[0].length;
  }
  if (last < text.length) nodes.push(<span key={key++}>{text.slice(last)}</span>);
  return <span className={className}>{nodes}</span>;
}

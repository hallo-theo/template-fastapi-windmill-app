// Windmill raw_app entry point.
//
// `wmill app push` looks for `index.tsx` at the raw_app root and uses it as
// the bundle entry. Vite's local dev uses `src/main.tsx` via the <script>
// tag in index.html. Both files coexist — different runtimes call different
// entry points.
//
// This file creates its own #root div because Windmill's host page doesn't
// provide one. Local dev gets #root from index.html.
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './src/App';

const root = document.createElement('div');
root.id = 'root';
document.body.appendChild(root);

createRoot(root).render(
  <StrictMode>
    <App />
  </StrictMode>
);

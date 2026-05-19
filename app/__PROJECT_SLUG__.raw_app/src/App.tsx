import { useEffect, useState } from 'react';
import { backend, type WmUser } from '../wmill';

export default function App() {
  const [me, setMe] = useState<WmUser | null>(null);

  useEffect(() => {
    let cancelled = false;
    backend.whoami()
      .then(u => { if (!cancelled) setMe(u); })
      .catch(err => console.error('whoami error:', err));
    return () => { cancelled = true; };
  }, []);

  return (
    <main style={{ fontFamily: 'system-ui, sans-serif', padding: '40px 48px' }}>
      <h1>__PROJECT_TITLE__</h1>
      <p>Logged in as: <strong>{me ? (me.username || '—') : 'loading…'}</strong></p>
      <p>Replace this scaffold with your app's UI.</p>
    </main>
  );
}

import { useState } from 'react';
import { useAuth0 } from '@auth0/auth0-react';

export default function App() {
  const { loginWithRedirect, logout, isAuthenticated, isLoading, error, user, getAccessTokenSilently } =
    useAuth0();
  const [result, setResult] = useState('');

  async function callApi() {
    try {
      const token = await getAccessTokenSilently();
      const response = await fetch(`${import.meta.env.VITE_API_URL}/api/risk-status`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      const body = await response.text();
      if (!response.ok) {
        throw new Error(`API returned ${response.status}${body ? `: ${body}` : ''}`);
      }
      setResult(JSON.stringify(JSON.parse(body), null, 2));
    } catch (err) {
      setResult(`Request failed: ${err.message}`);
    }
  }

  if (isLoading) return <main className="card"><p>Loading…</p></main>;

  if (error) {
    return (
      <main className="card">
        <h1>Enterprise Risk Lab</h1>
        <p className="error">Authentication error: {error.message}</p>
        <button onClick={() => loginWithRedirect()}>Try again</button>
      </main>
    );
  }

  if (!isAuthenticated) {
    return (
      <main className="card">
        <h1>Enterprise Risk Lab</h1>
        <p>Sign in with Auth0 to call the protected API.</p>
        <button onClick={() => loginWithRedirect()}>Log in</button>
      </main>
    );
  }

  return (
    <main className="card">
      <h1>Enterprise Risk Lab</h1>
      <p>Signed in as <strong>{user.name}</strong></p>
      <div className="actions">
        <button onClick={callApi}>Call protected API</button>
        <button
          className="secondary"
          onClick={() => logout({ logoutParams: { returnTo: window.location.origin } })}
        >
          Log out
        </button>
      </div>
      <pre>{result}</pre>
    </main>
  );
}

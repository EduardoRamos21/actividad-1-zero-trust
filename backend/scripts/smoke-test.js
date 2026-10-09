/**
 * Comprueba login, JWT, dashboard protegido y encabezados de Helmet.
 * Uso: npm test
 */
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'smoke-test-secret-that-is-long-enough-32';
process.env.CORS_ORIGIN = 'http://localhost:5173';

const assert = require('assert');
const app = require('../src/app');

function waitListening(server) {
  return new Promise((resolve, reject) => {
    server.once('listening', resolve);
    server.once('error', reject);
  });
}

async function call(base, path, options = {}) {
  const response = await fetch(`${base}${path}`, options);
  const text = await response.text();
  let body = text;
  try {
    body = JSON.parse(text);
  } catch {
    body = text;
  }
  return { status: response.status, headers: response.headers, body };
}

async function main() {
  const server = app.listen(0, '127.0.0.1');
  if (!server.listening) {
    await waitListening(server);
  }
  const { port } = server.address();
  const base = `http://127.0.0.1:${port}`;

  try {
    const health = await call(base, '/api/health');
    assert.strictEqual(health.status, 200);
    for (const header of [
      'content-security-policy',
      'strict-transport-security',
      'x-frame-options',
      'x-content-type-options',
      'referrer-policy',
      'permissions-policy',
    ]) {
      assert.ok(health.headers.get(header), `falta el encabezado ${header}`);
    }

    const denied = await call(base, '/api/dashboard');
    assert.strictEqual(denied.status, 401);

    const badLogin = await call(base, '/api/auth/login', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Forwarded-For': '203.0.113.10',
      },
      body: JSON.stringify({ username: 'admin', password: 'incorrecta' }),
    });
    assert.strictEqual(badLogin.status, 401);

    const login = await call(base, '/api/auth/login', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Forwarded-For': '203.0.113.11',
      },
      body: JSON.stringify({ username: 'admin', password: 'Admin123!' }),
    });
    assert.strictEqual(login.status, 200);
    const token = login.body.data.token;
    assert.ok(token);

    const dashboard = await call(base, '/api/dashboard', {
      headers: { Authorization: `Bearer ${token}` },
    });
    assert.strictEqual(dashboard.status, 200);
    assert.strictEqual(dashboard.body.data.securityStatus.jwtValidated, true);

    const forged = await call(base, '/api/dashboard', {
      headers: { Authorization: 'Bearer esto.no.es.un.jwt' },
    });
    assert.strictEqual(forged.status, 403);

    console.log('smoke-test ok');
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

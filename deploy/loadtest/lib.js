// Shared helpers for the k6 load tests.
import http from 'k6/http';
import { check, fail } from 'k6';

export const BASE_URL = (__ENV.BASE_URL || 'http://host.docker.internal:18080').replace(/\/$/, '');
export const API = `${BASE_URL}/api/v1`;

/** GET an API path and check the `{ code: 0 }` envelope. `name` groups URLs with ids in the summary. */
export function get(path, { token, name, params } = {}) {
  const res = http.get(`${API}${path}`, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    tags: { name: name || path },
    ...params,
  });
  checkOk(res, name || path);
  return res;
}

export function send(method, path, body, { token, name } = {}) {
  const res = http.request(method, `${API}${path}`, JSON.stringify(body), {
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    tags: { name: name || path },
  });
  checkOk(res, name || path);
  return res;
}

function checkOk(res, name) {
  check(res, {
    [`${name}: 2xx`]: r => r.status >= 200 && r.status < 300,
    [`${name}: code 0`]: r => r.status === 204 || safeJson(r)?.code === 0,
  });
}

export function safeJson(res) {
  try {
    return res.json();
  }
  catch {
    return null;
  }
}

export function data(res) {
  return safeJson(res)?.data;
}

/** Logs in once (the credential endpoints allow 5 requests a minute). */
export function login() {
  const login = __ENV.LOGIN || 'lighthouse01';
  const password = __ENV.PASSWORD || 'readerpass123';
  const res = http.post(`${API}/auth/login`, JSON.stringify({ login, password }), {
    headers: { 'Content-Type': 'application/json' },
  });
  const token = data(res)?.access_token;
  if (!token) fail(`login as ${login} failed: ${res.status} ${res.body}`);
  return token;
}

/** Published novels and their chapter ids, gathered once in setup(). */
export function catalogue() {
  const novels = data(get('/novels?page_size=50', { name: '/novels' }))?.items || [];
  if (!novels.length) fail('no published novels; run the seed first');
  return novels.map((n) => {
    const chapters = data(get(`/novels/${n.id}/chapters`, { name: '/novels/:id/chapters' })) || [];
    return { id: n.id, title: n.title, chapters: chapters.map(c => c.id) };
  }).filter(n => n.chapters.length);
}

export function pick(list) {
  return list[Math.floor(Math.random() * list.length)];
}

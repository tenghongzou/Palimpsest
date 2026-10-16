// Signed-in readers: bookshelf, progress sync, recommendations, notifications.
//
//   docker run --rm -i -v "$PWD/deploy/loadtest:/scripts" grafana/k6:1.3.0 run /scripts/reader.js
//
// Env: BASE_URL, LOGIN / PASSWORD (default the seed reader lighthouse01),
// VUS (default 30), DURATION (default 1m). Every virtual user shares the
// one account, so this measures the endpoints, not per-user data volume.
import { sleep } from 'k6';
import { catalogue, get, login, pick, send } from './lib.js';

const VUS = Number(__ENV.VUS || 30);

export const options = {
  scenarios: {
    reader: {
      executor: 'ramping-vus',
      stages: [
        { duration: '20s', target: VUS },
        { duration: __ENV.DURATION || '1m', target: VUS },
        { duration: '10s', target: 0 },
      ],
    },
  },
  thresholds: {
    'http_req_failed': ['rate<0.01'],
    'http_req_duration': ['p(95)<300'],
    'http_req_duration{name:PUT /reading-progress/:id}': ['p(95)<250'],
    'checks': ['rate>0.99'],
  },
};

export function setup() {
  return { token: login(), novels: catalogue() };
}

export default function ({ token, novels }) {
  get('/bookshelf', { token });
  get('/notifications/unread-count', { token });
  get('/recommendations', { token, name: '/recommendations (signed in)' });
  sleep(Math.random() * 2);

  const novel = pick(novels);
  const chapter = pick(novel.chapters);
  get(`/chapters/${chapter}?count_view=false`, { token, name: '/chapters/:id' });
  get(`/reading-progress/${novel.id}`, { token, name: '/reading-progress/:id' });
  sleep(1 + Math.random() * 2);
  send('PUT', `/reading-progress/${novel.id}`, {
    chapter_id: chapter,
    paragraph_index: Math.floor(Math.random() * 5),
    scroll_offset: Math.random(),
    duration: 30,
  }, { token, name: 'PUT /reading-progress/:id' });

  get('/users/me/reading-stats?period=daily&utc_offset=480', { token, name: '/users/me/reading-stats' });
  sleep(Math.random() * 3);
}

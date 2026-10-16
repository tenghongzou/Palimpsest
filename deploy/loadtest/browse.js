// Anonymous readers browsing the bookstore and reading chapters.
//
//   docker run --rm -i -v "$PWD/deploy/loadtest:/scripts" grafana/k6:1.3.0 run /scripts/browse.js
//
// Env: BASE_URL (default http://host.docker.internal:18080), VUS (peak, default 50),
// DURATION (steady phase, default 1m). The API's rate limits must be off
// (RATE_LIMIT_ENABLED=false), or every virtual user shares one IP's quota.
import { sleep } from 'k6';
import { catalogue, get, pick } from './lib.js';

const VUS = Number(__ENV.VUS || 50);

export const options = {
  scenarios: {
    browse: {
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
    'http_req_duration{name:/home}': ['p(95)<200'],
    'http_req_duration{name:/chapters/:id}': ['p(95)<200'],
    'checks': ['rate>0.99'],
  },
};

export function setup() {
  return { novels: catalogue() };
}

export default function ({ novels }) {
  get('/home');
  sleep(Math.random() * 2);

  const novel = pick(novels);
  get(`/novels/${novel.id}`, { name: '/novels/:id' });
  get(`/novels/${novel.id}/chapters?order=asc`, { name: '/novels/:id/chapters' });
  get(`/novels/${novel.id}/similar`, { name: '/novels/:id/similar' });
  get(`/novels/${novel.id}/reviews`, { name: '/novels/:id/reviews' });
  sleep(Math.random() * 2);

  // Read a few chapters in order, as a reader would.
  const start = Math.floor(Math.random() * novel.chapters.length);
  for (const id of novel.chapters.slice(start, start + 3)) {
    // count_view=false keeps load tests out of the view rankings.
    get(`/chapters/${id}?count_view=false`, { name: '/chapters/:id' });
    get(`/chapters/${id}/comments/paragraph-counts`, { name: '/chapters/:id/paragraph-counts' });
    sleep(1 + Math.random() * 3);
  }

  get(`/rankings/${pick(['views', 'favorites', 'rating', 'latest'])}`, { name: '/rankings/:type' });
  get('/recommendations');
  get('/categories');
  sleep(Math.random() * 2);
}

// Ramps the request rate on the hottest public endpoints until latency or
// errors break the thresholds, to find the API's capacity.
//
//   docker run --rm -i -v "$PWD/deploy/loadtest:/scripts" grafana/k6:1.3.0 run /scripts/stress.js
//
// Env: BASE_URL, PEAK_RPS (default 1000), STAGE (length of each step, default 30s).
import { catalogue, get, pick } from './lib.js';

const PEAK = Number(__ENV.PEAK_RPS || 1000);
const STAGE = __ENV.STAGE || '30s';

export const options = {
  scenarios: {
    stress: {
      executor: 'ramping-arrival-rate',
      startRate: Math.round(PEAK / 10),
      timeUnit: '1s',
      preAllocatedVUs: 100,
      maxVUs: 1000,
      stages: [
        { duration: STAGE, target: Math.round(PEAK / 4) },
        { duration: STAGE, target: Math.round(PEAK / 2) },
        { duration: STAGE, target: PEAK },
        { duration: STAGE, target: PEAK },
      ],
    },
  },
  thresholds: {
    'http_req_failed': ['rate<0.01'],
    'http_req_duration': ['p(95)<300', 'p(99)<1000'],
    'dropped_iterations': ['count<100'],
  },
};

export function setup() {
  return { novels: catalogue() };
}

// One request per iteration, weighted towards what readers hit most.
export default function ({ novels }) {
  const r = Math.random();
  const novel = pick(novels);
  if (r < 0.4) get(`/chapters/${pick(novel.chapters)}?count_view=false`, { name: '/chapters/:id' });
  else if (r < 0.6) get('/home');
  else if (r < 0.75) get(`/novels/${novel.id}`, { name: '/novels/:id' });
  else if (r < 0.85) get(`/novels/${novel.id}/chapters?order=asc`, { name: '/novels/:id/chapters' });
  else if (r < 0.92) get('/recommendations');
  else get(`/rankings/${pick(['views', 'favorites', 'rating', 'latest'])}`, { name: '/rankings/:type' });
}

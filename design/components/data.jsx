// Sample data — plausible fictional repos & workflows
const SAMPLE_RUNS = [
  { id: 1, repo: 'mattnz/orbital-cms', wf: 'CI', title: 'Strip trailing whitespace in markdown frontmatter', branch: 'main', event: 'push', status: 'running', conclusion: null, run: 1842, started: '— 2m 14s ago', actor: 'mattnz', actorHue: 80, durLive: '2m 14s' },
  { id: 2, repo: 'mattnz/orbital-cms', wf: 'Deploy · staging', title: 'Strip trailing whitespace in markdown frontmatter', branch: 'main', event: 'push', status: 'queued', conclusion: null, run: 1842, started: '— queued', actor: 'mattnz', actorHue: 80 },
  { id: 3, repo: 'kintsugi-labs/spindle', wf: 'Release', title: 'v3.4.0 — segmenter perf, fix split-on-emoji', branch: 'release/3.4', event: 'workflow_dispatch', status: 'completed', conclusion: 'failure', run: 412, started: '14m ago', dur: '5m 48s', actor: 'rinapeters', actorHue: 25 },
  { id: 4, repo: 'kintsugi-labs/spindle', wf: 'CI', title: 'feat(parser): lookahead for compound tokens', branch: 'rina/parser-lookahead', event: 'pull_request', status: 'completed', conclusion: 'success', run: 1109, started: '22m ago', dur: '3m 12s', actor: 'rinapeters', actorHue: 25 },
  { id: 5, repo: 'mattnz/dotfiles', wf: 'Lint', title: 'chore: bump fish to 4.2', branch: 'main', event: 'push', status: 'completed', conclusion: 'success', run: 87, started: '38m ago', dur: '0m 41s', actor: 'mattnz', actorHue: 80 },
  { id: 6, repo: 'foundry-co/relay', wf: 'CI', title: 'Reduce p99 latency on /v2/dispatch', branch: 'perf/dispatch-p99', event: 'pull_request', status: 'completed', conclusion: 'success', run: 9438, started: '1h ago', dur: '8m 03s', actor: 'jpark', actorHue: 200 },
  { id: 7, repo: 'foundry-co/relay', wf: 'Nightly · integration', title: 'scheduled · 02:00 UTC', branch: 'main', event: 'schedule', status: 'completed', conclusion: 'failure', run: 612, started: '3h ago', dur: '14m 22s', actor: 'foundry-bot', actorHue: 150 },
  { id: 8, repo: 'foundry-co/relay-edge', wf: 'CI', title: 'Drop libpcap dep on macOS arm64', branch: 'main', event: 'push', status: 'completed', conclusion: 'success', run: 2201, started: '4h ago', dur: '2m 55s', actor: 'jpark', actorHue: 200 },
  { id: 9, repo: 'mattnz/almanac', wf: 'Build site', title: 'Add 2026 lunar calendar overlay', branch: 'feat/lunar-2026', event: 'pull_request', status: 'completed', conclusion: 'success', run: 304, started: '6h ago', dur: '1m 09s', actor: 'mattnz', actorHue: 80 },
  { id: 10, repo: 'kintsugi-labs/spindle-rs', wf: 'CI', title: 'Bump regex to 1.11; drop once_cell', branch: 'main', event: 'push', status: 'completed', conclusion: 'success', run: 558, started: '8h ago', dur: '4m 37s', actor: 'rinapeters', actorHue: 25 },
  { id: 11, repo: 'foundry-co/dashboard', wf: 'Preview deploy', title: 'Onboarding rev 4 · empty states', branch: 'eli/onboarding-rev4', event: 'pull_request', status: 'completed', conclusion: 'cancelled', run: 1773, started: '10h ago', dur: '0m 32s', actor: 'eliboard', actorHue: 320 },
  { id: 12, repo: 'foundry-co/dashboard', wf: 'CI', title: 'Onboarding rev 4 · empty states', branch: 'eli/onboarding-rev4', event: 'pull_request', status: 'completed', conclusion: 'success', run: 1772, started: '10h ago', dur: '6m 18s', actor: 'eliboard', actorHue: 320 },
  { id: 13, repo: 'mattnz/sprocket', wf: 'CI', title: 'WIP: device flow polling backoff', branch: 'auth/device-flow', event: 'push', status: 'completed', conclusion: 'action_required', run: 12, started: '12h ago', dur: '0m 22s', actor: 'mattnz', actorHue: 80 },
  { id: 14, repo: 'kintsugi-labs/atlas', wf: 'Docs', title: 'Rewrite tokenizer chapter for v3', branch: 'docs/tokenizer-v3', event: 'pull_request', status: 'completed', conclusion: 'success', run: 88, started: '14h ago', dur: '0m 58s', actor: 'rinapeters', actorHue: 25 },
  { id: 15, repo: 'foundry-co/relay', wf: 'CodeQL', title: 'security scan · weekly', branch: 'main', event: 'schedule', status: 'completed', conclusion: 'success', run: 41, started: '1d ago', dur: '11m 02s', actor: 'foundry-bot', actorHue: 150 },
];

const ORG_LIST = [
  { id: 'all', label: 'All', count: 47 },
  { id: 'personal', label: 'Personal · @mattnz', count: 12 },
  { id: 'kintsugi', label: 'kintsugi-labs', count: 14 },
  { id: 'foundry', label: 'foundry-co', count: 21 },
];

window.SAMPLE_RUNS = SAMPLE_RUNS;
window.ORG_LIST = ORG_LIST;

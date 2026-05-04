// Sprocket icon set + menu bar glyphs
// All SVGs original, geometric only — no branded marks.

// ── Brand mark: a simple 8-tooth gear with a center dot ──
function SprocketMark({ size = 16, color = 'currentColor' }) {
  // 8 trapezoidal teeth around an annulus. Drawn in path so it's crisp at small sizes.
  const teeth = 8;
  const outer = 14;
  const inner = 10.5;
  const toothW = 2.4; // half-width
  const cx = 16, cy = 16;
  const pts = [];
  for (let i = 0; i < teeth; i++) {
    const a = (i / teeth) * Math.PI * 2;
    const next = ((i + 1) / teeth) * Math.PI * 2;
    const half = (next - a) / 2;
    // tooth base on inner ring
    const a0 = a + half - 0.18;
    const a1 = a + half + 0.18;
    // tooth tip on outer ring
    const a0o = a + half - 0.12;
    const a1o = a + half + 0.12;
    pts.push([cx + Math.cos(a0) * inner, cy + Math.sin(a0) * inner]);
    pts.push([cx + Math.cos(a0o) * outer, cy + Math.sin(a0o) * outer]);
    pts.push([cx + Math.cos(a1o) * outer, cy + Math.sin(a1o) * outer]);
    pts.push([cx + Math.cos(a1) * inner, cy + Math.sin(a1) * inner]);
  }
  const d = pts.map((p, i) => (i === 0 ? 'M' : 'L') + p[0].toFixed(2) + ' ' + p[1].toFixed(2)).join(' ') + ' Z';
  return (
    <svg width={size} height={size} viewBox="0 0 32 32" style={{ display: 'block' }}>
      <path d={d} fill={color} />
      <circle cx="16" cy="16" r="4.5" fill="none" stroke={color} strokeWidth="1.6" />
    </svg>
  );
}

// ── Menu bar glyph: state-aware ──
// state: 'success' | 'running' | 'failure' | 'auth' | 'ratelimit'
function MenuBarGlyph({ state = 'success', size = 18, tone = 'dark' }) {
  // base color = template-image color (foreground of menu bar)
  const fg = tone === 'dark' ? '#e8e6e1' : '#1c1c1e';
  const muted = tone === 'dark' ? 'rgba(232,230,225,.55)' : 'rgba(28,28,30,.55)';
  return (
    <svg width={size} height={size} viewBox="0 0 32 32" style={{ display: 'block' }}>
      {/* Always-on gear silhouette so the icon reads as 'sprocket' first */}
      <SprocketSilhouette color={state === 'auth' ? muted : fg} />
      {state === 'success' && (
        <g transform="translate(20 20)">
          <circle r="7" fill="oklch(0.72 0.16 145)" stroke={tone === 'dark' ? '#1c1c1e' : '#fff'} strokeWidth="1.5" />
          <path d="M-3 0 L-1 2.2 L3 -2.2" fill="none" stroke="#fff" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
        </g>
      )}
      {state === 'running' && (
        <g transform="translate(20 20)">
          <circle r="7" fill="oklch(0.78 0.16 80)" stroke={tone === 'dark' ? '#1c1c1e' : '#fff'} strokeWidth="1.5" />
          <g style={{ transformOrigin: '0 0', animation: 'sprocketSpin 1.4s linear infinite' }}>
            <path d="M0 -4 A4 4 0 1 1 -3.5 2" fill="none" stroke="#fff" strokeWidth="1.6" strokeLinecap="round" />
          </g>
        </g>
      )}
      {state === 'failure' && (
        <g transform="translate(20 20)">
          <circle r="7" fill="oklch(0.62 0.18 25)" stroke={tone === 'dark' ? '#1c1c1e' : '#fff'} strokeWidth="1.5" />
          <path d="M-2.6 -2.6 L2.6 2.6 M2.6 -2.6 L-2.6 2.6" stroke="#fff" strokeWidth="1.7" strokeLinecap="round" />
        </g>
      )}
      {state === 'auth' && (
        <g transform="translate(20 20)">
          <circle r="7" fill={muted} stroke={tone === 'dark' ? '#1c1c1e' : '#fff'} strokeWidth="1.5" />
          <path d="M0 -3 L0 1 M0 3 L0 3.5" stroke={tone === 'dark' ? '#1c1c1e' : '#fff'} strokeWidth="1.7" strokeLinecap="round" />
        </g>
      )}
      {state === 'ratelimit' && (
        <g transform="translate(20 20)">
          <circle r="7" fill="oklch(0.78 0.13 80)" stroke={tone === 'dark' ? '#1c1c1e' : '#fff'} strokeWidth="1.5" />
          <circle r="3" fill="none" stroke="#fff" strokeWidth="1.5" />
          <path d="M0 -3 L0 0 L2 1.5" stroke="#fff" strokeWidth="1.5" strokeLinecap="round" fill="none" />
        </g>
      )}
    </svg>
  );
}

function SprocketSilhouette({ color }) {
  // smaller inline gear at upper-left so the badge can sit at lower-right
  const teeth = 8, outer = 9, inner = 6.5, cx = 12, cy = 12;
  const pts = [];
  for (let i = 0; i < teeth; i++) {
    const a = (i / teeth) * Math.PI * 2;
    const next = ((i + 1) / teeth) * Math.PI * 2;
    const half = (next - a) / 2;
    pts.push([cx + Math.cos(a + half - 0.22) * inner, cy + Math.sin(a + half - 0.22) * inner]);
    pts.push([cx + Math.cos(a + half - 0.13) * outer, cy + Math.sin(a + half - 0.13) * outer]);
    pts.push([cx + Math.cos(a + half + 0.13) * outer, cy + Math.sin(a + half + 0.13) * outer]);
    pts.push([cx + Math.cos(a + half + 0.22) * inner, cy + Math.sin(a + half + 0.22) * inner]);
  }
  const d = pts.map((p, i) => (i === 0 ? 'M' : 'L') + p[0].toFixed(2) + ' ' + p[1].toFixed(2)).join(' ') + ' Z';
  return (
    <g>
      <path d={d} fill={color} />
      <circle cx={cx} cy={cy} r="2.6" fill="none" stroke={color} strokeWidth="1.3" />
    </g>
  );
}

// Generic UI glyphs
function Icon({ name, size = 14, color = 'currentColor', strokeWidth = 1.6 }) {
  const p = { width: size, height: size, viewBox: '0 0 16 16', fill: 'none', stroke: color, strokeWidth, strokeLinecap: 'round', strokeLinejoin: 'round', style: { display: 'block', flexShrink: 0 } };
  switch (name) {
    case 'check': return <svg {...p}><path d="M3 8.5 L6.5 12 L13 4.5" /></svg>;
    case 'x': return <svg {...p}><path d="M4 4 L12 12 M12 4 L4 12" /></svg>;
    case 'refresh': return <svg {...p}><path d="M13 4 V8 H9" /><path d="M3 12 V8 H7" /><path d="M11.5 6 A5 5 0 0 0 4 6.5" /><path d="M4.5 10 A5 5 0 0 0 12 9.5" /></svg>;
    case 'gear': return <svg {...p}><circle cx="8" cy="8" r="2.2" /><path d="M8 1.5 V3 M8 13 V14.5 M14.5 8 H13 M3 8 H1.5 M12.6 3.4 L11.5 4.5 M4.5 11.5 L3.4 12.6 M12.6 12.6 L11.5 11.5 M4.5 4.5 L3.4 3.4" /></svg>;
    case 'search': return <svg {...p}><circle cx="7" cy="7" r="4.5" /><path d="M10.5 10.5 L13.5 13.5" /></svg>;
    case 'chevron': return <svg {...p}><path d="M6 4 L10 8 L6 12" /></svg>;
    case 'chevron-down': return <svg {...p}><path d="M4 6 L8 10 L12 6" /></svg>;
    case 'branch': return <svg {...p}><circle cx="4" cy="3.5" r="1.4" /><circle cx="4" cy="12.5" r="1.4" /><circle cx="12" cy="6" r="1.4" /><path d="M4 5 V11" /><path d="M4 7 C4 6 6 6 8 6 H10.5" /></svg>;
    case 'commit': return <svg {...p}><circle cx="8" cy="8" r="2.4" /><path d="M2 8 H5.6 M10.4 8 H14" /></svg>;
    case 'pr': return <svg {...p}><circle cx="4" cy="3.5" r="1.4" /><circle cx="4" cy="12.5" r="1.4" /><circle cx="12" cy="12.5" r="1.4" /><path d="M4 5 V11" /><path d="M12 11 V8 C12 7 11 6 10 6 H8" /><path d="M9 5 L8 6 L9 7" /></svg>;
    case 'play': return <svg {...p}><path d="M5 3.5 L12 8 L5 12.5 Z" fill={color} /></svg>;
    case 'cal': return <svg {...p}><rect x="2.5" y="3.5" width="11" height="10" rx="1.5" /><path d="M2.5 6.5 H13.5" /><path d="M5.5 2 V5 M10.5 2 V5" /></svg>;
    case 'wand': return <svg {...p}><path d="M3 13 L13 3" /><path d="M11 3 L13 3 L13 5" /><path d="M2 8 L4 8 M3 7 V9" /></svg>;
    case 'open': return <svg {...p}><path d="M9 3 H13 V7" /><path d="M13 3 L7 9" /><path d="M11 9 V12 C11 12.5 10.5 13 10 13 H4 C3.5 13 3 12.5 3 12 V6 C3 5.5 3.5 5 4 5 H7" /></svg>;
    case 'copy': return <svg {...p}><rect x="5" y="5" width="8" height="8" rx="1.5" /><path d="M3 11 V4 C3 3.5 3.5 3 4 3 H11" /></svg>;
    case 'pause': return <svg {...p}><rect x="5" y="3.5" width="2" height="9" fill={color} stroke="none" /><rect x="9" y="3.5" width="2" height="9" fill={color} stroke="none" /></svg>;
    case 'dots': return <svg {...p}><circle cx="3.5" cy="8" r=".9" fill={color} stroke="none" /><circle cx="8" cy="8" r=".9" fill={color} stroke="none" /><circle cx="12.5" cy="8" r=".9" fill={color} stroke="none" /></svg>;
    case 'plus': return <svg {...p}><path d="M8 3 V13 M3 8 H13" /></svg>;
    case 'arrow-right': return <svg {...p}><path d="M3 8 H13 M9 4 L13 8 L9 12" /></svg>;
    case 'arrow-left': return <svg {...p}><path d="M13 8 H3 M7 4 L3 8 L7 12" /></svg>;
    case 'lock': return <svg {...p}><rect x="3" y="7" width="10" height="7" rx="1.5" /><path d="M5.5 7 V5 A2.5 2.5 0 0 1 10.5 5 V7" /></svg>;
    case 'globe': return <svg {...p}><circle cx="8" cy="8" r="5.5" /><path d="M2.5 8 H13.5" /><path d="M8 2.5 C10 4.5 10 11.5 8 13.5 C6 11.5 6 4.5 8 2.5" /></svg>;
    case 'bell': return <svg {...p}><path d="M4 11 V8 A4 4 0 0 1 12 8 V11 L13 12.5 H3 Z" /><path d="M6.5 13.5 A1.5 1.5 0 0 0 9.5 13.5" /></svg>;
    case 'mute': return <svg {...p}><path d="M3 6.5 V9.5 H5.5 L8.5 12 V4 L5.5 6.5 Z" /><path d="M11 5 L13.5 11 M13.5 5 L11 11" /></svg>;
    case 'archive': return <svg {...p}><rect x="2.5" y="3" width="11" height="3" rx=".8" /><path d="M3.5 6 V12.5 C3.5 13 4 13.2 4.3 13.2 H11.7 C12 13.2 12.5 13 12.5 12.5 V6" /><path d="M6.5 9 H9.5" /></svg>;
    case 'fork': return <svg {...p}><circle cx="4" cy="4" r="1.4" /><circle cx="12" cy="4" r="1.4" /><circle cx="8" cy="12.5" r="1.4" /><path d="M4 5.4 V7 C4 8 5 9 6 9 H10 C11 9 12 8 12 7 V5.4" /><path d="M8 9 V11" /></svg>;
    case 'mac-power': return <svg {...p}><path d="M8 2.5 V8" /><path d="M5 4 A4 4 0 1 0 11 4" /></svg>;
    default: return null;
  }
}

// Status dot variants reused everywhere
function StatusDot({ status, size = 10 }) {
  const map = {
    success: { c: 'oklch(0.72 0.16 145)', glyph: '✓' },
    failure: { c: 'oklch(0.62 0.18 25)', glyph: '✕' },
    running: { c: 'oklch(0.78 0.16 80)', glyph: '·' },
    queued:  { c: 'oklch(0.72 0.05 250)', glyph: '·' },
    cancelled: { c: 'oklch(0.65 0.02 250)', glyph: '/' },
    skipped: { c: 'oklch(0.65 0.02 250)', glyph: '–' },
    action_required: { c: 'oklch(0.78 0.16 80)', glyph: '!' },
  };
  const v = map[status] || map.queued;
  if (status === 'running') {
    return (
      <span style={{ position: 'relative', display: 'inline-flex', width: size, height: size }}>
        <span style={{ position: 'absolute', inset: 0, borderRadius: '50%', background: v.c, opacity: .25, animation: 'sprocketPulse 1.4s ease-out infinite' }} />
        <span style={{ position: 'absolute', inset: size * 0.2, borderRadius: '50%', background: v.c }} />
      </span>
    );
  }
  return <span style={{ display: 'inline-block', width: size, height: size, borderRadius: '50%', background: v.c }} />;
}

Object.assign(window, { SprocketMark, MenuBarGlyph, Icon, StatusDot });

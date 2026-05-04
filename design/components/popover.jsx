// Popover variations — Variation A (Comfortable, organized) + Variation B (Compact, info-dense)
// Both share row primitives but differ in chrome / layout / feel.

const POPOVER_W = 420;

// ── Avatar (procedural, no images) ──
function Avatar({ login, hue = 200, size = 16, ring = false }) {
  const initials = (login || '?').slice(0, 1).toUpperCase();
  return (
    <span style={{
      width: size, height: size, borderRadius: '50%',
      display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
      flexShrink: 0,
      background: `linear-gradient(135deg, oklch(0.72 0.12 ${hue}) 0%, oklch(0.58 0.14 ${(hue + 40) % 360}) 100%)`,
      color: 'rgba(255,255,255,.95)',
      fontSize: size * 0.5, fontWeight: 600, letterSpacing: '-0.01em',
      boxShadow: ring ? '0 0 0 1.5px var(--surface)' : 'inset 0 0 0 .5px rgba(0,0,0,.15)',
      fontFamily: 'ui-sans-serif, -apple-system, sans-serif',
    }}>{initials}</span>
  );
}

function Chip({ icon, children, tone = 'default' }) {
  const tones = {
    default: 'var(--chip-bg)',
    branch: 'var(--chip-bg)',
    event: 'var(--chip-bg)',
  };
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 3,
      height: 16, padding: '0 5px', borderRadius: 4,
      background: tones[tone], color: 'var(--text-2)',
      fontSize: 10.5, fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace',
      lineHeight: 1, whiteSpace: 'nowrap', maxWidth: 120, overflow: 'hidden', textOverflow: 'ellipsis',
    }}>
      {icon && <Icon name={icon} size={9} color="var(--text-3)" strokeWidth={1.6} />}
      <span style={{ overflow: 'hidden', textOverflow: 'ellipsis' }}>{children}</span>
    </span>
  );
}

// ── Run row, density-aware ──
function RunRow({ run, density = 'comfortable', accent }) {
  const isLive = run.status === 'running' || run.status === 'queued';
  const status = run.status === 'completed' ? run.conclusion : run.status;
  const padding = density === 'compact' ? '5px 12px' : density === 'spacious' ? '12px 14px' : '8px 14px';
  const titleSize = density === 'compact' ? 11.5 : 12.5;
  const showChips = density !== 'compact';

  return (
    <div className="sp-row" style={{
      padding, display: 'grid',
      gridTemplateColumns: '14px 1fr auto', gap: 10, alignItems: density === 'compact' ? 'center' : 'flex-start',
      cursor: 'default', position: 'relative',
    }}>
      <div style={{ paddingTop: density === 'compact' ? 0 : 3, display: 'flex', justifyContent: 'center' }}>
        <StatusDot status={status} size={density === 'spacious' ? 10 : 9} />
      </div>
      <div style={{ minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, minWidth: 0 }}>
          <span style={{ fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace', fontSize: 10.5, color: 'var(--text-3)', whiteSpace: 'nowrap' }}>
            {run.repo}
          </span>
          <span style={{ color: 'var(--text-4)', fontSize: 10 }}>·</span>
          <span style={{ fontSize: 10.5, color: 'var(--text-3)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{run.wf}</span>
        </div>
        <div style={{
          fontSize: titleSize, color: 'var(--text-1)', marginTop: 1,
          overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
          fontWeight: isLive ? 500 : 400,
        }}>{run.title}</div>
        {showChips && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 5, marginTop: 5, flexWrap: 'nowrap', overflow: 'hidden' }}>
            <Chip icon="branch" tone="branch">{run.branch}</Chip>
            <Chip icon={run.event === 'pull_request' ? 'pr' : run.event === 'schedule' ? 'cal' : run.event === 'workflow_dispatch' ? 'wand' : 'commit'} tone="event">
              {run.event}
            </Chip>
            <span style={{ fontSize: 10.5, color: 'var(--text-3)', fontVariantNumeric: 'tabular-nums', whiteSpace: 'nowrap' }}>
              {isLive ? `running · ${run.durLive || '0s'}` : run.dur}
            </span>
            <span style={{ fontSize: 10.5, color: 'var(--text-4)', whiteSpace: 'nowrap' }}>· {run.started.replace('— ', '')}</span>
          </div>
        )}
        {!showChips && (
          <div style={{ display: 'flex', gap: 8, marginTop: 1, fontSize: 10, color: 'var(--text-3)' }}>
            <span style={{ fontFamily: 'ui-monospace, monospace' }}>{run.branch}</span>
            <span style={{ color: 'var(--text-4)' }}>·</span>
            <span>{isLive ? `${run.durLive || '0s'}` : run.dur}</span>
            <span style={{ color: 'var(--text-4)' }}>·</span>
            <span>{run.started.replace('— ', '')}</span>
          </div>
        )}
      </div>
      <div style={{ display: 'flex', alignItems: density === 'compact' ? 'center' : 'flex-start', paddingTop: density === 'compact' ? 0 : 3, gap: 4 }}>
        <Avatar login={run.actor} hue={run.actorHue} size={density === 'compact' ? 14 : 16} />
      </div>
    </div>
  );
}

// ── Variation A: Comfortable, organized — "default + clean" ──
function PopoverA({ density = 'comfortable', filter = 'all', showRateLimit = true, runs, accent, dark }) {
  const visible = runs.filter(r => {
    if (filter === 'running') return r.status === 'running' || r.status === 'queued';
    if (filter === 'failing') return r.conclusion === 'failure' || r.conclusion === 'timed_out' || r.conclusion === 'action_required';
    if (filter === 'recent') return true;
    return true;
  });

  return (
    <div className="sp-popover sp-popover-a" style={{
      width: POPOVER_W, height: 560, display: 'flex', flexDirection: 'column',
      background: 'var(--surface)', color: 'var(--text-1)',
      borderRadius: 14,
      border: '.5px solid var(--surface-border)',
      boxShadow: 'var(--popover-shadow)',
      fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif',
      overflow: 'hidden',
      backdropFilter: 'blur(40px) saturate(180%)',
      WebkitBackdropFilter: 'blur(40px) saturate(180%)',
    }}>
      {/* Header */}
      <div style={{ padding: '10px 12px 8px', display: 'flex', alignItems: 'center', gap: 10, borderBottom: '.5px solid var(--divider)' }}>
        <Avatar login="m" hue={80} size={22} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 12.5, fontWeight: 600, letterSpacing: '-0.01em' }}>mattnz</div>
          <div style={{ fontSize: 10.5, color: 'var(--text-3)' }}>47 repos · last refreshed 12s ago</div>
        </div>
        <button className="sp-iconbtn" title="Refresh (⌘R)"><Icon name="refresh" size={13} /></button>
        <button className="sp-iconbtn" title="Settings"><Icon name="gear" size={13} /></button>
        <button className="sp-iconbtn" title="More"><Icon name="dots" size={13} /></button>
      </div>

      {/* Filter row */}
      <div style={{ padding: '8px 12px', display: 'flex', alignItems: 'center', gap: 8, borderBottom: '.5px solid var(--divider)' }}>
        <Segmented value={filter} options={[
          { id: 'all', label: 'All', count: 47 },
          { id: 'running', label: 'Running', count: 2 },
          { id: 'failing', label: 'Failing', count: 3 },
          { id: 'recent', label: 'Recent' },
        ]} accent={accent} />
        <div style={{ position: 'relative', flex: 1, minWidth: 90 }}>
          <Icon name="search" size={11} color="var(--text-3)" strokeWidth={1.5} />
          <input className="sp-search" placeholder="Filter…" />
        </div>
      </div>

      {/* Org switcher */}
      <div style={{ padding: '6px 12px', borderBottom: '.5px solid var(--divider)', display: 'flex', alignItems: 'center', gap: 6 }}>
        <span style={{ fontSize: 10.5, color: 'var(--text-3)' }}>Showing</span>
        <button className="sp-orgswitch">
          All organizations <Icon name="chevron-down" size={10} color="var(--text-3)" />
        </button>
        <span style={{ flex: 1 }} />
        <span style={{ fontSize: 10, color: 'var(--text-4)', fontFamily: 'ui-monospace, monospace' }}>{visible.length} runs</span>
      </div>

      {/* List */}
      <div style={{ flex: 1, overflowY: 'auto', minHeight: 0 }}>
        {visible.map(r => <RunRow key={r.id} run={r} density={density} accent={accent} />)}
      </div>

      {/* Footer */}
      {showRateLimit && (
        <div style={{
          padding: '7px 12px', borderTop: '.5px solid var(--divider)',
          display: 'flex', alignItems: 'center', gap: 8, fontSize: 10.5, color: 'var(--text-3)',
          background: 'var(--footer-bg)',
        }}>
          <RateBar pct={4832 / 5000} accent={accent} />
          <span style={{ fontFamily: 'ui-monospace, monospace', fontVariantNumeric: 'tabular-nums' }}>4,832 / 5,000</span>
          <span style={{ color: 'var(--text-4)' }}>· resets in 47m</span>
          <span style={{ flex: 1 }} />
          <a className="sp-link" style={{ color: accent }}>Open Actions <Icon name="open" size={9} color={accent} strokeWidth={1.6} /></a>
        </div>
      )}
    </div>
  );
}

function Segmented({ value, options, accent }) {
  return (
    <div className="sp-seg">
      {options.map(o => (
        <button key={o.id} className={'sp-seg-btn' + (o.id === value ? ' is-on' : '')}
          style={o.id === value ? { background: 'var(--seg-on)', boxShadow: '0 1px 2px rgba(0,0,0,.08), inset 0 0 0 .5px var(--seg-on-border)' } : {}}>
          {o.label}{typeof o.count === 'number' && (
            <span style={{ marginLeft: 4, fontSize: 9.5, color: o.id === value ? 'var(--text-2)' : 'var(--text-4)', fontVariantNumeric: 'tabular-nums' }}>{o.count}</span>
          )}
        </button>
      ))}
    </div>
  );
}

function RateBar({ pct, accent }) {
  return (
    <span style={{ display: 'inline-flex', width: 56, height: 4, background: 'var(--track)', borderRadius: 999, overflow: 'hidden' }}>
      <span style={{ width: `${pct * 100}%`, background: 'oklch(0.72 0.16 145)', height: '100%' }} />
    </span>
  );
}

// ── Variation B: Grouped-by-repo, info-dense ──
// Same data, different IA — repos collapse together so you scan by project.
function PopoverB({ density = 'comfortable', filter = 'all', showRateLimit = true, runs, accent, dark }) {
  const visible = runs.filter(r => {
    if (filter === 'running') return r.status === 'running' || r.status === 'queued';
    if (filter === 'failing') return r.conclusion === 'failure' || r.conclusion === 'timed_out' || r.conclusion === 'action_required';
    return true;
  });
  // group by repo
  const groups = {};
  visible.forEach(r => { (groups[r.repo] = groups[r.repo] || []).push(r); });
  const groupKeys = Object.keys(groups);

  return (
    <div className="sp-popover sp-popover-b" style={{
      width: POPOVER_W, height: 560, display: 'flex', flexDirection: 'column',
      background: 'var(--surface)', color: 'var(--text-1)',
      borderRadius: 14,
      border: '.5px solid var(--surface-border)',
      boxShadow: 'var(--popover-shadow)',
      fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif',
      overflow: 'hidden',
      backdropFilter: 'blur(40px) saturate(180%)',
      WebkitBackdropFilter: 'blur(40px) saturate(180%)',
    }}>
      {/* Compact header — title + summary stats inline */}
      <div style={{ padding: '10px 12px', display: 'flex', alignItems: 'center', gap: 10 }}>
        <SprocketMark size={14} color="var(--text-1)" />
        <span style={{ fontSize: 12.5, fontWeight: 600, letterSpacing: '-0.01em' }}>Sprocket</span>
        <span style={{ flex: 1 }} />
        <SummaryPill icon="check" count={42} tone="success" />
        <SummaryPill icon="play" count={2} tone="running" />
        <SummaryPill icon="x" count={3} tone="failure" />
        <span style={{ width: 1, height: 14, background: 'var(--divider)', margin: '0 4px' }} />
        <button className="sp-iconbtn" title="Refresh"><Icon name="refresh" size={13} /></button>
        <button className="sp-iconbtn" title="Settings"><Icon name="gear" size={13} /></button>
      </div>

      {/* Filter as inline row */}
      <div style={{ padding: '0 12px 8px', display: 'flex', alignItems: 'center', gap: 8, borderBottom: '.5px solid var(--divider)' }}>
        <Segmented value={filter} options={[
          { id: 'all', label: 'All' },
          { id: 'running', label: 'Running' },
          { id: 'failing', label: 'Failing' },
          { id: 'recent', label: 'Recent' },
        ]} accent={accent} />
      </div>

      {/* Grouped list */}
      <div style={{ flex: 1, overflowY: 'auto', minHeight: 0 }}>
        {groupKeys.map(repo => (
          <div key={repo}>
            <div style={{
              padding: '8px 12px 4px', display: 'flex', alignItems: 'center', gap: 6,
              fontSize: 10.5, color: 'var(--text-3)', fontFamily: 'ui-monospace, monospace',
              position: 'sticky', top: 0, background: 'var(--surface-sticky)',
              backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)', zIndex: 1,
            }}>
              <Icon name="chevron-down" size={9} color="var(--text-3)" />
              <span>{repo}</span>
              <span style={{ flex: 1 }} />
              <RepoSparkline runs={groups[repo]} />
            </div>
            {groups[repo].map(r => <CompactRunRow key={r.id} run={r} density={density} />)}
          </div>
        ))}
      </div>

      {showRateLimit && (
        <div style={{
          padding: '7px 12px', borderTop: '.5px solid var(--divider)',
          display: 'flex', alignItems: 'center', gap: 8, fontSize: 10.5, color: 'var(--text-3)',
        }}>
          <span style={{ fontFamily: 'ui-monospace, monospace' }}>API</span>
          <RateBar pct={4832 / 5000} accent={accent} />
          <span style={{ fontFamily: 'ui-monospace, monospace', fontVariantNumeric: 'tabular-nums' }}>4,832</span>
          <span style={{ color: 'var(--text-4)' }}>resets 47m</span>
          <span style={{ flex: 1 }} />
          <span style={{ fontFamily: 'ui-monospace, monospace', color: 'var(--text-4)' }}>updated 12s ago</span>
        </div>
      )}
    </div>
  );
}

function SummaryPill({ icon, count, tone }) {
  const c = tone === 'success' ? 'oklch(0.72 0.16 145)' : tone === 'failure' ? 'oklch(0.62 0.18 25)' : 'oklch(0.78 0.16 80)';
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 3,
      fontSize: 11, fontVariantNumeric: 'tabular-nums', color: 'var(--text-2)',
    }}>
      <span style={{ width: 6, height: 6, borderRadius: '50%', background: c }} />
      {count}
    </span>
  );
}

function RepoSparkline({ runs }) {
  // last 8 outcomes as colored squares
  const bars = runs.slice(0, 8);
  while (bars.length < 8) bars.push(null);
  return (
    <span style={{ display: 'inline-flex', gap: 2 }}>
      {bars.map((r, i) => {
        const status = !r ? 'empty' : (r.status === 'completed' ? r.conclusion : r.status);
        const c = status === 'success' ? 'oklch(0.72 0.16 145)'
          : status === 'failure' ? 'oklch(0.62 0.18 25)'
          : status === 'running' || status === 'queued' ? 'oklch(0.78 0.16 80)'
          : status === 'cancelled' ? 'oklch(0.6 0.02 250)'
          : status === 'action_required' ? 'oklch(0.78 0.16 80)'
          : 'var(--track)';
        return <span key={i} style={{ width: 5, height: 9, background: c, borderRadius: 1 }} />;
      })}
    </span>
  );
}

function CompactRunRow({ run, density }) {
  const isLive = run.status === 'running' || run.status === 'queued';
  const status = run.status === 'completed' ? run.conclusion : run.status;
  const padding = density === 'compact' ? '4px 12px 4px 28px' : density === 'spacious' ? '10px 12px 10px 28px' : '6px 12px 6px 28px';
  return (
    <div className="sp-row" style={{
      padding, display: 'grid', gridTemplateColumns: '10px 1fr auto auto', gap: 8, alignItems: 'center',
    }}>
      <StatusDot status={status} size={8} />
      <div style={{ minWidth: 0, display: 'flex', alignItems: 'baseline', gap: 6 }}>
        <span style={{ fontSize: 11.5, fontWeight: isLive ? 500 : 400, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', minWidth: 0, color: 'var(--text-1)' }}>{run.title}</span>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: 10, color: 'var(--text-3)', fontFamily: 'ui-monospace, monospace' }}>
        <span>{run.wf}</span>
        <span style={{ color: 'var(--text-4)' }}>·</span>
        <span style={{ fontVariantNumeric: 'tabular-nums' }}>{isLive ? run.durLive : run.dur}</span>
      </div>
      <Avatar login={run.actor} hue={run.actorHue} size={14} />
    </div>
  );
}

Object.assign(window, { PopoverA, PopoverB, Avatar, Segmented, RunRow });

// Welcome / OAuth flow + Settings + Desktop chrome

// ── Faux desktop chrome with menu bar ──
function Desktop({ children, dark, accent, activeIcon = 'success', wallpaperHue }) {
  return (
    <div style={{
      width: 1100, height: 720, position: 'relative',
      background: dark
        ? `radial-gradient(ellipse at 30% 20%, oklch(0.32 0.04 ${wallpaperHue}) 0%, oklch(0.18 0.03 ${wallpaperHue}) 60%, oklch(0.12 0.02 ${wallpaperHue}) 100%)`
        : `radial-gradient(ellipse at 30% 20%, oklch(0.92 0.03 ${wallpaperHue}) 0%, oklch(0.82 0.04 ${wallpaperHue}) 60%, oklch(0.72 0.05 ${wallpaperHue}) 100%)`,
      borderRadius: 14, overflow: 'hidden',
      fontFamily: '-apple-system, BlinkMacSystemFont, system-ui, sans-serif',
    }}>
      <MacMenuBar dark={dark} accent={accent} activeIcon={activeIcon} />
      <div style={{ position: 'absolute', inset: '32px 0 0 0' }}>{children}</div>
    </div>
  );
}

function MacMenuBar({ dark, accent, activeIcon }) {
  const fg = dark ? 'rgba(255,255,255,.94)' : 'rgba(0,0,0,.85)';
  const fg2 = dark ? 'rgba(255,255,255,.7)' : 'rgba(0,0,0,.65)';
  return (
    <div style={{
      position: 'absolute', top: 0, left: 0, right: 0, height: 32,
      background: dark ? 'rgba(20,20,22,.55)' : 'rgba(255,255,255,.5)',
      backdropFilter: 'blur(40px) saturate(180%)',
      WebkitBackdropFilter: 'blur(40px) saturate(180%)',
      borderBottom: dark ? '.5px solid rgba(255,255,255,.08)' : '.5px solid rgba(0,0,0,.08)',
      display: 'flex', alignItems: 'center', padding: '0 12px',
      fontSize: 13, color: fg, gap: 14, zIndex: 10,
    }}>
      <span style={{ display: 'inline-flex', alignItems: 'center' }}>
        <svg width="14" height="14" viewBox="0 0 16 16" fill={fg}><path d="M11.5 1.4 C9.7 1.4 8.6 2.6 8.6 4.2 C8.6 4.4 8.6 4.6 8.7 4.7 C7.4 5 6.4 6.1 6.4 7.5 C6.4 9.5 8.5 10.6 8.5 12.4 C8.5 13 8.2 13.6 7.6 14 C7.4 14.1 7.5 14.4 7.7 14.4 C9.4 14.4 10.7 13.1 10.7 11.6 C10.7 9.4 8.6 8.5 8.6 7.2 C8.6 6.4 9.2 5.8 10 5.8 C10.6 5.8 10.9 6 11.2 6 C11.6 6 11.9 5.6 11.9 5.1 C11.9 4.5 11.4 4 10.7 4 C10.6 4 10.5 4 10.4 4 C10.6 3.4 11.4 2.9 12.2 2.9 C12.4 2.9 12.5 2.7 12.4 2.5 C12.2 1.9 11.9 1.4 11.5 1.4 Z"/></svg>
      </span>
      <span style={{ fontWeight: 600 }}>Sprocket</span>
      <span style={{ fontWeight: 400, color: fg2 }}>File</span>
      <span style={{ fontWeight: 400, color: fg2 }}>Edit</span>
      <span style={{ fontWeight: 400, color: fg2 }}>View</span>
      <span style={{ fontWeight: 400, color: fg2 }}>Window</span>
      <span style={{ fontWeight: 400, color: fg2 }}>Help</span>
      <span style={{ flex: 1 }} />
      <MenuBarSlot active={activeIcon === 'success'} state="success" dark={dark} highlight />
      <span style={{ fontFamily: 'ui-monospace, monospace', fontSize: 11.5, color: fg2 }}>100%</span>
      <span style={{ fontSize: 11.5, color: fg2 }}>Tue 10:24</span>
      <Icon name="search" size={13} color={fg} />
      <span style={{ width: 18, height: 14, borderRadius: 2, background: fg, opacity: 0.9 }} />
    </div>
  );
}

function MenuBarSlot({ state, dark, highlight }) {
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
      width: 22, height: 22, borderRadius: 5,
      background: highlight ? (dark ? 'rgba(255,255,255,.16)' : 'rgba(0,0,0,.08)') : 'transparent',
    }}>
      <MenuBarGlyph state={state} size={16} tone={dark ? 'dark' : 'light'} />
    </span>
  );
}

// ── Welcome sheet ──
function WelcomeSheet({ step = 1, dark, accent }) {
  return (
    <div style={{
      width: 520, background: 'var(--surface-solid)', color: 'var(--text-1)',
      borderRadius: 12, overflow: 'hidden',
      border: '.5px solid var(--surface-border)',
      boxShadow: dark ? '0 30px 80px rgba(0,0,0,.6), 0 1px 0 rgba(255,255,255,.06) inset' : '0 30px 80px rgba(0,0,0,.18), 0 1px 0 rgba(255,255,255,.5) inset',
      fontFamily: '-apple-system, BlinkMacSystemFont, system-ui, sans-serif',
    }}>
      <div style={{ padding: '14px 16px 12px', borderBottom: '.5px solid var(--divider)', display: 'flex', alignItems: 'center', gap: 10 }}>
        <div style={{ width: 24, height: 24, borderRadius: 6, background: 'var(--chip-bg)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <SprocketMark size={14} color="var(--text-1)" />
        </div>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 12.5, fontWeight: 600 }}>Welcome to Sprocket</div>
          <div style={{ fontSize: 11, color: 'var(--text-3)' }}>Step {step} of 3</div>
        </div>
        <div style={{ display: 'flex', gap: 4 }}>
          {[1,2,3].map(n => <span key={n} style={{ width: 18, height: 3, borderRadius: 2, background: n <= step ? accent : 'var(--track)' }} />)}
        </div>
      </div>
      <div style={{ padding: '20px 22px 22px', minHeight: 360 }}>
        {step === 1 && <WelcomeStep1 accent={accent} />}
        {step === 2 && <WelcomeStep2 accent={accent} dark={dark} />}
        {step === 3 && <WelcomeStep3 accent={accent} />}
      </div>
      <div style={{ padding: '10px 14px', borderTop: '.5px solid var(--divider)', display: 'flex', justifyContent: 'space-between', background: 'var(--footer-bg)' }}>
        <button className="sp-btn sp-btn-ghost">{step === 1 ? 'Quit' : 'Back'}</button>
        <div style={{ display: 'flex', gap: 8 }}>
          {step !== 3 && <button className="sp-btn sp-btn-ghost">Skip</button>}
          <button className="sp-btn sp-btn-primary" style={{ background: accent }}>
            {step === 3 ? 'Continue & sign in' : 'Continue'}
          </button>
        </div>
      </div>
    </div>
  );
}

function WelcomeStep1({ accent }) {
  return (
    <div>
      <div style={{ fontSize: 22, fontWeight: 600, letterSpacing: '-0.02em', lineHeight: 1.15, textWrap: 'balance' }}>
        You'll create your own GitHub OAuth app.
      </div>
      <p style={{ marginTop: 10, fontSize: 13, lineHeight: 1.5, color: 'var(--text-2)', textWrap: 'pretty' }}>
        Sprocket talks to GitHub on your behalf. Rather than sharing one OAuth app across all
        Sprocket users — which gets rate-limited and is a security smell — you'll register your
        own. It takes about 90 seconds. Your token never leaves this Mac.
      </p>
      <div style={{ marginTop: 16, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
        <BulletCard icon="lock" title="Token in Keychain" body="Stored in macOS Keychain, never on disk in plaintext." />
        <BulletCard icon="globe" title="Direct to GitHub" body="No third-party server. Polling only — no analytics." />
        <BulletCard icon="branch" title="Your rate limit" body="Your own 5,000/hr budget, not shared." />
        <BulletCard icon="gear" title="One-time setup" body="Reused across sign-outs. Reconfigure anytime." />
      </div>
      <div style={{ marginTop: 14, padding: '8px 10px', background: 'var(--info-bg)', borderRadius: 7, fontSize: 11.5, color: 'var(--text-2)', display: 'flex', gap: 8, alignItems: 'flex-start' }}>
        <Icon name="lock" size={12} color={accent} />
        <span>Sprocket will request <code style={{ fontFamily: 'ui-monospace, monospace', fontSize: 11 }}>repo</code>, <code style={{ fontFamily: 'ui-monospace, monospace', fontSize: 11 }}>workflow</code>, <code style={{ fontFamily: 'ui-monospace, monospace', fontSize: 11 }}>read:org</code>, and <code style={{ fontFamily: 'ui-monospace, monospace', fontSize: 11 }}>read:user</code>.</span>
      </div>
    </div>
  );
}

function BulletCard({ icon, title, body }) {
  return (
    <div style={{ padding: '10px 11px', background: 'var(--card-bg)', borderRadius: 8, border: '.5px solid var(--card-border)' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        <Icon name={icon} size={11} color="var(--text-2)" />
        <span style={{ fontSize: 11.5, fontWeight: 600 }}>{title}</span>
      </div>
      <div style={{ fontSize: 11, color: 'var(--text-3)', marginTop: 3, lineHeight: 1.4 }}>{body}</div>
    </div>
  );
}

function WelcomeStep2({ accent, dark }) {
  return (
    <div>
      <div style={{ fontSize: 17, fontWeight: 600, letterSpacing: '-0.01em' }}>Register the app on GitHub</div>
      <p style={{ marginTop: 6, fontSize: 12.5, lineHeight: 1.5, color: 'var(--text-2)' }}>
        We'll open a pre-filled registration page. Follow these five steps:
      </p>
      <div style={{ display: 'flex', gap: 14, marginTop: 12 }}>
        <ol style={{ flex: 1, fontSize: 12, lineHeight: 1.6, color: 'var(--text-2)', paddingLeft: 18, margin: 0 }}>
          <li>The form is pre-filled — leave defaults or rename it.</li>
          <li>Scroll down and tick <b>"Enable Device Flow"</b>. <span style={{ color: 'oklch(0.62 0.18 25)' }}>Critical.</span></li>
          <li>Click <b>"Register application"</b>.</li>
          <li>Copy the <b>Client ID</b> (no secret needed).</li>
          <li>Come back to Sprocket.</li>
        </ol>
        {/* Static SVG illustration of the device flow checkbox */}
        <div style={{ width: 160, padding: 10, background: 'var(--card-bg)', border: '.5px solid var(--card-border)', borderRadius: 8 }}>
          <div style={{ fontSize: 9.5, color: 'var(--text-3)', fontFamily: 'ui-monospace, monospace', marginBottom: 6 }}>github.com</div>
          <div style={{ height: 8, background: 'var(--track)', borderRadius: 2, marginBottom: 5 }} />
          <div style={{ height: 8, background: 'var(--track)', borderRadius: 2, width: '70%', marginBottom: 10 }} />
          <div style={{ display: 'flex', gap: 6, alignItems: 'flex-start', padding: 6, borderRadius: 5, background: accent + '22', border: `1px dashed ${accent}` }}>
            <span style={{ width: 12, height: 12, borderRadius: 3, border: `1.5px solid ${accent}`, background: accent, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
              <Icon name="check" size={8} color="#fff" strokeWidth={2.5} />
            </span>
            <div>
              <div style={{ fontSize: 10, fontWeight: 600, color: 'var(--text-1)' }}>Enable Device Flow</div>
              <div style={{ fontSize: 9, color: 'var(--text-3)', lineHeight: 1.3, marginTop: 1 }}>Allow this OAuth App to authorize users via Device Flow.</div>
            </div>
          </div>
          <div style={{ height: 8, background: 'var(--track)', borderRadius: 2, marginTop: 10, width: '50%' }} />
          <div style={{ marginTop: 8, padding: '4px 8px', background: accent, color: '#fff', borderRadius: 4, fontSize: 10, fontWeight: 500, display: 'inline-block' }}>
            Register application
          </div>
        </div>
      </div>
      <div style={{ marginTop: 16, display: 'flex', gap: 8 }}>
        <button className="sp-btn sp-btn-primary" style={{ background: accent }}>
          <Icon name="open" size={11} color="#fff" /> Open GitHub to create app
        </button>
        <button className="sp-btn sp-btn-ghost">
          <Icon name="copy" size={11} /> Copy registration URL
        </button>
      </div>
    </div>
  );
}

function WelcomeStep3({ accent }) {
  return (
    <div>
      <div style={{ fontSize: 17, fontWeight: 600, letterSpacing: '-0.01em' }}>Paste your Client ID</div>
      <p style={{ marginTop: 6, fontSize: 12.5, lineHeight: 1.5, color: 'var(--text-2)' }}>
        From the GitHub page after registering, copy the Client ID and paste it here.
      </p>
      <label style={{ display: 'block', marginTop: 16, fontSize: 11, color: 'var(--text-3)', fontWeight: 500 }}>Client ID</label>
      <div style={{ marginTop: 4, position: 'relative' }}>
        <input
          className="sp-input-mono"
          defaultValue="Iv1.a4f2e9c81b3d7e60"
          style={{
            width: '100%', padding: '8px 10px', borderRadius: 7,
            background: 'var(--input-bg)', border: '1px solid ' + accent,
            fontFamily: 'ui-monospace, SFMono-Regular, monospace', fontSize: 12.5,
            color: 'var(--text-1)', outline: 'none',
            boxShadow: `0 0 0 3px ${accent}33`,
          }}
        />
        <span style={{ position: 'absolute', right: 8, top: 9, color: 'oklch(0.72 0.16 145)' }}>
          <Icon name="check" size={13} color="oklch(0.72 0.16 145)" strokeWidth={2} />
        </span>
      </div>
      <div style={{ marginTop: 6, fontSize: 11, color: 'oklch(0.72 0.16 145)', display: 'flex', alignItems: 'center', gap: 4 }}>
        <Icon name="check" size={10} color="oklch(0.72 0.16 145)" strokeWidth={2} /> Looks like a valid Client ID
      </div>
      <div style={{ marginTop: 18, padding: 12, background: 'var(--card-bg)', borderRadius: 8, border: '.5px solid var(--card-border)' }}>
        <div style={{ fontSize: 11, color: 'var(--text-3)', fontWeight: 500, marginBottom: 8 }}>Next: device sign-in</div>
        <div style={{ fontSize: 11.5, color: 'var(--text-2)', lineHeight: 1.45 }}>
          We'll show a one-time code, open <span style={{ fontFamily: 'ui-monospace, monospace' }}>github.com/login/device</span> in your browser, and finish signing in automatically.
        </div>
      </div>
      <label style={{ display: 'flex', gap: 6, alignItems: 'center', marginTop: 12, fontSize: 11.5, color: 'var(--text-2)' }}>
        <span style={{ width: 12, height: 12, borderRadius: 3, border: '1.5px solid var(--text-3)', display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }}>
          <Icon name="check" size={8} color="var(--text-3)" strokeWidth={2.5} />
        </span>
        Save this Client ID for next time
      </label>
    </div>
  );
}

// ── Device flow code window (separate artboard) ──
function DeviceFlowSheet({ accent, dark }) {
  return (
    <div style={{
      width: 440, padding: '24px 26px 22px',
      background: 'var(--surface-solid)', color: 'var(--text-1)',
      borderRadius: 12, border: '.5px solid var(--surface-border)',
      boxShadow: dark ? '0 30px 80px rgba(0,0,0,.6)' : '0 30px 80px rgba(0,0,0,.18)',
      fontFamily: '-apple-system, BlinkMacSystemFont, system-ui, sans-serif',
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <SprocketMark size={14} color="var(--text-2)" />
        <span style={{ fontSize: 11.5, color: 'var(--text-3)' }}>Sign in to GitHub</span>
      </div>
      <div style={{ fontSize: 18, fontWeight: 600, marginTop: 10, letterSpacing: '-0.01em' }}>
        Enter this code in your browser
      </div>
      <p style={{ fontSize: 12, color: 'var(--text-3)', marginTop: 4, lineHeight: 1.5 }}>
        We've opened <span style={{ fontFamily: 'ui-monospace, monospace' }}>github.com/login/device</span>. The code below is pre-filled — you just need to confirm.
      </p>
      <div style={{
        marginTop: 18, padding: '20px 16px', background: 'var(--code-bg)',
        border: '.5px solid var(--card-border)', borderRadius: 10,
        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
        fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace',
        fontSize: 30, fontWeight: 500, letterSpacing: '0.18em', color: 'var(--text-1)',
      }}>
        <span>9F4G</span><span style={{ color: 'var(--text-4)' }}>—</span><span>X7R2</span>
      </div>
      <div style={{ marginTop: 10, display: 'flex', gap: 8, justifyContent: 'center' }}>
        <button className="sp-btn sp-btn-ghost" style={{ fontSize: 11 }}>
          <Icon name="copy" size={11} /> Copy code
        </button>
        <button className="sp-btn sp-btn-ghost" style={{ fontSize: 11 }}>
          <Icon name="open" size={11} /> Reopen browser
        </button>
      </div>
      <div style={{ marginTop: 18, display: 'flex', alignItems: 'center', gap: 8, fontSize: 11.5, color: 'var(--text-3)', justifyContent: 'center' }}>
        <span style={{ width: 10, height: 10, borderRadius: '50%', background: accent, animation: 'sprocketPulse 1.4s ease-out infinite' }} />
        Waiting for authorization… expires in 14:32
      </div>
    </div>
  );
}

// ── Settings window ──
function SettingsWindow({ tab = 'general', dark, accent }) {
  const tabs = [
    { id: 'general', label: 'General', icon: 'gear' },
    { id: 'account', label: 'Account', icon: 'lock' },
    { id: 'repos', label: 'Repositories', icon: 'fork' },
    { id: 'notifs', label: 'Notifications', icon: 'bell' },
    { id: 'advanced', label: 'Advanced', icon: 'wand' },
  ];
  return (
    <div style={{
      width: 660, height: 520,
      background: 'var(--surface-solid)', color: 'var(--text-1)',
      borderRadius: 11, overflow: 'hidden',
      border: '.5px solid var(--surface-border)',
      boxShadow: dark ? '0 30px 80px rgba(0,0,0,.6)' : '0 30px 80px rgba(0,0,0,.18)',
      fontFamily: '-apple-system, BlinkMacSystemFont, system-ui, sans-serif',
      display: 'flex', flexDirection: 'column',
    }}>
      <div style={{ height: 38, padding: '0 12px', display: 'flex', alignItems: 'center', borderBottom: '.5px solid var(--divider)', gap: 8, background: 'var(--titlebar-bg)' }}>
        <div style={{ display: 'flex', gap: 6 }}>
          <span style={{ width: 11, height: 11, borderRadius: '50%', background: '#ff5f57' }} />
          <span style={{ width: 11, height: 11, borderRadius: '50%', background: '#febc2e' }} />
          <span style={{ width: 11, height: 11, borderRadius: '50%', background: '#28c840' }} />
        </div>
        <span style={{ flex: 1, textAlign: 'center', fontSize: 12.5, fontWeight: 500 }}>Settings</span>
        <span style={{ width: 39 }} />
      </div>
      <div style={{ display: 'flex', height: 38, alignItems: 'center', padding: '0 8px', borderBottom: '.5px solid var(--divider)', gap: 2 }}>
        {tabs.map(t => (
          <button key={t.id} style={{
            display: 'flex', alignItems: 'center', gap: 5,
            padding: '4px 10px', borderRadius: 6, background: t.id === tab ? 'var(--seg-on)' : 'transparent',
            border: 0, color: 'var(--text-1)', fontSize: 11.5, fontFamily: 'inherit', fontWeight: t.id === tab ? 500 : 400,
          }}>
            <Icon name={t.icon} size={11} color="var(--text-2)" /> {t.label}
          </button>
        ))}
      </div>
      <div style={{ flex: 1, overflowY: 'auto', padding: '18px 22px' }}>
        {tab === 'general' && <SettingsGeneral accent={accent} />}
        {tab === 'account' && <SettingsAccount accent={accent} />}
        {tab === 'repos' && <SettingsRepos accent={accent} />}
        {tab === 'notifs' && <SettingsNotifs accent={accent} />}
        {tab === 'advanced' && <SettingsAdvanced accent={accent} />}
      </div>
    </div>
  );
}

function SettingsRow({ label, hint, control }) {
  return (
    <div style={{ display: 'grid', gridTemplateColumns: '180px 1fr', gap: 18, padding: '10px 0', alignItems: 'flex-start' }}>
      <div style={{ paddingTop: 4, textAlign: 'right' }}>
        <div style={{ fontSize: 12.5, fontWeight: 500 }}>{label}</div>
      </div>
      <div>
        {control}
        {hint && <div style={{ fontSize: 11, color: 'var(--text-3)', marginTop: 4, lineHeight: 1.4, maxWidth: 360 }}>{hint}</div>}
      </div>
    </div>
  );
}

function SwitchControl({ on, accent }) {
  return (
    <span style={{
      width: 30, height: 18, borderRadius: 999,
      background: on ? accent : 'var(--track-strong)',
      position: 'relative', display: 'inline-block', verticalAlign: 'middle',
      boxShadow: 'inset 0 0 0 .5px rgba(0,0,0,.1)',
    }}>
      <span style={{
        position: 'absolute', top: 2, left: on ? 14 : 2,
        width: 14, height: 14, borderRadius: '50%', background: '#fff',
        boxShadow: '0 1px 3px rgba(0,0,0,.25)', transition: 'left .15s',
      }} />
    </span>
  );
}

function SettingsGeneral({ accent }) {
  return (
    <div>
      <SectionHeader>Startup</SectionHeader>
      <SettingsRow label="Launch at login" hint="Sprocket will start automatically when you sign in to your Mac." control={<SwitchControl on accent={accent} />} />
      <SettingsRow label="Hide from Dock" hint="Sprocket lives only in the menu bar. Always on for menu bar apps." control={<SwitchControl on accent={accent} />} />
      <SectionHeader>Polling</SectionHeader>
      <SettingsRow label="Refresh cadence" control={
        <select className="sp-select" defaultValue="60">
          <option value="30">Every 30 seconds</option>
          <option value="60">Every minute</option>
          <option value="120">Every 2 minutes</option>
          <option value="300">Every 5 minutes</option>
          <option value="900">Every 15 minutes</option>
          <option value="manual">Manual only</option>
        </select>
      } hint="Repos with in-progress runs poll every 15 s regardless." />
      <SettingsRow label="Battery saver" hint="Pause polling when your laptop is on battery and below 20%." control={<SwitchControl on accent={accent} />} />
      <SettingsRow label="Pause on no network" control={<SwitchControl on accent={accent} />} />
    </div>
  );
}

function SettingsAccount({ accent }) {
  return (
    <div>
      <SectionHeader>Signed in</SectionHeader>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '4px 0 16px' }}>
        <Avatar login="m" hue={80} size={44} />
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 13.5, fontWeight: 600 }}>Matt Connors</div>
          <div style={{ fontSize: 11.5, color: 'var(--text-3)', fontFamily: 'ui-monospace, monospace' }}>@mattnz</div>
        </div>
        <button className="sp-btn sp-btn-ghost">Sign out</button>
      </div>
      <SectionHeader>Scopes granted</SectionHeader>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, padding: '6px 0 14px' }}>
        {[
          ['repo', 'Read & write across repos you can access'],
          ['workflow', 'Re-run / cancel runs'],
          ['read:org', 'Discover repos in your orgs'],
          ['read:user', 'Your avatar & login'],
        ].map(([s, h]) => (
          <span key={s} style={{ display: 'inline-flex', alignItems: 'center', gap: 5, padding: '5px 8px', background: 'var(--card-bg)', border: '.5px solid var(--card-border)', borderRadius: 6, fontSize: 11 }}>
            <Icon name="check" size={10} color="oklch(0.72 0.16 145)" strokeWidth={2.5} />
            <span style={{ fontFamily: 'ui-monospace, monospace', fontWeight: 500 }}>{s}</span>
            <span style={{ color: 'var(--text-3)' }}>· {h}</span>
          </span>
        ))}
      </div>
      <SectionHeader>OAuth app</SectionHeader>
      <SettingsRow label="Client ID" control={
        <span style={{ fontFamily: 'ui-monospace, monospace', fontSize: 12, padding: '4px 8px', background: 'var(--code-bg)', borderRadius: 5 }}>Iv1.a4f2e9c81b3d7e60</span>
      } hint="Stored in UserDefaults. Token kept separately in Keychain." />
      <SettingsRow label="" control={
        <div style={{ display: 'flex', gap: 8 }}>
          <button className="sp-btn sp-btn-ghost">Reconfigure OAuth app</button>
          <button className="sp-btn sp-btn-ghost" style={{ color: 'oklch(0.62 0.18 25)' }}>Forget OAuth app</button>
        </div>
      } />
    </div>
  );
}

function SettingsRepos({ accent }) {
  const items = [
    { repo: 'mattnz/orbital-cms', org: 'Personal', muted: false, archived: false, runs: 132, last: 'success' },
    { repo: 'mattnz/dotfiles', org: 'Personal', muted: false, archived: false, runs: 41, last: 'success' },
    { repo: 'mattnz/almanac', org: 'Personal', muted: false, archived: false, runs: 88, last: 'success' },
    { repo: 'mattnz/sprocket', org: 'Personal', muted: false, archived: false, runs: 12, last: 'action_required' },
    { repo: 'mattnz/old-blog', org: 'Personal', muted: true, archived: true, runs: 320, last: 'success' },
    { repo: 'kintsugi-labs/spindle', org: 'kintsugi-labs', muted: false, archived: false, runs: 1109, last: 'success' },
    { repo: 'kintsugi-labs/atlas', org: 'kintsugi-labs', muted: false, archived: false, runs: 88, last: 'success' },
    { repo: 'kintsugi-labs/spindle-rs', org: 'kintsugi-labs', muted: false, archived: false, runs: 558, last: 'success' },
    { repo: 'foundry-co/relay', org: 'foundry-co', muted: false, archived: false, runs: 9438, last: 'failure' },
    { repo: 'foundry-co/dashboard', org: 'foundry-co', muted: false, archived: false, runs: 1772, last: 'success' },
    { repo: 'foundry-co/relay-edge', org: 'foundry-co', muted: false, archived: false, runs: 2201, last: 'success' },
    { repo: 'foundry-co/internal-tools', org: 'foundry-co', muted: true, archived: false, runs: 88, last: 'cancelled' },
  ];
  return (
    <div>
      <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 12 }}>
        <div style={{ position: 'relative', flex: 1 }}>
          <span style={{ position: 'absolute', left: 8, top: 6 }}><Icon name="search" size={11} color="var(--text-3)" /></span>
          <input className="sp-search-wide" placeholder="Filter repositories…" />
        </div>
        <button className="sp-btn sp-btn-ghost"><Icon name="archive" size={11} /> Mute archived</button>
        <button className="sp-btn sp-btn-ghost"><Icon name="fork" size={11} /> Mute forks</button>
      </div>
      <div style={{ border: '.5px solid var(--card-border)', borderRadius: 8, overflow: 'hidden', background: 'var(--card-bg)' }}>
        <div style={{ display: 'grid', gridTemplateColumns: '24px 1fr 110px 70px 70px', padding: '6px 12px', fontSize: 10.5, color: 'var(--text-3)', fontWeight: 500, letterSpacing: '0.04em', textTransform: 'uppercase', borderBottom: '.5px solid var(--divider)' }}>
          <span></span><span>Repository</span><span>Org</span><span style={{ textAlign: 'right' }}>Runs</span><span style={{ textAlign: 'right' }}>Last</span>
        </div>
        {items.map(it => (
          <div key={it.repo} style={{ display: 'grid', gridTemplateColumns: '24px 1fr 110px 70px 70px', padding: '7px 12px', fontSize: 12, alignItems: 'center', borderBottom: '.5px solid var(--divider)', opacity: it.muted ? 0.45 : 1 }}>
            <span style={{ width: 14, height: 14, borderRadius: 3, background: it.muted ? 'transparent' : accent, border: it.muted ? '1.2px solid var(--text-3)' : 'none', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              {!it.muted && <Icon name="check" size={9} color="#fff" strokeWidth={2.5} />}
            </span>
            <span style={{ display: 'flex', alignItems: 'center', gap: 6, fontFamily: 'ui-monospace, monospace', fontSize: 11.5 }}>
              {it.archived && <Icon name="archive" size={10} color="var(--text-3)" />}
              {it.repo}
            </span>
            <span style={{ fontSize: 11, color: 'var(--text-3)' }}>{it.org}</span>
            <span style={{ textAlign: 'right', fontVariantNumeric: 'tabular-nums', fontSize: 11, color: 'var(--text-3)' }}>{it.runs.toLocaleString()}</span>
            <span style={{ display: 'flex', justifyContent: 'flex-end' }}>
              <StatusDot status={it.last} size={8} />
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}

function SettingsNotifs({ accent }) {
  return (
    <div>
      <SectionHeader>Events</SectionHeader>
      <SettingsRow label="On failure" hint="Notify when a run transitions to failure, timed_out, or action_required." control={<SwitchControl on accent={accent} />} />
      <SettingsRow label="Back to green" hint="Notify on the first success after a previously-failing repo. Recoveries are noise for most people." control={<SwitchControl on={false} accent={accent} />} />
      <SettingsRow label="My runs only" hint="Suppress notifications for runs triggered by other actors." control={<SwitchControl on={false} accent={accent} />} />
      <SectionHeader>Delivery</SectionHeader>
      <SettingsRow label="Sound" control={
        <select className="sp-select" defaultValue="default"><option>Default</option><option>None</option><option>Funk</option><option>Glass</option></select>
      } />
      <SettingsRow label="Quiet hours" hint="Mute notifications during this window. Banner state still updates." control={
        <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
          <SwitchControl on accent={accent} />
          <span style={{ fontSize: 11.5, color: 'var(--text-2)' }}>22:00 — 08:00</span>
        </div>
      } />
      <SettingsRow label="Coalesce bursts" hint="If more than 5 failures arrive in one poll, post a single summary." control={<SwitchControl on accent={accent} />} />
    </div>
  );
}

function SettingsAdvanced({ accent }) {
  return (
    <div>
      <SectionHeader>API</SectionHeader>
      <SettingsRow label="Base URL" hint="For GitHub Enterprise Server. The OAuth registration deeplink updates accordingly." control={
        <input className="sp-input" defaultValue="https://api.github.com" />
      } />
      <SettingsRow label="User-Agent" control={<input className="sp-input" defaultValue="Sprocket/0.1 (matts-mbp; macOS 26.0)" />} />
      <SectionHeader>Cache</SectionHeader>
      <SettingsRow label="Cache size" hint="ETags + last-seen run snapshots." control={
        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <span style={{ fontFamily: 'ui-monospace, monospace', fontSize: 12 }}>284 KB</span>
          <button className="sp-btn sp-btn-ghost">Reveal in Finder</button>
        </div>
      } />
      <SectionHeader>Reset</SectionHeader>
      <SettingsRow label="" hint="Wipes Keychain entry, UserDefaults, and the cache. The OAuth app on GitHub is unaffected." control={
        <button className="sp-btn sp-btn-ghost" style={{ color: 'oklch(0.62 0.18 25)', borderColor: 'oklch(0.62 0.18 25)' }}>Reset all data…</button>
      } />
    </div>
  );
}

function SectionHeader({ children }) {
  return (
    <div style={{ fontSize: 10, fontWeight: 600, letterSpacing: '0.06em', color: 'var(--text-3)', textTransform: 'uppercase', padding: '14px 0 6px' }}>{children}</div>
  );
}

Object.assign(window, { Desktop, MenuBarSlot, WelcomeSheet, DeviceFlowSheet, SettingsWindow });

// Party Mayhem – telefonos kontroller
(() => {
  const socket = io({ transports: ['websocket', 'polling'] });
  const screen = document.getElementById('screen');
  const top = document.getElementById('top');
  const conn = document.getElementById('conn');
  const connText = document.getElementById('conn-text');

  const store = {
    get: (k) => { try { return localStorage.getItem(k); } catch { return null; } },
    set: (k, v) => { try { localStorage.setItem(k, v); } catch { /* privát mód */ } },
  };
  let pid = store.get('pm_pid');
  if (!pid) {
    pid = (crypto.randomUUID ? crypto.randomUUID() : `${Math.random().toString(36).slice(2)}${Date.now()}`);
    store.set('pm_pid', pid);
  }
  let name = store.get('pm_name') || '';
  let joined = false;
  let layout = null;

  const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const buzz = (p) => { try { navigator.vibrate?.(p); } catch { /* nem támogatott */ } };
  const send = (msg) => socket.emit('player:input', { ...msg, lid: layout?.id });

  // ------------------------------------------------------------ kapcsolat
  function setConn(msg) {
    conn.hidden = !msg;
    if (msg) connText.textContent = msg;
  }
  socket.on('connect', () => {
    setConn(null);
    if (joined) socket.emit('player:join', { pid, name });
  });
  socket.on('disconnect', () => setConn('Megszakadt a kapcsolat – újracsatlakozás…'));
  socket.on('host:offline', () => setConn('Várakozás a játékképernyőre…\n(nyisd meg a /host oldalt a gépen)'));
  socket.on('host:online', () => setConn(null));
  socket.on('ctrl', (msg) => {
    if (!msg) return;
    if (msg.kind === 'layout') {
      layout = msg.layout;
      if (layout.me) setMe(layout.me);
      render();
    } else if (msg.kind === 'status') {
      if (msg.me) setMe(msg.me);
    } else if (msg.kind === 'vibrate') {
      buzz(msg.pattern);
    }
  });

  function setMe(me) {
    top.hidden = false;
    document.documentElement.style.setProperty('--pc', me.color);
    document.getElementById('me-av').textContent = me.animal;
    document.getElementById('me-name').textContent = me.name;
    document.getElementById('me-stats').textContent = me.playing
      ? `🪙 ${me.coins}   👑 ${me.crowns}   ${(me.items || []).join(' ')}`
      : 'Lobby';
  }

  document.getElementById('fs').addEventListener('click', () => {
    if (document.fullscreenElement) document.exitFullscreen?.();
    else document.documentElement.requestFullscreen?.().catch(() => {});
  });

  // ------------------------------------------------------------ csatlakozás
  function renderJoin() {
    top.hidden = true;
    screen.innerHTML = `
      <div class="center" style="gap:18px">
        <div class="logo">PARTY<br>MAYHEM</div>
        <p class="muted">Írd be a neved, és csatlakozz!</p>
        <input id="name" maxlength="14" placeholder="A neved" autocomplete="off" value="${esc(name)}">
        <button class="primary" id="join">Csatlakozás 🎉</button>
      </div>`;
    const inp = document.getElementById('name');
    const go = () => {
      const n = inp.value.trim();
      if (!n) { inp.focus(); inp.style.borderColor = '#ff6b6b'; return; }
      name = n.slice(0, 14);
      store.set('pm_name', name);
      try { sessionStorage.setItem('pm_joined', '1'); } catch { /* */ }
      join();
    };
    document.getElementById('join').addEventListener('click', go);
    inp.addEventListener('keydown', (e) => { if (e.key === 'Enter') go(); });
  }

  function join() {
    joined = true;
    socket.emit('player:join', { pid, name });
    screen.innerHTML = '<div class="center"><div class="big-emoji">🛰️</div><h2>Csatlakozás…</h2></div>';
    navigator.wakeLock?.request('screen').catch(() => {});
  }

  // ------------------------------------------------------------ elrendezések
  const R = {
    wait(l) {
      screen.innerHTML = `<div class="center"><div class="big-emoji">${esc(l.icon || '⏳')}</div>
        <h2>${esc(l.title || 'Várj…')}</h2><p>${esc(l.text || '')}</p></div>`;
    },

    result(l) {
      screen.innerHTML = `<div class="center"><div class="big-emoji" style="font-size:110px">${esc(l.icon || '🎉')}</div>
        <h2 style="font-size:38px">${esc(l.title)}</h2><p style="font-size:24px;color:#ffe066">${esc(l.text || '')}</p>
        ${l.again ? '<button class="primary" id="again" style="margin-top:20px">🔄 Új játék</button>' : ''}</div>`;
      document.getElementById('again')?.addEventListener('click', () => send({ t: 'again' }));
    },

    lobby(l) {
      screen.innerHTML = `
        <h2>Válassz figurát!</h2>
        <div class="animals">${l.animals.map((a) => `<button class="animal ${a === l.animal ? 'sel' : ''}" data-a="${esc(a)}" ${l.taken.includes(a) ? 'disabled' : ''}>${esc(a)}</button>`).join('')}</div>
        <button class="ready-btn ${l.ready ? 'on' : ''}" id="ready">${l.ready ? '✔ Kész vagyok!' : '👉 Kész vagyok'}</button>
        ${l.vip ? `
          <div class="vip">
            <h3>⭐ Te vagy a VIP</h3>
            <div class="rounds">${l.roundOptions.map((r) => `<button data-r="${r}" class="${r === l.rounds ? 'sel' : ''}">${r} kör</button>`).join('')}</div>
            <button class="start" id="start" ${l.canStart ? '' : 'disabled'}>▶ Játék indítása</button>
            <p class="muted">${l.canStart ? `Mindenki kész! (${l.count} játékos)` : 'Várj, amíg mindenki kész lesz…'}</p>
          </div>`
          : `<p class="muted">${l.rounds} kör · ${l.count} játékos · a ⭐ VIP indítja a játékot</p>`}`;
      screen.querySelectorAll('.animal').forEach((b) => b.addEventListener('click', () => send({ t: 'animal', v: b.dataset.a })));
      document.getElementById('ready').addEventListener('click', () => { buzz(30); send({ t: 'ready', v: !l.ready }); });
      screen.querySelectorAll('.rounds button').forEach((b) => b.addEventListener('click', () => send({ t: 'rounds', v: Number(b.dataset.r) })));
      document.getElementById('start')?.addEventListener('click', () => send({ t: 'start' }));
    },

    choice(l) {
      screen.innerHTML = `<h2>${esc(l.title)}</h2>${l.text ? `<p>${esc(l.text)}</p>` : ''}
        <div class="choices">${l.options.map((o, i) => `<button class="choice" data-i="${i}" ${o.disabled ? 'disabled' : ''}>${esc(o.label)}${o.sub ? `<small>${esc(o.sub)}</small>` : ''}</button>`).join('')}</div>`;
      let done = false;
      screen.querySelectorAll('.choice').forEach((b) => b.addEventListener('click', () => {
        if (done) return;
        done = true;
        b.classList.add('picked');
        screen.querySelectorAll('.choice').forEach((x) => { x.disabled = true; });
        buzz(30);
        send({ t: 'choice', v: Number(b.dataset.i) });
      }));
    },

    tap(l) {
      screen.innerHTML = `<div class="tapwrap"><button class="tapbtn" id="tap">${esc(l.label || 'NYOMD!')}</button><p>${esc(l.hint || '')}</p></div>`;
      const b = document.getElementById('tap');
      let once = false;
      b.addEventListener('pointerdown', (e) => {
        e.preventDefault();
        if (!l.rapid && once) return;
        once = true;
        send({ t: 'tap' });
        buzz(l.rapid ? 8 : 40);
        b.classList.add('hit');
        setTimeout(() => b.classList.remove('hit'), 70);
      });
    },

    ready(l) {
      screen.innerHTML = `<div class="center"><div class="big-emoji">${esc(l.icon || '🎮')}</div><h2 style="font-size:32px">${esc(l.title)}</h2>
        <p>${esc(l.text || '')}</p><button class="primary" id="rdy" style="margin-top:22px">✋ Kész vagyok!</button></div>`;
      document.getElementById('rdy').addEventListener('click', (e) => {
        e.target.disabled = true;
        e.target.textContent = 'Várakozás…';
        buzz(30);
        send({ t: 'ready' });
      });
    },

    stick(l) {
      screen.innerHTML = `<div class="stickwrap">
        <div class="stickzone" id="zone"><div class="base" id="base"><div class="knob" id="knob"></div></div></div>
        <button class="actbtn" id="act">${esc(l.btn || 'AKCIÓ')}</button></div>`;
      const zone = document.getElementById('zone');
      const base = document.getElementById('base');
      const knob = document.getElementById('knob');
      let active = null, last = 0, lx = 0, ly = 0, cur = { x: 0, y: 0 };
      const push = (force) => {
        const now = performance.now();
        if (!force && now - last < 45) return;
        if (!force && Math.abs(cur.x - lx) < 0.04 && Math.abs(cur.y - ly) < 0.04) return;
        last = now; lx = cur.x; ly = cur.y;
        send({ t: 'stick', x: +cur.x.toFixed(2), y: +cur.y.toFixed(2) });
      };
      const move = (e) => {
        const r = base.getBoundingClientRect();
        const cx = r.left + r.width / 2, cy = r.top + r.height / 2, max = r.width / 2;
        let dx = e.clientX - cx, dy = e.clientY - cy;
        const d = Math.hypot(dx, dy);
        if (d > max) { dx *= max / d; dy *= max / d; }
        knob.style.transform = `translate(${dx}px, ${dy}px)`;
        cur = { x: dx / max, y: dy / max };
        push(false);
      };
      zone.addEventListener('pointerdown', (e) => { e.preventDefault(); active = e.pointerId; zone.setPointerCapture(e.pointerId); move(e); });
      zone.addEventListener('pointermove', (e) => { if (e.pointerId === active) move(e); });
      const end = (e) => {
        if (e.pointerId !== active) return;
        active = null;
        knob.style.transform = '';
        cur = { x: 0, y: 0 };
        push(true);
      };
      zone.addEventListener('pointerup', end);
      zone.addEventListener('pointercancel', end);
      const act = document.getElementById('act');
      act.addEventListener('pointerdown', (e) => {
        e.preventDefault();
        if (act.classList.contains('cool')) return;
        send({ t: 'btn' });
        buzz(50);
        act.classList.add('hit', 'cool');
        setTimeout(() => act.classList.remove('hit'), 100);
        setTimeout(() => act.classList.remove('cool'), 1300);
      });
      // folyamatos frissítés, hogy a host biztosan megkapja az aktuális irányt
      const iv = setInterval(() => { if (!document.body.contains(zone)) { clearInterval(iv); return; } if (active !== null) push(true); }, 150);
    },

    lr() {
      screen.innerHTML = '<div class="lr"><button data-v="-1">◀</button><button data-v="1">▶</button></div>';
      const held = new Map();
      let lastV = 0;
      const update = () => {
        const vals = new Set(held.values());
        const v = (vals.has(1) ? 1 : 0) - (vals.has(-1) ? 1 : 0);
        screen.querySelectorAll('.lr button').forEach((b) => b.classList.toggle('hit', vals.has(Number(b.dataset.v))));
        if (v !== lastV) { lastV = v; send({ t: 'lr', v }); }
      };
      screen.querySelectorAll('.lr button').forEach((b) => {
        b.addEventListener('pointerdown', (e) => { e.preventDefault(); b.setPointerCapture(e.pointerId); held.set(e.pointerId, Number(b.dataset.v)); buzz(10); update(); });
        const up = (e) => { held.delete(e.pointerId); update(); };
        b.addEventListener('pointerup', up);
        b.addEventListener('pointercancel', up);
      });
    },

    pads(l) {
      screen.innerHTML = `<h2>${esc(l.title || '')}</h2><div class="pads ${l.enabled ? '' : 'off'}">${l.pads.map((p, i) => `<button class="pad" data-i="${i}" style="background:${esc(p.color)}">${esc(p.shape)}</button>`).join('')}</div>`;
      screen.querySelectorAll('.pad').forEach((b) => b.addEventListener('pointerdown', (e) => {
        e.preventDefault();
        if (!l.enabled) return;
        send({ t: 'pad', v: Number(b.dataset.i) });
        buzz(20);
        b.classList.add('hit');
        setTimeout(() => b.classList.remove('hit'), 140);
      }));
    },

    number(l) {
      let val = '';
      screen.innerHTML = `<h2>${esc(l.title || 'Írd be a számot')}</h2><div class="numdisp" id="disp">&nbsp;</div>
        <div class="keypad">${[1, 2, 3, 4, 5, 6, 7, 8, 9].map((n) => `<button data-k="${n}">${n}</button>`).join('')}
        <button class="del" data-k="del">⌫</button><button data-k="0">0</button><button class="ok" data-k="ok">✓</button></div>`;
      const disp = document.getElementById('disp');
      screen.querySelectorAll('.keypad button').forEach((b) => b.addEventListener('click', () => {
        const k = b.dataset.k;
        buzz(10);
        if (k === 'del') val = val.slice(0, -1);
        else if (k === 'ok') { if (val !== '') send({ t: 'num', v: Number(val) }); return; }
        else if (val.length < 3) val = (val === '0' ? '' : val) + k;
        disp.innerHTML = val || '&nbsp;';
      }));
    },
  };

  function render() {
    if (!layout) return;
    (R[layout.mode] || R.wait)(layout);
  }

  document.addEventListener('contextmenu', (e) => e.preventDefault());
  document.addEventListener('gesturestart', (e) => e.preventDefault());

  let auto = false;
  try { auto = sessionStorage.getItem('pm_joined') === '1' && !!name; } catch { /* */ }
  if (auto) join();
  else renderJoin();
})();

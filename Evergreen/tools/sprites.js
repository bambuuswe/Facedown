// Every Evergreen sprite, drawn by code. Returns { sprites, meta }.
const { hex, mix, withAlpha, Canvas, rng, hash2, noise, ascii } = require("./lib");

const C = {
  outline: hex("#2b3353"), snow: hex("#ffffff"), snowMid: hex("#e9f0fc"), snowShade: hex("#cbd8f0"), snowDeep: hex("#a9bbe0"),
  shadow: [86, 108, 168, 80],
  wood: hex("#8f5f3f"), woodDark: hex("#643f2b"), woodLight: hex("#b9845a"), woodPale: hex("#d3a878"),
  iron: hex("#2e3548"), ironLight: hex("#4c5672"), glassOff: hex("#7d8fb3"), glassDark: hex("#33486e"), glassGlint: hex("#9db8dc"),
  stone: hex("#a4acbc"), stoneDark: hex("#7c8598"), stoneLight: hex("#c3cad6"),
  warm1: hex("#fff6c9"), warm2: hex("#ffd97a"), warm3: hex("#ffb347"),
  red: hex("#d8483e"), redDark: hex("#a53030"), gold: hex("#f5c93c"), cream: hex("#f6ead0"),
};
const FIR = { tones: [hex("#6dbb5c"), hex("#439652"), hex("#2c744b"), hex("#1e5642")], outline: hex("#143530") };
const PINE = { tones: [hex("#5aa07e"), hex("#3a7f6a"), hex("#2a635c"), hex("#1d4a4c")], outline: hex("#12303a") };
const BULBS = [hex("#ff5a4d"), hex("#ffd84d"), hex("#5ab8ff"), hex("#fff6d8"), hex("#ff8ad0")];

const sprites = {};
const meta = {};

/** Lays snow on every surface that is open to the sky. */
function snowTop(cv, depthAt, skip) {
  for (let x = 0; x < cv.w; x++) {
    let left = 0;
    for (let y = 0; y < cv.h; y++) {
      const solid = cv.alpha(x, y) > 128;
      if (!solid) { left = 0; continue; }
      if (cv.alpha(x, y - 1) <= 128) left = skip && skip(x, y) ? 0 : depthAt(x, y);
      if (left > 0) {
        cv.set(x, y, left === 1 && depthAt(x, y) > 1 ? C.snowShade : C.snow);
        left--;
      }
    }
  }
}
function ball(cv, cx, cy, rx, ry, tones) {
  for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++) for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) {
    const nx = (x - cx) / rx, ny = (y - cy) / ry;
    if (nx * nx + ny * ny > 1) continue;
    const t = nx * 0.6 + ny * 0.8;
    cv.set(x, y, t < -0.25 ? tones[0] : t < 0.45 ? tones[1] : tones[2]);
  }
}

// ---------------------------------------------------------------- trees
function fir(o) {
  const { H, halfW, tiers, lean = 0, snow = 1, pal, cw = 32, seed = 1, trunkW = 3, dusting = false } = o;
  const trunkH = o.trunkH || 5, ch = H + trunkH + 6;
  const cv = new Canvas(cw, ch), can = new Canvas(cw, ch);
  const cx = cw / 2 - 0.5, baseY = ch - 3, top = baseY - trunkH - H + 1;
  const off = (t) => lean * Math.pow(1 - t, 1.3) + (lean ? Math.sin(t * Math.PI * 2) * 1.3 : 0);
  const prof = (y) => {
    const t = (y - top) / (H - 1);
    if (t < 0 || t > 1) return null;
    const k = Math.min(tiers - 1, Math.floor(t * tiers)), local = Math.min(1, t * tiers - k);
    const wk = halfW * Math.pow((k + 1) / tiers, 0.8), wTop = k === 0 ? 0 : halfW * Math.pow(k / tiers, 0.8) * 0.5;
    return { t, k, local, w: wTop + (wk - wTop) * Math.pow(local, 0.75), sx: cx + off(t) };
  };
  const inside = (x, y) => {
    const p = prof(y);
    if (!p) return false;
    const dx = Math.abs(x - p.sx);
    if (dx > p.w + 0.5) return false;
    if (p.local > 0.8 && ((x + p.k * 2 + 64) % 4) >= 2 && dx > p.w - 1.5) return false;
    return true;
  };
  const points = [];
  for (let y = 0; y < ch; y++) for (let x = 0; x < cw; x++) {
    if (!inside(x, y)) continue;
    const p = prof(y);
    const tone = ((x - p.sx) / halfW) * 0.9 + (p.local - 0.45) * 0.7 + (p.k > 0 && p.local < 0.2 ? 0.55 : 0) + (hash2(x, y, seed) - 0.5) * 0.3;
    can.set(x, y, pal.tones[tone < -0.35 ? 0 : tone < 0.1 ? 1 : tone < 0.5 ? 2 : 3]);
    if (inside(x - 1, y) && inside(x + 1, y) && inside(x, y - 1) && inside(x, y + 1) && inside(x, y + 2)) points.push([x, y]);
  }
  if (snow > 0) {
    snowTop(can, (x, y) => (dusting ? 1 : snow - (hash2(x, 0, seed) < 0.3 ? 1 : 0)), dusting ? (x, y) => hash2(x, y, seed + 9) < 0.45 || x - cx > halfW * 0.45 : null);
  }
  can.outline(pal.outline);
  cv.ellipse(cx, baseY, Math.max(5, halfW * 0.95), 2.6, C.shadow);
  const tx = Math.round(cx - trunkW / 2 + 0.5);
  cv.rect(tx - 1, baseY - trunkH - 1, trunkW + 2, trunkH + 2, C.outline);
  cv.rect(tx, baseY - trunkH - 1, trunkW, trunkH + 1, C.wood);
  cv.rect(tx + trunkW - 1, baseY - trunkH - 1, 1, trunkH + 1, C.woodDark);
  cv.blit(can, 0, 0);
  return { cv, points, tip: [Math.round(cx + off(0)), top] };
}
function star(cv, x, y, big) {
  const rows = big ? ["...Y...", "...Y...", ".YYYYY.", "YYYWYYY", ".YYYYY.", ".YY.YY.", ".Y...Y."] : ["..Y..", ".YWY.", "YYYYY", ".YYY.", ".Y.Y."];
  const half = (rows[0].length - 1) / 2;
  rows.forEach((row, j) => [...row].forEach((ch, i) => { if (ch !== ".") cv.set(x - half + i, y - rows.length + 2 + j, ch === "W" ? C.warm1 : C.gold); }));
}
function decorate(tree, spacing, seed, opts = {}) {
  const lit = new Canvas(tree.cv.w, tree.cv.h), r = rng(seed), chosen = [];
  const pool = tree.points.slice().sort(() => r() - 0.5);
  for (const [x, y] of pool) {
    if (y < tree.tip[1] + 4) continue;
    if (chosen.every(([cx, cy]) => (cx - x) ** 2 + (cy - y) ** 2 >= spacing * spacing)) chosen.push([x, y]);
  }
  chosen.forEach(([x, y], i) => {
    const c = BULBS[i % BULBS.length];
    if (opts.baubles) { lit.rect(x, y, 2, 2, c); lit.set(x, y, mix(c, C.snow, 0.6)); lit.set(x + 1, y + 1, mix(c, C.outline, 0.35)); }
    else { lit.set(x, y, mix(c, C.snow, 0.45)); lit.set(x, y + 1, c); }
  });
  if (opts.star) star(lit, tree.tip[0], tree.tip[1], opts.star === "big");
  return lit;
}
const HEIGHTS = [18, 28, 38], WIDTHS = [6, 9, 12], TIERS = [3, 4, 5];
for (let h = 0; h < 3; h++) for (let f = 0; f < 3; f++) for (let c = 0; c < 2; c++) {
  const name = `fir_${h}${f}${c}`;
  const lean = c ? ((h + f) % 2 ? -1 : 1) * (4 + h) : 0;
  const tree = fir({ H: HEIGHTS[h], halfW: WIDTHS[f], tiers: TIERS[h], lean, pal: FIR, dusting: true, seed: h * 7 + f * 3 + c });
  sprites[name] = tree.cv;
  sprites[name + "_lit"] = decorate(tree, 4.2, 40 + h * 6 + f * 2 + c, { star: true });
}
(() => {
  const tree = fir({ H: 70, halfW: 21, tiers: 8, pal: FIR, dusting: true, cw: 48, seed: 99, trunkW: 5, trunkH: 7 });
  sprites.giant = tree.cv;
  sprites.giant_lit1 = decorate(tree, 5.5, 501);
  sprites.giant_lit2 = decorate(tree, 7.5, 502, { baubles: true });
  const top = new Canvas(tree.cv.w, tree.cv.h);
  star(top, tree.tip[0], tree.tip[1] + 1, "big");
  const r = rng(503);
  for (let i = 0; i < 9; i++) {
    const [x, y] = tree.points[Math.floor(r() * tree.points.length)];
    top.set(x, y, C.warm1); top.set(x - 1, y, C.warm2); top.set(x + 1, y, C.warm2); top.set(x, y - 1, C.warm2); top.set(x, y + 1, C.warm2);
  }
  sprites.giant_lit3 = top;
  meta.giant = { tipY: tree.cv.h - tree.tip[1] };
})();
[[30, 10, 4, 2], [40, 13, 5, 3], [24, 9, 3, 2]].forEach(([H, halfW, tiers, snow], i) => {
  sprites[`pine_${i}`] = fir({ H, halfW, tiers, snow, pal: PINE, seed: 200 + i }).cv;
});
function bareTree(seed) {
  const cv = new Canvas(40, 50), r = rng(seed);
  const bark = hex("#6a4a3c"), barkDark = hex("#4a3229");
  cv.ellipse(19.5, 47, 9, 2.6, C.shadow);
  const branch = (x, y, angle, len, depth) => {
    const x2 = x + Math.cos(angle) * len, y2 = y - Math.sin(angle) * len;
    cv.line(x, y, x2, y2, depth < 2 ? barkDark : bark);
    if (depth < 2) cv.line(x - 1, y, x2 - 1, y2, bark);
    if (depth >= 4) return;
    const n = depth === 0 ? 3 : 2;
    for (let i = 0; i < n; i++) branch(x2, y2, angle + (i - (n - 1) / 2) * (0.55 + r() * 0.35) + (r() - 0.5) * 0.3, len * (0.68 + r() * 0.12), depth + 1);
  };
  cv.rect(18, 36, 4, 12, barkDark); cv.rect(18, 36, 2, 12, bark);
  branch(20, 37, Math.PI / 2 + (r() - 0.5) * 0.2, 11, 0);
  snowTop(cv, () => 1, (x, y) => y > 44 || hash2(x, y, seed) < 0.25);
  return cv;
}
sprites.bare_0 = bareTree(11);
sprites.bare_1 = bareTree(23);
(() => {
  const cv = new Canvas(14, 11);
  cv.ellipse(6.5, 8, 6, 2.2, C.shadow);
  cv.rect(3, 3, 8, 6, C.wood); cv.rect(9, 3, 2, 6, C.woodDark);
  cv.rect(3, 2, 8, 3, C.woodPale); cv.rect(5, 3, 4, 1, C.woodLight); cv.set(6, 3, C.wood);
  snowTop(cv, () => 1, (x) => x > 7);
  cv.outline(C.outline);
  sprites.stump = cv;
})();

// ---------------------------------------------------------------- buildings
function wallPixel(style, x, y, x0, y0, colors, seed) {
  const [base, dark, light] = colors;
  const lx = x - x0, ly = y - y0;
  if (style === "plank") return ly % 4 === 3 ? dark : (lx + Math.floor(ly / 4) * 7) % 13 === 0 ? dark : ly % 4 === 0 ? light : base;
  if (style === "log") return ly % 5 === 4 ? dark : ly % 5 === 0 ? light : (lx * 3 + Math.floor(ly / 5) * 5) % 17 === 0 ? dark : base;
  if (style === "stone") {
    const row = Math.floor(ly / 4), bx = lx + (row % 2) * 3;
    if (ly % 4 === 3 || bx % 7 === 6) return dark;
    const v = hash2(Math.floor(bx / 7), row, seed);
    return v < 0.3 ? light : v < 0.75 ? base : mix(base, dark, 0.45);
  }
  return hash2(lx, ly, seed) < 0.06 ? light : base; // plaster, beams are added afterwards
}
function windowAt(cv, lit, x, y, w, h, trim, shutter) {
  if (shutter) {
    cv.rect(x - 3, y, 3, h, shutter[0]); cv.rect(x + w, y, 3, h, shutter[0]);
    for (let j = y + 1; j < y + h; j += 2) { cv.rect(x - 3, j, 3, 1, shutter[1]); cv.rect(x + w, j, 3, 1, shutter[1]); }
  }
  cv.rect(x, y, w, h, trim);
  const mx = x + Math.floor(w / 2), my = y + Math.floor(h / 2);
  for (let j = y + 1; j < y + h - 1; j++) for (let i = x + 1; i < x + w - 1; i++) {
    if (i === mx || j === my) continue;
    cv.set(i, j, (i - x + j - y) % 7 === 3 ? C.glassGlint : j < my ? C.glassDark : mix(C.glassDark, C.outline, 0.3));
    lit.set(i, j, mix(C.warm1, C.warm3, (j - y) / h));
  }
  // curtains show when the lamps are lit
  for (let k = 0; k < 3; k++) { lit.set(x + 1 + k, y + 1, C.red); lit.set(x + w - 2 - k, y + 1, C.red); }
  lit.set(x + 1, y + 2, C.red); lit.set(x + w - 2, y + 2, C.red);
  cv.rect(x - 1, y + h, w + 2, 1, C.snow); cv.rect(x, y + h - 1, w, 1, C.snowMid); cv.rect(x - 1, y + h + 1, w + 2, 1, C.snowShade);
}
function doorAt(cv, x, y, w, h, color, trim) {
  cv.rect(x - 1, y - 1, w + 2, h + 1, trim);
  cv.rect(x, y, w, h, color);
  cv.rect(x + 1, y + 1, w - 2, 5, mix(color, C.outline, 0.25)); cv.rect(x + 1, y + 8, w - 2, h - 10, mix(color, C.outline, 0.25));
  cv.rect(x + 2, y + 2, w - 4, 3, color); cv.rect(x + 2, y + 9, w - 4, h - 12, color);
  cv.set(x + w - 2, y + 8, C.gold);
  // wreath
  const wx = x + w / 2 - 0.5, wy = y + 4;
  for (let a = 0; a < 12; a++) cv.set(Math.round(wx + Math.cos(a * 0.524) * 2.4), Math.round(wy + Math.sin(a * 0.524) * 2.4), a % 2 ? FIR.tones[1] : FIR.tones[2]);
  cv.set(Math.round(wx), Math.round(wy + 2.4), C.red); cv.set(Math.round(wx - 2), Math.round(wy - 1), C.red);
  cv.rect(x - 2, y + h, w + 4, 1, C.stoneLight);
}
function icicles(cv, x0, x1, y, seed) {
  for (let x = x0; x <= x1; x++) {
    const v = hash2(x, y, seed);
    if (v > 0.38) continue;
    const len = 1 + Math.floor(v * 9);
    for (let j = 0; j < len; j++) cv.set(x, y + j, j === len - 1 ? hex("#dff1fc") : hex("#b8dcf5"));
  }
}
function chimney(cv, x, y, w, h) {
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
    const brick = (i + (Math.floor(j / 3) % 2) * 2) % 4 === 3 || j % 3 === 2;
    cv.set(x + i, y + j, brick ? hex("#7d4a3e") : i > w - 3 ? hex("#96564a") : hex("#b0695a"));
  }
  cv.rect(x - 1, y, w + 2, 2, C.stoneDark);
  cv.rect(x - 1, y - 2, w + 2, 2, C.snow); cv.rect(x, y - 3, w, 1, C.snow);
}
function house(o) {
  const { shape, style, wall, trim, door, roof, seed } = o;
  const W = 64, H = 78, cv = new Canvas(W, H), lit = new Canvas(W, H), cx = 31.5, ground = 76;
  const glows = [];
  if (shape === "eave") {
    const x0 = 5, x1 = 58, y0 = 46;
    chimney(cv, 43, 10, 7, 14);
    for (let y = y0; y <= ground; y++) for (let x = x0; x <= x1; x++) cv.set(x, y, wallPixel(style, x, y, x0, y0, wall, seed));
    for (let x = x0; x <= x1; x++) for (let j = 0; j < 4; j++) cv.set(x, y0 + 3 + j, mix(cv.get(x, y0 + 3 + j), C.outline, 0.3 - j * 0.06));
    if (style === "plaster") beams(cv, x0, y0 + 3, x1, ground - 3, trim[1]);
    cv.rect(x0, ground - 2, x1 - x0 + 1, 3, C.stoneDark);
    for (let x = x0; x <= x1; x += 5) cv.set(x, ground - 1, C.stone);
    windowAt(cv, lit, 10, 54, 12, 12, trim[2], [trim[0], trim[1]]);
    windowAt(cv, lit, 42, 54, 12, 12, trim[2], [trim[0], trim[1]]);
    doorAt(cv, 27, 57, 10, 19, door, trim[1]);
    glows.push([16, ground - 60], [48, ground - 60]);
    // roof slab: shingles below, deep snow above
    const top = 17, bottom = 49, half = (y) => 21 + ((y - top) / (bottom - top)) * 10.5;
    for (let y = top; y <= bottom; y++) for (let x = 0; x < W; x++) {
      if (Math.abs(x - cx) > half(y)) continue;
      const row = Math.floor((y - top) / 4), inRow = (y - top) % 4;
      cv.set(x, y, inRow === 3 || (x + row * 3) % 6 === 0 ? roof[1] : inRow === 0 ? roof[2] : roof[0]);
      if (y >= bottom - 1) cv.set(x, y, roof[1]);
      const snowLine = bottom - 8 + Math.round(noise(x, 0, 7, seed) * 5 - 2 + Math.sin(x * 0.7) * 1.2);
      if (y < snowLine) cv.set(x, y, y > snowLine - 3 ? C.snowShade : noise(x, y, 6, seed + 1) > 0.6 ? C.snowMid : C.snow);
    }
    for (let x = Math.ceil(cx - 21); x <= cx + 21; x++) { const bump = Math.round(noise(x, 3, 5, seed) * 2.4); for (let j = 1; j <= bump; j++) cv.set(x, top - j, C.snow); }
    icicles(cv, 1, 62, bottom + 1, seed);
  } else {
    const x0 = 7, x1 = 56, y0 = 44, peak = 16, slope = (y0 - peak) / 24.5;
    chimney(cv, 45, 14, 6, 18);
    const edge = (x) => peak + Math.abs(x - cx) * slope;
    for (let y = peak; y <= ground; y++) for (let x = x0; x <= x1; x++) {
      if (y < edge(x)) continue;
      cv.set(x, y, wallPixel(style, x, y, x0, peak, wall, seed));
    }
    if (style === "plaster") { beams(cv, x0, y0, x1, ground - 3, trim[1]); cv.line(cx - 12, y0, cx, peak + 12, trim[1]); cv.line(cx + 12, y0, cx, peak + 12, trim[1]); }
    cv.rect(x0, ground - 2, x1 - x0 + 1, 3, C.stoneDark);
    for (let x = x0; x <= x1; x += 5) cv.set(x, ground - 1, C.stone);
    windowAt(cv, lit, 12, 54, 11, 12, trim[2], [trim[0], trim[1]]);
    windowAt(cv, lit, 41, 54, 11, 12, trim[2], [trim[0], trim[1]]);
    windowAt(cv, lit, 28, 32, 8, 8, trim[2], null);
    doorAt(cv, 27, 57, 10, 19, door, trim[1]);
    glows.push([17, ground - 60], [46, ground - 60], [31, ground - 36]);
    // two roof planes following the gable, with overhang
    for (let x = 0; x < W; x++) {
      if (Math.abs(x - cx) > 31) continue;
      const e = Math.round(edge(x));
      for (let j = 0; j < 9; j++) {
        const y = e - 8 + j;
        cv.set(x, y, j < 5 ? (j === 4 ? C.snowShade : noise(x, y, 5, seed) > 0.62 ? C.snowMid : C.snow) : j === 8 ? roof[1] : (x + j) % 5 === 0 ? roof[1] : j === 5 ? roof[2] : roof[0]);
      }
      const bump = Math.round(noise(x, 9, 5, seed) * 2.2);
      for (let j = 1; j <= bump; j++) cv.set(x, e - 8 - j, C.snow);
    }
    icicles(cv, 1, 9, Math.round(edge(1)) + 1, seed); icicles(cv, 54, 62, Math.round(edge(62)) + 1, seed + 1);
  }
  // snow drifts against the wall
  [[6, 5, 2.5], [20, 4, 2], [44, 5, 2.2], [57, 5, 2.6]].forEach(([x, rx, ry]) => ball(cv, x, ground + 0.5, rx, ry, [C.snow, C.snowMid, C.snowShade]));
  for (let y = ground + 1; y < H; y++) for (let x = 0; x < W; x++) cv.clear(x, y);
  cv.outline(C.outline);
  return { cv, lit, glows };
}
function beams(cv, x0, y0, x1, y1, c) {
  cv.rect(x0, y0, x1 - x0 + 1, 2, c); cv.rect(x0, y1 - 1, x1 - x0 + 1, 2, c);
  for (const x of [x0, x0 + 1, x1 - 1, x1, 24, 25, 38, 39]) cv.rect(x, y0, 1, y1 - y0, c);
  cv.line(x0 + 2, y1 - 2, 23, y0 + 2, c); cv.line(40, y0 + 2, x1 - 2, y1 - 2, c);
}
const ROOF = {
  red: [hex("#c9483a"), hex("#96302d"), hex("#e37a63")], blue: [hex("#4a78c8"), hex("#33539a"), hex("#7aa3e6")],
  green: [hex("#3f8f6e"), hex("#2a6a55"), hex("#69b894")], purple: [hex("#8660bd"), hex("#614294"), hex("#aa8adb")],
  brown: [hex("#96603d"), hex("#6d4129"), hex("#bb8659")], slate: [hex("#5f6b85"), hex("#434c63"), hex("#8793ad")],
};
const WALL = {
  cream: [hex("#f1e3c4"), hex("#d6c19a"), hex("#fbf3df")], red: [hex("#c2584a"), hex("#96403a"), hex("#d97a66")],
  blue: [hex("#6f93c4"), hex("#4f6f9e"), hex("#94b3dc")], yellow: [hex("#e6c463"), hex("#bf9a44"), hex("#f4dc8e")],
  green: [hex("#7fae7a"), hex("#5c8a5e"), hex("#a3cb9c")], stone: [hex("#b3b9c6"), hex("#858da0"), hex("#d0d5de")],
  log: [hex("#a06c45"), hex("#6e452d"), hex("#c08a5c")], pink: [hex("#dba0ac"), hex("#b57886"), hex("#efc2ca")],
};
const TRIM = {
  white: [hex("#f3efe6"), hex("#bdb7aa"), hex("#fffdf6")], brown: [hex("#7a5038"), hex("#553524"), hex("#f1e6d0")],
  green: [hex("#3f7f5c"), hex("#2a5a42"), hex("#f3efe6")], red: [hex("#b8443b"), hex("#872f2c"), hex("#f6ecd9")], navy: [hex("#3d517e"), hex("#2a3a5e"), hex("#eef0f5")],
};
const HOUSES = [
  ["eave", "plank", "red", "white", hex("#f1e3c4"), "slate"], ["gable", "plaster", "cream", "brown", hex("#b8443b"), "red"],
  ["eave", "stone", "stone", "green", hex("#3f7f5c"), "green"], ["gable", "plank", "blue", "white", hex("#f4dc8e"), "slate"],
  ["eave", "plaster", "cream", "brown", hex("#3d517e"), "blue"], ["gable", "stone", "stone", "red", hex("#b8443b"), "brown"],
  ["eave", "plank", "yellow", "white", hex("#3f7f5c"), "brown"], ["gable", "plank", "green", "white", hex("#96302d"), "red"],
  ["eave", "plank", "pink", "white", hex("#8660bd"), "purple"], ["gable", "plaster", "cream", "navy", hex("#3d517e"), "blue"],
  ["eave", "stone", "stone", "navy", hex("#c9483a"), "purple"],
];
meta.houses = HOUSES.map(([shape, style, wall, trim, door, roof], i) => {
  const h = house({ shape, style, wall: WALL[wall], trim: TRIM[trim], door, roof: ROOF[roof], seed: 300 + i });
  sprites[`house_${i}`] = h.cv; sprites[`house_${i}_lit`] = h.lit;
  return { glows: h.glows, wall, roof };
});
(() => {
  const h = house({ shape: "eave", style: "log", wall: WALL.log, trim: TRIM.green, door: hex("#3f7f5c"), roof: ROOF.brown, seed: 777 });
  sprites.cabin = h.cv; sprites.cabin_lit = h.lit;
  const lights = new Canvas(64, 78);
  for (let x = 2; x <= 61; x += 4) { const c = BULBS[(x / 4) % BULBS.length | 0]; lights.set(x, 52, mix(c, C.snow, 0.45)); lights.set(x, 53, c); }
  sprites.cabin_lights = lights;
  meta.cabin = { glows: h.glows };
})();
const FONT = { T: ["###", ".#.", ".#.", ".#.", ".#."], R: ["##.", "#.#", "##.", "#.#", "#.#"], E: ["###", "#..", "##.", "#..", "###"], S: [".##", "#..", ".#.", "..#", "##."] };
function text(cv, str, x, y, c) {
  [...str].forEach((ch, n) => FONT[ch].forEach((row, j) => [...row].forEach((p, i) => { if (p === "#") cv.set(x + n * 4 + i, y + j, c); })));
}
(() => {
  const cv = new Canvas(48, 48), lit = new Canvas(48, 48), g = 46;
  cv.rect(4, 14, 3, g - 14, C.woodDark); cv.rect(41, 14, 3, g - 14, C.woodDark); cv.rect(4, 14, 1, g - 14, C.wood); cv.rect(41, 14, 1, g - 14, C.wood);
  for (let y = 31; y <= g; y++) for (let x = 3; x <= 44; x++) cv.set(x, y, (y - 31) % 5 === 4 ? C.woodDark : (x + Math.floor((y - 31) / 5) * 6) % 11 === 0 ? C.woodDark : C.wood);
  cv.rect(2, 29, 44, 3, C.woodPale); cv.rect(2, 31, 44, 1, C.woodLight);
  cv.rect(12, 34, 24, 9, C.cream); cv.frame(12, 34, 24, 9, C.woodDark); text(cv, "TREES", 15, 36, FIR.tones[2]);
  // a little potted fir and a coin tin on the counter
  cv.rect(7, 26, 4, 3, C.redDark); [[9, 19], [8, 21], [9, 21], [10, 21], [7, 23], [8, 23], [9, 23], [10, 23], [11, 23], [8, 24], [9, 24], [10, 24], [9, 25]].forEach(([x, y]) => cv.set(x, y, FIR.tones[(x + y) % 3]));
  cv.rect(36, 25, 5, 4, C.stone); cv.rect(36, 25, 5, 1, C.stoneLight); cv.set(38, 24, C.gold);
  for (let y = 5; y <= 17; y++) for (let x = 1; x <= 46; x++) {
    if (y > 14 && (x - 1) % 6 > 3 + (17 - y)) continue;
    cv.set(x, y, Math.floor((x - 1) / 4) % 2 ? (y > 12 ? hex("#e3dccd") : C.cream) : y > 12 ? C.redDark : C.red);
  }
  const awning = cv.crop(0, 0, 48, 12);
  snowTop(cv, (x) => 2 + (hash2(x, 1, 5) < 0.4 ? 1 : 0), (x, y) => y > 8);
  for (let x = 3; x <= 45; x += 6) { const c = BULBS[(x / 6 | 0) % BULBS.length]; lit.set(x, 18, mix(c, C.snow, 0.45)); lit.set(x, 19, c); }
  ball(cv, 4, g + 0.5, 4, 2, [C.snow, C.snowMid, C.snowShade]); ball(cv, 43, g + 0.5, 4, 2, [C.snow, C.snowMid, C.snowShade]);
  for (let x = 0; x < 48; x++) cv.clear(x, 47);
  cv.outline(C.outline);
  sprites.stand = cv; sprites.stand_lights = lit;
})();

// ---------------------------------------------------------------- props
(() => {
  const cv = new Canvas(14, 36), lit = new Canvas(14, 36), g = 34;
  cv.rect(6, 13, 2, g - 13, C.iron); cv.rect(6, 13, 1, g - 13, C.ironLight);
  cv.rect(4, g - 2, 6, 2, C.iron); cv.rect(5, g - 4, 4, 2, C.iron); cv.rect(5, 15, 4, 1, C.iron);
  cv.rect(3, 5, 8, 1, C.iron); cv.rect(4, 4, 6, 1, C.iron); cv.rect(6, 2, 2, 2, C.iron);
  cv.rect(4, 6, 6, 6, C.glassOff); cv.rect(4, 6, 1, 6, C.iron); cv.rect(9, 6, 1, 6, C.iron); cv.rect(4, 12, 6, 1, C.iron); cv.set(5, 7, C.glassGlint);
  for (let y = 6; y < 12; y++) for (let x = 5; x < 9; x++) lit.set(x, y, y < 8 ? C.warm2 : y < 10 ? C.warm1 : C.warm3);
  lit.set(6, 9, C.snow); lit.set(7, 9, C.snow);
  snowTop(cv, () => 1, (x, y) => y > 6);
  ball(cv, 6.5, g + 0.5, 5, 2, [C.snow, C.snowMid, C.snowShade]);
  for (let x = 0; x < 14; x++) cv.clear(x, 35);
  cv.outline(C.outline);
  sprites.lantern = cv; sprites.lantern_lit = lit;
})();
(() => {
  const cv = new Canvas(22, 28), lit = new Canvas(22, 28), tones = [C.snow, C.snowMid, C.snowShade];
  cv.ellipse(10, 25, 8, 2.4, C.shadow);
  ball(cv, 10, 20, 6.5, 5.5, tones); ball(cv, 10, 12, 4.8, 4.5, tones); ball(cv, 10, 6, 3.6, 3.5, tones);
  cv.rect(7, 1, 7, 3, C.iron); cv.rect(5, 3, 11, 1, C.iron); cv.rect(7, 2, 7, 1, C.red);
  cv.set(9, 5, C.iron); cv.set(12, 5, C.iron); cv.rect(10, 7, 3, 1, hex("#f08a2c")); cv.set(9, 8, C.iron); cv.set(11, 9, C.iron);
  cv.rect(6, 9, 9, 2, C.red); cv.rect(13, 10, 2, 4, C.redDark);
  cv.set(10, 12, C.iron); cv.set(10, 15, C.iron); cv.set(10, 19, C.iron);
  cv.line(5, 12, 1, 9, C.woodDark); cv.set(1, 11, C.woodDark); cv.line(15, 12, 18, 13, C.woodDark);
  cv.rect(17, 14, 4, 5, C.iron); cv.rect(18, 15, 2, 3, C.glassOff); cv.rect(18, 13, 2, 1, C.iron);
  lit.rect(18, 15, 2, 3, C.warm1); lit.set(18, 17, C.warm3); lit.set(19, 17, C.warm3);
  cv.outline(C.outline);
  sprites.snowman = cv; sprites.snowman_lit = lit;
})();
(() => {
  const cv = new Canvas(26, 15);
  cv.rect(2, 4, 22, 3, C.wood); cv.rect(2, 6, 22, 1, C.woodDark); cv.rect(2, 8, 22, 3, C.woodLight); cv.rect(2, 10, 22, 1, C.wood);
  cv.rect(3, 10, 2, 4, C.iron); cv.rect(21, 10, 2, 4, C.iron); cv.rect(3, 2, 2, 3, C.iron); cv.rect(21, 2, 2, 3, C.iron);
  snowTop(cv, (x) => 2, (x, y) => y > 8 && false);
  cv.outline(C.outline);
  sprites.bench = cv;
})();
(() => {
  const cv = new Canvas(26, 32), g = 30;
  cv.ellipse(12.5, g, 11, 2.4, C.shadow);
  for (let y = 20; y <= g; y++) for (let x = 3; x <= 22; x++) {
    const row = Math.floor((y - 20) / 4), bx = x + (row % 2) * 3;
    cv.set(x, y, (y - 20) % 4 === 3 || bx % 6 === 5 ? C.stoneDark : hash2(Math.floor(bx / 6), row, 5) < 0.4 ? C.stoneLight : C.stone);
  }
  cv.rect(4, 19, 18, 2, C.glassDark); cv.rect(3, 18, 20, 1, C.stoneLight);
  cv.rect(4, 6, 2, 13, C.woodDark); cv.rect(20, 6, 2, 13, C.woodDark); cv.rect(5, 11, 16, 1, C.wood); cv.rect(12, 12, 1, 4, C.woodPale); cv.rect(11, 15, 3, 3, C.wood);
  for (let y = 1; y <= 8; y++) for (let x = 1; x <= 24; x++) if (Math.abs(x - 12.5) <= 4 + y * 1.1) cv.set(x, y, y > 6 ? C.woodDark : (x + y) % 4 === 0 ? C.woodDark : C.wood);
  snowTop(cv, (x) => 2 + (hash2(x, 2, 8) < 0.5 ? 1 : 0), (x, y) => y > 6 && y < 17);
  cv.outline(C.outline);
  sprites.well = cv;
})();
(() => {
  const cv = new Canvas(24, 17);
  cv.ellipse(11.5, 15, 10, 2, C.shadow);
  const log = (x, y) => { cv.ellipse(x, y, 2.4, 2.4, C.wood); cv.ellipse(x, y, 1.4, 1.4, C.woodPale); cv.set(x, y, C.woodLight); };
  for (let i = 0; i < 4; i++) log(4 + i * 5, 12); for (let i = 0; i < 3; i++) log(6.5 + i * 5, 8); for (let i = 0; i < 2; i++) log(9 + i * 5, 4);
  snowTop(cv, () => 2, null);
  cv.outline(C.outline);
  sprites.woodpile = cv;
})();
(() => {
  const cv = new Canvas(18, 26);
  cv.rect(8, 6, 2, 19, C.woodDark); cv.rect(8, 6, 1, 19, C.wood);
  cv.rect(2, 7, 14, 5, C.woodPale); cv.rect(2, 11, 14, 1, C.wood); cv.rect(1, 9, 1, 1, C.woodPale); cv.rect(4, 9, 8, 1, C.woodDark); cv.set(3, 8, C.woodDark); cv.set(3, 10, C.woodDark);
  cv.rect(3, 14, 13, 4, C.woodPale); cv.rect(3, 17, 13, 1, C.wood); cv.rect(6, 16, 8, 1, C.woodDark); cv.set(14, 15, C.woodDark); cv.set(14, 17, C.woodDark);
  snowTop(cv, () => 1, null);
  ball(cv, 8.5, 25, 4, 1.6, [C.snow, C.snowMid, C.snowShade]);
  cv.outline(C.outline);
  sprites.signpost = cv;
})();
(() => {
  const cv = new Canvas(8, 40);
  cv.rect(3, 3, 2, 36, C.woodDark); cv.rect(3, 3, 1, 36, C.wood); cv.rect(2, 2, 4, 2, C.woodDark);
  snowTop(cv, () => 2, null);
  ball(cv, 3.5, 39, 3.4, 1.5, [C.snow, C.snowMid, C.snowShade]);
  cv.outline(C.outline);
  sprites.pole = cv;
})();
(() => {
  const cv = new Canvas(10, 20), lit = new Canvas(10, 20);
  cv.rect(4, 2, 1, 17, C.woodDark); cv.rect(4, 2, 4, 1, C.woodDark); cv.rect(7, 3, 1, 2, C.iron);
  cv.rect(5, 5, 5, 7, C.redDark); cv.rect(6, 5, 3, 7, C.red); cv.rect(5, 5, 5, 1, C.iron); cv.rect(5, 11, 5, 1, C.iron); cv.set(7, 12, C.gold); cv.set(7, 13, C.gold);
  for (let y = 6; y < 11; y++) for (let x = 5; x < 10; x++) lit.set(x, y, x === 7 ? C.warm1 : x === 6 || x === 8 ? C.warm2 : hex("#ff8a4d"));
  cv.outline(C.outline);
  sprites.paperlantern = cv; sprites.paperlantern_lit = lit;
})();
function stringLights(w, sag, posts) {
  const cv = new Canvas(w, sag + 8);
  for (let x = 0; x < w; x++) {
    const span = posts ? w / posts : w, t = (x % span) / span, y = 2 + Math.round(Math.sin(t * Math.PI) * sag);
    cv.set(x, y, withAlpha(C.iron, 200));
    if (x % 6 === 3) { const c = BULBS[(x / 6 | 0) % BULBS.length]; cv.set(x, y + 1, mix(c, C.snow, 0.5)); cv.set(x, y + 2, c); }
  }
  return cv;
}
sprites.fence_lights = stringLights(48, 3, 3);
sprites.span_lights = stringLights(176, 7, 2);
(() => {
  const cv = new Canvas(44, 62);
  for (let y = 2; y < 60; y += 5) for (const x of [1, 42]) { const c = BULBS[(y / 5 | 0) % BULBS.length]; cv.set(x, y, mix(c, C.snow, 0.5)); cv.set(x, y + 1, c); }
  sprites.bridge_lights = cv;
})();

// ---------------------------------------------------------------- people
const PERSON = {
  down: [
    "......OPPO......", ".....OPPPPO.....", "....OOHHHHOO....", "...OHHHHHHHHO...", "...OHHHHHHHHO...", "..OhhhhhhhhhhO..",
    "..OKSSSSSSSSKO..", "..OSSESSSSESSO..", "..OSSSSSSSSSSO..", "...OSsSSSSsSO...", "..ORRRRRRRRRRO..", ".OCORRRRRRRROCO.",
    ".OCCCCCRRCCCCCO.", ".OCCCCCRRCCCCCO.", ".OMCCCCCCCCCCMO.", ".OMCCCCccCCCCMO.", "..OCCCCccCCCCO..", "..OWWWWWWWWWWO..",
  ],
  up: [
    "......OPPO......", ".....OPPPPO.....", "....OOHHHHOO....", "...OHHHHHHHHO...", "...OHHHHHHHHO...", "..OhhhhhhhhhhO..",
    "..OHHHHHHHHHHO..", "..OHHHHHHHHHHO..", "..OKKKKKKKKKKO..", "...OKKKKKKKKO...", "..ORRRRRRRRRRO..", ".OCORRRRRRRROCO.",
    ".OCCCCRRCCCCCCO.", ".OCCCCRRCCCCCCO.", ".OMCCCCCCCCCCMO.", ".OMCCCCCCCCCCMO.", "..OCCCCCCCCCCO..", "..OWWWWWWWWWWO..",
  ],
  side: [
    ".....OPPO.......", "....OPPPPO......", "....OOHHHHO.....", "...OHHHHHHHO....", "...OHHHHHHHHO...", "...OhhhhhhhhhO..",
    "...OKKSSSSSSO...", "...OKSSSSESSO...", "...OKSSSSSSSSO..", "....OSSSSSSSO...", "...ORRRRRRRRO...", "..ORRCCCCCCCO...",
    "..ORCCCCCCCCO...", "...OCCCCMMCCO...", "...OCCCCMMCCO...", "...OCCCCCCCCO...", "...OCCCCCCCCO...", "...OWWWWWWWWO...",
  ],
};
const LEGS = {
  front: [
    ["...OLLLOOLLLO...", "...OLLO..OLLO...", "...OBBO..OBBO...", "...OOOO..OOOO..."],
    ["...OLLLOOLLLO...", "...OBBO..OLLO...", "...OOOO..OBBO...", ".........OOOO..."],
    ["...OLLLOOLLLO...", "...OLLO..OBBO...", "...OBBO..OOOO...", "...OOOO........."],
  ],
  side: [
    ["....OLLLLLLO....", "....OLLOOLLO....", "....OBBOOBBBO...", "....OOOOOOOOO..."],
    ["....OLLLLLLO....", "...OLLO..OLLO...", "..OBBO....OBBO..", "..OOOO....OOOO.."],
    ["....OLLLLLLO....", ".....OLLLLO.....", ".....OBBBBO.....", ".....OOOOOO....."],
  ],
};
const TOPHAT = ["................", "....OOOOOOOO....", "....OHHHHHHO....", "....OHHHHHHO....", "....OhhhhhhO....", "..OOHHHHHHHHOO.."];
function outfit(hat, band, coat, scarf, hair, skin, pants, mitten) {
  const c = hex(coat);
  return { O: C.outline, P: C.snow, H: hex(hat), h: hex(band), K: hex(hair), S: hex(skin), s: mix(hex(skin), hex("#e8756a"), 0.45), E: hex("#2a2233"),
    R: hex(scarf), C: c, c: mix(c, C.outline, 0.3), M: hex(mitten || hat), W: hex("#f4f0e6"), L: hex(pants), B: hex("#5a3b2a") };
}
const PLAYER = outfit("#d8483e", "#f4f0e6", "#3f8a5c", "#f5c93c", "#7a4a2c", "#f6cfa8", "#3d4f80");
for (const dir of ["down", "up", "side"]) for (let f = 0; f < 3; f++) {
  sprites[`player_${dir}_${f}`] = ascii([...PERSON[dir], ...(dir === "side" ? LEGS.side : LEGS.front)[f]], PLAYER);
}
const VILLAGERS = [
  ["Marta", "#4a78c8", "#f4f0e6", "#b8443b", "#f4f0e6", "#d9a441", "#f6cfa8", "#5a4a6a"],
  ["Olle", "#3f7f5c", "#f5c93c", "#8a5a3c", "#d8483e", "#4a3229", "#e9b98c", "#3d4f80"],
  ["Ingrid", "#8660bd", "#efc2ca", "#e6c463", "#8660bd", "#c96a3a", "#f6cfa8", "#6a4a3c"],
  ["Sven", "#5f6b85", "#c3cad6", "#3d517e", "#f5c93c", "#b9b9c2", "#f1c7a0", "#3a3a48"],
  ["Astrid", "#d9709a", "#f4f0e6", "#f1e3c4", "#d9709a", "#2a2233", "#c98f66", "#5a4a6a"],
  ["Nils", "#c9483a", "#3f7f5c", "#4f6f9e", "#f4f0e6", "#7a4a2c", "#f6cfa8", "#3a3a48"],
  ["Greta", "#f5c93c", "#b8443b", "#3f8f6e", "#f5c93c", "#e8e2d2", "#f1c7a0", "#6a4a3c"],
  ["Emil", "#3d517e", "#7aa3e6", "#96603d", "#3f7f5c", "#d9a441", "#e9b98c", "#3d4f80"],
  ["Selma", "#3f8f6e", "#f4f0e6", "#c2584a", "#f4f0e6", "#4a3229", "#a8704c", "#5a4a6a"],
  ["Anton", "#96603d", "#f1e3c4", "#5f6b85", "#c9483a", "#2a2233", "#f6cfa8", "#3a3a48"],
  ["Freja", "#e37a63", "#f4f0e6", "#6f93c4", "#f5c93c", "#c96a3a", "#f6cfa8", "#6a4a3c"],
];
meta.villagers = VILLAGERS.map(([name, ...o], i) => { sprites[`villager_${i}`] = ascii([...PERSON.down, ...LEGS.front[0]], outfit(...o)); return name; });
sprites.mayor = ascii([...TOPHAT, ...PERSON.down.slice(6), ...LEGS.front[0]], outfit("#2a2233", "#c9483a", "#3a3a48", "#f5c93c", "#b9b9c2", "#f1c7a0", "#2a2233", "#f4f0e6"));
sprites.sled = ascii([
  "....................", "..OOOOOOOOOOOOOOO...", ".OWWWWWWWWWWWWWWWO..", ".OwwwwwwwwwwwwwwwO.R", "..OOOOOOOOOOOOOOO.R.", "...O.....O.....O.R..", ".RRRRRRRRRRRRRRRRR..",
], { O: C.outline, W: C.woodPale, w: C.wood, R: C.red });

// ---------------------------------------------------------------- icons, markers, effects
function bubble(draw) {
  const cv = new Canvas(16, 18);
  cv.rect(1, 0, 14, 14, C.outline); cv.rect(0, 1, 16, 12, C.outline); cv.rect(1, 1, 14, 12, C.snow);
  cv.rect(6, 14, 4, 1, C.outline); cv.rect(7, 15, 2, 1, C.outline); cv.rect(7, 13, 2, 2, C.snow); cv.set(7, 16, C.outline);
  draw(cv);
  return cv;
}
const miniFir = (cv, x, y) => { [[0, 0], [-1, 1], [0, 1], [1, 1], [-1, 2], [0, 2], [1, 2], [-2, 3], [-1, 3], [0, 3], [1, 3], [2, 3], [-2, 4], [-1, 4], [0, 4], [1, 4], [2, 4], [-3, 5], [-2, 5], [-1, 5], [0, 5], [1, 5], [2, 5], [3, 5]].forEach(([i, j]) => cv.set(x + i, y + j, FIR.tones[i > 0 ? 2 : 1])); cv.rect(x, y + 6, 1, 2, C.woodDark); };
sprites.marker_tree = bubble((cv) => miniFir(cv, 8, 3));
sprites.marker_talk = bubble((cv) => { cv.rect(7, 3, 2, 5, hex("#e8792b")); cv.rect(7, 9, 2, 2, hex("#e8792b")); });
sprites.marker_home = bubble((cv) => { cv.rect(5, 7, 6, 4, C.red); [[8, 3], [7, 4], [8, 4], [6, 5], [7, 5], [8, 5], [9, 5], [5, 6], [6, 6], [7, 6], [8, 6], [9, 6], [10, 6]].forEach(([x, y]) => cv.set(x, y, C.iron)); cv.rect(7, 9, 2, 2, C.warm2); });
sprites.marker_star = bubble((cv) => star(cv, 8, 9, false));
sprites.arrow = ascii(["OO.......", "OWOO.....", "OWWWOO...", "OWWWWWOO.", "OWWWWWWWO", "OWWWWWOO.", "OWWWOO...", "OWOO.....", "OO......."], { O: C.outline, W: C.snow });
sprites.icon_coin = ascii(["..OOOO..", ".OYYYYO.", "OYWYYyYO", "OYWYYyYO", "OYYYYyYO", "OYYyyYYO", ".OYYYYO.", "..OOOO.."], { O: hex("#8a5a14"), Y: C.gold, W: C.warm1, y: hex("#d79a22") });
sprites.icon_heart = ascii([".OO...OO.", "ORROOORRO", "ORWRRRRRO", "ORRRRRRRO", ".ORRRRRO.", "..ORRRO..", "...ORO...", "....O...."], { O: C.outline, R: hex("#e8556a"), W: hex("#ffc2cc") });
sprites.icon_bulb = ascii([".OOOOO.", "OYYYYYO", "OYWYYYO", "OYWYYYO", "OYYYYYO", ".OYYYO.", "..OGO..", "..OGO..", "...O..."], { O: C.outline, Y: C.warm2, W: C.snow, G: C.stone });
sprites.icon_fir = (() => { const cv = new Canvas(9, 10); miniFir(cv, 4, 1); return cv; })();
sprites.flake = ascii([".W.", "WWW", ".W."], { W: C.snow });
sprites.dot = ascii(["WW", "WW"], { W: C.snow });
sprites.sparkle = ascii(["..W..", "..W..", "WWWWW", "..W..", "..W.."], { W: C.warm1 });
sprites.glow = (() => {
  const n = 64, cv = new Canvas(n, n), bayer = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
  for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
    const d = Math.hypot(x - 31.5, y - 31.5) / 32;
    if (d >= 1) continue;
    const a = Math.pow(1 - d, 1.8) * 0.85, steps = 7, q = a * steps, base = Math.floor(q);
    const level = (base + (q - base > (bayer[(y % 4) * 4 + (x % 4)] + 0.5) / 16 ? 1 : 0)) / steps;
    if (level > 0) cv.set(x, y, [255, 255, 255, Math.round(level * 255)]);
  }
  return cv;
})();

module.exports = { sprites, meta, C, FIR, snowTop, ball };

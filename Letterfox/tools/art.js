// Generates every Letterfox sprite as a PNG, plus the app icon and a preview sheet.
// Usage: node art.js <spritesDir> <iconPath> <previewPath>
const fs = require("fs");
const zlib = require("zlib");
const path = require("path");

const [SPRITES, ICON, PREVIEW] = process.argv.slice(2);

// ---------- canvas + png ----------
function hex(h, a = 255) {
  return [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16), a];
}
class Canvas {
  constructor(w, h) { this.w = w; this.h = h; this.d = new Uint8Array(w * h * 4); }
  inside(x, y) { return x >= 0 && y >= 0 && x < this.w && y < this.h; }
  get(x, y) { const i = (y * this.w + x) * 4; return this.inside(x, y) ? [this.d[i], this.d[i + 1], this.d[i + 2], this.d[i + 3]] : [0, 0, 0, 0]; }
  set(x, y, c) {
    if (!this.inside(x, y)) return;
    const i = (y * this.w + x) * 4, a = c[3] / 255;
    if (a >= 1 || this.d[i + 3] === 0) { this.d.set(c, i); return; }
    for (let k = 0; k < 3; k++) this.d[i + k] = Math.round(c[k] * a + this.d[i + k] * (1 - a));
    this.d[i + 3] = Math.max(this.d[i + 3], c[3]);
  }
  rect(x, y, w, h, c) { for (let j = y; j < y + h; j++) for (let i = x; i < x + w; i++) this.set(i, j, c); }
  frame(x, y, w, h, c) { this.rect(x, y, w, 1, c); this.rect(x, y + h - 1, w, 1, c); this.rect(x, y, 1, h, c); this.rect(x + w - 1, y, 1, h, c); }
  blit(src, dx, dy, scale = 1) {
    for (let y = 0; y < src.h; y++) for (let x = 0; x < src.w; x++) {
      const c = src.get(x, y);
      if (c[3] === 0) continue;
      for (let j = 0; j < scale; j++) for (let i = 0; i < scale; i++) this.set(dx + x * scale + i, dy + y * scale + j, c);
    }
  }
  flipX() { const o = new Canvas(this.w, this.h); for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) o.set(this.w - 1 - x, y, this.get(x, y)); return o; }
}
const crcTable = new Uint32Array(256).map((_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
function crc(buf) { let c = 0xffffffff; for (const b of buf) c = crcTable[(c ^ b) & 0xff] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; }
function chunk(type, data) {
  const body = Buffer.concat([Buffer.from(type), data]);
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const sum = Buffer.alloc(4); sum.writeUInt32BE(crc(body));
  return Buffer.concat([len, body, sum]);
}
function writePng(file, cv, alpha = true) {
  const bpp = alpha ? 4 : 3;
  const raw = Buffer.alloc(cv.h * (cv.w * bpp + 1));
  for (let y = 0; y < cv.h; y++) {
    const row = y * (cv.w * bpp + 1);
    for (let x = 0; x < cv.w; x++) for (let k = 0; k < bpp; k++) raw[row + 1 + x * bpp + k] = cv.d[(y * cv.w + x) * 4 + k];
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(cv.w, 0); ihdr.writeUInt32BE(cv.h, 4); ihdr[8] = 8; ihdr[9] = alpha ? 6 : 2;
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk("IHDR", ihdr), chunk("IDAT", zlib.deflateSync(raw, { level: 9 })), chunk("IEND", Buffer.alloc(0))]));
}
function rng(seed) { let a = seed >>> 0; return () => { a = (a + 0x6d2b79f5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }

const sprites = {};

// ---------- palette ----------
const P = {
  grass: hex("#6cb548"), grassDark: hex("#559c3d"), grassLight: hex("#86c95a"),
  path: hex("#dcb87c"), pathDark: hex("#c49a5c"), pathLight: hex("#ead09a"), pathRim: hex("#a9814a"),
  water: hex("#4aa6dc"), waterLight: hex("#8fd0f0"), waterRim: hex("#2c6fa6"), foam: hex("#c9ecf8"),
  outline: hex("#3a2a22"), wood: hex("#8a5a34"), woodDark: hex("#6b4226"),
  leaf: [hex("#9bd65c"), hex("#67b443"), hex("#448f3c"), hex("#2f6d3a")], leafOutline: hex("#1f4a2e"),
  pine: [hex("#6fbf73"), hex("#3f9a63"), hex("#2c7a58"), hex("#1f5c4b")], pineOutline: hex("#163f38"),
  wall: hex("#f3e2b8"), wallDark: hex("#dcc594"), wallShade: hex("#c4ab7c"),
  glass: hex("#9fd8ee"), glint: hex("#ffffff"), stone: hex("#d3d7da"), stoneDark: hex("#aab0b6"),
  paper: hex("#fff6dd"), paperDark: hex("#d9c79a"), white: hex("#ffffff"),
};

// ---------- ground tiles ----------
function grassPixel(x, y) {
  // Deterministic speckle so fringes on path and water tiles match plain grass.
  const n = (x * 7 + y * 13 + ((x * y) % 5) * 3) % 23;
  return n === 0 ? P.grassDark : n === 11 ? P.grassLight : P.grass;
}
function grassTile(variant) {
  const cv = new Canvas(16, 16), r = rng(100 + variant);
  for (let y = 0; y < 16; y++) for (let x = 0; x < 16; x++) cv.set(x, y, grassPixel(x, y));
  for (let i = 0; i < 5; i++) {
    const x = 1 + Math.floor(r() * 13), y = 1 + Math.floor(r() * 12);
    cv.set(x, y, P.grassDark); cv.set(x, y + 1, P.grassDark); cv.set(x + 1, y + 1, P.grassLight); cv.set(x + 1, y, P.grassLight);
  }
  if (variant === 2) {
    const petals = [hex("#ffffff"), hex("#ffc6dd"), hex("#fff09a")];
    [[4, 4], [11, 9], [6, 12]].forEach(([x, y], i) => {
      const c = petals[i];
      cv.set(x, y - 1, c); cv.set(x - 1, y, c); cv.set(x + 1, y, c); cv.set(x, y + 1, c);
      cv.set(x, y, hex("#f2a531"));
    });
  }
  return cv;
}
// mask bits: 1 = north neighbour is the same ground, 2 = east, 4 = south, 8 = west.
function edgeDistance(x, y, mask) {
  const wob = (k) => [2, 3, 2, 2, 1, 2, 3, 3, 2, 1, 2, 2, 3, 2, 2, 3][k];
  const openN = !(mask & 1), openE = !(mask & 2), openS = !(mask & 4), openW = !(mask & 8);
  let d = 99;
  const dN = y - wob(x) + 2, dS = 15 - y - wob(15 - x) + 2, dW = x - wob(y) + 2, dE = 15 - x - wob(15 - y) + 2;
  if (openN) d = Math.min(d, dN);
  if (openS) d = Math.min(d, dS);
  if (openW) d = Math.min(d, dW);
  if (openE) d = Math.min(d, dE);
  const corner = (a, b) => { d = Math.min(d, a + b - 4); };
  if (openN && openW) corner(y, x);
  if (openN && openE) corner(y, 15 - x);
  if (openS && openW) corner(15 - y, x);
  if (openS && openE) corner(15 - y, 15 - x);
  return d;
}
function pathTile(mask) {
  const cv = new Canvas(16, 16), r = rng(7);
  const speck = [];
  for (let i = 0; i < 14; i++) speck.push([Math.floor(r() * 16), Math.floor(r() * 16), r() < 0.5 ? P.pathDark : P.pathLight]);
  for (let y = 0; y < 16; y++) for (let x = 0; x < 16; x++) {
    const d = edgeDistance(x, y, mask);
    cv.set(x, y, d < 2 ? grassPixel(x, y) : d === 2 ? P.pathRim : d === 3 ? P.pathDark : P.path);
  }
  for (const [x, y, c] of speck) if (edgeDistance(x, y, mask) > 3) cv.set(x, y, c);
  return cv;
}
function waterTile(mask, frame) {
  const cv = new Canvas(16, 16);
  for (let y = 0; y < 16; y++) for (let x = 0; x < 16; x++) {
    const d = edgeDistance(x, y, mask);
    cv.set(x, y, d < 2 ? grassPixel(x, y) : d === 2 ? P.waterRim : d === 3 ? (frame ? P.water : P.foam) : d === 4 && frame ? P.foam : P.water);
  }
  [[2, 4, 4], [9, 8, 5], [4, 12, 3]].forEach(([x, y, len]) => {
    for (let i = 0; i < len; i++) {
      const px = (x + i + frame * 4) % 16;
      if (edgeDistance(px, y, mask) > 5) cv.set(px, y, P.waterLight);
    }
  });
  return cv;
}
for (let v = 0; v < 3; v++) sprites[`grass_${v}`] = grassTile(v);
for (let m = 0; m < 16; m++) {
  sprites[`path_${m}`] = pathTile(m);
  sprites[`water_${m}_0`] = waterTile(m, 0);
  sprites[`water_${m}_1`] = waterTile(m, 1);
}

// ---------- trees ----------
function shadow(cv, cx, cy, rx, ry) {
  for (let y = cy - ry; y <= cy + ry; y++) for (let x = cx - rx; x <= cx + rx; x++)
    if (((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1) cv.set(x, y, [20, 40, 30, 80]);
}
function shadeBlob(cv, inside, tone, colors, outline) {
  for (let y = 0; y < cv.h; y++) for (let x = 0; x < cv.w; x++) {
    if (!inside(x, y)) continue;
    const edge = !inside(x - 1, y) || !inside(x + 1, y) || !inside(x, y - 1) || !inside(x, y + 1);
    if (edge) { cv.set(x, y, outline); continue; }
    const t = tone(x, y);
    cv.set(x, y, colors[t < -0.4 ? 0 : t < 0.15 ? 1 : t < 0.6 ? 2 : 3]);
  }
}
function roundTree() {
  const cv = new Canvas(32, 44);
  shadow(cv, 16, 40, 11, 3);
  cv.rect(13, 28, 6, 13, P.outline); cv.rect(14, 28, 4, 12, P.wood); cv.rect(17, 28, 1, 12, P.woodDark);
  cv.set(12, 40, P.outline); cv.set(19, 40, P.outline);
  const blobs = [[16, 14, 12], [8, 20, 7], [24, 20, 7], [16, 23, 9], [10, 11, 6], [22, 11, 6]];
  const inside = (x, y) => blobs.some(([cx, cy, r]) => (x - cx) ** 2 + (y - cy) ** 2 <= r * r);
  const tone = (x, y) => ((x - 16) * 0.55 + (y - 16) * 0.85) / 13 + 0.28 * Math.sin(x * 1.1 + y * 0.4) * Math.cos(y * 0.9 - x * 0.3);
  shadeBlob(cv, inside, tone, P.leaf, P.leafOutline);
  return cv;
}
function pineTree() {
  const cv = new Canvas(32, 48);
  shadow(cv, 16, 44, 9, 3);
  cv.rect(14, 36, 5, 9, P.outline); cv.rect(15, 36, 3, 8, P.wood); cv.set(17, 38, P.woodDark); cv.set(17, 41, P.woodDark);
  const tiers = [[2, 14, 8], [10, 25, 11], [20, 38, 14]]; // top y, bottom y, half width at bottom
  const inside = (x, y) => tiers.some(([t, b, hw]) => y >= t && y <= b && Math.abs(x - 15.5) <= 1 + ((y - t) / (b - t)) * hw);
  const tone = (x, y) => {
    const tier = tiers.find(([t, b]) => y >= t && y <= b && true) || tiers[2];
    const lower = tiers.filter(([t, b]) => y >= t && y <= b).pop() || tier;
    return (x - 15.5) / 11 + ((y - lower[0]) / (lower[1] - lower[0])) * 0.9 - 0.5 + 0.15 * Math.sin(x * 1.7 + y);
  };
  shadeBlob(cv, inside, tone, P.pine, P.pineOutline);
  return cv;
}
sprites.tree_0 = roundTree();
sprites.tree_1 = pineTree();

// ---------- buildings ----------
function envelope(cv, x, y, w, h) {
  cv.rect(x, y, w, h, P.paper); cv.frame(x, y, w, h, P.outline);
  const mid = Math.floor(w / 2);
  for (let i = 1; i < mid; i++) { cv.set(x + i, y + i, P.outline); cv.set(x + w - 1 - i, y + i, P.outline); }
  if (w % 2) cv.set(x + mid, y + mid, P.outline);
}
function roof(cv, top, bottom, topHalf, bottomHalf, c) {
  const [main, dark, light] = c;
  const half = (y) => topHalf + ((y - top) / (bottom - top)) * (bottomHalf - topHalf);
  const inside = (x, y) => y >= top && y <= bottom && Math.abs(x - 23.5) <= half(y);
  for (let y = top; y <= bottom; y++) for (let x = 0; x < 48; x++) {
    if (!inside(x, y)) continue;
    const edge = !inside(x - 1, y) || !inside(x + 1, y) || !inside(x, y - 1) || !inside(x, y + 1);
    const row = Math.floor((y - top) / 4), inRow = (y - top) % 4;
    let col = main;
    if (inRow === 3) col = dark;
    else if ((x + row * 3) % 6 === 0) col = dark;
    else if (inRow === 0 && y > top + 1) col = light;
    if (y <= top + 2) col = light;
    if (y >= bottom - 1) col = dark;
    cv.set(x, y, edge ? P.outline : col);
  }
}
function window(cv, x, y) {
  cv.rect(x, y, 9, 9, P.woodDark); cv.rect(x + 1, y + 1, 7, 7, P.glass);
  cv.rect(x + 4, y + 1, 1, 7, P.woodDark); cv.rect(x + 1, y + 4, 7, 1, P.woodDark);
  cv.set(x + 2, y + 2, P.glint); cv.set(x + 6, y + 6, P.glint);
  cv.rect(x - 1, y + 9, 11, 2, P.wood);
  for (let i = 0; i < 11; i += 2) cv.set(x - 1 + i, y + 9, i % 4 === 0 ? hex("#ff8fb0") : hex("#5fae3f"));
}
function house(roofColors) {
  const cv = new Canvas(48, 56);
  shadow(cv, 24, 53, 22, 2);
  cv.rect(31, 2, 7, 12, P.outline); cv.rect(32, 3, 5, 11, P.stoneDark); cv.rect(32, 3, 5, 2, P.stone);
  cv.rect(4, 29, 40, 25, P.outline);
  cv.rect(5, 30, 38, 23, P.wall);
  for (let y = 34; y < 52; y += 4) cv.rect(5, y, 38, 1, P.wallDark);
  cv.rect(5, 30, 38, 3, P.wallShade);
  cv.rect(5, 51, 38, 2, P.stoneDark);
  window(cv, 8, 36); window(cv, 31, 36);
  cv.rect(19, 37, 10, 17, P.outline); cv.rect(20, 38, 8, 15, P.wood);
  cv.rect(20, 38, 8, 1, P.woodDark); cv.rect(23, 39, 1, 14, P.woodDark); cv.set(26, 46, hex("#f5d04c"));
  roof(cv, 7, 31, 15, 23.5, roofColors);
  return cv;
}
const ROOFS = [
  [hex("#d2553f"), hex("#a53a30"), hex("#e9806a")],
  [hex("#4f7fd0"), hex("#3a5ea6"), hex("#7ba6e8")],
  [hex("#8a5fc4"), hex("#66429a"), hex("#ae8ae0")],
  [hex("#e3a93a"), hex("#b9802a"), hex("#f4cb6a")],
  [hex("#d9709a"), hex("#ad4f78"), hex("#eea0c0")],
];
ROOFS.forEach((c, i) => { sprites[`house_${i}`] = house(c); });
function postOffice() {
  const cv = new Canvas(48, 56);
  shadow(cv, 24, 53, 22, 2);
  cv.rect(4, 29, 40, 25, P.outline);
  cv.rect(5, 30, 38, 23, P.stone);
  for (let y = 33; y < 52; y += 4) for (let x = 6 + ((y - 33) % 8 ? 4 : 0); x < 42; x += 8) cv.rect(x, y, 3, 1, P.stoneDark);
  cv.rect(5, 30, 38, 3, P.stoneDark);
  window(cv, 7, 36);
  cv.rect(17, 36, 14, 18, P.outline); cv.rect(18, 37, 12, 16, hex("#3f6fb5"));
  cv.rect(24, 37, 1, 16, P.outline); cv.set(22, 45, hex("#f5d04c")); cv.set(26, 45, hex("#f5d04c"));
  cv.rect(18, 37, 12, 1, hex("#2f548c"));
  // red mailbox
  cv.rect(37, 47, 2, 7, P.outline);
  cv.rect(34, 40, 8, 8, P.outline); cv.rect(35, 41, 6, 6, hex("#d2453f")); cv.rect(35, 41, 6, 1, hex("#ec7a6c")); cv.rect(36, 44, 4, 1, P.outline);
  roof(cv, 7, 31, 15, 23.5, [hex("#3a8f7a"), hex("#286a5c"), hex("#62b8a0")]);
  cv.rect(15, 13, 18, 13, P.outline); cv.rect(16, 14, 16, 11, P.paperDark);
  envelope(cv, 18, 16, 12, 7);
  return cv;
}
sprites.post = postOffice();

// ---------- markers and icons ----------
function bubble(drawInside) {
  const cv = new Canvas(16, 18);
  cv.rect(1, 0, 14, 14, P.outline); cv.rect(0, 1, 16, 12, P.outline);
  cv.rect(1, 1, 14, 12, P.white);
  cv.rect(6, 14, 4, 1, P.outline); cv.rect(7, 15, 2, 1, P.outline); cv.rect(7, 13, 2, 1, P.white); cv.rect(7, 14, 2, 1, P.white);
  cv.set(7, 16, P.outline);
  drawInside(cv);
  return cv;
}
sprites.marker_letter = bubble((cv) => envelope(cv, 3, 3, 10, 7));
sprites.marker_post = bubble((cv) => { cv.rect(7, 3, 2, 5, hex("#e8792b")); cv.rect(7, 9, 2, 2, hex("#e8792b")); });
(() => {
  const cv = new Canvas(10, 8); envelope(cv, 0, 0, 10, 8); sprites.icon_letter = cv;
  const coin = new Canvas(8, 8);
  for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) {
    const d = (x - 3.5) ** 2 + (y - 3.5) ** 2;
    if (d <= 16.5) coin.set(x, y, d > 9.5 ? hex("#8a5a14") : hex("#f5c93c"));
  }
  coin.set(2, 2, P.white); coin.set(3, 2, hex("#fff2a8")); coin.set(2, 3, hex("#fff2a8")); coin.rect(4, 5, 2, 1, hex("#d79a22")); coin.set(5, 4, hex("#d79a22"));
  sprites.icon_coin = coin;
  const arrow = new Canvas(9, 9);
  ["OO.......","OWOO.....","OWWWOO...","OWWWWWOO.","OWWWWWWWO","OWWWWWOO.","OWWWOO...","OWOO.....","OO......."].forEach((row, y) => [...row].forEach((ch, x) => { if (ch !== ".") arrow.set(x, y, ch === "W" ? P.white : P.outline); }));
  sprites.arrow = arrow;
})();

// ---------- characters (16x16 ASCII) ----------
function ascii(rows, pal) {
  const cv = new Canvas(16, rows.length);
  rows.forEach((row, y) => {
    if (row.length !== 16) throw new Error(`row ${y} is ${row.length} wide: "${row}"`);
    [...row].forEach((ch, x) => { if (ch !== ".") { if (!pal[ch]) throw new Error("no colour " + ch); cv.set(x, y, pal[ch]); } });
  });
  return cv;
}
const FOX = { O: hex("#3b2318"), F: hex("#ea7d2c"), f: hex("#c65d20"), W: hex("#fdf0dc"), B: hex("#1c1412"), b: hex("#3f6fb5"), p: hex("#f4a6a0") };
const foxDown = [
  "..OO........OO..",
  ".OFFO......OFFO.",
  ".OFpFOOOOOOFpFO.",
  ".OFFFFFFFFFFFFO.",
  ".OFFFFFFFFFFFFO.",
  ".OFFBFFFFFFBFFO.",
  ".OWWBFFFFFFBWWO.",
  "..OWWWWBBWWWWO..",
  "...OOWWWWWWOO...",
  "....ObFWWFFO....",
  "...OFFbWWFFFO...",
  "...OFFFbWbbFO...",
  "...OFFFFbbbFO...",
  "....OFFOOFFO....",
];
const foxUp = [
  "..OO........OO..",
  ".OFFO......OFFO.",
  ".OFfFOOOOOOFfFO.",
  ".OFFFFFFFFFFFFO.",
  ".OFFFFFFFFFFFFO.",
  ".OFFFFFFFFFFFFO.",
  ".OFFFFFFFFFFFFO.",
  "..OFFFFFFFFFFO..",
  "...OOFFFFFFOO...",
  "....OFFFFFbO....",
  "...OFFFFFbFFO...",
  "...OFbbfffFFO...",
  "...OFbbfWWfFO...",
  "....OFFOWWOO....",
];
const foxSide = [
  "........OO..OO..",
  ".......OFFOOFFO.",
  ".......OFpFFFFO.",
  ".......OFFFFFFOO",
  ".......OFFFFBFFO",
  ".......OFFFFFWWB",
  ".......OWWWWWWO.",
  "........OOWWOO..",
  ".OO.....OFFFO...",
  "OWWO...ObFFFO...",
  "OWFFO.OFFbFFO...",
  ".OFFFOOFFFbbO...",
  "..OFFFFFFFbbO...",
  "...OOFFOOFFO....",
];
const feetWide = [["....OBBOOBBO....", ".....OO..OO....."], ["....OBBO.OO.....", ".....OO........."], [".....OO.OBBO....", ".........OO....."]];
const feetSide = [["...OBBO.OBBO....", "....OO...OO....."], ["...OBBO..OO.....", "....OO.........."], ["....OO..OBBO....", ".........OO....."]];
for (let f = 0; f < 3; f++) {
  sprites[`fox_down_${f}`] = ascii([...foxDown, ...feetWide[f]], FOX);
  sprites[`fox_up_${f}`] = ascii([...foxUp, ...feetWide[f]], FOX);
  sprites[`fox_side_${f}`] = ascii([...foxSide, ...feetSide[f]], FOX);
}
const GOOSE = { O: hex("#3a3a48"), W: hex("#fdfdf5"), G: hex("#d2d8e2"), Y: hex("#f29b30"), B: hex("#1c1412") };
const gooseBody = [
  "................",
  "..........OOO...",
  ".........OWWWO..",
  ".........OWBWOOO",
  ".........OWWWYYO",
  ".........OWWOOO.",
  ".........OWWO...",
  "..OO.....OWWO...",
  ".OWWOOOOOOWWO...",
  "OWWWWWWWWWWWO...",
  "OWGWWWWWWWWWO...",
  ".OWGGGGWWWWO....",
  "..OWWWWWWWO.....",
  "...OOOOOOO......",
];
const gooseFeet = [[".....Y..Y.......", "....YY.YY......."], [".....Y...Y......", "....YY...YY....."], ["......YY........", ".....YY.Y......."]];
for (let f = 0; f < 3; f++) sprites[`goose_${f}`] = ascii([...gooseBody, ...gooseFeet[f]], GOOSE);

// ---------- write sprites ----------
for (const [name, cv] of Object.entries(sprites)) writePng(path.join(SPRITES, name + ".png"), cv);

// ---------- app icon ----------
(() => {
  const icon = new Canvas(1024, 1024);
  for (let y = 0; y < 1024; y++) for (let x = 0; x < 1024; x++) icon.set(x, y, grassPixel(Math.floor(x / 64), Math.floor(y / 64)));
  icon.blit(sprites.fox_down_0, 128, 128, 48);
  writePng(ICON, icon, false);
})();

// ---------- preview: a mock village scene ----------
(() => {
  const W = 16, H = 14, T = 16, S = 4;
  const g = Array.from({ length: H }, (_, y) => Array.from({ length: W }, (_, x) => (y === 8 || y === 9 || x === 7 || x === 8 ? "p" : "g")));
  for (let y = 10; y < 14; y++) for (let x = 10; x < 15; x++) if (((x - 12) / 2.4) ** 2 + ((y - 11.7) / 1.6) ** 2 <= 1) g[y][x] = "w";
  const same = (x, y, t) => x < 0 || y < 0 || x >= W || y >= H || g[y][x] === t;
  const scene = new Canvas(W * T, H * T);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const t = g[y][x];
    const mask = (same(x, y - 1, t) ? 1 : 0) | (same(x + 1, y, t) ? 2 : 0) | (same(x, y + 1, t) ? 4 : 0) | (same(x - 1, y, t) ? 8 : 0);
    const s = t === "g" ? sprites[`grass_${(x * 5 + y * 3) % 7 === 0 ? 2 : (x + y) % 2}`] : t === "p" ? sprites[`path_${mask}`] : sprites[`water_${mask}_0`];
    scene.blit(s, x * T, y * T);
  }
  const objs = [
    [sprites.house_0, 1 * T, 8 * T], [sprites.house_1, 4 * T, 8 * T], [sprites.post, 9 * T, 8 * T], [sprites.house_3, 12 * T + 8, 8 * T],
    [sprites.tree_0, 0, 3 * T], [sprites.tree_1, 3 * T, 3 * T], [sprites.tree_0, 5 * T, 13 * T], [sprites.tree_1, 1 * T, 13 * T], [sprites.tree_0, 13 * T, 3 * T],
    [sprites.fox_down_0, 6 * T, 10 * T], [sprites.fox_side_1, 9 * T, 10 * T], [sprites.fox_up_2, 7 * T + 8, 12 * T], [sprites.goose_0, 11 * T, 10 * T - 2], [sprites.goose_1.flipX(), 3 * T, 10 * T],
    [sprites.marker_letter, 2 * T, 4 * T + 4], [sprites.marker_post, 10 * T, 4 * T + 4], [sprites.arrow, 14 * T, 6 * T], [sprites.icon_letter, 14 * T, 1 * T], [sprites.icon_coin, 15 * T, 1 * T],
  ];
  objs.sort((a, b) => a[2] - b[2]);
  for (const [s, x, bottom] of objs) scene.blit(s, x, bottom - s.h);
  const out = new Canvas(W * T * S, H * T * S);
  out.blit(scene, 0, 0, S);
  writePng(PREVIEW, out, false);
})();
console.log("sprites:", Object.keys(sprites).length);

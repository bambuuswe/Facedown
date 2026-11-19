// More things for the bigger village: market stalls, a chapel, a barn, animals,
// fires, and the wreath-and-bauble joystick. Adds to the sprites made in sprites.js.
const { hex, mix, withAlpha, Canvas, hash2, noise, ascii } = require("./lib");
const { sprites, meta, C, FIR, snowTop, ball } = require("./sprites");

const BULBS = [hex("#ff5a4d"), hex("#ffd84d"), hex("#5ab8ff"), hex("#fff6d8"), hex("#ff8ad0")];
const SNOWS = [C.snow, C.snowMid, C.snowShade];

// ---------------------------------------------------------------- market stalls
function stall(a, b, goods) {
  const cv = new Canvas(48, 58), lit = new Canvas(48, 58), g = 56;
  cv.rect(4, 12, 3, g - 12, C.woodDark); cv.rect(41, 12, 3, g - 12, C.woodDark); cv.rect(4, 12, 1, g - 12, C.wood); cv.rect(41, 12, 1, g - 12, C.wood);
  for (let y = 40; y <= g; y++) for (let x = 3; x <= 44; x++) cv.set(x, y, (y - 40) % 5 === 4 ? C.woodDark : (x + Math.floor((y - 40) / 5) * 6) % 11 === 0 ? C.woodDark : C.wood);
  cv.rect(2, 37, 44, 3, C.woodPale); cv.rect(2, 39, 44, 1, C.woodLight);
  goods(cv, 37);
  for (let y = 3; y <= 16; y++) for (let x = 1; x <= 46; x++) {
    if (y > 13 && (x - 1) % 6 > 3 + (16 - y)) continue;
    cv.set(x, y, Math.floor((x - 1) / 4) % 2 ? (y > 11 ? mix(b, C.outline, 0.18) : b) : y > 11 ? mix(a, C.outline, 0.22) : a);
  }
  snowTop(cv, (x) => 2 + (hash2(x, 1, 5) < 0.4 ? 1 : 0), (x, y) => y > 6);
  for (let x = 3; x <= 45; x += 6) { const c = BULBS[(x / 6 | 0) % BULBS.length]; lit.set(x, 17, mix(c, C.snow, 0.45)); lit.set(x, 18, c); }
  ball(cv, 4, g + 0.5, 4, 2, SNOWS); ball(cv, 43, g + 0.5, 4, 2, SNOWS);
  for (let x = 0; x < 48; x++) cv.clear(x, 57);
  cv.outline(C.outline);
  return { cv, lit };
}
const GOODS = [
  (cv, top) => { // bread and buns
    for (const x of [9, 17, 26, 34]) { cv.ellipse(x + 2, top - 3, 3.4, 2.2, hex("#c98a4a")); cv.rect(x, top - 4, 5, 1, hex("#e3b06e")); cv.set(x + 1, top - 3, hex("#8f5a2c")); cv.set(x + 3, top - 3, hex("#8f5a2c")); }
    cv.rect(13, top - 1, 22, 1, C.cream);
  },
  (cv, top) => { // toys and ornaments
    [[9, "#d8483e"], [15, "#4a78c8"], [21, "#f5c93c"], [27, "#3f8f6e"], [33, "#8660bd"]].forEach(([x, c], i) => {
      if (i % 2) { cv.rect(x, top - 5, 4, 5, hex(c)); cv.rect(x, top - 5, 4, 1, mix(hex(c), C.snow, 0.5)); cv.rect(x + 1, top - 3, 2, 1, C.gold); }
      else { cv.ellipse(x + 1.5, top - 3, 2.3, 2.3, hex(c)); cv.set(x + 1, top - 4, C.snow); cv.set(x + 1, top - 6, C.gold); }
    });
  },
  (cv, top) => { // cocoa pot and mugs
    cv.rect(9, top - 8, 8, 8, C.stoneDark); cv.rect(9, top - 8, 8, 1, C.stoneLight); cv.rect(10, top - 10, 6, 2, hex("#6a4a3c")); cv.set(12, top - 12, withAlpha(C.snow, 180)); cv.set(13, top - 14, withAlpha(C.snow, 140));
    for (const x of [21, 27, 33]) { cv.rect(x, top - 4, 4, 4, C.cream); cv.rect(x, top - 4, 4, 1, hex("#6a4a3c")); cv.set(x + 4, top - 3, C.cream); cv.set(x + 4, top - 2, C.cream); cv.rect(x, top - 2, 4, 1, C.red); }
  },
];
[[hex("#3f7f5c"), C.cream], [hex("#4a78c8"), C.cream], [hex("#e3a93a"), hex("#b8443b")]].forEach(([a, b], i) => {
  const s = stall(a, b, GOODS[i]);
  sprites[`stall_${i}`] = s.cv; sprites[`stall_${i}_lit`] = s.lit;
});

// ---------------------------------------------------------------- chapel
(() => {
  const W = 96, H = 126, g = 124, cx = 47.5;
  const cv = new Canvas(W, H), lit = new Canvas(W, H);
  const stone = (x, y) => {
    const row = Math.floor(y / 5), bx = x + (row % 2) * 4;
    if (y % 5 === 4 || bx % 9 === 8) return C.stoneDark;
    const v = hash2(Math.floor(bx / 9), row, 31);
    return v < 0.3 ? C.stoneLight : v < 0.8 ? C.stone : mix(C.stone, C.stoneDark, 0.5);
  };
  const edge = (x) => 44 + Math.abs(x - cx) * 0.78;
  // tower behind the gable
  for (let y = 22; y <= 70; y++) for (let x = 36; x <= 59; x++) cv.set(x, y, x > 55 ? mix(stone(x, y), C.outline, 0.2) : stone(x, y));
  for (let y = 0; y <= 23; y++) for (let x = 30; x <= 65; x++) {
    const half = (y / 23) * 15;
    if (Math.abs(x - cx) > half) continue;
    cv.set(x, y, x - cx > half * 0.35 ? C.snowShade : y > 20 ? C.snowShade : noise(x, y, 5, 32) > 0.6 ? C.snowMid : C.snow);
  }
  cv.rect(33, 23, 30, 2, hex("#434c63"));
  // belfry and bell
  for (let y = 28; y <= 40; y++) for (let x = 43; x <= 52; x++) if (y > 31 || Math.abs(x - cx) < (y - 27) * 1.2) { cv.set(x, y, hex("#1c2238")); }
  cv.rect(46, 31, 4, 5, C.gold); cv.rect(45, 35, 6, 2, C.gold); cv.set(47, 37, hex("#b9802a")); cv.rect(46, 31, 1, 5, C.warm1);
  // nave
  for (let y = 40; y <= g; y++) for (let x = 10; x <= 85; x++) { if (y < edge(x)) continue; cv.set(x, y, stone(x, y)); }
  cv.rect(10, g - 3, 76, 4, C.stoneDark);
  // rose window
  for (let y = 58; y <= 74; y++) for (let x = 39; x <= 56; x++) {
    const dx = x - cx, dy = y - 66, d = Math.hypot(dx, dy);
    if (d > 8.2) continue;
    if (d > 6.8) { cv.set(x, y, C.stoneLight); continue; }
    const seg = Math.floor(((Math.atan2(dy, dx) + Math.PI) / (Math.PI * 2)) * 8) % 8, spoke = Math.abs(((Math.atan2(dy, dx) + Math.PI) / (Math.PI * 2)) * 8 % 1 - 0.5) > 0.42;
    const jewel = [hex("#b8443b"), hex("#3d6bb5"), hex("#e3a93a"), hex("#3f8f6e")][seg % 4];
    cv.set(x, y, spoke || d < 1.5 ? C.iron : mix(jewel, C.outline, 0.45));
    if (!(spoke || d < 1.5)) lit.set(x, y, mix(jewel, C.warm1, 0.35));
  }
  // side windows
  for (const wx of [19, 70]) {
    for (let y = 86; y <= 108; y++) for (let x = wx; x <= wx + 7; x++) {
      if (y < 90 && Math.abs(x - wx - 3.5) > (y - 85) * 0.9) continue;
      const frame = x === wx || x === wx + 7 || y === 108 || (y < 90 && Math.abs(x - wx - 3.5) > (y - 86) * 0.9 - 0.2);
      const jewel = [hex("#3d6bb5"), hex("#b8443b"), hex("#e3a93a")][Math.floor((y - 86) / 8) % 3];
      cv.set(x, y, frame || x === wx + 4 ? C.stoneLight : mix(jewel, C.outline, 0.45));
      if (!(frame || x === wx + 4)) lit.set(x, y, mix(jewel, C.warm1, 0.4));
    }
    cv.rect(wx - 1, 109, 10, 1, C.snow); cv.rect(wx - 1, 110, 10, 1, C.snowShade);
  }
  // doors
  for (let y = 94; y <= g; y++) for (let x = 39; x <= 56; x++) {
    if (y < 100 && Math.abs(x - cx) > 3 + (y - 94) * 1.1) continue;
    const frame = x === 39 || x === 56 || (y < 100 && Math.abs(x - cx) > 2 + (y - 94) * 1.1);
    cv.set(x, y, frame ? C.stoneLight : x === 47 || x === 48 ? C.woodDark : (x + y) % 6 === 0 ? C.woodDark : C.wood);
  }
  cv.rect(41, 106, 5, 1, C.iron); cv.rect(50, 106, 5, 1, C.iron); cv.rect(41, 116, 5, 1, C.iron); cv.rect(50, 116, 5, 1, C.iron); cv.set(46, 111, C.gold); cv.set(49, 111, C.gold);
  for (let a = 0; a < 14; a++) cv.set(Math.round(cx + Math.cos(a * 0.45) * 3), Math.round(101 + Math.sin(a * 0.45) * 3), a % 2 ? FIR.tones[1] : FIR.tones[2]);
  cv.set(47, 104, C.red); cv.set(48, 104, C.red);
  cv.rect(36, g - 1, 24, 2, C.stoneLight);
  // lamp over the door
  cv.rect(47, 90, 2, 3, C.iron); lit.rect(46, 92, 4, 3, C.warm2); cv.rect(46, 92, 4, 3, C.glassOff);
  // roof planes with snow
  for (let x = 0; x < W; x++) {
    if (Math.abs(x - cx) > 46 || (x >= 36 && x <= 59 && edge(x) < 46)) { if (Math.abs(x - cx) > 46) continue; }
    const e = Math.round(edge(x));
    for (let j = 0; j < 10; j++) {
      const y = e - 9 + j;
      if (x >= 37 && x <= 58 && y < 70 && cv.alpha(x, y) > 0 && j < 5 && y < 44) continue;
      cv.set(x, y, j < 5 ? (j === 4 ? C.snowShade : noise(x, y, 5, 33) > 0.62 ? C.snowMid : C.snow) : j === 9 ? hex("#434c63") : (x + j) % 5 === 0 ? hex("#434c63") : j === 5 ? hex("#8793ad") : hex("#5f6b85"));
    }
  }
  // cross
  cv.rect(47, 0, 2, 1, C.gold);
  const top = new Canvas(W, H + 8);
  top.blit(cv, 0, 8); top.rect(47, 1, 2, 8, C.gold); top.rect(45, 3, 6, 2, C.gold); top.set(47, 1, C.warm1);
  const litTop = new Canvas(W, H + 8); litTop.blit(lit, 0, 8);
  for (const x of [8, 24, 70, 86]) ball(top, x, g + 8.5, 6, 2.6, SNOWS);
  for (let y = g + 9; y < H + 8; y++) for (let x = 0; x < W; x++) top.clear(x, y);
  top.outline(C.outline);
  sprites.chapel = top; sprites.chapel_lit = litTop;
  meta.chapel = { glows: [[47.5, 66, 20], [22.5, 36, 16], [73.5, 36, 16], [47.5, 38, 14]] }; // x, height above base, radius
})();

// ---------------------------------------------------------------- barn
(() => {
  const W = 64, H = 78, g = 76, cv = new Canvas(W, H), cx = 31.5;
  const red = [hex("#b8443b"), hex("#8a302c"), hex("#d0685a")];
  const edge = (x) => 22 + Math.abs(x - cx) * 0.75;
  for (let y = 20; y <= g; y++) for (let x = 6; x <= 57; x++) {
    if (y < edge(x)) continue;
    cv.set(x, y, (x - 6) % 5 === 4 ? red[1] : hash2(x, Math.floor(y / 9), 41) < 0.08 ? red[2] : red[0]);
  }
  cv.rect(6, g - 2, 52, 3, C.stoneDark);
  // big doors with white braces
  cv.rect(19, 48, 26, g - 50, C.cream); cv.rect(20, 49, 24, g - 51, red[1]);
  cv.rect(31, 49, 2, g - 51, C.cream); cv.line(20, 49, 30, g - 3, C.cream); cv.line(20, g - 3, 30, 49, C.cream); cv.line(33, 49, 43, g - 3, C.cream); cv.line(33, g - 3, 43, 49, C.cream);
  // hay loft
  cv.rect(26, 30, 12, 10, C.cream); cv.rect(27, 31, 10, 8, hex("#3a2a22")); cv.rect(27, 36, 10, 3, hex("#e3c15a")); cv.set(29, 35, hex("#e3c15a")); cv.set(33, 34, hex("#e3c15a"));
  for (let x = 0; x < W; x++) {
    if (Math.abs(x - cx) > 31) continue;
    const e = Math.round(edge(x));
    for (let j = 0; j < 9; j++) cv.set(x, e - 8 + j, j < 5 ? (j === 4 ? C.snowShade : noise(x, j, 5, 42) > 0.6 ? C.snowMid : C.snow) : j === 8 ? hex("#6d4129") : hex("#96603d"));
  }
  for (const x of [5, 58]) ball(cv, x, g + 0.5, 5, 2.4, SNOWS);
  for (let y = g + 1; y < H; y++) for (let x = 0; x < W; x++) cv.clear(x, y);
  cv.outline(C.outline);
  sprites.barn = cv;
})();

// ---------------------------------------------------------------- small props
(() => {
  const bush = new Canvas(16, 12);
  ball(bush, 7.5, 7, 7, 4.5, [FIR.tones[1], FIR.tones[2], FIR.tones[3]]);
  for (let i = 0; i < 9; i++) bush.set(2 + Math.floor(hash2(i, 1, 51) * 12), 5 + Math.floor(hash2(i, 2, 51) * 5), FIR.tones[0]);
  bush.set(4, 8, C.red); bush.set(10, 7, C.red); bush.set(7, 9, C.red);
  snowTop(bush, (x) => 2 + (hash2(x, 3, 51) < 0.5 ? 1 : 0), null);
  bush.outline(C.outline);
  sprites.bush = bush;

  const barrel = new Canvas(12, 15);
  for (let y = 2; y <= 13; y++) for (let x = 1; x <= 10; x++) { if ((y < 4 || y > 11) && (x < 2 || x > 9)) continue; barrel.set(x, y, x > 7 ? C.woodDark : x % 3 === 0 ? C.wood : C.woodLight); }
  barrel.rect(1, 4, 10, 1, C.iron); barrel.rect(1, 10, 10, 1, C.iron);
  snowTop(barrel, () => 2, null);
  barrel.outline(C.outline);
  sprites.barrel = barrel;

  const crates = new Canvas(18, 18);
  const crate = (x, y, s) => { crates.rect(x, y, s, s, C.woodLight); crates.frame(x, y, s, s, C.wood); crates.line(x + 1, y + 1, x + s - 2, y + s - 2, C.wood); crates.rect(x + s - 2, y + 1, 1, s - 2, C.woodDark); };
  crate(1, 8, 9); crate(9, 9, 8); crate(5, 1, 8);
  snowTop(crates, () => 2, null);
  crates.outline(C.outline);
  sprites.crates = crates;

  const hay = new Canvas(18, 13);
  for (let y = 2; y <= 11; y++) for (let x = 1; x <= 16; x++) hay.set(x, y, (x + y * 3) % 5 === 0 ? hex("#b9902f") : (x * 2 + y) % 7 === 0 ? hex("#f2dc86") : hex("#e3c15a"));
  hay.rect(5, 2, 1, 10, hex("#8a5a3c")); hay.rect(12, 2, 1, 10, hex("#8a5a3c"));
  snowTop(hay, () => 2, null);
  hay.outline(C.outline);
  sprites.haybale = hay;

  const fire = (lit, f) => {
    const cv = new Canvas(18, 22);
    if (!lit) {
      cv.ellipse(8.5, 18, 8, 3, C.shadow);
      for (let a = 0; a < 10; a++) { const x = Math.round(8.5 + Math.cos(a * 0.63) * 6.5), y = Math.round(17 + Math.sin(a * 0.63) * 2.6); cv.rect(x - 1, y - 1, 3, 2, a % 2 ? C.stone : C.stoneLight); cv.rect(x - 1, y + 1, 3, 1, C.stoneDark); }
      cv.line(4, 17, 13, 14, C.woodDark); cv.line(4, 14, 13, 17, C.wood); cv.line(5, 16, 12, 16, C.woodLight);
      cv.outline(C.outline);
    } else {
      const tips = f ? [[8, 4], [5, 9], [12, 8]] : [[9, 5], [6, 8], [11, 10]];
      for (let y = 4; y <= 16; y++) for (let x = 3; x <= 14; x++) {
        const d = tips.map(([tx, ty]) => Math.abs(x - tx) * 1.3 + Math.max(0, ty - y) * 3 + Math.max(0, y - 16)).reduce((a, b) => Math.min(a, b));
        const w = 5.5 - (16 - y) * 0.33;
        if (Math.abs(x - 8.5) > w || d > (16 - y) * 0.9 + 3) continue;
        const heat = Math.abs(x - 8.5) / Math.max(w, 1) + (16 - y) / 14;
        cv.set(x, y, heat < 0.55 ? C.warm1 : heat < 0.95 ? C.warm2 : heat < 1.3 ? C.warm3 : hex("#f0682c"));
      }
    }
    return cv;
  };
  sprites.campfire = fire(false, 0); sprites.campfire_lit_0 = fire(true, 0); sprites.campfire_lit_1 = fire(true, 1);

  const brazier = new Canvas(18, 22);
  brazier.rect(4, 13, 10, 5, C.iron); brazier.rect(5, 13, 1, 5, C.ironLight); brazier.rect(3, 12, 12, 1, C.ironLight);
  for (let x = 5; x <= 12; x += 2) brazier.rect(x, 14, 1, 3, hex("#6a3a2c"));
  brazier.rect(5, 18, 1, 3, C.iron); brazier.rect(12, 18, 1, 3, C.iron); brazier.rect(8, 18, 2, 2, C.iron);
  ball(brazier, 8.5, 21, 6, 1.6, SNOWS);
  brazier.outline(C.outline);
  sprites.brazier = brazier;
  const up = (src) => { const o = new Canvas(18, 22); o.blit(src, 0, -4); return o; };
  sprites.brazier_lit_0 = up(sprites.campfire_lit_0); sprites.brazier_lit_1 = up(sprites.campfire_lit_1);

  const puff = new Canvas(7, 7);
  for (let y = 0; y < 7; y++) for (let x = 0; x < 7; x++) { const d = Math.hypot(x - 3, y - 3); if (d < 3.3) puff.set(x, y, [235, 240, 250, d < 2 ? 190 : 110]); }
  sprites.puff = puff;
})();

// ---------------------------------------------------------------- animals
const SHEEP = { O: C.outline, W: hex("#f6f2e8"), w: hex("#d9d3c4"), K: hex("#3a3340"), E: C.snow };
const sheepBody = [
  "....OOOOOOO.....",
  "..OOWWWWWWWOOOO.",
  ".OWWWWWWWWWWKKKO",
  "OWWWWWWWWWWKKEKO",
  "OWWWWWWWWWWKKKKO",
  "OWwWWWWWWWWWKKO.",
  "OWwwWWWWWWWWOO..",
  ".OWwwwWWWWWO....",
  "..OOOOOOOOO.....",
];
sprites.sheep_0 = ascii([...sheepBody, "...K..K.K..K....", "...K..K.K..K...."], SHEEP);
sprites.sheep_1 = ascii([...sheepBody, "...K.K...K.K....", "..K..K...K..K..."], SHEEP);
const DEER = { O: C.outline, T: hex("#b9804f"), t: hex("#96603d"), W: hex("#f1e3c4"), K: hex("#4a3229"), E: hex("#1c1412"), N: hex("#2a2233"), A: hex("#d9c7a0") };
const deerBody = [
  "..............A...A...",
  "..............AA.AA...",
  "...............AAA....",
  "..............OOOOO...",
  ".............OTTTTTO..",
  ".............OTTETTTO.",
  ".............OTTTTTNO.",
  "....OOOOOOOOOOTTTOOO..",
  "...OTTTTTTTTTTTTTO....",
  "..OWTTTTTTTTTTTTTO....",
  "..OWTTTTTTTTTTTTO.....",
  "..OTTtTTTTTTTTTTO.....",
  "...OTtWWWWWWWTTO......",
  "...OTOOOOOOOOTTO......",
];
sprites.deer_0 = ascii([...deerBody, "...OTO.OTO.OTOOTO.....", "...OTO.OTO.OTO.OTO....", "...OKO.OKO.OKO.OKO....", "...OOO.OOO.OOO.OOO...."], DEER);
sprites.deer_1 = ascii([...deerBody, "..OTO..OTO..OTOOTO....", "..OTO...OTO.OTO..OTO..", ".OKO....OKO.OKO..OKO..", ".OOO....OOO.OOO..OOO.."], DEER);
const BIRD = { O: C.outline, B: hex("#8a6a52"), R: hex("#e0563f"), E: hex("#1c1412"), Y: hex("#f29b30") };
sprites.bird_0 = ascii(["...OOO..", "..OBBEOY", "OOBBBRO.", ".OBBRRO.", "..OOOO..", "...Y.Y.."], BIRD);
sprites.bird_1 = ascii(["........", "...OOO..", "OOOBBEO.", ".OBBBRRY", "..OOOO..", "...Y.Y.."], BIRD);
sprites.bird_fly_0 = ascii([".O...O..", ".OO.OO..", "..OBBEOY", "OOBBRRO.", "..OOOO..", "........"], BIRD);
sprites.bird_fly_1 = ascii(["........", "..OBBEOY", "OOBBRRO.", ".OOOOO..", ".O...O..", "........"], BIRD);
const CAT = { O: C.outline, G: hex("#e8a04a"), g: hex("#c97f30"), W: hex("#fdf0dc"), E: hex("#2a6b3a"), P: hex("#f4a6a0") };
const catTop = [".O..O.......", "OGOOGO......", "OGGGGO......", "OEGGEO......", "OGGPGO....OO"];
sprites.cat_0 = ascii([...catTop, ".OWWGOOO.OGO", ".OGgGGGGOOGO", ".OGGgGGGGGO.", ".OWGGWGGGO..", ".OOOOOOOO..."], CAT);
sprites.cat_1 = ascii([...catTop.slice(0, 4), "OGGPGO.....O", ".OWWGOOO..OG", ".OGgGGGGOOGO", ".OGGgGGGGGO.", ".OWGGWGGGO..", ".OOOOOOOO..."], CAT);

// ---------------------------------------------------------------- workbench and icons
(() => {
  const cv = new Canvas(26, 22);
  cv.ellipse(12.5, 19, 12, 2.4, C.shadow);
  cv.rect(2, 9, 22, 3, C.woodPale); cv.rect(2, 11, 22, 1, C.woodLight);
  cv.rect(3, 12, 2, 8, C.woodDark); cv.rect(21, 12, 2, 8, C.woodDark); cv.rect(5, 15, 16, 1, C.wood);
  cv.rect(17, 5, 5, 4, C.iron); cv.rect(18, 4, 3, 1, C.ironLight); cv.rect(15, 6, 2, 1, C.ironLight); // vice
  cv.line(5, 8, 12, 3, C.wood); cv.rect(11, 1, 4, 4, C.stone); cv.rect(11, 1, 1, 4, C.stoneLight); // axe
  cv.rect(7, 13, 6, 1, C.stoneLight); cv.rect(6, 14, 1, 1, C.wood); // saw hanging underneath
  snowTop(cv, () => 1, (x, y) => y < 8 || y > 10 || x > 14);
  cv.outline(C.outline);
  sprites.workbench = cv;
})();
const CATW = { O: C.outline, G: hex("#e8a04a"), g: hex("#c97f30"), W: hex("#fdf0dc"), E: hex("#2a6b3a") };
const catWalk = ["O..........O.O..", "OO........OGOGO.", ".OG.......OGGGO.", ".OGOOOOOOOOEGEO.", "..OGGgGGgGGGGWO.", "..OGGGGGGGGGGO..", "..OWGGGGGGGWO..."];
sprites.cat_walk_0 = ascii([...catWalk, "..OGO.OGO.OGO...", "..OO..OO..OO...."], CATW);
sprites.cat_walk_1 = ascii([...catWalk, "...OGOOGO..OGO..", "...OO.OO...OO..."], CATW);
sprites.icon_mug = ascii([".........", ".OOOOOO..", ".OBBBBOOO", ".OWWWWO.O", ".OWWWWOOO", ".OWWWWO..", ".OOOOOO..", "........."], { O: C.outline, B: hex("#6a4a3c"), W: C.cream });
sprites.icon_gift = ascii(["..RR.RR..", "...RRR...", ".OOOROOO.", ".OGGRGGO.", ".RRRRRRR.", ".OGGRGGO.", ".OGGRGGO.", ".OOOOOOO."], { O: C.outline, R: C.red, G: hex("#3f8f6e") });
sprites.icon_treat = ascii(["..OOOOO..", ".OBBBBBO.", "OBBWBWBBO", "OBBBBBBBO", "OBWBBBWBO", ".OBWWWBO.", "..OOOOO..", "........."], { O: C.outline, B: hex("#b9773a"), W: C.snow });

// ---------------------------------------------------------------- themed joystick
(() => {
  const n = 46, cv = new Canvas(n, n), c = 22.5;
  for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
    const d = Math.hypot(x - c, y - c), wob = noise(x, y, 3, 61) * 3;
    if (d < 14 + wob * 0.5 || d > 20.5 + wob * 0.6) continue;
    const t = (x - c) * 0.03 + (y - c) * 0.04 + hash2(x, y, 62) * 0.9;
    cv.set(x, y, FIR.tones[t < 0.25 ? 0 : t < 0.6 ? 1 : t < 0.95 ? 2 : 3]);
  }
  for (let a = 0; a < 9; a++) { const ang = a * 0.7 + 0.3, x = Math.round(c + Math.cos(ang) * 17.5), y = Math.round(c + Math.sin(ang) * 17.5); if (y > 34) continue; cv.rect(x, y, 2, 2, C.red); cv.set(x, y, hex("#ff9a8a")); }
  for (let a = 0; a < 5; a++) { const ang = a * 1.26 + 1, x = Math.round(c + Math.cos(ang) * 16), y = Math.round(c + Math.sin(ang) * 16); if (y > 33) continue; cv.set(x, y, C.snow); cv.set(x + 1, y, C.snowMid); }
  // bow at the bottom
  const bow = ["RR.....RR", "RRR...RRR", "RRRRDRRRR", "RRR.D.RRR", "RR..D..RR", "...RDR...", "..RR.RR..", "..R...R.."];
  bow.forEach((row, j) => [...row].forEach((ch, i) => { if (ch !== ".") cv.set(18 + i, 36 + j, ch === "D" ? C.redDark : C.red); }));
  cv.outline(C.outline);
  sprites.stick_base = cv;

  const knob = new Canvas(20, 23);
  for (let y = 0; y < 23; y++) for (let x = 0; x < 20; x++) {
    const dx = x - 9.5, dy = y - 13, d = Math.hypot(dx, dy);
    if (d > 8.4) continue;
    const t = (dx * 0.6 + dy * 0.8) / 8.4;
    knob.set(x, y, t < -0.45 ? hex("#f0796c") : t < 0.3 ? C.red : C.redDark);
  }
  knob.rect(5, 9, 2, 3, hex("#ffd0c8")); knob.set(7, 8, hex("#ffd0c8"));
  for (let x = 3; x <= 16; x++) if (Math.hypot(x - 9.5, 0) < 8) knob.set(x, 15 + Math.round(Math.sin(x * 0.9) * 1), C.gold);
  knob.rect(8, 2, 4, 3, C.gold); knob.rect(8, 2, 4, 1, C.warm1); knob.rect(9, 0, 2, 2, hex("#b9802a"));
  knob.outline(C.outline);
  sprites.stick_knob = knob;
})();

module.exports = { sprites, meta };

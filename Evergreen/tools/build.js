// Lays out the farm, village, lake, forest, market and chapel; bakes the ground
// into one image; and writes the sprites, world.json, minimap, icon and previews.
// Usage: node build.js <artDir> <iconPath> <previewDir>
const fs = require("fs");
const path = require("path");
const { hex, mix, Canvas, writePng, rng, hash2, noise } = require("./lib");
const { C, ball } = require("./sprites");
const { sprites, meta } = require("./extras");

const [ART, ICON, PREVIEW] = process.argv.slice(2);
const W = 57, H = 76, T = 16, PW = W * T, PH = H * T;
const sk = (imgY) => PH - imgY; // image rows grow downward, the game's y grows upward

// ------------------------------------------------------------ layout
const surf = Array.from({ length: H }, () => Array(W).fill("s"));
const fill = (x0, y0, x1, y1, ch) => { for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) surf[y][x] = ch; };
fill(5, 10, 23, 11, "p");   // farm lane, from the cabin to the lot gate
fill(5, 8, 6, 9, "p");      // cabin doorstep
fill(19, 10, 20, 71, "p");  // main road, farm to chapel
fill(4, 31, 47, 32, "p");   // north street
fill(3, 42, 40, 43, "p");   // middle street, out to the lake
fill(5, 53, 50, 54, "p");   // south street, out to the barn
fill(8, 60, 31, 61, "p");   // market row
fill(46, 14, 47, 31, "p");  // forest trail
fill(6, 12, 6, 13, "p");    // path into your garden
fill(14, 38, 25, 47, "c");  // village square

const streamY = (px) => 24.5 * T + 9 * Math.sin(px / 37) + 5 * Math.sin(px / 13 + 1);
const bridge = (cx) => ({ x0: cx - 20, x1: cx + 20, y0: Math.round(streamY(cx)) - 27, y1: Math.round(streamY(cx)) + 27, cx });
const BRIDGES = [bridge(320), bridge(47 * T)];
const POND = { x: 31 * T, y: 47.6 * T, rx: 3.1 * T, ry: 1.6 * T };
const LAKE = { x: 47.5 * T, y: 40.5 * T, rx: 6.2 * T, ry: 4.8 * T };
const JETTY = { x0: 40 * T + 4, x1: 43 * T + 2, y0: 42 * T + 3, y1: 44 * T - 3 };

const cabin = { hx: 4, hy: 6 };
const HOUSE_TILES = [[5, 29], [11, 29], [24, 29], [30, 29], [3, 40], [8, 40], [28, 40], [33, 40], [6, 51], [24, 51], [30, 51]];
const STREET = ["on the north street", "on the north street", "on the north street", "on the north street", "west of the square", "west of the square", "east of the square", "east of the square", "on the south street", "on the south street", "on the south street"];
const WALL_NAME = { red: "red", cream: "cream", stone: "stone", blue: "blue", yellow: "yellow", green: "green", pink: "pink" };
const LANTERNS = [[18, 14], [21, 19], [18, 28], [21, 35], [18, 50], [21, 50], [8, 33], [14, 33], [27, 33], [33, 33], [5, 44], [10, 44], [29, 44], [34, 44], [9, 55], [16, 55], [27, 55], [33, 55],
  [38, 33], [44, 33], [39, 44], [40, 55], [48, 55], [18, 58], [22, 63]];
const FENCES = [[15, 36], [22, 36], [3, 46], [7, 46], [15, 50], [22, 50]];
const LOT = { x0: 22, y0: 2, x1: 37, y1: 19, gate: [10, 11], cols: [24, 27, 30, 33, 36], rows: [5, 9, 13, 17] };
const PEN = { x0: 41, y0: 57, x1: 51, y1: 63, gate: 46 };
const GARDEN = { x0: 2, y0: 13, x1: 10, y1: 20, gate: 6 };
const GIANT = [12, 16];
const SQUARE_TREE = { x: 320, y: 43 * T - 4 };
const POLES = [[14, 38], [25, 38], [14, 47], [25, 47]];
const SNOWMEN = [[5, 48], [10, 49]];
const PAPER = [[27, 46], [35, 46], [28, 50], [34, 50]];
const LAKE_LAMPS = [[41, 35], [53, 35], [41, 46], [53, 46]];
const STALLS = [9, 13, 23, 27];
const CAMPFIRE = [47, 10];
const BRAZIER = [17, 59];

const solid = Array.from({ length: H }, () => Array(W).fill(false));
const reserved = Array.from({ length: H }, () => Array(W).fill(false));
const glyph = Array.from({ length: H }, () => Array(W).fill("")); // for the minimap
const block = (x, y) => { if (x >= 0 && y >= 0 && x < W && y < H) solid[y][x] = true; };
const reserve = (x0, y0, x1, y1) => { for (let y = Math.max(0, y0); y <= Math.min(H - 1, y1); y++) for (let x = Math.max(0, x0); x <= Math.min(W - 1, x1); x++) reserved[y][x] = true; };

const props = []; // static, depth-sorted sprites: { sprite, x, y } with y at the base, image coordinates
const addProp = (sprite, x, y) => props.push({ sprite, x, y });
const tileBase = (tx, ty) => [(tx + 0.5) * T, (ty + 1) * T - 2];

// ------------------------------------------------------------ pixel classes
const SNOW = 0, PATH = 1, COBBLE = 2, ICE = 3, PLANK = 4, DOCK = 5;
const cls = new Uint8Array(PW * PH);
for (let py = 0; py < PH; py++) for (let px = 0; px < PW; px++) {
  const wx = px + (noise(px, py, 9, 1) - 0.5) * 7, wy = py + (noise(px, py, 9, 2) - 0.5) * 7;
  const tx = Math.min(W - 1, Math.max(0, Math.floor(wx / T))), ty = Math.min(H - 1, Math.max(0, Math.floor(wy / T)));
  let c = surf[ty][tx] === "p" ? PATH : surf[ty][tx] === "c" ? COBBLE : SNOW;
  const wob = (noise(px, py, 11, 3) - 0.5) * 6;
  if (Math.abs(py - streamY(px)) < 17 + wob && px > 20 && px < PW - 20) c = ICE;
  if (((px - POND.x) / POND.rx) ** 2 + ((py - POND.y) / POND.ry) ** 2 < 1 + wob * 0.04) c = ICE;
  if (((px - LAKE.x) / LAKE.rx) ** 2 + ((py - LAKE.y) / LAKE.ry) ** 2 < 1 + wob * 0.02) c = ICE;
  for (const b of BRIDGES) if (px >= b.x0 && px < b.x1 && py >= b.y0 && py < b.y1) c = PLANK;
  if (px >= JETTY.x0 && px < JETTY.x1 && py >= JETTY.y0 && py < JETTY.y1) c = DOCK;
  cls[py * PW + px] = c;
}
const at = (px, py) => (px < 0 || py < 0 || px >= PW || py >= PH ? SNOW : cls[py * PW + px]);
const wood = (c) => c === PLANK || c === DOCK;

// ------------------------------------------------------------ ground painting
const ground = new Canvas(PW, PH);
const G = {
  snow: [hex("#ffffff"), hex("#eef3fd"), hex("#dfe8f8")], drift: hex("#d0dcf2"), bank: hex("#b4c4e6"), speck: hex("#c5d3ee"),
  path: [hex("#ddd2bf"), hex("#c1ab8f"), hex("#a78f74")], pathEdge: hex("#8c775f"), pebble: hex("#857565"), rut: hex("#b39a7c"),
  stones: [hex("#9aa3b5"), hex("#8791a6"), hex("#aab2c2"), hex("#7f899e")], mortar: hex("#646e88"), crevice: hex("#cdd7ea"),
  ice: hex("#bfe2f2"), iceLight: hex("#e6f6fc"), iceDark: hex("#a3d0e7"), crack: hex("#86bcd8"), iceEdge: hex("#74a8cc"), skate: hex("#d9f0fa"),
  plank: [hex("#9a6a45"), hex("#8a5c3b"), hex("#b07d54")], plankDark: hex("#5f3b29"),
};
for (let py = 0; py < PH; py++) for (let px = 0; px < PW; px++) {
  const c = at(px, py);
  let col;
  if (c === SNOW) {
    const n = noise(px, py, 26, 3) * 0.6 + noise(px, py, 7, 4) * 0.4;
    col = n > 0.6 ? G.snow[0] : n < 0.4 ? G.snow[2] : G.snow[1];
    if (Math.abs(noise(px, py, 34, 5) - 0.5) < 0.011) col = G.drift;
    if (Math.abs(noise(px, py, 21, 25) - 0.5) < 0.006) col = G.snow[0];
    const h = hash2(px, py, 6);
    if (h < 0.004) col = G.snow[0]; else if (h < 0.007) col = G.speck;
    const below = at(px, py + 1), below2 = at(px, py + 2);
    if (below !== SNOW) col = G.bank; else if (below2 !== SNOW) col = G.drift;
    if (at(px - 1, py) !== SNOW || at(px + 1, py) !== SNOW) col = G.drift;
  } else if (c === PATH) {
    const n = noise(px, py, 10, 6) * 0.7 + noise(px, py, 4, 7) * 0.3;
    col = n > 0.6 ? G.path[0] : n < 0.38 ? G.path[2] : G.path[1];
    if (noise(px, py, 6, 8) > 0.82) col = G.snow[1];
    if (hash2(px, py, 9) < 0.008) col = G.pebble;
    if (hash2(Math.floor(px / 3), Math.floor(py / 2), 26) < 0.035) col = G.rut; // old footprints
    if (at(px, py - 1) === SNOW || at(px, py - 2) === SNOW) col = G.pathEdge;
  } else if (c === COBBLE) {
    const row = Math.floor(py / 5), bx = px + (row % 2) * 4, stone = Math.floor(bx / 8);
    const joint = py % 5 === 4 || bx % 8 === 7;
    if (joint) col = hash2(px, py, 10) < 0.45 ? G.crevice : G.mortar;
    else {
      col = G.stones[Math.floor(hash2(stone, row, 11) * 4)];
      if (py % 5 === 0 && bx % 8 < 5) col = mix(col, G.snow[0], 0.25);
    }
    if (noise(px, py, 13, 12) > 0.66) col = noise(px, py, 5, 13) > 0.5 ? G.snow[0] : G.snow[1];
  } else if (c === ICE) {
    col = G.ice;
    if (noise(px, py, 15, 14) < 0.32) col = G.iceDark;
    if ((px + py * 0.6 + noise(px, py, 20, 15) * 26) % 23 < 2) col = G.iceLight;
    if (Math.abs(noise(px, py, 17, 16) - 0.5) < 0.012) col = G.crack;
    // skate marks looping round the lake
    const ld = Math.hypot((px - LAKE.x) / (4.4 * T), (py - LAKE.y) / (3.1 * T));
    if (Math.abs(ld - 1) < 0.022 || Math.abs(ld - 0.72 - noise(px, py, 30, 27) * 0.2) < 0.012) col = G.skate;
    if (noise(px, py, 9, 17) > 0.8) col = G.snow[1];
    if (at(px, py - 1) !== ICE && !wood(at(px, py - 1))) col = G.iceEdge;
    else if (at(px - 1, py) === SNOW || at(px + 1, py) === SNOW || at(px, py + 1) === SNOW) col = G.iceLight;
  } else if (c === PLANK) {
    const ly = py % 4;
    col = ly === 3 ? G.plankDark : G.plank[(Math.floor(py / 4) * 3) % 3];
    if (hash2(px, py, 18) < 0.05) col = G.snow[1];
  } else {
    const lx = px % 4;
    col = lx === 3 ? G.plankDark : G.plank[(Math.floor(px / 4) * 3) % 3];
    if (py === JETTY.y0 || py === JETTY.y1 - 1) col = G.plankDark;
    if (hash2(px, py, 19) < 0.06) col = G.snow[1];
  }
  ground.set(px, py, col);
}
// bridge rails
for (const b of BRIDGES) for (const rx of [b.x0, b.x1 - 3]) {
  ground.rect(rx, b.y0 - 2, 3, b.y1 - b.y0 + 4, C.woodDark);
  ground.rect(rx, b.y0 - 2, 1, b.y1 - b.y0 + 4, C.wood);
  for (let y = b.y0 - 3; y < b.y1; y += 9) { ground.rect(rx - 1, y, 5, 4, C.woodDark); ground.rect(rx - 1, y - 1, 5, 2, C.snow); ground.rect(rx - 1, y + 4, 5, 1, C.outline); }
}
// jetty posts
for (let x = JETTY.x0 + 2; x < JETTY.x1; x += 12) for (const y of [JETTY.y0 - 3, JETTY.y1 - 1]) { ground.rect(x, y, 3, 4, C.woodDark); ground.rect(x, y - 1, 3, 2, C.snow); ground.rect(x, y + 4, 3, 1, C.outline); }
// fences
function fenceH(tx, ty) {
  const x = tx * T, y = ty * T;
  ground.rect(x, y + 13, 16, 2, C.shadow);
  ground.rect(x, y + 6, 16, 2, C.woodLight); ground.rect(x, y + 7, 16, 1, C.wood);
  ground.rect(x, y + 10, 16, 2, C.wood); ground.rect(x, y + 11, 16, 1, C.woodDark);
  for (const ox of [1, 9]) { ground.rect(x + ox, y + 3, 3, 11, C.wood); ground.rect(x + ox + 2, y + 3, 1, 11, C.woodDark); ground.rect(x + ox, y + 2, 3, 2, C.snow); ground.rect(x + ox, y + 13, 3, 1, C.outline); }
  for (let i = 0; i < 16; i++) if (hash2(x + i, y, 20) < 0.6) ground.set(x + i, y + 5, C.snow);
  block(tx, ty); glyph[ty][tx] = "f";
}
function fenceV(tx, ty) {
  const x = tx * T, y = ty * T;
  ground.rect(x + 7, y, 2, 16, C.wood); ground.rect(x + 8, y, 1, 16, C.woodDark);
  ground.rect(x + 9, y, 1, 16, C.shadow);
  for (const oy of [1, 9]) { ground.rect(x + 6, y + oy, 4, 6, C.wood); ground.rect(x + 9, y + oy, 1, 6, C.woodDark); ground.rect(x + 6, y + oy - 1, 4, 2, C.snow); ground.rect(x + 6, y + oy + 6, 4, 1, C.outline); }
  block(tx, ty); glyph[ty][tx] = "f";
}
for (let x = LOT.x0; x <= LOT.x1; x++) { fenceH(x, LOT.y0); fenceH(x, LOT.y1); }
for (let y = LOT.y0 + 1; y < LOT.y1; y++) { if (!LOT.gate.includes(y)) fenceV(LOT.x0, y); fenceV(LOT.x1, y); }
for (let x = PEN.x0; x <= PEN.x1; x++) { if (x !== PEN.gate) fenceH(x, PEN.y0); fenceH(x, PEN.y1); }
for (let y = PEN.y0 + 1; y < PEN.y1; y++) { fenceV(PEN.x0, y); fenceV(PEN.x1, y); }
for (let x = GARDEN.x0; x <= GARDEN.x1; x++) { if (x !== GARDEN.gate) fenceH(x, GARDEN.y0); fenceH(x, GARDEN.y1); }
for (let y = GARDEN.y0 + 1; y < GARDEN.y1; y++) { fenceV(GARDEN.x0, y); fenceV(GARDEN.x1, y); }
reserve(GARDEN.x0 - 1, GARDEN.y0 - 2, GARDEN.x1 + 1, GARDEN.y1 + 1);
for (const [fx, fy] of FENCES) for (let i = 0; i < 3; i++) fenceH(fx + i, fy);
reserve(LOT.x0 - 1, LOT.y0 - 1, LOT.x1 + 1, LOT.y1 + 1);
reserve(PEN.x0 - 1, PEN.y0 - 3, PEN.x1 + 1, PEN.y1 + 1);
for (const [fx, fy] of FENCES) reserve(fx - 1, fy - 1, fx + 3, fy + 1);
// trampled straw in the sheep pen
for (let i = 0; i < 260; i++) {
  const px = (PEN.x0 + 1) * T + Math.floor(hash2(i, 1, 71) * (PEN.x1 - PEN.x0 - 1) * T), py = (PEN.y0 + 1) * T + Math.floor(hash2(i, 2, 71) * (PEN.y1 - PEN.y0 - 1) * T);
  ground.rect(px, py, 2 + (i % 2), 1, i % 3 ? hex("#e3c15a") : hex("#c9a544"));
}

// the stream is too thin to walk on, but the lake and the pond are for skating
const skateTile = Array.from({ length: H }, () => Array(W).fill(false));
const inEllipse = (e, px, py, grow) => ((px - e.x) / (e.rx + grow)) ** 2 + ((py - e.y) / (e.ry + grow)) ** 2 < 1;
for (let ty = 0; ty < H; ty++) for (let tx = 0; tx < W; tx++) {
  const c = at(tx * T + 8, ty * T + 8);
  if (c === ICE) {
    if (inEllipse(LAKE, tx * T + 8, ty * T + 8, 10) || inEllipse(POND, tx * T + 8, ty * T + 8, 10)) skateTile[ty][tx] = true;
    else block(tx, ty);
  }
  if (c !== SNOW) reserved[ty][tx] = true;
}
for (const b of BRIDGES) reserve(Math.floor(b.cx / T) - 3, 21, Math.floor(b.cx / T) + 2, 28);
reserve(39, 33, 55, 48);   // lake shore
reserve(42, 6, 51, 15);    // forest clearing
reserve(44, 13, 49, 32);   // forest trail

// ------------------------------------------------------------ buildings
const shade = (x, y, rx, ry) => ground.ellipse(x, y, rx, ry, C.shadow);
function placeBuilding(sprite, hx, hy, tilesWide, mark) {
  const x = (hx + tilesWide / 2) * T, y = (hy + 2) * T + 1;
  shade(x, y - 1, tilesWide * 8 - 1, 3);
  addProp(sprite, x, y);
  for (let i = 0; i < tilesWide; i++) { block(hx + i, hy); block(hx + i, hy + 1); glyph[hy][hx + i] = mark; glyph[hy + 1][hx + i] = mark; }
  reserve(hx - 1, hy - 3, hx + tilesWide + 1, hy + 3);
  return { x, y };
}
function tub(x, y) {
  ground.ellipse(x, y + 1, 7, 2.5, C.shadow);
  ground.rect(x - 5, y - 5, 10, 6, C.wood); ground.rect(x - 5, y - 5, 10, 1, C.woodPale); ground.rect(x + 3, y - 4, 2, 5, C.woodDark);
  ground.rect(x - 5, y - 2, 10, 1, C.iron); ground.frame(x - 6, y - 6, 12, 8, C.outline); ground.rect(x - 4, y - 6, 8, 1, C.snow);
}
const smokeAt = (pos, shape) => ({ x: pos.x + (shape === "gable" ? 16 : 14.5), y: sk(pos.y) + (shape === "gable" ? 66 : 70) });
const cabinPos = placeBuilding("cabin", cabin.hx, cabin.hy, 4, "C");
addProp("woodpile", (cabin.hx + 4.9) * T, (cabin.hy + 2) * T - 1); block(cabin.hx + 4, cabin.hy + 1);
addProp("barrel", (cabin.hx - 0.4) * T, (cabin.hy + 2) * T - 1); block(cabin.hx - 1, cabin.hy + 1);
const standX = 11.5 * T, standY = 9 * T;
shade(standX, standY - 1, 23, 3);
addProp("stand", standX, standY + 1);
for (let i = 10; i <= 12; i++) { block(i, 7); block(i, 8); glyph[8][i] = "S"; }
reserve(3, 3, 15, 12);
addProp("signpost", 18.2 * T, 10 * T - 2); block(18, 9);
addProp("crates", 13.8 * T, 9 * T - 1); block(13, 8);
addProp("workbench", 8.6 * T, 9 * T - 2); block(8, 8);
addProp("nameboard", 9.7 * T, 13 * T - 1); for (let x = 8; x <= 11; x++) block(x, 12);
addProp("mailbox", 4.6 * T, 13 * T - 2); block(4, 12);

const HOUSE_SHAPES = ["eave", "gable", "eave", "gable", "eave", "gable", "eave", "gable", "eave", "gable", "eave"];
const houses = HOUSE_TILES.map(([hx, hy], i) => {
  const pos = placeBuilding(`house_${i}`, hx, hy, 4, "H");
  const treeX = (hx + 4) * T + 9, treeY = (hy + 2) * T - 3;
  tub(treeX, treeY);
  block(hx + 4, hy + 1);
  if (!solid[hy + 1][hx - 1] && surf[hy + 1][hx - 1] === "s") { addProp("bush", (hx - 0.5) * T, (hy + 2) * T - 2); block(hx - 1, hy + 1); }
  return {
    sprite: `house_${i}`, lit: `house_${i}_lit`, x: pos.x, y: sk(pos.y), doorX: pos.x, doorY: sk((hy + 2) * T + 8),
    treeX, treeY: sk(treeY + 2), name: meta.villagers[i], villager: `villager_${i}`,
    hint: `the ${WALL_NAME[meta.houses[i].wall]} house ${STREET[i]}`,
    glows: meta.houses[i].glows.map(([gx, up]) => ({ x: pos.x - 32 + gx, y: sk(pos.y) + up + 2, r: 22, c: [1, 0.74, 0.4] })),
    smoke: smokeAt(pos, HOUSE_SHAPES[i]),
  };
});
const barnPos = placeBuilding("barn", 42, 51, 4, "B");
addProp("haybale", 46.6 * T, 53 * T - 2); block(46, 52);
addProp("haybale", 43.5 * T, 59 * T); block(43, 58);
addProp("crates", 47.8 * T, 53 * T - 1); block(47, 52);
const chapelPos = placeBuilding("chapel", 17, 69, 6, "K");
reserve(14, 62, 26, 74);
const vendors = [];
STALLS.forEach((sx, i) => {
  const x = (sx + 1.5) * T, y = 60 * T;
  shade(x, y - 1, 23, 3);
  addProp(`stall_${i % 3}`, x, y + 1);
  for (let k = 0; k < 3; k++) { block(sx + k, 58); block(sx + k, 59); glyph[59][sx + k] = "M"; glyph[58][sx + k] = "M"; }
  if (i < 3) vendors.push({ sprite: `vendor_${i}`, x, y: sk(y - 12) });
});
reserve(7, 55, 32, 62);
addProp("barrel", 12.5 * T, 60 * T - 1); block(12, 59);
addProp("crates", 26.6 * T, 60 * T - 1); block(26, 59);

// ------------------------------------------------------------ lights
const WARM = [1, 0.72, 0.38];
const lights = [];
const addLight = (kind, cost, label, parts, glows, points) => lights.push({ id: lights.length, kind, cost, label, parts, glows, points });
for (const [tx, ty] of LANTERNS) {
  const [x, y] = tileBase(tx, ty);
  shade(x, y, 5, 2); block(tx, ty); reserve(tx - 1, ty - 1, tx + 1, ty + 1);
  addLight("lantern", 4, "street lantern", [{ sprite: "lantern", lit: "lantern_lit", x, y: sk(y + 1) }], [{ x, y: sk(y) + 25, r: 46, c: WARM }], [{ x, y: sk(y) }]);
}
for (const [fx, fy] of FENCES) {
  const x = (fx + 1.5) * T, y = fy * T + 14;
  addLight("fence", 6, "fence lights", [{ sprite: "", lit: "fence_lights", x, y: sk(y) }],
    [0, 1, 2].map((i) => ({ x: (fx + 0.5 + i) * T, y: sk(fy * T + 8), r: 18, c: [[1, 0.5, 0.45], [1, 0.85, 0.45], [0.5, 0.75, 1]][i] })),
    [{ x, y: sk((fy + 1) * T + 8) }, { x, y: sk(fy * T - 6) }]);
}
(() => {
  const b = BRIDGES[0], mid = (b.y0 + b.y1) / 2;
  addLight("bridge", 8, "bridge lights", [{ sprite: "", lit: "bridge_lights", x: b.cx, y: sk(b.y1 + 4) }],
    [[b.x0, -16], [b.x1, -16], [b.x0, 16], [b.x1, 16]].map(([x, dy]) => ({ x, y: sk(mid + dy), r: 22, c: WARM })),
    [{ x: b.cx, y: sk(b.y0 - 4) }, { x: b.cx, y: sk(mid) }, { x: b.cx, y: sk(b.y1 + 4) }]);
})();
for (const [tx, ty] of SNOWMEN) {
  const [x, y] = tileBase(tx, ty);
  block(tx, ty); reserve(tx - 1, ty - 1, tx + 1, ty + 1);
  addLight("snowman", 5, "snowman's lantern", [{ sprite: "snowman", lit: "snowman_lit", x, y: sk(y + 2) }], [{ x: x + 8, y: sk(y) + 11, r: 24, c: WARM }], [{ x, y: sk(y) }]);
}
const TRIO = [[1, 0.5, 0.45], [1, 0.85, 0.45], [0.5, 0.75, 1]];
addLight("cabin", 6, "cabin lights", [{ sprite: "", lit: "cabin_lights", x: cabinPos.x, y: sk(cabinPos.y) }],
  [-22, 0, 22].map((dx, i) => ({ x: cabinPos.x + dx, y: sk(cabinPos.y) + 26, r: 20, c: TRIO[i] })),
  [{ x: cabinPos.x - 22, y: sk((cabin.hy + 2) * T + 8) }]);
addLight("stand", 6, "stand lights", [{ sprite: "", lit: "stand_lights", x: standX, y: sk(standY + 1) }],
  [-14, 14].map((dx) => ({ x: standX + dx, y: sk(standY) + 28, r: 20, c: WARM })), [{ x: standX + 30, y: sk(standY + 2) }]);
for (const [tx, ty] of POLES) { const [x, y] = tileBase(tx, ty); shade(x, y, 4, 2); addProp("pole", x, y + 1); block(tx, ty); }
for (const row of [38, 47]) {
  const [, y] = tileBase(14, row);
  addLight("span", 10, "square garland", [{ sprite: "", lit: "span_lights", x: 320, y: sk(y - 38 + 15) }],
    [0, 1, 2, 3, 4].map((i) => ({ x: 240 + i * 40, y: sk(y - 32), r: 24, c: WARM })),
    [{ x: 14.5 * T, y: sk(y) }, { x: 25.5 * T, y: sk(y) }]);
}
function paperSet(tiles, label) {
  addLight("pond", 10, label, tiles.map(([tx, ty]) => { const [x, y] = tileBase(tx, ty); block(tx, ty); reserve(tx - 1, ty - 1, tx + 1, ty + 1); return { sprite: "paperlantern", lit: "paperlantern_lit", x, y: sk(y + 1) }; }),
    tiles.map(([tx, ty]) => { const [x, y] = tileBase(tx, ty); return { x: x + 2, y: sk(y) + 11, r: 24, c: [1, 0.55, 0.35] }; }),
    tiles.map(([tx, ty]) => { const [x, y] = tileBase(tx, ty); return { x, y: sk(y) }; }));
}
paperSet(PAPER, "pond lanterns");
paperSet(LAKE_LAMPS, "lake lanterns");
function fireLight(kind, tile, label, cost, flameUp) {
  const [x, y] = tileBase(tile[0], tile[1]);
  block(tile[0], tile[1]); reserve(tile[0] - 1, tile[1] - 1, tile[0] + 1, tile[1] + 1);
  addLight(kind, cost, label, [{ sprite: kind, lit: `${kind}_lit_0`, x, y: sk(y + 2) }], [{ x, y: sk(y) + flameUp, r: 50, c: [1, 0.62, 0.3] }], [{ x, y: sk(y) }]);
}
fireLight("campfire", CAMPFIRE, "campfire", 6, 8);
fireLight("brazier", BRAZIER, "market brazier", 6, 12);
addLight("market", 10, "market lights", STALLS.map((sx, i) => ({ sprite: "", lit: `stall_${i % 3}_lit`, x: (sx + 1.5) * T, y: sk(60 * T + 1) })),
  STALLS.map((sx) => ({ x: (sx + 1.5) * T, y: sk(60 * T) + 36, r: 26, c: WARM })),
  [{ x: (STALLS[3] + 1.5) * T, y: sk(60 * T + 8) }]);
addLight("chapel", 10, "chapel windows", [{ sprite: "", lit: "chapel_lit", x: chapelPos.x, y: sk(chapelPos.y) }],
  meta.chapel.glows.map(([gx, up, r], i) => ({ x: chapelPos.x - 48 + gx, y: sk(chapelPos.y) + up, r: r + 8, c: i === 0 ? [1, 0.7, 0.55] : i === 3 ? WARM : [0.7, 0.75, 1] })),
  [{ x: chapelPos.x - 34, y: sk(71 * T + 6) }, { x: chapelPos.x + 34, y: sk(71 * T + 6) }]);

// ------------------------------------------------------------ decoration
addProp("well", 16.5 * T, 46 * T); block(16, 45); shade(16.5 * T, 46 * T - 1, 11, 2.5);
const bench = (tx, ty) => { addProp("bench", (tx + 0.5) * T, (ty + 1) * T - 2); block(tx, ty); shade((tx + 0.5) * T, (ty + 1) * T - 2, 12, 2); };
bench(7, 48); bench(22, 39); bench(39, 40); bench(44, 11); bench(50, 12); bench(30, 62);
reserve(2, 45, 12, 51); reserve(13, 37, 26, 48); reserve(10, 14, 14, 18);
// planter for the great tree in the square
ground.ellipse(SQUARE_TREE.x, SQUARE_TREE.y + 1, 17, 7, C.outline);
ground.ellipse(SQUARE_TREE.x, SQUARE_TREE.y, 16, 6, C.stoneLight);
ground.ellipse(SQUARE_TREE.x, SQUARE_TREE.y + 1, 15, 5, C.stone);
ground.ellipse(SQUARE_TREE.x, SQUARE_TREE.y - 1, 12, 3.5, hex("#6a5446"));
ground.ellipse(SQUARE_TREE.x - 2, SQUARE_TREE.y - 1, 8, 2, C.snowMid);
block(19, 42); block(20, 42);
block(GIANT[0], GIANT[1]);

const lot = [];
for (const ty of LOT.rows) for (const tx of LOT.cols) { const [x, y] = tileBase(tx, ty); lot.push({ x, y: sk(y) }); block(tx, ty); glyph[ty][tx] = "l"; }

// forest wall and scattered trees; the old forest in the north-east is denser
const rand = rng(2024);
for (let ty = 0; ty < H; ty++) for (let tx = 0; tx < W; tx++) {
  const ring = Math.min(tx, ty, W - 1 - tx, H - 1 - ty);
  const density = tx >= 38 && ty <= 21 ? 0.32 : tx >= 38 && ty >= 47 ? 0.14 : ty >= 63 ? 0.14 : 0.085;
  if (ring < 2) {
    block(tx, ty); glyph[ty][tx] = "t";
    if (ring === 1 || (tx + ty) % 2 === 0) { const [x, y] = tileBase(tx, ty); addProp(`pine_${Math.floor(rand() * 3)}`, x + Math.round(rand() * 6 - 3), y + Math.round(rand() * 4 - 2)); }
  } else if (!reserved[ty][tx] && !solid[ty][tx] && surf[ty][tx] === "s" && rand() < density) {
    const [x, y] = tileBase(tx, ty);
    const kind = rand();
    if (kind < 0.12) addProp("bush", x, y);
    else addProp(kind < 0.36 ? `bare_${Math.floor(rand() * 2)}` : `pine_${Math.floor(rand() * 3)}`, x, y);
    block(tx, ty); glyph[ty][tx] = kind < 0.12 ? "" : "t";
  }
}
// twigs, tufts and stones poking through the snow
for (let i = 0; i < 900; i++) {
  const px = 34 + Math.floor(rand() * (PW - 68)), py = 34 + Math.floor(rand() * (PH - 68));
  if (at(px, py) !== SNOW || at(px + 3, py) !== SNOW || at(px, py + 3) !== SNOW) continue;
  const kind = rand();
  if (kind < 0.4) { ground.set(px, py, hex("#8fa07a")); ground.set(px + 1, py - 1, hex("#7b8f6c")); ground.set(px + 2, py, hex("#8fa07a")); ground.set(px + 1, py, hex("#6a7d5e")); }
  else if (kind < 0.7) { ground.rect(px, py, 3, 2, C.stone); ground.set(px, py, C.stoneLight); ground.rect(px, py + 2, 3, 1, G.bank); ground.rect(px, py - 1, 2, 1, C.snow); }
  else { ground.line(px, py, px + 4, py - 1, hex("#7a5a48")); ground.set(px + 2, py - 2, hex("#7a5a48")); }
}

// ------------------------------------------------------------ write everything
fs.mkdirSync(ART, { recursive: true });
for (const file of fs.readdirSync(ART)) if (file.endsWith(".png")) fs.unlinkSync(path.join(ART, file));
for (const [name, cv] of Object.entries(sprites)) writePng(path.join(ART, name + ".png"), cv);
writePng(path.join(ART, "ground.png"), ground, false);

const grid = (test) => Array.from({ length: H }, (_, r) => Array.from({ length: W }, (_, tx) => (test(tx, H - 1 - r) ? "1" : "0")).join("")).join("");
const giantBase = tileBase(GIANT[0], GIANT[1]);
const zone = (x0, y0, x1, y1) => ({ x0: x0 * T, y0: sk((y1 + 1) * T), x1: (x1 + 1) * T, y1: sk(y0 * T) });
const world = {
  width: PW, height: PH, tile: T, cols: W, rows: H,
  solid: grid((tx, ty) => solid[ty][tx]),
  snow: grid((tx, ty) => at(tx * T + 8, ty * T + 8) === SNOW),
  ice: grid((tx, ty) => skateTile[ty][tx]),
  stroll: grid((tx, ty) => { const c = at(tx * T + 8, ty * T + 8); return ty >= 28 && ty <= 62 && !solid[ty][tx] && (c === PATH || c === COBBLE); }),
  props: props.map((p) => ({ sprite: p.sprite, x: p.x, y: sk(p.y) })),
  houses, lights, lot, vendors,
  giant: { x: giantBase[0], y: sk(giantBase[1]) },
  square: { x: SQUARE_TREE.x, y: sk(SQUARE_TREE.y + 2) },
  cabinDoor: { x: cabinPos.x, y: sk((cabin.hy + 2) * T + 8) },
  cabinSmoke: smokeAt(cabinPos, "eave"),
  customer: { x: standX, y: sk(standY + 9) },
  gate: { x: (LOT.x0 + 0.5) * T, y: sk(11 * T) },
  skate: { x: LAKE.x, y: sk(LAKE.y), rx: 4.4 * T, ry: 3.1 * T },
  sheepZone: zone(PEN.x0 + 1, PEN.y0 + 1, PEN.x1 - 1, PEN.y1 - 1),
  deerZone: zone(39, 3, 54, 20),
  cat: { x: 17.6 * T, y: sk(46 * T + 7) },
  workshop: { x: 8.6 * T, y: sk(9 * T + 8) },
  garden: { col0: GARDEN.x0 + 1, col1: GARDEN.x1 - 1, row0: H - 1 - (GARDEN.y1 - 1), row1: H - 1 - (GARDEN.y0 + 1) },
  gardenGate: { x: (GARDEN.gate + 0.5) * T, y: sk(13 * T + 4) },
  nameboard: { x: 9.7 * T, y: sk(13 * T - 1) },
  chapelDoor: { x: chapelPos.x, y: sk(71 * T + 8) },
  stalls: ["treat", "gift", "cocoa"].map((kind, i) => ({ kind, x: (STALLS[i] + 1.5) * T, y: sk(60 * T + 8) })),
  labels: [["Your farm", 8, 3], ["Your garden", 6, 21.5], ["Tree lot", 30, 1], ["Old forest", 46, 6], ["Square", 19.5, 37], ["Lake", 47.5, 40], ["Barn", 46, 50], ["Market", 19.5, 57], ["Chapel", 19.5, 73]]
    .map(([text, tx, ty]) => ({ text, x: tx / W, y: ty / H })),
};
fs.writeFileSync(path.join(ART, "world.json"), JSON.stringify(world));

// minimap: one small picture of the whole place, six pixels to a tile
(() => {
  const S = 6, map = new Canvas(W * S, H * S);
  const M = { snow: hex("#eef3fd"), path: hex("#cdb48f"), cobble: hex("#9aa3b5"), ice: hex("#a9d8ee"), plank: hex("#9a6a45"), tree: hex("#3f8a63"), treeDark: hex("#2a6b4d"), fir: hex("#5fae5a") };
  for (let ty = 0; ty < H; ty++) for (let tx = 0; tx < W; tx++) for (let j = 0; j < S; j++) for (let i = 0; i < S; i++) {
    const c = at(tx * T + Math.floor(((i + 0.5) / S) * T), ty * T + Math.floor(((j + 0.5) / S) * T));
    map.set(tx * S + i, ty * S + j, c === PATH ? M.path : c === COBBLE ? M.cobble : c === ICE ? M.ice : wood(c) ? M.plank : hash2(tx * S + i, ty * S + j, 81) < 0.08 ? hex("#dfe8f8") : M.snow);
  }
  for (let ty = 0; ty < H; ty++) for (let tx = 0; tx < W; tx++) {
    const g = glyph[ty][tx], x = tx * S, y = ty * S;
    if (g === "t" || g === "l") { const c = g === "l" ? M.fir : M.tree; map.set(x + 2, y, c); map.rect(x + 1, y + 1, 3, 2, c); map.rect(x, y + 3, 5, 2, g === "l" ? c : M.treeDark); map.set(x + 2, y + 5, hex("#6b4a36")); }
    if (g === "f") map.rect(x, y + 2, S, 1, hex("#8f5f3f"));
  }
  const building = (hx, hy, w, roof, wall) => {
    const x = hx * S, y = hy * S - 3, pw = w * S, ph = 2 * S + 3;
    map.rect(x, y, pw, ph, wall); map.rect(x, y, pw, 7, roof); map.rect(x, y, pw, 2, hex("#ffffff")); map.frame(x, y, pw, ph, C.outline); map.rect(x + pw / 2 - 1, y + ph - 4, 2, 3, C.outline);
  };
  const roofs = { red: "#c9483a", blue: "#4a78c8", green: "#3f8f6e", purple: "#8660bd", brown: "#96603d", slate: "#5f6b85" };
  const walls = { red: "#c2584a", cream: "#f1e3c4", stone: "#b3b9c6", blue: "#6f93c4", yellow: "#e6c463", green: "#7fae7a", pink: "#dba0ac" };
  HOUSE_TILES.forEach(([hx, hy], i) => building(hx, hy, 4, hex(roofs[meta.houses[i].roof]), hex(walls[meta.houses[i].wall])));
  building(cabin.hx, cabin.hy, 4, hex("#96603d"), hex("#a06c45"));
  building(42, 51, 4, hex("#96603d"), hex("#b8443b"));
  building(17, 69, 6, hex("#5f6b85"), hex("#b3b9c6")); map.rect(19.5 * S + 2, 69 * S - 9, 3, 6, hex("#5f6b85")); map.rect(19.5 * S + 3, 69 * S - 11, 1, 2, C.gold);
  for (const sx of STALLS) { map.rect(sx * S, 58 * S + 2, 3 * S, S + 2, hex("#b8443b")); for (let i = 0; i < 3 * S; i += 4) map.rect(sx * S + i, 58 * S + 2, 2, S + 2, C.cream); map.frame(sx * S, 58 * S + 2, 3 * S, S + 2, C.outline); }
  map.rect(10 * S, 7 * S + 2, 3 * S, S + 2, C.red); map.frame(10 * S, 7 * S + 2, 3 * S, S + 2, C.outline);
  map.ellipse(SQUARE_TREE.x / T * S, SQUARE_TREE.y / T * S, 4, 3, C.stoneDark);
  const framed = new Canvas(map.w + 8, map.h + 8);
  framed.rect(0, 0, framed.w, framed.h, hex("#643f2b")); framed.rect(1, 1, framed.w - 2, framed.h - 2, hex("#b9845a")); framed.rect(3, 3, framed.w - 6, framed.h - 6, C.outline);
  framed.blit(map, 4, 4);
  writePng(path.join(ART, "minimap.png"), framed, false);
  world.mapInset = 4 / framed.w;
  fs.writeFileSync(path.join(ART, "world.json"), JSON.stringify(world));
})();

// app icon: a lit fir on a night sky
(() => {
  const small = new Canvas(64, 64);
  for (let y = 0; y < 64; y++) for (let x = 0; x < 64; x++) small.set(x, y, mix(hex("#1d2a52"), hex("#3f5a96"), y / 64));
  for (let i = 0; i < 26; i++) small.set(Math.floor(hash2(i, 1, 3) * 64), Math.floor(hash2(i, 2, 3) * 44), i % 3 ? hex("#c9d8f5") : C.snow);
  ball(small, 32, 66, 44, 12, [C.snow, C.snowMid, C.snowShade]);
  const glow = sprites.glow;
  for (let y = 0; y < 64; y++) for (let x = 0; x < 64; x++) { const a = glow.get(x, y)[3] / 255 * 0.5; const c = small.get(x, Math.max(0, y - 6)); small.set(x, Math.max(0, y - 6), [Math.min(255, c[0] + 255 * a), Math.min(255, c[1] + 190 * a), Math.min(255, c[2] + 90 * a), 255]); }
  small.stamp(sprites.fir_210, 32, 58); small.stamp(sprites.fir_210_lit, 32, 58);
  const icon = new Canvas(1024, 1024);
  icon.blit(small, 0, 0, 16);
  writePng(ICON, icon, false);
})();

// previews: the whole map by day, and by night with every light on
fs.mkdirSync(PREVIEW, { recursive: true });
const day = new Canvas(PW, PH);
day.blit(ground, 0, 0);
const drawn = props.map((p) => ({ ...p }));
for (const l of lights) for (const p of l.parts) if (p.sprite) drawn.push({ sprite: p.sprite, x: p.x, y: PH - p.y });
lot.forEach((s, i) => drawn.push({ sprite: `fir_${i % 3}${Math.floor(i / 3) % 3}${i % 2}`, x: s.x, y: PH - s.y + 2 }));
drawn.push({ sprite: "giant", x: world.giant.x, y: PH - world.giant.y + 2 });
drawn.push({ sprite: "villager_3_down_0", x: world.customer.x, y: PH - world.customer.y }, { sprite: "hero_0_0_down_0", x: world.cabinDoor.x, y: PH - world.cabinDoor.y + 4 });
for (const v of vendors) drawn.push({ sprite: v.sprite + "_down_0", x: v.x, y: PH - v.y });
[["villager_0_side_1", 150, 510], ["villager_5_down_1", 322, 600], ["villager_8_side_0", 420, 690], ["kid_2_down_1", 280, 660], ["villager_6_down_0", 300, 975], ["villager_1_side_1", 200, 972],
  ["kid_0_side_1", 730, 630], ["kid_1_side_0", 800, 670], ["sheep_0", 700, 960], ["sheep_1", 760, 985], ["sheep_0", 790, 945], ["deer_0", 690, 150], ["deer_1", 820, 230], ["cat_0", world.cat.x, PH - world.cat.y],
  ["bird_0", 130, 560], ["bird_1", 142, 566], ["bird_0", 520, 330]].forEach(([sprite, x, y]) => drawn.push({ sprite, x, y }));
drawn.sort((a, b) => a.y - b.y);
for (const p of drawn) day.stamp(sprites[p.sprite], p.x, p.y);
writePng(path.join(PREVIEW, "map_day.png"), day, false);

const night = new Canvas(PW, PH);
const tint = [0.38, 0.44, 0.76];
const dusk = new Canvas(PW, PH);
dusk.blit(day, 0, 0);
houses.forEach((h, i) => { dusk.stamp(sprites[`fir_${i % 3}${(i + 1) % 3}0`], h.treeX, PH - h.treeY); });
dusk.stamp(sprites.giant, world.square.x, PH - world.square.y);
for (let i = 0; i < PW * PH; i++) { night.d[i * 4] = dusk.d[i * 4] * tint[0]; night.d[i * 4 + 1] = dusk.d[i * 4 + 1] * tint[1]; night.d[i * 4 + 2] = dusk.d[i * 4 + 2] * tint[2]; night.d[i * 4 + 3] = 255; }
const emit = [];
const glows = [];
houses.forEach((h, i) => { emit.push([h.lit, h.x, PH - h.y], [`fir_${i % 3}${(i + 1) % 3}0_lit`, h.treeX, PH - h.treeY]); glows.push(...h.glows, { x: h.treeX, y: h.treeY + 16, r: 30, c: [1, 0.85, 0.6] }); });
for (const l of lights) { for (const p of l.parts) emit.push([p.lit, p.x, PH - p.y]); glows.push(...l.glows); }
for (const n of ["giant_lit1", "giant_lit2", "giant_lit3"]) emit.push([n, world.square.x, PH - world.square.y]);
glows.push({ x: world.square.x, y: world.square.y + 40, r: 80, c: [1, 0.85, 0.55] });
emit.push(["cabin_lit", cabinPos.x, cabinPos.y]);
for (const [name, x, y] of emit) night.stamp(sprites[name], x, y);
for (const g of glows) {
  const scale = g.r / 32;
  for (let y = Math.floor(PH - g.y - g.r); y < PH - g.y + g.r; y++) for (let x = Math.floor(g.x - g.r); x < g.x + g.r; x++) {
    if (!night.inside(x, y)) continue;
    const a = sprites.glow.get(Math.floor((x - g.x + g.r) / scale), Math.floor((y - (PH - g.y) + g.r) / scale))[3] / 255 * 0.7;
    const i = (y * PW + x) * 4;
    for (let k = 0; k < 3; k++) night.d[i + k] = Math.min(255, night.d[i + k] + 255 * g.c[k] * a);
  }
}
writePng(path.join(PREVIEW, "map_night.png"), night, false);
const zoom = (src, name, x, y, w, h, s) => { const o = new Canvas(w * s, h * s); o.blit(src.crop(x, y, w, h), 0, 0, s); writePng(path.join(PREVIEW, name), o, false); };
zoom(day, "lake.png", 590, 500, 320, 300, 3);
zoom(day, "market.png", 100, 880, 330, 300, 3);
zoom(night, "market_night.png", 100, 880, 330, 300, 3);
zoom(day, "forest.png", 600, 60, 310, 300, 3);
zoom(day, "garden.png", 16, 60, 310, 290, 3);
zoom(day, "barn.png", 600, 780, 310, 280, 3);
const mini = (() => { const m = new Canvas(0, 0); return m; })();
console.log("sprites", Object.keys(sprites).length, "props", props.length, "lights", lights.length, "cost", lights.reduce((a, l) => a + l.cost, 0));

// Lays out the farm and village, bakes the ground into one image, and writes
// the sprites, world.json, app icon and preview pictures.
// Usage: node build.js <artDir> <iconPath> <previewDir>
const fs = require("fs");
const path = require("path");
const { hex, mix, Canvas, writePng, rng, hash2, noise } = require("./lib");
const { sprites, meta, C, ball } = require("./sprites");

const [ART, ICON, PREVIEW] = process.argv.slice(2);
const W = 40, H = 60, T = 16, PW = W * T, PH = H * T;
const sk = (imgY) => PH - imgY; // image rows grow downward, the game's y grows upward

// ------------------------------------------------------------ layout
const surf = Array.from({ length: H }, () => Array(W).fill("s"));
const fill = (x0, y0, x1, y1, ch) => { for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) surf[y][x] = ch; };
fill(5, 10, 23, 11, "p");   // farm lane, from the cabin to the lot gate
fill(5, 8, 6, 9, "p");      // cabin doorstep
fill(19, 10, 20, 54, "p");  // main road
fill(4, 31, 35, 32, "p");   // north street
fill(3, 42, 36, 43, "p");   // middle street
fill(5, 53, 34, 54, "p");   // south street
fill(14, 38, 25, 47, "c");  // village square

const streamY = (px) => 24.5 * T + 9 * Math.sin(px / 37) + 5 * Math.sin(px / 13 + 1);
const BRIDGE = { x0: 300, x1: 340, y0: Math.round(streamY(320)) - 27, y1: Math.round(streamY(320)) + 27 };
const POND = { x: 31 * T, y: 47.6 * T, rx: 3.1 * T, ry: 1.6 * T };

const cabin = { hx: 4, hy: 6 };
const HOUSE_TILES = [[5, 29], [11, 29], [24, 29], [30, 29], [3, 40], [8, 40], [28, 40], [33, 40], [6, 51], [24, 51], [30, 51]];
const STREET = ["on the north street", "on the north street", "on the north street", "on the north street", "west of the square", "west of the square", "east of the square", "east of the square", "on the south street", "on the south street", "on the south street"];
const WALL_NAME = { red: "red", cream: "cream", stone: "stone", blue: "blue", yellow: "yellow", green: "green", pink: "pink" };
const LANTERNS = [[18, 14], [21, 19], [18, 28], [21, 35], [18, 50], [21, 50], [8, 33], [14, 33], [27, 33], [33, 33], [5, 44], [10, 44], [29, 44], [34, 44], [9, 55], [16, 55], [27, 55], [33, 55]];
const FENCES = [[15, 36], [22, 36], [3, 46], [7, 46], [15, 50], [22, 50]];
const LOT = { x0: 22, y0: 2, x1: 37, y1: 19, gate: [10, 11], cols: [24, 27, 30, 33, 36], rows: [5, 9, 13, 17] };
const GIANT = [12, 16];
const SQUARE_TREE = { x: 320, y: 43 * T - 4 };
const POLES = [[14, 38], [25, 38], [14, 47], [25, 47]];
const SNOWMEN = [[5, 48], [10, 49]];
const PAPER = [[27, 46], [35, 46], [28, 50], [34, 50]];

const solid = Array.from({ length: H }, () => Array(W).fill(false));
const reserved = Array.from({ length: H }, () => Array(W).fill(false));
const block = (x, y) => { if (x >= 0 && y >= 0 && x < W && y < H) solid[y][x] = true; };
const reserve = (x0, y0, x1, y1) => { for (let y = Math.max(0, y0); y <= Math.min(H - 1, y1); y++) for (let x = Math.max(0, x0); x <= Math.min(W - 1, x1); x++) reserved[y][x] = true; };

const props = []; // static, depth-sorted sprites: { sprite, x, y } with y at the base, image coordinates
const addProp = (sprite, x, y) => props.push({ sprite, x, y });
const tileBase = (tx, ty) => [(tx + 0.5) * T, (ty + 1) * T - 2];

// ------------------------------------------------------------ pixel classes
const SNOW = 0, PATH = 1, COBBLE = 2, ICE = 3, PLANK = 4;
const cls = new Uint8Array(PW * PH);
for (let py = 0; py < PH; py++) for (let px = 0; px < PW; px++) {
  const wx = px + (noise(px, py, 9, 1) - 0.5) * 7, wy = py + (noise(px, py, 9, 2) - 0.5) * 7;
  const tx = Math.min(W - 1, Math.max(0, Math.floor(wx / T))), ty = Math.min(H - 1, Math.max(0, Math.floor(wy / T)));
  let c = surf[ty][tx] === "p" ? PATH : surf[ty][tx] === "c" ? COBBLE : SNOW;
  const wob = (noise(px, py, 11, 3) - 0.5) * 6;
  if (Math.abs(py - streamY(px)) < 17 + wob && px > 20 && px < PW - 20) c = ICE;
  if (((px - POND.x) / POND.rx) ** 2 + ((py - POND.y) / POND.ry) ** 2 < 1 + wob * 0.04) c = ICE;
  if (px >= BRIDGE.x0 && px < BRIDGE.x1 && py >= BRIDGE.y0 && py < BRIDGE.y1) c = PLANK;
  cls[py * PW + px] = c;
}
const at = (px, py) => (px < 0 || py < 0 || px >= PW || py >= PH ? SNOW : cls[py * PW + px]);

// ------------------------------------------------------------ ground painting
const ground = new Canvas(PW, PH);
const G = {
  snow: [hex("#ffffff"), hex("#eef3fd"), hex("#dfe8f8")], drift: hex("#d0dcf2"), bank: hex("#b4c4e6"), speck: hex("#c5d3ee"),
  path: [hex("#ddd2bf"), hex("#c1ab8f"), hex("#a78f74")], pathEdge: hex("#8c775f"), pebble: hex("#857565"),
  stones: [hex("#9aa3b5"), hex("#8791a6"), hex("#aab2c2"), hex("#7f899e")], mortar: hex("#646e88"), crevice: hex("#cdd7ea"),
  ice: hex("#bfe2f2"), iceLight: hex("#e6f6fc"), iceDark: hex("#a3d0e7"), crack: hex("#86bcd8"), iceEdge: hex("#74a8cc"),
  plank: [hex("#9a6a45"), hex("#8a5c3b"), hex("#b07d54")], plankDark: hex("#5f3b29"),
};
for (let py = 0; py < PH; py++) for (let px = 0; px < PW; px++) {
  const c = at(px, py);
  let col;
  if (c === SNOW) {
    const n = noise(px, py, 26, 3) * 0.6 + noise(px, py, 7, 4) * 0.4;
    col = n > 0.6 ? G.snow[0] : n < 0.4 ? G.snow[2] : G.snow[1];
    if (Math.abs(noise(px, py, 34, 5) - 0.5) < 0.011) col = G.drift;
    const h = hash2(px, py, 6);
    if (h < 0.004) col = G.snow[0]; else if (h < 0.007) col = G.speck;
    const below = at(px, py + 1), below2 = at(px, py + 2);
    if (below !== SNOW) col = G.bank; else if (below2 !== SNOW) col = G.drift;
    if (at(px - 1, py) !== SNOW || at(px + 1, py) !== SNOW) col = G.drift;
  } else if (c === PATH) {
    const n = noise(px, py, 10, 6) * 0.7 + noise(px, py, 4, 7) * 0.3;
    col = n > 0.6 ? G.path[0] : n < 0.38 ? G.path[2] : G.path[1];
    if (noise(px, py, 6, 8) > 0.8) col = G.snow[1];
    if (hash2(px, py, 9) < 0.008) col = G.pebble;
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
    if (noise(px, py, 9, 17) > 0.8) col = G.snow[1];
    if (at(px, py - 1) !== ICE && at(px, py - 1) !== PLANK) col = G.iceEdge;
    else if (at(px - 1, py) === SNOW || at(px + 1, py) === SNOW || at(px, py + 1) === SNOW) col = G.iceLight;
  } else {
    const ly = py - BRIDGE.y0;
    col = ly % 4 === 3 ? G.plankDark : G.plank[(Math.floor(ly / 4) * 3) % 3];
    if (ly % 4 === 1 && (px === BRIDGE.x0 + 6 || px === BRIDGE.x1 - 7)) col = G.plankDark;
    if (hash2(px, py, 18) < 0.05) col = G.snow[1];
  }
  ground.set(px, py, col);
}
// bridge rails
for (const rx of [BRIDGE.x0, BRIDGE.x1 - 3]) {
  ground.rect(rx, BRIDGE.y0 - 2, 3, BRIDGE.y1 - BRIDGE.y0 + 4, C.woodDark);
  ground.rect(rx, BRIDGE.y0 - 2, 1, BRIDGE.y1 - BRIDGE.y0 + 4, C.wood);
  for (let y = BRIDGE.y0 - 3; y < BRIDGE.y1; y += 9) { ground.rect(rx - 1, y, 5, 4, C.woodDark); ground.rect(rx - 1, y - 1, 5, 2, C.snow); ground.rect(rx - 1, y + 4, 5, 1, C.outline); }
}
// fences
function fenceH(tx, ty) {
  const x = tx * T, y = ty * T;
  ground.rect(x, y + 13, 16, 2, C.shadow);
  ground.rect(x, y + 6, 16, 2, C.woodLight); ground.rect(x, y + 7, 16, 1, C.wood);
  ground.rect(x, y + 10, 16, 2, C.wood); ground.rect(x, y + 11, 16, 1, C.woodDark);
  for (const ox of [1, 9]) { ground.rect(x + ox, y + 3, 3, 11, C.wood); ground.rect(x + ox + 2, y + 3, 1, 11, C.woodDark); ground.rect(x + ox, y + 2, 3, 2, C.snow); ground.rect(x + ox, y + 13, 3, 1, C.outline); }
  for (let i = 0; i < 16; i++) if (hash2(x + i, y, 20) < 0.6) ground.set(x + i, y + 5, C.snow);
  block(tx, ty);
}
function fenceV(tx, ty) {
  const x = tx * T, y = ty * T;
  ground.rect(x + 7, y, 2, 16, C.wood); ground.rect(x + 8, y, 1, 16, C.woodDark);
  ground.rect(x + 9, y, 1, 16, C.shadow);
  for (const oy of [1, 9]) { ground.rect(x + 6, y + oy, 4, 6, C.wood); ground.rect(x + 9, y + oy, 1, 6, C.woodDark); ground.rect(x + 6, y + oy - 1, 4, 2, C.snow); ground.rect(x + 6, y + oy + 6, 4, 1, C.outline); }
  block(tx, ty);
}
for (let x = LOT.x0; x <= LOT.x1; x++) { fenceH(x, LOT.y0); fenceH(x, LOT.y1); }
for (let y = LOT.y0 + 1; y < LOT.y1; y++) { if (!LOT.gate.includes(y)) fenceV(LOT.x0, y); fenceV(LOT.x1, y); }
for (const [fx, fy] of FENCES) for (let i = 0; i < 3; i++) fenceH(fx + i, fy);
reserve(LOT.x0 - 1, LOT.y0 - 1, LOT.x1 + 1, LOT.y1 + 1);
for (const [fx, fy] of FENCES) reserve(fx - 1, fy - 1, fx + 3, fy + 1);

// ice is not walkable, the bridge is
for (let ty = 0; ty < H; ty++) for (let tx = 0; tx < W; tx++) {
  const c = at(tx * T + 8, ty * T + 8);
  if (c === ICE) block(tx, ty);
  if (c !== SNOW) reserved[ty][tx] = true;
}
for (let ty = 21; ty <= 28; ty++) reserve(17, ty, 22, ty);

// ------------------------------------------------------------ buildings
const shade = (x, y, rx, ry) => ground.ellipse(x, y, rx, ry, C.shadow);
function placeBuilding(sprite, hx, hy, tilesWide) {
  const x = (hx + tilesWide / 2) * T, y = (hy + 2) * T + 1;
  shade(x, y - 1, tilesWide * 8 - 1, 3);
  addProp(sprite, x, y);
  for (let i = 0; i < tilesWide; i++) { block(hx + i, hy); block(hx + i, hy + 1); }
  reserve(hx - 1, hy - 3, hx + tilesWide + 1, hy + 3);
  return { x, y };
}
function tub(x, y) {
  ground.ellipse(x, y + 1, 7, 2.5, C.shadow);
  ground.rect(x - 5, y - 5, 10, 6, C.wood); ground.rect(x - 5, y - 5, 10, 1, C.woodPale); ground.rect(x + 3, y - 4, 2, 5, C.woodDark);
  ground.rect(x - 5, y - 2, 10, 1, C.iron); ground.rect(x - 4, y - 6, 8, 1, C.snow); ground.frame(x - 6, y - 6, 12, 8, C.outline); ground.rect(x - 4, y - 6, 8, 1, C.snow);
}
const cabinPos = placeBuilding("cabin", cabin.hx, cabin.hy, 4);
addProp("woodpile", (cabin.hx + 4.9) * T, (cabin.hy + 2) * T - 1); block(cabin.hx + 4, cabin.hy + 1);
const standX = 11.5 * T, standY = 9 * T;
shade(standX, standY - 1, 23, 3);
addProp("stand", standX, standY + 1);
for (let i = 10; i <= 12; i++) { block(i, 7); block(i, 8); }
reserve(3, 3, 15, 12);
addProp("signpost", 18.2 * T, 10 * T - 2); block(18, 9);

const houses = HOUSE_TILES.map(([hx, hy], i) => {
  const pos = placeBuilding(`house_${i}`, hx, hy, 4);
  const treeX = (hx + 4) * T + 9, treeY = (hy + 2) * T - 3;
  tub(treeX, treeY);
  block(hx + 4, hy + 1);
  return {
    sprite: `house_${i}`, lit: `house_${i}_lit`, x: pos.x, y: sk(pos.y), doorX: pos.x, doorY: sk((hy + 2) * T + 8),
    treeX, treeY: sk(treeY + 2), name: meta.villagers[i], villager: `villager_${i}`,
    hint: `the ${WALL_NAME[meta.houses[i].wall]} house ${STREET[i]}`,
    glows: meta.houses[i].glows.map(([gx, up]) => ({ x: pos.x - 32 + gx, y: sk(pos.y) + up + 2, r: 22, c: [1, 0.74, 0.4] })),
  };
});

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
  const mid = (BRIDGE.y0 + BRIDGE.y1) / 2;
  addLight("bridge", 8, "bridge lights", [{ sprite: "", lit: "bridge_lights", x: 320, y: sk(BRIDGE.y1 + 4) }],
    [[300, -16], [340, -16], [300, 16], [340, 16]].map(([x, dy]) => ({ x, y: sk(mid + dy), r: 22, c: WARM })),
    [{ x: 320, y: sk(BRIDGE.y0 - 4) }, { x: 320, y: sk(mid) }, { x: 320, y: sk(BRIDGE.y1 + 4) }]);
})();
for (const [tx, ty] of SNOWMEN) {
  const [x, y] = tileBase(tx, ty);
  block(tx, ty); reserve(tx - 1, ty - 1, tx + 1, ty + 1);
  addLight("snowman", 5, "snowman's lantern", [{ sprite: "snowman", lit: "snowman_lit", x, y: sk(y + 2) }], [{ x: x + 8, y: sk(y) + 11, r: 24, c: WARM }], [{ x, y: sk(y) }]);
}
addLight("cabin", 6, "cabin lights", [{ sprite: "", lit: "cabin_lights", x: cabinPos.x, y: sk(cabinPos.y) }],
  [-22, 0, 22].map((dx) => ({ x: cabinPos.x + dx, y: sk(cabinPos.y) + 26, r: 20, c: [[1, 0.5, 0.45], [1, 0.85, 0.45], [0.5, 0.75, 1]][(dx + 22) / 22] })),
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
addLight("pond", 10, "pond lanterns", PAPER.map(([tx, ty]) => { const [x, y] = tileBase(tx, ty); block(tx, ty); reserve(tx - 1, ty - 1, tx + 1, ty + 1); return { sprite: "paperlantern", lit: "paperlantern_lit", x, y: sk(y + 1) }; }),
  PAPER.map(([tx, ty]) => { const [x, y] = tileBase(tx, ty); return { x: x + 2, y: sk(y) + 11, r: 24, c: [1, 0.55, 0.35] }; }),
  PAPER.map(([tx, ty]) => { const [x, y] = tileBase(tx, ty); return { x, y: sk(y) }; }));

// ------------------------------------------------------------ decoration
addProp("well", 16.5 * T, 46 * T); block(16, 45); shade(16.5 * T, 46 * T - 1, 11, 2.5);
addProp("bench", 7.5 * T, 49 * T - 2); block(7, 48); shade(7.5 * T, 49 * T - 2, 12, 2);
addProp("bench", 22.5 * T, 40 * T - 2); block(22, 39); shade(22.5 * T, 40 * T - 2, 12, 2);
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
for (const ty of LOT.rows) for (const tx of LOT.cols) { const [x, y] = tileBase(tx, ty); lot.push({ x, y: sk(y) }); block(tx, ty); }

// forest wall and scattered trees
const rand = rng(2024);
for (let ty = 0; ty < H; ty++) for (let tx = 0; tx < W; tx++) {
  const ring = Math.min(tx, ty, W - 1 - tx, H - 1 - ty);
  if (ring < 2) {
    block(tx, ty);
    if (ring === 1 || (tx + ty) % 2 === 0) { const [x, y] = tileBase(tx, ty); addProp(`pine_${Math.floor(rand() * 3)}`, x + Math.round(rand() * 6 - 3), y + Math.round(rand() * 4 - 2)); }
  } else if (!reserved[ty][tx] && !solid[ty][tx] && surf[ty][tx] === "s" && rand() < 0.085) {
    const [x, y] = tileBase(tx, ty);
    addProp(rand() < 0.3 ? `bare_${Math.floor(rand() * 2)}` : `pine_${Math.floor(rand() * 3)}`, x, y);
    block(tx, ty);
  }
}
// twigs, tufts and stones poking through the snow
for (let i = 0; i < 520; i++) {
  const px = 34 + Math.floor(rand() * (PW - 68)), py = 34 + Math.floor(rand() * (PH - 68));
  if (at(px, py) !== SNOW || at(px + 3, py) !== SNOW || at(px, py + 3) !== SNOW) continue;
  const kind = rand();
  if (kind < 0.4) { ground.set(px, py, hex("#8fa07a")); ground.set(px + 1, py - 1, hex("#7b8f6c")); ground.set(px + 2, py, hex("#8fa07a")); ground.set(px + 1, py, hex("#6a7d5e")); }
  else if (kind < 0.7) { ground.rect(px, py, 3, 2, C.stone); ground.set(px, py, C.stoneLight); ground.rect(px, py + 2, 3, 1, G.bank); ground.rect(px, py - 1, 2, 1, C.snow); }
  else { ground.line(px, py, px + 4, py - 1, hex("#7a5a48")); ground.set(px + 2, py - 2, hex("#7a5a48")); }
}

// ------------------------------------------------------------ write everything
fs.mkdirSync(ART, { recursive: true });
for (const [name, cv] of Object.entries(sprites)) writePng(path.join(ART, name + ".png"), cv);
writePng(path.join(ART, "ground.png"), ground, false);

const giantBase = tileBase(GIANT[0], GIANT[1]);
const world = {
  width: PW, height: PH, tile: T, cols: W, rows: H,
  solid: Array.from({ length: H }, (_, r) => solid[H - 1 - r].map((v) => (v ? "1" : "0")).join("")).join(""),
  snow: Array.from({ length: H }, (_, r) => Array.from({ length: W }, (_, tx) => (at(tx * T + 8, (H - 1 - r) * T + 8) === SNOW ? "1" : "0")).join("")).join(""),
  props: props.map((p) => ({ sprite: p.sprite, x: p.x, y: sk(p.y) })),
  houses, lights, lot,
  giant: { x: giantBase[0], y: sk(giantBase[1]) },
  square: { x: SQUARE_TREE.x, y: sk(SQUARE_TREE.y + 2) },
  cabinDoor: { x: cabinPos.x, y: sk((cabin.hy + 2) * T + 8) },
  customer: { x: standX, y: sk(standY + 9) },
  gate: { x: (LOT.x0 + 0.5) * T, y: sk(11 * T) },
};
fs.writeFileSync(path.join(ART, "world.json"), JSON.stringify(world));

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
drawn.push({ sprite: "villager_3", x: world.customer.x, y: PH - world.customer.y }, { sprite: "player_down_0", x: world.cabinDoor.x, y: PH - world.cabinDoor.y + 4 });
drawn.sort((a, b) => a.y - b.y);
for (const p of drawn) day.stamp(sprites[p.sprite], p.x, p.y);
writePng(path.join(PREVIEW, "map_day.png"), day, false);

const night = new Canvas(PW, PH);
const tint = [0.36, 0.42, 0.74];
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
    const a = sprites.glow.get(Math.floor((x - g.x + g.r) / scale), Math.floor((y - (PH - g.y) + g.r) / scale))[3] / 255 * 0.55;
    const i = (y * PW + x) * 4;
    for (let k = 0; k < 3; k++) night.d[i + k] = Math.min(255, night.d[i + k] + 255 * g.c[k] * a);
  }
}
writePng(path.join(PREVIEW, "map_night.png"), night, false);
const zoom = (src, name, x, y, w, h, s) => { const o = new Canvas(w * s, h * s); o.blit(src.crop(x, y, w, h), 0, 0, s); writePng(path.join(PREVIEW, name), o, false); };
zoom(day, "farm.png", 32, 32, 330, 300, 3);
zoom(day, "square.png", 160, 560, 330, 300, 3);
zoom(night, "square_night.png", 160, 560, 330, 300, 3);
zoom(night, "north_night.png", 40, 330, 330, 240, 3);
console.log("sprites", Object.keys(sprites).length, "props", props.length, "lights", lights.length, "cost", lights.reduce((a, l) => a + l.cost, 0));

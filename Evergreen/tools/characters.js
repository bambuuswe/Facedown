// People, built from parts so every villager can have their own hat, hair and coat.
// makePerson(look, dir, frame): dir is "down", "up" or "side" (facing right);
// frame 0 stands, frames 1 and 2 are the two steps of the walk.
const { hex, mix, Canvas } = require("./lib");

const OUTLINE = hex("#2b3353");
const FLAT = new Set(["eye", "blush", "mouth", "button", "glass", "coatD", "scarfD", "bootD"]);

function makePerson(o, dir, frame) {
  const W = 20, H = 30;
  const buf = Array.from({ length: H }, () => Array(W).fill(null));
  const P = (x, y, k) => { if (x >= 0 && y >= 0 && x < W && y < H) buf[y][x] = k; };
  const R = (x0, y0, x1, y1, k) => { for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) P(x, y, k); };

  const kid = !!o.kid, step = frame === 1 ? 1 : frame === 2 ? -1 : 0, bob = step !== 0 ? 1 : 0;
  const hw = kid ? 10 : 12, hh = kid ? 7 : 8;
  const hx0 = 10 - hw / 2, hx1 = 9 + hw / 2;
  const hy = (kid ? 11 : 8) + bob, sy = hy + hh, cy = sy + 2, hem = 25 + bob;
  const bx0 = kid ? 5 : 4, bx1 = kid ? 14 : 15;
  const my = hy + hh - 2; // mouth row
  const hat = o.hat || "none", hair = o.hair || "short";
  const side = dir === "side", back = dir === "up";

  // ---- legs
  if (side) {
    if (step === 0) { R(7, 26, 12, 26, "pants"); R(7, 27, 9, 28, "bootD"); R(10, 27, 14, 28, "boot"); }
    else if (step === 1) { R(10, 26, 13, 26, "pants"); R(11, 27, 15, 28, "boot"); R(6, 26, 8, 26, "pants"); R(4, 26, 7, 27, "bootD"); }
    else { R(8, 26, 11, 26, "pants"); R(6, 26, 8, 27, "bootD"); R(8, 27, 12, 28, "boot"); }
  } else {
    const lift = (s) => (step === s ? 1 : 0);
    if (!o.skirt) { R(6, 26, 8, 26, "pants"); R(11, 26, 13, 26, "pants"); }
    R(5, 27 - lift(-1), 8, 28 - lift(-1), "boot");
    R(11, 27 - lift(1), 14, 28 - lift(1), "boot");
  }

  // ---- coat
  if (side) {
    R(6, cy, 13, hem, "coat"); R(5, cy + 3, 14, hem, "coat");
    if (o.skirt) R(4, hem - 1, 15, hem + 1, "coat");
    if (o.trim) R(o.skirt ? 4 : 5, o.skirt ? hem + 1 : hem, o.skirt ? 15 : 14, o.skirt ? hem + 1 : hem, "trim");
  } else {
    R(bx0, cy, bx1, hem, "coat");
    if (o.skirt) { R(bx0 - 1, hem - 2, bx1 + 1, hem + 1, "coat"); }
    if (o.trim) R(o.skirt ? bx0 - 1 : bx0, o.skirt ? hem + 1 : hem, o.skirt ? bx1 + 1 : bx1, o.skirt ? hem + 1 : hem, "trim");
    if (back) R(9, cy + 2, 9, hem - 1, "coatD");
    else {
      for (const y of [cy + 1, cy + 3, cy + 5]) if (y < hem) P(9, y, "button");
      P(bx0 + 2, cy + 5, "coatD"); P(bx0 + 3, cy + 5, "coatD"); P(bx1 - 2, cy + 5, "coatD"); P(bx1 - 3, cy + 5, "coatD");
    }
    if (o.belt) R(bx0, cy + 4, bx1, cy + 4, "belt");
  }

  // ---- arms
  if (side) {
    const ax = 8 - step * 2;
    R(ax, cy, ax + 2, cy + 5, "sleeve"); R(ax, cy + 6, ax + 2, cy + 7, "mitten");
  } else {
    const swing = back ? -step : step;
    R(bx0 - 2, cy - swing, bx0 - 1, cy + 5 - swing, "sleeve"); R(bx0 - 2, cy + 6 - swing, bx0 - 1, cy + 7 - swing, "mitten");
    R(bx1 + 1, cy + swing, bx1 + 2, cy + 5 + swing, "sleeve"); R(bx1 + 1, cy + 6 + swing, bx1 + 2, cy + 7 + swing, "mitten");
  }

  // ---- head
  const fx0 = side ? hx0 + 1 : hx0, fx1 = hx1; // face span
  R(fx0, hy + 1, fx1, hy + hh - 2, "skin");
  R(fx0 + 1, hy, fx1 - 1, hy, "skin");
  R(side ? fx0 + 2 : fx0 + 1, hy + hh - 1, fx1 - 1, hy + hh - 1, "skin");
  if (side) P(fx1 + 1, hy + 4, "skin");

  // ---- scarf
  if (o.scarf) {
    R(fx0 + 1, sy, fx1 - 1, sy + 1, "scarf");
    if (side) { R(fx0 - 2, sy + 1, fx0, sy + 2, "scarf"); P(fx0 - 3, sy + 2 + bob, "scarfD"); }
    else if (back) { R(8, sy + 2, 8, sy + 4, "scarf"); R(11, sy + 2, 11, sy + 3, "scarf"); }
    else { R(12, sy + 2, 13, sy + 4, "scarf"); P(12, sy + 5, "scarfD"); P(13, sy + 5, "scarf"); }
  }

  // ---- hair
  if (hair !== "bald") {
    if (back) {
      R(fx0, hy, fx1, hy + 4, "hair");
      if (hair === "long") { R(fx0, hy, fx1, sy + 2, "hair"); R(fx0 + 1, sy + 3, fx1 - 1, sy + 3, "hair"); for (let x = fx0 + 2; x < fx1; x += 3) R(x, hy + 3, x, sy + 2, "hairD"); }
      if (hair === "braids") { R(fx0, hy + 4, fx0 + 1, sy + 4, "hair"); R(fx1 - 1, hy + 4, fx1, sy + 4, "hair"); P(fx0, sy + 5, "scarf"); P(fx1, sy + 5, "scarf"); }
      if (hair === "bun") R(8, hy + 1, 11, hy + 3, "hairD");
    } else if (side) {
      R(fx0, hy, fx0 + 2, hy + 4, "hair"); R(fx0 + 1, hy, fx1 - 1, hy, "hair"); R(fx0 + 3, hy + 1, fx0 + 3, hy + 2, "hair");
      if (hair === "long") R(fx0 - 1, hy + 2, fx0 + 1, sy + 3, "hair");
      if (hair === "braids") { R(fx0, hy + 4, fx0 + 1, sy + 4, "hair"); P(fx0, sy + 5, "scarf"); }
    } else {
      R(fx0 + 1, hy, fx1 - 1, hy, "hair"); R(fx0, hy + 1, fx0, hy + 3, "hair"); R(fx1, hy + 1, fx1, hy + 3, "hair");
      R(fx0 + 1, hy + 1, fx0 + 3, hy + 1, "hair"); R(fx1 - 2, hy + 1, fx1 - 1, hy + 1, "hair");
      if (hair === "long") { R(fx0 - 1, hy + 2, fx0, sy + 3, "hair"); R(fx1, hy + 2, fx1 + 1, sy + 3, "hair"); }
      if (hair === "braids") { R(fx0 - 1, hy + 4, fx0, sy + 4, "hair"); R(fx1, hy + 4, fx1 + 1, sy + 4, "hair"); P(fx0 - 1, sy + 5, "scarf"); P(fx1 + 1, sy + 5, "scarf"); }
    }
  }

  // ---- hat
  if (hat === "bobble" || hat === "earflap") {
    R(fx0 + 2, hy - 5, fx1 - 2, hy - 5, "hat"); R(fx0 + 1, hy - 4, fx1 - 1, hy - 4, "hat"); R(fx0, hy - 3, fx1, hy - 2, "hat");
    R(fx0 - 1, hy - 1, fx1 + 1, hy, "band");
    if (hat === "bobble") { R(8, hy - 7, 11, hy - 6, "pom"); for (let x = fx0; x <= fx1; x += 2) P(x, hy - 3, "band"); }
    else if (side) R(fx0 + 1, hy + 1, fx0 + 4, hy + 5, "hat");
    else { R(fx0 - 1, hy + 1, fx0, hy + 5, "hat"); R(fx1, hy + 1, fx1 + 1, hy + 5, "hat"); }
  } else if (hat === "cap") {
    R(fx0 + 1, hy - 3, fx1 - 1, hy - 3, "hat"); R(fx0, hy - 2, fx1, hy - 1, "hat");
    if (side) R(fx1 - 2, hy, fx1 + 3, hy, "band"); else if (!back) R(fx0 - 1, hy, fx1 - 3, hy, "band"); else R(fx0, hy, fx1, hy, "hat");
  } else if (hat === "tophat") {
    R(fx0 + 2, hy - 7, fx1 - 2, hy - 2, "hat"); R(fx0 + 2, hy - 3, fx1 - 2, hy - 3, "band"); R(fx0 - 1, hy - 1, fx1 + 1, hy - 1, "hat");
  } else if (hat === "beret") {
    R(fx0 - 1, hy - 3, fx1 - 1, hy - 1, "hat"); R(fx0 + 1, hy - 4, fx1 - 3, hy - 4, "hat"); P(fx0 + 4, hy - 5, "hat");
  } else if (hat === "hood") {
    R(fx0 - 1, hy - 1, fx1 + 1, sy - 1, "hood"); R(fx0, hy - 2, fx1, hy - 2, "hood"); R(fx0 + 3, hy - 3, fx1 - 3, hy - 3, "hood");
    if (back) R(9, hy, 9, sy - 1, "coatD");
    if (!back) {
      const ox0 = side ? fx1 - 4 : fx0 + 1, ox1 = side ? fx1 : fx1 - 1;
      R(ox0, hy + 1, ox1, hy + hh - 2, "skin");
      for (let y = hy; y <= hy + hh - 1; y++) { P(ox0 - 1, y, "trim"); if (!side) P(ox1 + 1, y, "trim"); }
      R(ox0, hy, ox1, hy, "trim");
      if (side) P(fx1 + 1, hy + 4, "skin");
    }
  } else if (hair !== "bald") {
    R(fx0 + 1, hy - 2, fx1 - 1, hy - 2, "hair"); R(fx0, hy - 1, fx1, hy, "hair");
    if (hair === "bun" && !back) R(8, hy - 5, 11, hy - 3, "hair");
  }

  // ---- face
  if (!back) {
    if (side) {
      P(fx1 - 2, hy + 3, "eye"); P(fx1 - 2, hy + 4, "eye");
      P(fx1 - 1, my - 1, "blush"); P(fx1, my - 1, "blush"); P(fx1, my, "mouth");
      if (o.glasses) { R(fx1 - 3, hy + 2, fx1 - 1, hy + 2, "glass"); R(fx1 - 3, hy + 5, fx1 - 1, hy + 5, "glass"); P(fx1 - 3, hy + 3, "glass"); P(fx1 - 3, hy + 4, "glass"); R(fx0 + 3, hy + 3, fx1 - 4, hy + 3, "glass"); }
      if (o.beard) { R(fx0 + 4, my - 1, fx1, sy, "beard"); P(fx1, my, "mouth"); }
    } else {
      const ex0 = fx0 + 3, ex1 = fx1 - 3;
      for (const ex of [ex0, ex1]) { P(ex, hy + 3, "eye"); P(ex, hy + 4, "eye"); }
      P(fx0 + 1, my - 1, "blush"); P(fx0 + 2, my - 1, "blush"); P(fx1 - 2, my - 1, "blush"); P(fx1 - 1, my - 1, "blush");
      P(9, my, "mouth"); P(10, my, "mouth");
      if (o.glasses) for (const ex of [ex0, ex1]) { R(ex - 1, hy + 2, ex + 1, hy + 2, "glass"); R(ex - 1, hy + 5, ex + 1, hy + 5, "glass"); P(ex - 1, hy + 3, "glass"); P(ex - 1, hy + 4, "glass"); P(ex + 1, hy + 3, "glass"); P(ex + 1, hy + 4, "glass"); }
      if (o.glasses) R(ex0 + 2, hy + 3, ex1 - 2, hy + 3, "glass");
      if (o.beard) { R(fx0 + 1, my - 1, fx1 - 1, sy, "beard"); R(fx0 + 3, sy + 1, fx1 - 3, sy + 1, "beard"); R(8, my - 2, 11, my - 2, "beard"); P(9, my, "mouth"); P(10, my, "mouth"); }
    }
  }

  // ---- colour and shade
  const coat = hex(o.coat), skin = hex(o.skin), hairC = hex(o.hairColor || "#7a4a2c");
  const pal = {
    skin, hair: hairC, hairD: mix(hairC, OUTLINE, 0.3), hat: hex(o.hatColor || "#d8483e"), band: hex(o.band || "#f4f0e6"), pom: hex("#ffffff"),
    scarf: hex(o.scarf || "#f5c93c"), scarfD: mix(hex(o.scarf || "#f5c93c"), OUTLINE, 0.35), coat, coatD: mix(coat, OUTLINE, 0.32), sleeve: coat, hood: coat,
    trim: hex(o.trim || "#f4f0e6"), button: mix(coat, hex("#ffffff"), 0.6), belt: hex("#3a2a22"), mitten: hex(o.mitten || o.hatColor || "#d8483e"),
    pants: hex(o.pants || "#3d4f80"), boot: hex(o.boots || "#5a3b2a"), bootD: mix(hex(o.boots || "#5a3b2a"), OUTLINE, 0.35),
    eye: hex("#2a2233"), blush: mix(skin, hex("#e8756a"), 0.45), mouth: mix(skin, hex("#a34a3a"), 0.55), glass: hex("#3a3a48"), beard: hex(o.beard || "#e8e2d2"),
  };
  const cv = new Canvas(W, H);
  const key = (x, y) => (x < 0 || y < 0 || x >= W || y >= H ? null : buf[y][x]);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const k = buf[y][x];
    if (!k) continue;
    let c = pal[k];
    if (!FLAT.has(k)) {
      const dark = key(x + 1, y) !== k || key(x, y + 1) !== k, light = key(x - 1, y) !== k || key(x, y - 1) !== k;
      if (k === "skin") { const above = key(x, y - 1); if (above === "band" || above === "hat" || above === "hair" || above === "trim") c = mix(c, hex("#b0705a"), 0.28); else if (key(x + 1, y) === null) c = mix(c, hex("#b0705a"), 0.2); }
      else if (dark && !FLAT.has(key(x + 1, y)) ) c = mix(c, OUTLINE, 0.24);
      else if (light) c = mix(c, hex("#ffffff"), 0.2);
    }
    cv.set(x, y, c);
  }
  cv.outline(OUTLINE);
  return cv;
}

const look = (o) => o;
const CAST = {
  player: look({ hat: "bobble", hatColor: "#d8483e", band: "#f4f0e6", hairColor: "#7a4a2c", skin: "#f6cfa8", coat: "#3f8a5c", trim: "#f4f0e6", scarf: "#f5c93c", pants: "#3d4f80", belt: true }),
  player_santa: look({ hat: "bobble", hatColor: "#c9342c", band: "#ffffff", hairColor: "#7a4a2c", skin: "#f6cfa8", coat: "#c9342c", trim: "#ffffff", scarf: "#ffffff", pants: "#c9342c", boots: "#2a2233", mitten: "#ffffff", belt: true }),
  player_blue: look({ hat: "earflap", hatColor: "#3d6bb5", band: "#f4f0e6", hairColor: "#7a4a2c", skin: "#f6cfa8", coat: "#4a8fd0", trim: "#f4f0e6", scarf: "#f08a2c", pants: "#2a3a5e", mitten: "#f08a2c" }),
  villager_0: look({ hat: "beret", hatColor: "#4a78c8", hair: "long", hairColor: "#d9a441", skin: "#f6cfa8", coat: "#b8443b", trim: "#f4f0e6", scarf: "#f4f0e6", mitten: "#4a78c8", skirt: true, pants: "#5a4a6a" }),
  villager_1: look({ hat: "cap", hatColor: "#3f7f5c", band: "#2a5a42", hairColor: "#4a3229", skin: "#e9b98c", coat: "#8a5a3c", scarf: "#d8483e", beard: "#4a3229", pants: "#3d4f80" }),
  villager_2: look({ hat: "bobble", hatColor: "#8660bd", band: "#efc2ca", hair: "braids", hairColor: "#c96a3a", skin: "#f6cfa8", coat: "#e6c463", trim: "#f4f0e6", scarf: "#8660bd", skirt: true }),
  villager_3: look({ hat: "earflap", hatColor: "#5f6b85", band: "#e8e2d2", hair: "bald", skin: "#f1c7a0", coat: "#3d517e", scarf: "#f5c93c", beard: "#e8e2d2", glasses: true, pants: "#3a3a48" }),
  villager_4: look({ hat: "hood", hair: "short", hairColor: "#2a2233", skin: "#c98f66", coat: "#d9709a", trim: "#f4f0e6", scarf: "#f1e3c4", mitten: "#f4f0e6", skirt: true }),
  villager_5: look({ hat: "bobble", hatColor: "#c9483a", band: "#3f7f5c", hairColor: "#7a4a2c", skin: "#f6cfa8", coat: "#4f6f9e", scarf: "#f4f0e6", pants: "#3a3a48", belt: true }),
  villager_6: look({ hat: "none", hair: "bun", hairColor: "#e8e2d2", skin: "#f1c7a0", coat: "#3f8f6e", trim: "#f5c93c", scarf: "#b8443b", glasses: true, skirt: true, mitten: "#b8443b" }),
  villager_7: look({ hat: "cap", hatColor: "#3d517e", band: "#2a3a5e", hairColor: "#d9a441", skin: "#e9b98c", coat: "#96603d", scarf: "#3f7f5c", pants: "#3d4f80", mitten: "#3f7f5c" }),
  villager_8: look({ hat: "beret", hatColor: "#3f8f6e", hair: "long", hairColor: "#4a3229", skin: "#a8704c", coat: "#c2584a", trim: "#f4f0e6", scarf: "#f4f0e6", skirt: true, mitten: "#3f8f6e" }),
  villager_9: look({ hat: "earflap", hatColor: "#96603d", band: "#f1e3c4", hairColor: "#2a2233", skin: "#f6cfa8", coat: "#5f6b85", scarf: "#c9483a", beard: "#2a2233", pants: "#3a3a48" }),
  villager_10: look({ hat: "bobble", hatColor: "#e37a63", band: "#f4f0e6", hair: "long", hairColor: "#c96a3a", skin: "#f6cfa8", coat: "#6f93c4", trim: "#f4f0e6", scarf: "#f5c93c", skirt: true }),
  mayor: look({ hat: "tophat", hatColor: "#2a2233", band: "#c9483a", hairColor: "#b9b9c2", skin: "#f1c7a0", coat: "#3a3a48", trim: "#f5c93c", scarf: "#c9483a", beard: "#e8e2d2", glasses: true, pants: "#2a2233", mitten: "#f4f0e6", belt: true }),
  kid_0: look({ kid: true, hat: "bobble", hatColor: "#5ab8ff", band: "#f4f0e6", hairColor: "#d9a441", skin: "#f6cfa8", coat: "#f08a2c", scarf: "#f4f0e6", pants: "#3d4f80" }),
  kid_1: look({ kid: true, hat: "earflap", hatColor: "#d9709a", band: "#f4f0e6", hair: "braids", hairColor: "#4a3229", skin: "#c98f66", coat: "#8660bd", scarf: "#f5c93c", pants: "#5a4a6a" }),
  kid_2: look({ kid: true, hat: "hood", hairColor: "#c96a3a", skin: "#f6cfa8", coat: "#3f8f6e", trim: "#f4f0e6", scarf: "#d8483e", pants: "#3a3a48" }),
  vendor_0: look({ hat: "cap", hatColor: "#f1e3c4", band: "#d6c19a", hairColor: "#4a3229", skin: "#f1c7a0", coat: "#f4f0e6", scarf: "#c9483a", beard: "#4a3229" }),
  vendor_1: look({ hat: "beret", hatColor: "#c9483a", hair: "long", hairColor: "#2a2233", skin: "#c98f66", coat: "#3f7f5c", trim: "#f5c93c", scarf: "#f5c93c" }),
  vendor_2: look({ hat: "bobble", hatColor: "#3d517e", band: "#f5c93c", hairColor: "#b9b9c2", skin: "#f6cfa8", coat: "#8660bd", scarf: "#f4f0e6", glasses: true }),
};
const NAMES = ["Marta", "Olle", "Ingrid", "Sven", "Astrid", "Nils", "Greta", "Emil", "Selma", "Anton", "Freja"];

module.exports = { makePerson, CAST, NAMES };

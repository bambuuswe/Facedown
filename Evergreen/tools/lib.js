// Tiny pixel-art toolkit: an RGBA canvas, a PNG writer, seeded randomness and noise.
const fs = require("fs");
const zlib = require("zlib");
const path = require("path");

function hex(h, a = 255) {
  return [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16), a];
}
function mix(a, b, t) {
  return [0, 1, 2, 3].map((k) => Math.round(a[k] + (b[k] - a[k]) * t));
}
function withAlpha(c, a) {
  return [c[0], c[1], c[2], a];
}

class Canvas {
  constructor(w, h) { this.w = w; this.h = h; this.d = new Uint8Array(w * h * 4); }
  inside(x, y) { return x >= 0 && y >= 0 && x < this.w && y < this.h; }
  get(x, y) {
    if (!this.inside(x, y)) return [0, 0, 0, 0];
    const i = (y * this.w + x) * 4;
    return [this.d[i], this.d[i + 1], this.d[i + 2], this.d[i + 3]];
  }
  alpha(x, y) { return this.inside(x, y) ? this.d[(y * this.w + x) * 4 + 3] : 0; }
  set(x, y, c) {
    x = Math.round(x); y = Math.round(y);
    if (!this.inside(x, y)) return;
    const i = (y * this.w + x) * 4, a = c[3] / 255, da = this.d[i + 3] / 255;
    if (a >= 1 || da === 0) { this.d[i] = c[0]; this.d[i + 1] = c[1]; this.d[i + 2] = c[2]; this.d[i + 3] = c[3]; return; }
    for (let k = 0; k < 3; k++) this.d[i + k] = Math.round(c[k] * a + this.d[i + k] * (1 - a));
    this.d[i + 3] = Math.round((a + da * (1 - a)) * 255);
  }
  clear(x, y) { if (this.inside(x, y)) this.d.fill(0, (y * this.w + x) * 4, (y * this.w + x) * 4 + 4); }
  rect(x, y, w, h, c) { for (let j = y; j < y + h; j++) for (let i = x; i < x + w; i++) this.set(i, j, c); }
  frame(x, y, w, h, c) { this.rect(x, y, w, 1, c); this.rect(x, y + h - 1, w, 1, c); this.rect(x, y, 1, h, c); this.rect(x + w - 1, y, 1, h, c); }
  line(x0, y0, x1, y1, c) {
    x0 = Math.round(x0); y0 = Math.round(y0); x1 = Math.round(x1); y1 = Math.round(y1);
    const dx = Math.abs(x1 - x0), dy = -Math.abs(y1 - y0), sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1;
    let err = dx + dy;
    for (;;) {
      this.set(x0, y0, c);
      if (x0 === x1 && y0 === y1) break;
      const e2 = 2 * err;
      if (e2 >= dy) { err += dy; x0 += sx; }
      if (e2 <= dx) { err += dx; y0 += sy; }
    }
  }
  ellipse(cx, cy, rx, ry, c) {
    for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++)
      for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++)
        if (((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1) this.set(x, y, c);
  }
  blit(src, dx, dy, scale = 1) {
    for (let y = 0; y < src.h; y++) for (let x = 0; x < src.w; x++) {
      const c = src.get(x, y);
      if (c[3] === 0) continue;
      if (scale === 1) this.set(dx + x, dy + y, c);
      else for (let j = 0; j < scale; j++) for (let i = 0; i < scale; i++) this.set(dx + x * scale + i, dy + y * scale + j, c);
    }
  }
  /** Draws src so that its bottom-centre lands on (x, y). */
  stamp(src, x, y) { this.blit(src, Math.round(x - src.w / 2), Math.round(y - src.h)); }
  flipX() {
    const o = new Canvas(this.w, this.h);
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) { const c = this.get(x, y); if (c[3]) o.set(this.w - 1 - x, y, c); }
    return o;
  }
  crop(x, y, w, h) {
    const o = new Canvas(w, h);
    for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) { const c = this.get(x + i, y + j); if (c[3]) o.set(i, j, c); }
    return o;
  }
  /** Paints a one pixel outline around everything already drawn. */
  outline(c) {
    const edge = [];
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) {
      if (this.alpha(x, y) > 128) continue;
      if (this.alpha(x - 1, y) > 128 || this.alpha(x + 1, y) > 128 || this.alpha(x, y - 1) > 128 || this.alpha(x, y + 1) > 128) edge.push([x, y]);
    }
    for (const [x, y] of edge) { this.clear(x, y); this.set(x, y, c); }
    return this;
  }
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

function rng(seed) {
  let a = seed >>> 0;
  return () => { a = (a + 0x6d2b79f5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}
function hash2(x, y, seed = 0) {
  let h = (Math.imul(x | 0, 374761393) + Math.imul(y | 0, 668265263) + Math.imul(seed | 0, 2147483647)) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
}
/** Smooth value noise in 0..1 with features about `scale` pixels wide. */
function noise(x, y, scale, seed = 0) {
  const fx = x / scale, fy = y / scale, x0 = Math.floor(fx), y0 = Math.floor(fy);
  const tx = fx - x0, ty = fy - y0, sx = tx * tx * (3 - 2 * tx), sy = ty * ty * (3 - 2 * ty);
  const a = hash2(x0, y0, seed), b = hash2(x0 + 1, y0, seed), c = hash2(x0, y0 + 1, seed), d = hash2(x0 + 1, y0 + 1, seed);
  return a + (b - a) * sx + (c - a) * sy + (a - b - c + d) * sx * sy;
}

/** Builds a sprite from rows of characters and a character-to-colour table. */
function ascii(rows, pal) {
  const w = rows[0].length, cv = new Canvas(w, rows.length);
  rows.forEach((row, y) => {
    if (row.length !== w) throw new Error(`row ${y} is ${row.length} wide, expected ${w}: "${row}"`);
    [...row].forEach((ch, x) => { if (ch !== "." && pal[ch]) cv.set(x, y, pal[ch]); });
  });
  return cv;
}

module.exports = { hex, mix, withAlpha, Canvas, writePng, rng, hash2, noise, ascii };

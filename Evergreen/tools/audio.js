// Synthesises all of Evergreen's music and sound effects as WAV files.
// Usage: node audio.js <audioDir>
const fs = require("fs");
const path = require("path");

const OUT = process.argv[2];
const SR = 22050, TAU = Math.PI * 2;

// ---------------------------------------------------------------- basics
let seed = 12345;
const rand = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };
const buf = (sec) => new Float32Array(Math.ceil(sec * SR));
function add(dst, src, at, gain = 1, wrap = false) {
  const o = Math.floor(at * SR);
  for (let i = 0; i < src.length; i++) {
    let k = o + i;
    if (k >= dst.length) { if (!wrap) break; k %= dst.length; }
    dst[k] += src[i] * gain;
  }
}
const SEMI = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 };
function hz(name) {
  const m = /^([A-G])(#|b)?(\d)$/.exec(name);
  const n = SEMI[m[1]] + (m[2] === "#" ? 1 : m[2] === "b" ? -1 : 0) + (Number(m[3]) + 1) * 12;
  return 440 * Math.pow(2, (n - 69) / 12);
}
/** Music-box note: a sine with two quick-fading overtones. */
function bell(freq, dur, bright = 1) {
  const o = buf(dur);
  for (let i = 0; i < o.length; i++) {
    const t = i / SR, env = Math.exp(-t / (dur * 0.26)) * Math.min(1, t / 0.004) * Math.min(1, (dur - t) / 0.03);
    o[i] = (Math.sin(TAU * freq * t) + 0.4 * bright * Math.sin(TAU * 2 * freq * t) * Math.exp(-t / (dur * 0.12)) + 0.16 * bright * Math.sin(TAU * 3.01 * freq * t) * Math.exp(-t / (dur * 0.06))) * env * 0.5;
  }
  return o;
}
function tri(freq, dur, attack = 0.03, release = 0.12) {
  const o = buf(dur);
  for (let i = 0; i < o.length; i++) {
    const t = i / SR, p = (freq * t) % 1, env = Math.min(1, t / attack) * Math.min(1, (dur - t) / release);
    o[i] = (4 * Math.abs(p - 0.5) - 1) * env;
  }
  return o;
}
function sine(freqAt, dur, envAt) {
  const o = buf(dur);
  let phase = 0;
  for (let i = 0; i < o.length; i++) { const t = i / SR; phase += TAU * freqAt(t) / SR; o[i] = Math.sin(phase) * envAt(t); }
  return o;
}
function noise(dur) { const o = buf(dur); for (let i = 0; i < o.length; i++) o[i] = rand() * 2 - 1; return o; }
function lowpass(a, cutoff) { const o = new Float32Array(a.length), k = 1 - Math.exp(-TAU * cutoff / SR); let y = 0; for (let i = 0; i < a.length; i++) { y += (a[i] - y) * k; o[i] = y; } return o; }
function highpass(a, cutoff) { const l = lowpass(a, cutoff), o = new Float32Array(a.length); for (let i = 0; i < a.length; i++) o[i] = a[i] - l[i]; return o; }
function shape(a, envAt) { const o = new Float32Array(a.length); for (let i = 0; i < a.length; i++) o[i] = a[i] * envAt(i / SR); return o; }
const pluck = (attack, decay) => (t) => Math.min(1, t / attack) * Math.exp(-t / decay);
function write(name, a, peak = 0.8) {
  let max = 0;
  for (const v of a) max = Math.max(max, Math.abs(v));
  const g = max > 0 ? peak / max : 1, data = Buffer.alloc(a.length * 2);
  for (let i = 0; i < a.length; i++) data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, a[i] * g)) * 32767), i * 2);
  const head = Buffer.alloc(44);
  head.write("RIFF", 0); head.writeUInt32LE(36 + data.length, 4); head.write("WAVEfmt ", 8); head.writeUInt32LE(16, 16); head.writeUInt16LE(1, 20); head.writeUInt16LE(1, 22);
  head.writeUInt32LE(SR, 24); head.writeUInt32LE(SR * 2, 28); head.writeUInt16LE(2, 32); head.writeUInt16LE(16, 34); head.write("data", 36); head.writeUInt32LE(data.length, 40);
  fs.writeFileSync(path.join(OUT, name + ".wav"), Buffer.concat([head, data]));
  return (a.length / SR).toFixed(2) + "s";
}

// ---------------------------------------------------------------- music
const CHORDS = { C: ["C3", "C4", "E4", "G4"], Am: ["A2", "A3", "C4", "E4"], F: ["F2", "F3", "A3", "C4"], G: ["G2", "G3", "B3", "D4"], Em: ["E3", "E3", "G3", "B3"] };
function song({ bpm, bars, tail, bright, bassGain, padGain, sleigh }) {
  const beat = 60 / bpm, barLen = beat * 4, out = buf(barLen * bars.length);
  bars.forEach(([chord, notes], b) => {
    const start = b * barLen, [bass, ...triad] = CHORDS[chord], slot = barLen / notes.length;
    notes.forEach((n, i) => { if (n !== "-") add(out, bell(hz(n), tail, bright), start + i * slot, 0.55, true); });
    add(out, lowpass(tri(hz(bass) * 2, barLen * 0.5 - 0.02), 900), start, bassGain, true);
    add(out, lowpass(tri(hz(bass) * 2, barLen * 0.5 - 0.02), 900), start + barLen * 0.5, bassGain * 0.8, true);
    for (const n of triad) add(out, lowpass(tri(hz(n), barLen, 0.5, 0.6), 1400), start, padGain, true);
    if (sleigh) for (const k of [1, 3]) add(out, shape(highpass(noise(0.07), 5000), pluck(0.002, 0.02)), start + k * beat, 0.05, true);
  });
  return out;
}
const day = song({ bpm: 100, tail: 0.9, bright: 1, bassGain: 0.2, padGain: 0.05, sleigh: true, bars: [
  ["C", ["E5", "G5", "C6", "G5", "E5", "G5", "D5", "E5"]], ["Am", ["C5", "E5", "A5", "E5", "C5", "E5", "B4", "C5"]],
  ["F", ["A4", "C5", "F5", "C5", "A5", "F5", "E5", "D5"]], ["G", ["B4", "D5", "G5", "D5", "B4", "D5", "G5", "-"]],
  ["C", ["E5", "G5", "C6", "G5", "E6", "D6", "C6", "G5"]], ["Em", ["B4", "E5", "G5", "B5", "G5", "E5", "D5", "E5"]],
  ["F", ["F5", "A5", "C6", "A5", "F5", "A5", "G5", "F5"]], ["G", ["D5", "G5", "B5", "G5", "D6", "B5", "G5", "-"]],
  ["Am", ["A5", "-", "E5", "A5", "C6", "-", "B5", "A5"]], ["F", ["F5", "-", "C5", "F5", "A5", "-", "G5", "F5"]],
  ["C", ["E5", "-", "C5", "E5", "G5", "-", "E5", "C5"]], ["G", ["D5", "-", "B4", "D5", "G5", "A5", "B5", "-"]],
  ["F", ["C6", "A5", "F5", "A5", "C6", "A5", "F5", "A5"]], ["G", ["B5", "G5", "D5", "G5", "B5", "G5", "D6", "B5"]],
  ["C", ["C6", "-", "G5", "E5", "C5", "E5", "G5", "C6"]], ["C", ["E6", "-", "-", "-", "C6", "-", "-", "-"]],
] });
const night = song({ bpm: 66, tail: 2.4, bright: 0.6, bassGain: 0.16, padGain: 0.075, sleigh: false, bars: [
  ["Am", ["A4", "C5", "E5", "C5"]], ["F", ["A4", "C5", "F5", "C5"]], ["C", ["G4", "C5", "E5", "G5"]], ["G", ["G4", "B4", "D5", "B4"]],
  ["Am", ["A4", "E5", "A5", "E5"]], ["F", ["F4", "A4", "C5", "F5"]], ["G", ["D5", "B4", "G4", "B4"]], ["C", ["C5", "E5", "G5", "C6"]],
] });
const wind = (() => {
  // Noise that runs a little past the end; the overhang is folded back over the start so the loop has no seam.
  const len = 8, over = 0.6, o = buf(len), raw = lowpass(highpass(noise(len + over), 120), 520), n = o.length;
  for (let i = 0; i < n; i++) {
    const t = i / SR, gust = 0.55 + 0.3 * Math.sin(TAU * t / 8) + 0.15 * Math.sin(TAU * t / 2.667 + 1);
    const w = Math.min(1, t / over);
    o[i] = (raw[i] * w + (w < 1 ? raw[i + n] * (1 - w) : 0)) * gust;
  }
  return o;
})();

// ---------------------------------------------------------------- effects
const fx = {};
const crunch = (cut) => shape(lowpass(highpass(noise(0.11), 300), cut), pluck(0.004, 0.035));
fx.step_0 = crunch(2600); fx.step_1 = crunch(2000);
fx.skate = shape(highpass(lowpass(noise(0.3), 5200), 1800), (t) => Math.sin(Math.PI * Math.min(1, t / 0.3)) ** 2);
fx.chop = (() => { const o = buf(0.2); add(o, sine(() => 130, 0.2, pluck(0.002, 0.045)), 0, 1); add(o, shape(lowpass(noise(0.06), 3000), pluck(0.001, 0.012)), 0, 0.8); return o; })();
fx.chop_good = (() => { const o = buf(0.5); add(o, fx.chop, 0, 1); add(o, bell(hz("E6"), 0.45), 0.01, 0.6); return o; })();
fx.timber = (() => {
  const o = buf(1.2);
  add(o, sine((t) => 340 - t * 260, 0.6, (t) => Math.min(1, t / 0.05) * (1 - t / 0.6) * (0.6 + 0.4 * Math.sin(t * 90))), 0, 0.35);
  add(o, shape(lowpass(noise(0.5), 1500), (t) => (t / 0.5) ** 2), 0.15, 0.4);
  add(o, sine(() => 70, 0.45, pluck(0.003, 0.11)), 0.62, 1.2); add(o, shape(lowpass(noise(0.3), 900), pluck(0.002, 0.07)), 0.62, 0.9);
  return o;
})();
const jingle = (notes, gap, tail, bright = 1) => { const o = buf(gap * notes.length + tail); notes.forEach((n, i) => add(o, bell(hz(n), tail, bright), i * gap, 0.7)); return o; };
fx.coin = jingle(["B5", "E6"], 0.07, 0.35);
fx.light = jingle(["C6", "E6", "G6", "C7"], 0.06, 0.5);
fx.heart = jingle(["E5", "A5"], 0.11, 0.5, 0.5);
fx.deliver = jingle(["C5", "E5", "G5", "C6", "E6"], 0.09, 0.8);
fx.sleep = jingle(["E5", "C5", "A4", "E4"], 0.3, 1.2, 0.4);
fx.fanfare = (() => { const o = buf(3); ["C5", "E5", "G5", "C6", "E6", "G6", "C7"].forEach((n, i) => add(o, bell(hz(n), 1.6), i * 0.11, 0.6)); for (const n of ["C5", "E5", "G5", "C6"]) add(o, bell(hz(n), 2), 0.95, 0.5); return o; })();
fx.talk = (() => { const o = buf(0.12); add(o, tri(hz("A5"), 0.05, 0.005, 0.03), 0, 0.6); add(o, tri(hz("C6"), 0.06, 0.005, 0.04), 0.05, 0.6); return lowpass(o, 3000); })();
fx.tap = lowpass(tri(hz("E6"), 0.05, 0.003, 0.04), 3500);
fx.nope = (() => { const o = buf(0.25); add(o, tri(hz("E4"), 0.09, 0.005, 0.05), 0, 0.7); add(o, tri(hz("C4"), 0.12, 0.005, 0.08), 0.1, 0.7); return lowpass(o, 1800); })();
fx.sip = (() => { const o = buf(0.5); [520, 430, 360].forEach((f, i) => add(o, sine((t) => f - t * 400, 0.1, pluck(0.01, 0.035)), i * 0.13, 0.8)); return o; })();
fx.meow = sine((t) => 620 + 420 * Math.sin(Math.PI * Math.min(1, t / 0.38)) + 14 * Math.sin(TAU * 24 * t), 0.42, (t) => Math.sin(Math.PI * Math.min(1, t / 0.42)) ** 0.7);
fx.baa = (() => { const o = buf(0.6); for (let i = 0; i < o.length; i++) { const t = i / SR, f = 235 - t * 30; o[i] = (((f * t) % 1) * 2 - 1) * (0.55 + 0.45 * Math.sin(TAU * 11 * t)) * Math.sin(Math.PI * t / 0.6); } return lowpass(highpass(o, 250), 1700); })();
fx.munch = (() => { const o = buf(0.5); for (const at of [0, 0.16, 0.32]) add(o, crunch(3200), at, 1); return o; })();
fx.flutter = (() => { const o = buf(0.5); for (let i = 0; i < 7; i++) add(o, shape(highpass(lowpass(noise(0.04), 4500), 900), pluck(0.004, 0.012)), i * 0.06, 1 - i * 0.1); return o; })();
fx.bell = (() => {
  const o = buf(5), strike = buf(3.2), f = hz("G3");
  for (let i = 0; i < strike.length; i++) { const t = i / SR; strike[i] = (Math.sin(TAU * f * t) * Math.exp(-t / 1.1) + 0.6 * Math.sin(TAU * f * 2.0 * t) * Math.exp(-t / 0.8) + 0.45 * Math.sin(TAU * f * 2.76 * t) * Math.exp(-t / 0.5) + 0.25 * Math.sin(TAU * f * 5.4 * t) * Math.exp(-t / 0.2)) * Math.min(1, t / 0.003); }
  add(o, strike, 0, 1); add(o, strike, 0.9, 0.85); add(o, strike, 1.8, 0.9);
  return o;
})();
fx.firework = (() => { const o = buf(0.9); add(o, sine(() => 90, 0.25, pluck(0.002, 0.06)), 0, 1); add(o, shape(lowpass(noise(0.2), 2500), pluck(0.001, 0.04)), 0, 0.8); for (let i = 0; i < 26; i++) add(o, shape(highpass(noise(0.012), 3000), pluck(0.001, 0.004)), 0.12 + rand() * 0.7, 0.25 * (1 - i / 30)); return o; })();
fx.fire = (() => { const o = buf(0.6); add(o, shape(lowpass(noise(0.6), 700), (t) => Math.sin(Math.PI * t / 0.6) * 0.5), 0, 1); for (let i = 0; i < 8; i++) add(o, shape(highpass(noise(0.01), 2500), pluck(0.001, 0.004)), rand() * 0.55, 0.7); return o; })();

fs.mkdirSync(OUT, { recursive: true });
const report = [["music_day", write("music_day", day, 0.7)], ["music_night", write("music_night", night, 0.7)], ["wind", write("wind", wind, 0.6)]];
for (const [name, a] of Object.entries(fx)) report.push([name, write(name, a)]);
let total = 0;
for (const f of fs.readdirSync(OUT)) total += fs.statSync(path.join(OUT, f)).size;
console.log(report.map(([n, d]) => n + " " + d).join(", "));
console.log("files", report.length, "total MB", (total / 1e6).toFixed(2));

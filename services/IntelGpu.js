.pragma library

// intel_gpu_top emits a JSON array incrementally. Publish complete objects only.
function stream() { return {parts: [], depth: 0, quoted: false, escaped: false}; }
function read(state, chunk) {
    const frames = [];
    let start = 0;
    for (let i = 0; i < chunk.length; i++) {
        const ch = chunk[i];
        if (state.depth === 0) {
            if (ch !== "{") continue;
            state.parts = [];
            start = i;
            state.depth = 1;
            state.quoted = false;
            state.escaped = false;
            continue;
        }
        if (state.quoted) {
            if (state.escaped) state.escaped = false;
            else if (ch === "\\") state.escaped = true;
            else if (ch === '"') state.quoted = false;
        } else if (ch === '"') state.quoted = true;
        else if (ch === "{") state.depth++;
        else if (ch === "}" && --state.depth === 0) {
            state.parts.push(chunk.slice(start, i + 1));
            frames.push(JSON.parse(state.parts.join("")));
            state.parts = [];
            start = i + 1;
        }
    }
    if (state.depth > 0) state.parts.push(chunk.slice(start));
    return frames;
}
function number(value) {
    if (value === undefined || value === null || value === "") return -1;
    const n = Number(value);
    return isFinite(n) && n >= 0 ? n : -1;
}
function normalize(frame) {
    const busy = key => frame.engines?.[key]?.unit === "%" ? number(frame.engines[key].busy) : -1;
    const rounded = n => n < 0 ? -1 : Math.round(Math.min(n, 100) * 10) / 10;
    const engines = [["Blitter", "Copy"], ["Video", "Video"], ["VideoEnhance", "Video+"], ["Compute", "Compute"]]
        .map(pair => ({name: pair[1], load: rounded(busy(pair[0]))})).filter(e => e.load >= 0);
    const clients = {};
    for (const id of Object.keys(frame.clients ?? {})) {
        const client = frame.clients[id];
        const pid = String(client.pid ?? "");
        if (!/^\d+$/.test(pid)) continue;
        const regions = Object.values(client.memory ?? {});
        const resident = regions.map(r => number(r.resident));
        if (!resident.length || resident.some(n => n < 0)) continue;
        if (!clients[pid]) clients[pid] = {};
        clients[pid][id] = resident.reduce((a, b) => a + b, 0) / 1048576;
    }
    const clock = frame.frequency?.unit === "MHz" ? number(frame.frequency.actual) : -1;
    return {gpu: {name: "Intel GPU", load: rounded(busy("Render/3D")), engines: engines,
        clock: clock < 0 ? -1 : Math.round(clock), averageClock: true,
        power: frame.power?.unit === "W" ? number(frame.power.GPU) : -1,
        temperature: -1, fan: -1, memUsed: -1, memTotal: -1}, clients: clients};
}

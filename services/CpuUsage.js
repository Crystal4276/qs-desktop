.pragma library

// guest and guest_nice are already included in user and nice.
function parse(text) {
    return text.split("\n").filter(line => /^cpu\d*\s/.test(line)).map(line => {
        const fields = line.trim().split(/\s+/);
        const times = fields.slice(1, 9).map(Number);
        return { id: fields[0], idle: times[3] + times[4], total: times.reduce((a, b) => a + b, 0),
            valid: times.length === 8 && times.every(t => isFinite(t) && t >= 0) };
    }).filter(row => row.valid);
}

function usage(current, previous) {
    if (!previous || current.id !== previous.id) return 0;
    const elapsed = current.total - previous.total;
    const idle = current.idle - previous.idle;
    // A reset or an inconsistent sample must not produce a spike.
    if (elapsed <= 0 || idle < 0 || idle > elapsed) return 0;
    return Math.max(0, Math.min(100, Math.floor(100 * (1 - idle / elapsed))));
}

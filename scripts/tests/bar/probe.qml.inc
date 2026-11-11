        IpcHandler {
            target: "geometry"
            function configure(artist: string, title: string, paused: bool, updates: int): void {
                Media.player = ({trackArtist: artist, trackTitle: title}); Media.paused = paused; Updates.count = updates;
            }
            function updates(count: int): void { Updates.count = count; }
            function extras(count: int): void { Media.extraIcons = count; }
            function absent(): void { Media.player = null; Battery.available = false; Brightness.available = false; }
            function state(): string { return JSON.stringify({ width: bar.width, level: bar.compactLevel,
                fixed: [bar.fixedWidth(0), bar.fixedWidth(1), bar.fixedWidth(2)], extra: bar.musicExtra,
                leftEnd: leftSide.x + leftSide.width, rightStart: rightSide.x,
                slots: bar.groups.reduce((all, group) => all.concat(group), []).map(s => ({ name: s.modelData, wanted: s.wanted, width: s.width, itemWidth: s.item?.width, text: s.item?.dynamic ?? "", textWidth: s.item?.textWidth ?? 0, segments: s.item?.segments?.length ?? 0,
                    label: Array.from(s.item?.children ?? []).find(c => c.segments !== undefined && c.visible)?.implicitWidth ?? 0 })) }); }
        }

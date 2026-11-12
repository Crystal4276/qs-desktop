#!/bin/sh
set -eu
kit_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
for size in 14 16 18 20 22 24 26 28 32 36 40 48 56 64; do
  grub-mkfont --size="$size" --range=0x20-0x17f,0x2190-0x2193 --output="$kit_dir/assets/fonts/inter-$size.pf2" "$kit_dir/assets/fonts/Inter-Regular.ttf"
done

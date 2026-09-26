use std::fs;

use half::prelude::*;

fn main() {
    let g = fs::read("../dfg_lut.bin").unwrap();

    let g = g
        .as_chunks::<2>()
        .0
        .iter()
        .map(|i| f16::from_le_bytes(*i))
        .collect::<Vec<_>>();

    let g = g
        .as_chunks::<3>()
        .0
        .iter()
        .flat_map(|c| [c[0], c[1]])
        .collect::<Vec<_>>();

    let g = g
        .as_chunks::<2>()
        .0
        .iter()
        .flat_map(|h| (h[0] + h[1]).to_le_bytes())
        .collect::<Vec<_>>();

    //let g = g.iter().flat_map(|h| h.to_le_bytes()).collect::<Vec<_>>();

    fs::write("../dfg_lut2.bin", &g).unwrap();
}

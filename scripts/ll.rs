/// https://play.rust-lang.org/
///
/// Used in `shaders/shaders.properties`.
fn main() {
    const CAPACITIES: [u32; 19] = [
        128, 256, 512, 1024, 2048, 3072, 4096, 5120, 6114, 7178, 8192, 9216, 10240, 11264, 12288,
        13312, 14336, 15360, 16384,
    ]; // The possible values of `LL_CAPACITY`.

    let mut elif = "if";

    for capacity in CAPACITIES {
        println!("#{elif} LL_CAPACITY == {capacity}");

        println!(
            "	bufferObject.1={}",
            4 * (4 + (capacity + capacity.div_ceil(2)))
        );
        println!("	bufferObject.2={}", 4 * (1 + (capacity * 2))); // TODO: Account for 16-bit colors in llq.

        elif = "elif";
    }

    println!("#endif");
}

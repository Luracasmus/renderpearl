/// https://play.rust-lang.org/
///
/// Used in `shaders/prelude/directive.glsl`.
fn main() {
    const REN_MUL: f64 = 0.85; // `shadowDistanceRenderMul`
    const MAX_ROT: f64 = 25.0; // Maximum `sunPathRotation`.
    const Y_RANGE: f64 = 384.0; // Y axis length of the world.

    let mut elif = "if";

    let cos_a = (std::f64::consts::PI * 0.25 - MAX_ROT.to_radians()).cos();

    for i in 1..=32 {
        let dist = i * 16;

        println!("#{elif} SM_DIST == {i}");
        println!("	const float shadowDistance = {dist};");

        let visible = dist as f64 * REN_MUL;

        let max_y = visible.min(Y_RANGE);
        let max_xz = (2.0_f64).sqrt() * visible * visible * cos_a;
        let plane = (max_xz * max_xz + max_y * max_y).sqrt().ceil();
        println!("	const float shadowNearPlane = -{plane};");
        println!("	const float shadowFarPlane = {plane};");

        elif = "elif";
    }

    println!("#endif");
}

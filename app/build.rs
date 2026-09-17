// Cargo mặc định KHÔNG build lại khi biến môi trường đổi, nên `option_env!("GIT_SHA")`
// sẽ giữ giá trị của lần build đầu tiên. Dòng dưới bảo Cargo theo dõi GIT_SHA và
// build lại khi nó thay đổi — nếu không, /version sẽ trả SHA cũ và bằng chứng M2 sai.
fn main() {
    println!("cargo::rerun-if-env-changed=GIT_SHA");
}

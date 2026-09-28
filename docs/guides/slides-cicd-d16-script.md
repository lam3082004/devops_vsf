# Kịch bản thuyết trình và giải thích: OpsBoard CI/CD (tới D16)

Đi kèm `slides-cicd-d16.html` (15 slide). Nói hết khoảng **14 phút**, chưa tính hỏi đáp. Cần rút xuống 10 phút thì nói lướt slide 9, 11 và 13.

Mỗi slide có hai phần:
- **🎤 Nói**: lời thuyết trình. Không cần đọc thuộc, nhớ ý in đậm là đủ. **▶** là chỗ nên chỉ vào slide; *→* là câu nối sang slide sau.
- **💡 Giải thích**: kiến thức nền và lý do. Phần này để bạn hiểu, không phải để đọc to. Khi bị hỏi thì lấy ý ở đây ra trả lời.

| # | Slide | Thời lượng |
|---|---|---|
| 1 | Bìa | 0:40 |
| 2 | Hành trình của một thay đổi | 1:00 |
| 3 | Trunk-based | 1:00 |
| 4 | Ruleset protect-main | 1:00 |
| 5 | CI: 8 job | 1:30 |
| 6 | Cố tình làm sai 6 lần | 1:00 |
| 7 | OIDC | 1:30 |
| 8 | Ba danh tính | 1:00 |
| 9 | Preflight | 0:45 |
| 10 | CD: 3 job | 1:15 |
| 11 | Staging | 0:45 |
| 12 | Production (swap) | 1:00 |
| 13 | Flow CI/CD | 0:45 |
| 14 | Đang chuẩn bị làm gì | 0:40 |
| 15 | Cảm ơn · Q&A | 0:20 |

---

## 1 · Bìa

### 🎤 Nói
> Em chào mọi người. Em là Lâm. Hôm nay em trình bày phần em đã làm tới ngày 16 của đợt thực tập: đưa một app web lên Azure App Service, với một pipeline CI/CD tự động hoàn toàn.
>
> App tên là **OpsBoard**, một công cụ quản lý ticket lỗi có bảng kanban. Nó gồm hai phần: backend .NET và frontend Next.js.
>
> ▶ *Chỉ 4 con số.* Tóm tắt nhanh: **8 trên 11** yêu cầu bắt buộc đã đạt. Từ lúc merge tới lúc người dùng thấy bản mới mất khoảng **7 phút**. Và **không có mật khẩu Azure nào** nằm trên GitHub.

*→ "Trước khi đi vào chi tiết, em cho mọi người xem toàn cảnh một thay đổi đi qua những đâu."*

### 💡 Giải thích
- **8/11 must-have gồm những gì?** Đã đạt:
  - M1: App Service kéo image từ ACR bằng managed identity.
  - M3: MySQL, firewall chỉ mở cho IP của app.
  - M4: dùng managed identity đọc Key Vault.
  - M5: gỡ quyền Key Vault thì app gãy.
  - M6: IP whitelist.
  - M8: Terraform toàn bộ hạ tầng.
  - M9: CI chặn cái sai.
  - M10: CD deploy từ `main`.

  Chưa làm: M2 (zero-downtime), M7 (chi phí và autoscale), M11 (monitoring). Ba cái này nằm ở D18–D22.
- **Vì sao hai service?** Frontend Next.js và backend .NET là hai Web App riêng trên **cùng một** App Service Plan. Cùng plan nên không tốn thêm tiền. Tách hai app thì request đi qua chặng fe → be thật, sau này làm tracing mới có ý nghĩa.
- **"~7 phút"** là thời gian thật của một lần CD. Lần chạy #8 mất 7m 55s.

## 2 · Hành trình của một thay đổi

### 🎤 Nói
> ▶ *Chỉ dọc 7 trạm.* Một thay đổi đi qua 7 trạm:
> - Viết code trên nhánh ngắn, mở Pull Request.
> - CI tự kiểm tra.
> - Pipeline đăng nhập Azure mà không cần mật khẩu.
> - Merge xong thì CD chạy: đóng gói, chạy thử trên staging, rồi đưa lên production.
>
> ▶ *Chỉ hai vùng màu.* Năm trạm đầu diễn ra trên GitHub, hai trạm cuối trên Azure.
>
> ▶ *Chỉ hai thanh dưới.* Có hai quy tắc em giữ suốt dự án: chỉ `main` sống lâu, và chỉ `main` mới được deploy.

*→ "Bắt đầu từ trạm 1: cách em quản lý nhánh."*

### 💡 Giải thích
- **CI (Continuous Integration):** mỗi thay đổi được kiểm tra tự động **trước khi** gộp vào nhánh chính. Kết quả của CI là câu trả lời "có được merge không". CI ở đây không deploy gì.
- **CD (Continuous Delivery/Deployment):** sau khi merge, hệ thống tự đưa bản mới lên môi trường chạy thật. Ở repo này CD tự động hoàn toàn, không có bước duyệt tay.
- **GitHub Actions** là nơi chạy CI/CD. Mỗi file `.yml` trong `.github/workflows/` là một workflow, mỗi workflow gồm nhiều **job**, mỗi job gồm nhiều **step**.

## 3 · Trunk-based

### 🎤 Nói
> Repo làm theo **trunk-based development**.
>
> ▶ *Chỉ đường đen.* Đây là `main`, nhánh duy nhất sống lâu. Không có `develop`, không có `release`.
>
> ▶ *Chỉ các nhánh màu.* Mỗi việc là một nhánh ngắn, đặt tên `feat/`, `fix/` hoặc `chore/`, sống tối đa 2 ngày (tên trên hình là ví dụ). Nhánh ngắn thì PR nhỏ, review nhanh, ít xung đột.
>
> ▶ *Chỉ chữ "squash".* Khi merge, cả nhánh được **squash** thành đúng một commit trên `main`. Lịch sử gọn, và nếu có lỗi thì revert một commit là xong.
>
> ▶ *Chỉ dòng dưới.* Trước khi push, em chạy `make check`, tức là chạy lại lint, test, build giống CI. Máy em cũng có hook gitleaks chặn ngay những commit có mật khẩu hay token.

*→ "Push lên rồi thì code phải qua cổng merge."*

### 💡 Giải thích
- **Trunk-based khác Git Flow chỗ nào?** Git Flow có nhiều nhánh sống lâu (`develop`, `release/*`, `hotfix/*`), code nằm tách biệt lâu nên hay xung đột khi gộp. Trunk-based chỉ có một thân chính và các nhánh ngắn, gộp liên tục. Nó hợp với CD vì `main` luôn ở trạng thái deploy được.
- **Squash merge:** gộp mọi commit của nhánh thành **một** commit trên `main`. Mỗi PR tương ứng một commit, dễ đọc, và revert một lần là gỡ trọn một thay đổi.
- **Pre-commit hook:** script git tự chạy **trước** mỗi commit. Ở đây hook chạy gitleaks, thấy chuỗi giống mật khẩu hay token thì chặn commit. Điểm yếu: hook nằm trong `.git/hooks`, không được lưu trong repo, nên người clone mới phải tự cài. Lớp chặn thật sự vẫn là CI.
- **`make check`** chạy `dotnet format` và `dotnet test` cho backend, `npm run lint` và `npm run build` cho frontend, tức là phần lint, test, build của CI. Nó không chạy gitleaks, terraform hay docker.

## 4 · Ruleset protect-main

### 🎤 Nói
> Cổng merge là **Ruleset `protect-main`** của GitHub.
>
> ▶ *Chỉ khung giữa.* Ruleset có bốn luật:
> - Phải đi qua Pull Request.
> - Đủ **8 trên 8** required checks phải xanh, và nhánh phải cập nhật theo `main`.
> - Danh sách bypass để trống, tức là kể cả admin cũng không merge được khi đang đỏ.
> - Chỉ cho squash merge, cấm force push, cấm xoá nhánh.
>
> ▶ *Chỉ hai ô phải.* Đủ xanh thì trạng thái là `clean`, nút Merge mở. Một check đỏ là `blocked`.
>
> ▶ *Chỉ hai ghi chú dưới.* Có một chuyện thật ở ngày 14. Lúc đầu ruleset chỉ bắt buộc 4 trên 6 check, nên một PR làm hỏng frontend vẫn merge được. Em sửa ruleset, và **cùng PR đó**, không đổi một dòng code, chuyển sang bị chặn. Bài học: phải đo trạng thái thật, không tin cấu hình nhìn có vẻ đúng.

*→ "Vậy 8 check đó là những gì?"*

### 💡 Giải thích
- **Ruleset** là cơ chế mới hơn "branch protection" của GitHub. Nó áp luật lên một nhánh (ở đây là nhánh mặc định `main`). Repo này private mà ruleset vẫn có hiệu lực, đã kiểm bằng chặn merge thật.
- **Required status check:** một job CI được đánh dấu là "bắt buộc xanh". Job CI **không** tự chặn merge; chỉ khi tên job nằm trong danh sách required của ruleset thì đỏ mới chặn. Đó chính là lỗ ở D14: job có chạy, có đỏ, nhưng không nằm trong danh sách nên không chặn.
- **`mergeable_state`** là trạng thái GitHub trả qua API:
  - `clean`: merge được.
  - `blocked`: bị luật chặn.
  - `unstable`: có check đỏ nhưng không bắt buộc, nên **vẫn merge được**.
  - `behind`: nhánh cũ hơn `main`, phải cập nhật trước.

  Nhìn tab Checks thì không phân biệt được `unstable` với `blocked`, nên phải đọc API.
- **Bypass list trống:** không ai được bỏ qua luật. Nếu cho admin bypass thì cổng chỉ là hình thức.

## 5 · CI: 8 job

### 🎤 Nói
> Đây là CI, file `ci.yml`, chạy trên mọi Pull Request. ▶ *Chỉ thanh trên.* Đây là một lần chạy thật: run #64, tổng **2 phút 9 giây**.
>
> ▶ *Chỉ khung nét đứt.* **6 job chạy song song:**
> - **gitleaks** quét toàn bộ lịch sử git tìm mật khẩu.
> - **dotnet** chạy format, build và test backend, với một MySQL 8.4 thật.
> - **frontend** chạy lint và build Next.js, có kiểm kiểu TypeScript.
> - **Hai job docker** build image backend và frontend, **chỉ build, không push**, rồi Trivy quét lỗ hổng. Image frontend lúc đầu có 1 lỗ hổng CRITICAL và 13 HIGH. Em sửa Dockerfile (bỏ npm, nâng image nền), không nới luật quét, và về 0.
> - **azure login** kiểm cơ chế đăng nhập không mật khẩu còn chạy được.
>
> ▶ *Chỉ hàng dưới.* **Hai job nối tiếp:** terraform format và validate xong thì mới chạy `plan`. Plan xuất file `plan.txt` để người review đọc trước hạ tầng sẽ đổi gì.
>
> Cả 8 job đều là required check, nên một job đỏ là không merge được.

*→ "Nói CI chặn được thì phải chứng minh."*

### 💡 Giải thích
- **Song song và nối tiếp:** mặc định các job chạy cùng lúc trên các máy riêng. `needs: terraform` bắt job plan phải đợi job fmt/validate xanh, để khỏi tốn một lượt gọi Azure cho code còn sai cú pháp.
- **gitleaks với `fetch-depth: 0`:** lấy **toàn bộ** lịch sử chứ không chỉ commit mới nhất. Nếu mật khẩu nằm ở một commit giữa PR rồi bị xoá ở commit sau, nó vẫn bị bắt.
- **Vì sao test với MySQL thật?** Test giả lập không bắt được lỗi SQL. CI bật một container MySQL 8.4 (service container) ngay trong job để test chạy trên DB thật.
- **Vì sao build image mà không push?** Code trong PR chưa ai duyệt. Push nghĩa là cho code đó ghi vào kho image mà production kéo về. Build chỉ để chứng minh Dockerfile còn chạy được và image sạch.
- **Trivy và CVE:** CVE là mã định danh công khai của một lỗ hổng đã biết. Trivy đối chiếu các gói trong image với cơ sở dữ liệu CVE. Cổng chỉ chặn mức **CRITICAL/HIGH**. Mức MEDIUM của backend (7 cái, nằm trong thư viện `libc6` của image nền Microsoft) không tự vá được, nên chỉ in ra để theo dõi.
- **Vì sao cần cả job frontend lẫn job docker frontend?** Job frontend build trên máy CI và không đụng Dockerfile. Job docker frontend build đúng image sẽ lên production và quét các gói của image nền Node (npm, openssl) mà backend không có.
- **`terraform plan`** so code hạ tầng với hạ tầng thật và in ra "sẽ tạo, sửa, xoá gì", nhưng không làm gì cả. Người review đọc `plan.txt` trước khi merge.
- **Hủy run cũ:** đẩy commit mới lên cùng PR thì run cũ tự huỷ (`cancel-in-progress: true`). Huỷ một lần build dở không để lại hậu quả gì.

## 6 · Cố tình làm sai 6 lần

### 🎤 Nói
> Đề bài nói rõ: chứng minh M9 không phải là pipeline chạy xanh, mà là **pipeline chặn được cái sai**.
>
> ▶ *Chỉ 6 thẻ đỏ.* Em mở 6 PR, mỗi PR cố tình làm sai một thứ: cài mật khẩu giả, gõ sai Dockerfile, cho ticket đã đóng mở lại được (một lỗi nghiệp vụ thật), thụt lề sai file Terraform, dùng image nền cũ có 56 lỗ hổng, và lỗi kiểu dữ liệu ở frontend. Cả 6 đều bị chặn, đúng job em dự đoán.
>
> ▶ *Chỉ thẻ xanh.* Có thêm một PR đúng để đối chứng. Nếu không có nó, có thể pipeline đang đỏ với mọi PR.
>
> ▶ *Chỉ khung terminal.* Em còn thử merge bằng lệnh khi đang đỏ, và GitHub từ chối.

*→ "Tiếp theo là phần em thấy thú vị nhất: pipeline vào Azure bằng cách nào."*

### 💡 Giải thích
- **Kiểm thử âm (negative test):** cố tình đưa vào thứ sai để xem hệ thống có chặn không. Pipeline lúc nào cũng xanh chưa chứng minh được gì, vì có thể nó không kiểm gì cả.
- **PR đối chứng:** nếu chỉ có PR đỏ thì không phân biệt được "CI chặn đúng" với "CI hỏng, đỏ mọi thứ". Một PR đúng mà xanh loại trừ khả năng thứ hai.
- **Bài học về secret giả:** chuỗi ví dụ trong tài liệu AWS nằm sẵn trong danh sách bỏ qua của gitleaks, nên lần đầu dùng nó thì gitleaks báo "không có gì". Phép thử âm tính chưa chắc chứng minh được điều mình tưởng.
- **Hệ quả ngoài dự kiến:** vì gitleaks quét toàn bộ repo, một mật khẩu giả ở **một** nhánh làm gitleaks đỏ ở **mọi** PR đang mở. Cách đọc đúng là xem dòng `Commit:` và `File:` trong log để biết nó nằm ở nhánh nào.

## 7 · OIDC

### 🎤 Nói
> Cách thông thường là cất một mật khẩu Azure trong GitHub Secrets. Em **không làm vậy**. Em dùng OIDC.
>
> ▶ *Đi theo số 1 → 8.* Lấy ví dụ job preflight của CD:
> 1. Job xin GitHub một "thẻ tên" có chữ ký, gọi là JWT.
> 2. Trong thẻ ghi rõ repo nào, nhánh nào.
> 3. Job gửi thẻ đó cho Microsoft Entra, xin đóng vai danh tính `id-gh-deploy`.
> 4. Entra tải khoá công khai của GitHub để kiểm chữ ký là thật.
> 5. Entra so thẻ với luật đã đăng ký trước.
> 6. Khớp thì Entra cấp một token Azure sống ngắn.
> 7. Job dùng token đó để push image và swap.
> 8. Azure kiểm quyền của danh tính: có được làm việc đó không.
>
> ▶ *Chỉ hai thẻ dưới.* Chỗ quan trọng nhất là **bước 5**. Ba trường `iss`, `aud`, `sub` phải khớp tuyệt đối với luật em khai trong Terraform. Trường `sub` có chứa tên nhánh.
>
> ▶ *Chỉ dòng đỏ.* Em đã thử chạy CD từ một nhánh `feat/`. Khi đó `sub` khác đi, Entra trả lỗi `AADSTS700213` và job dừng ngay.
>
> Kết quả: không có mật khẩu nào để lộ, và không có mật khẩu nào phải xoay vòng.

*→ "Có token rồi thì mỗi danh tính được làm gì?"*

### 💡 Giải thích
- **OIDC (OpenID Connect):** chuẩn để một hệ thống chứng minh danh tính với hệ thống khác bằng token có chữ ký. Ở đây GitHub là **bên phát thẻ**, Entra là **bên tin thẻ**.
- **JWT:** chuỗi token gồm ba phần: header, nội dung và chữ ký. Nội dung có các "claim":
  - `iss` (issuer, ai phát): `https://token.actions.githubusercontent.com`
  - `aud` (audience, phát cho ai dùng): `api://AzureADTokenExchange`
  - `sub` (subject, thẻ nói về ai): repo + nhánh, hoặc repo + environment
- **Federated credential:** luật khai trên danh tính Azure, nói rằng "tin thẻ nào có đúng iss, aud, sub như sau". Không có mật khẩu nào được lưu. Luật khai trong `infra/bootstrap/cicd.tf`.
- **Vì sao dùng managed identity mà không dùng app registration?** Tenant của trường đặt `allowedToCreateApps = false`, user thường không tạo được app registration. User-assigned managed identity chỉ cần quyền trên subscription, và cũng gắn federated credential được.
- **Bẫy "immutable subject":** repo bật chế độ này nên GitHub gửi `sub` kèm mã số, dạng `repo:lam3082004@67915284/devops_vsf@1371039109:…`, chứ không phải dạng tên đơn giản như mọi tài liệu ví dụ. Vì vậy mỗi luật phải khai hai lần: dạng tên và dạng có mã số.
- **Bẫy environment:** job nào khai `environment:` thì `sub` đổi thành `…:environment:<tên>` và **không còn tên nhánh**. Vì thế chỉ job `preflight` (không có environment) mới kiểm được tên nhánh ở tầng Entra.
- **`permissions: id-token: write`:** thiếu dòng này thì job không xin được JWT. Khai ở cấp job nào cần, không cấp tràn lan.
- **`client_id`** nằm trong GitHub **Variables** chứ không phải Secrets, vì nó chỉ là mã định danh, không phải mật khẩu. Có `client_id` mà không có thẻ hợp lệ thì vẫn không làm được gì.

## 8 · Ba danh tính

### 🎤 Nói
> Em tách ra ba danh tính, mỗi cái chỉ đủ quyền cho việc của nó.
>
> ▶ *Cột 1.* `id-gh-plan` dùng cho CI trên PR. Nó chỉ đọc và chạy `terraform plan`, không được apply. Nó cần quyền ghi vào storage chứa state, vì plan phải khoá state trong lúc chạy.
>
> ▶ *Cột 2.* `id-gh-deploy` dùng cho CD trên `main`: đẩy image lên ACR và quản lý web app trong resource group, nhưng không đụng database hay Key Vault, và không tự cấp quyền được. Ô mờ là một quyền hiện chưa dùng, em sẽ gỡ.
>
> ▶ *Cột 3.* `id-vsf-app` là danh tính của chính app lúc chạy: kéo image và đọc mật khẩu database trong Key Vault. Chỉ vậy.
>
> ▶ *Hàng dưới.* Để chắc chắn chỉ `main` mới deploy được, có 3 lớp: workflow chỉ chạy khi push `main`; environment trên GitHub chỉ cho `main` vào; và Entra kiểm tên nhánh trong token. Lớp 3 nằm **ngoài GitHub**, nên kể cả ai sửa được workflow cũng không lấy được token.

*→ "Giờ tới CD, chạy ngay khi PR được merge."*

### 💡 Giải thích
- **RBAC (Role-Based Access Control):** quyền trên Azure = **ai** (principal) + **được làm gì** (role) + **ở đâu** (scope: subscription, resource group, hay một tài nguyên cụ thể). Scope càng hẹp càng an toàn.
- **Least privilege:** cấp đúng quyền cần cho việc, không hơn. Ví dụ CI chỉ cần xem trước, nên không có quyền sửa tài nguyên.
- **Vì sao `terraform plan` cần quyền ghi?** Terraform lưu "sổ hạ tầng" (state) trong Azure Storage. Trước khi chạy, nó **khoá** file state (blob lease) để hai người không sửa cùng lúc, và khoá là một thao tác ghi.
- **Vì sao có role tự tạo?** Khi đọc cấu hình Web App, Terraform gọi một API dạng `list`. Role `Reader` có sẵn không cấp API này. Thay vì dùng một role rộng, em tạo role chỉ gồm đúng 2 quyền cần.
- **Vì sao `id-gh-deploy` cần thêm `Reader`?** `AcrPush` chỉ cho đẩy và kéo image, không cho **đọc thông tin** ACR, mà `az acr login` cần đọc. Thiếu `Reader` là lỗi 403 ngay ở bước đăng nhập ACR.
- **Vì sao gán quyền ở resource group?** Có 2 app × 2 slot = 4 chỗ cần quyền. Gán một lần ở resource group thì phủ đủ cả 4, không sót slot.
- **Environment của GitHub:** nhóm các job deploy lại và giới hạn nhánh nào được vào. Có thể gắn thêm nút duyệt tay, nhưng tính năng đó trả phí với repo private.
- **User-assigned vs system-assigned identity:** system-assigned gắn với từng slot, swap xong code đổi chỗ nhưng identity không đổi theo, nên quyền sẽ lệch. User-assigned là một identity dùng chung cho cả hai slot, nên swap không làm đổi quyền.

## 9 · Preflight

### 🎤 Nói
> Việc đầu tiên CD làm là **hỏi trước: có chỗ để deploy không?**
>
> ▶ *Chỉ 3 nhánh.* Vì tiết kiệm chi phí, cuối ngày em tắt toàn bộ môi trường. Nên sẽ có 3 trường hợp:
> - **Không có gì:** dừng lại, vẫn báo xanh, để PR tài liệu không để lại một run đỏ vô nghĩa.
> - **Thiếu một phần:** cũng dừng, và ghi rõ thiếu gì. Môi trường dở dang còn nguy hiểm hơn môi trường trống.
> - **Đủ cả ba:** đi tiếp.
>
> ▶ *Chỉ ghi chú.* Hai lần merge sát nhau thì CD xếp hàng chạy lần lượt, không huỷ nhau. Huỷ giữa lúc đang swap sẽ để production ở trạng thái không ai biết.

*→ "Còn toàn bộ CD trông thế nào?"*

### 💡 Giải thích
- **Vì sao phải tìm tên app?** Mỗi lần dựng lại môi trường, tên tài nguyên có một hậu tố ngẫu nhiên (ví dụ `app-vsf-jcip0s`), nên không ghi cứng tên trong workflow được. Preflight hỏi Azure theo tiền tố để lấy tên thật.
- **`concurrency` với `cancel-in-progress: false`:** các run CD dùng chung một "hàng đợi" tên `cd-deploy`. Run sau đợi run trước xong, không huỷ nhau. CI thì ngược lại (huỷ được), vì huỷ CI không để lại hậu quả, còn huỷ CD giữa lúc swap có thể để lại backend bản mới, frontend bản cũ.
- **Vì sao preflight không nằm trong environment?** Giữ cho token của nó còn mang tên nhánh (xem slide 7), nhờ đó lớp chặn thứ 3 có tác dụng. Và nếu sau này bật nút duyệt ở environment, PR tài liệu sẽ không sinh yêu cầu duyệt treo.

## 10 · CD: 3 job

### 🎤 Nói
> ▶ *Thanh trên.* Đây là run #8 của CD, cho commit `92b0a35`. Tổng **7 phút 55 giây**, không ai bấm gì.
>
> ▶ *Đi từ trái sang phải.* CD có 3 job nối tiếp:
> - **preflight**, 18 giây, là cái em vừa nói.
> - **build, push, set image**, gần 5 phút: build lại image ngay trên `main`, gắn tag bằng mã commit, quét Trivy lần nữa, đẩy lên ACR, rồi đặt image mới cho slot staging.
> - **swap**, 2 phút rưỡi: swap backend trước, frontend sau.
>
> ▶ *Chỉ nhãn environment.* Job 2 và job 3 nằm trong hai environment riêng, `staging-deploy` và `production`, cả hai đều chỉ cho `main`.
>
> ▶ *Chỉ ghi chú.* Rollback rất nhanh: slot staging đang giữ bản cũ, swap lại là xong.

*→ "Em nói kỹ hơn về staging và swap."*

### 💡 Giải thích
- **Vì sao build lại mà không dùng image của CI?** CI không được push (code chưa duyệt), nên image của CI không nằm trong ACR. CD build từ `main` sau khi merge, nên image chắc chắn là code đã duyệt.
- **Tag = mã commit, không dùng `latest`:** nhìn tên image là biết production đang chạy đúng commit nào. `latest` thì không biết là bản nào, và dễ kéo nhầm.
- **Vì sao quét Trivy lần nữa?** Cơ sở dữ liệu lỗ hổng cập nhật mỗi ngày. Image hôm qua sạch, hôm nay có thể dính CVE mới công bố.
- **Hai environment:** `staging-deploy` cho bước đưa lên staging, `production` cho bước swap. Tách ra để nếu sau này có nút duyệt tay thì nút đó nằm **trước swap**, không phải trước build.
- **Kiểm "cờ pull bằng managed identity":** sau khi đặt image, CD đọc lại cấu hình để chắc app vẫn kéo image bằng managed identity. Nếu cờ này mất, lệnh đặt image vẫn báo thành công nhưng container không kéo được image.

## 11 · Staging

### 🎤 Nói
> Slot staging là **một bản sao của app, chạy song song với production nhưng người dùng chưa thấy.**
>
> ▶ *Cột trái.* Phần của CD: build, quét, push, rồi nói với staging "chạy image mới này".
>
> ▶ *Cột phải.* Phần còn lại Azure tự làm, bằng danh tính của app:
> - kéo image từ ACR (tài khoản admin của ACR đã tắt);
> - lấy mật khẩu database từ Key Vault. Trong cấu hình app chỉ có **địa chỉ** của secret, không có mật khẩu thật;
> - khởi động app. Lấy mật khẩu hỏng thì app tự tắt ngay và báo lỗi rõ ràng.
>
> ▶ *Chỉ ghi chú đỏ.* Em nói thẳng điểm chưa ổn: hiện CD chỉ đợi cố định 75 giây rồi coi như xong, chưa kiểm app đã chạy đúng chưa. Đây là việc đầu tiên của ngày 17.

*→ "Sau staging là bước cuối: lên production."*

### 💡 Giải thích
- **Deployment slot:** App Service cho một app có thêm "slot" phụ, mỗi slot có địa chỉ riêng (ví dụ `app-vsf-xxx-staging.azurewebsites.net`). Gói máy P0v3 có slot, gói B1 rẻ hơn thì không, đó là lý do chọn P0v3.
- **ACR admin tắt:** ACR có sẵn một tài khoản admin (username/password chung). Em tắt nó, nên cách duy nhất để kéo image là qua danh tính có quyền `AcrPull`.
- **Key Vault reference:** trong cấu hình app, `DB_PASSWORD` có giá trị `@Microsoft.KeyVault(SecretUri=…)`. Lúc container khởi động, App Service dùng danh tính của app để lấy mật khẩu thật từ Key Vault rồi đưa vào biến môi trường. Ai đọc được cấu hình cũng chỉ thấy địa chỉ.
- **Fail-fast:** nếu lấy mật khẩu hỏng, nền tảng không báo lỗi mà để nguyên chuỗi `@Microsoft.KeyVault(…)`. App tự kiểm tra, thấy chuỗi đó thì thoát ngay với lỗi rõ ràng, thay vì mang chuỗi đó đi đăng nhập MySQL rồi báo "sai mật khẩu" gây hiểu nhầm. Đã thử thật: gỡ quyền Key Vault và restart, app tắt sau 0.2 giây.
- **Hạn chế đã biết:** frontend staging đang gọi backend **production**, vì cả hai slot dùng chung cấu hình `API_BASE_URL`. Sửa ở D17 bằng setting "dính slot" (slot-sticky).

## 12 · Production (swap)

### 🎤 Nói
> ▶ *Chỉ hình trước/sau.* Swap là **đổi chỗ** hai slot. Trước: production chạy bản A, staging chạy bản B. Sau: production chạy B, còn A nằm lại ở staging.
>
> ▶ *Ghi chú xanh.* Vì bản cũ vẫn còn đó, bản mới lỗi thì swap lại một lần, khoảng 2–3 phút, không cần build lại.
>
> ▶ *Ghi chú xanh dương.* Em cố ý swap backend trước frontend. Trong khoảng lệch ngắn đó, frontend cũ gọi backend mới ít rủi ro hơn frontend mới gọi một API chưa tồn tại.
>
> ▶ *Thanh thời gian.* Đây là một lần deploy thật, khoảng 7 phút. Phần chờ và phần swap chiếm hơn một nửa.

*→ "Ghép tất cả lại thì được bức tranh này."*

### 💡 Giải thích
- **Swap diễn ra thế nào?**
  1. Azure áp cấu hình của production lên staging và khởi động lại staging.
  2. Azure gọi thử staging (warm-up) cho tới khi nó trả lời.
  3. Azure đổi đường đi: tên miền production trỏ sang instance đã nóng.

  Instance cũ vẫn phục vụ tới lúc đổi, nên về lý thuyết người dùng không thấy gián đoạn. Điều này chưa được đo, đó là bài D18.
- **Swap không nguyên tử giữa hai app:** Azure không có lệnh swap hai app cùng lúc, nên luôn có vài chục giây backend đã là bản mới mà frontend vẫn là bản cũ. CD bắt lỗi từng lệnh swap. Nếu swap frontend lỗi, summary in sẵn lệnh để đưa về trạng thái nhất quán.
- **Rollback chỉ an toàn khi chưa deploy chồng:** nếu lại merge thêm một lần, staging sẽ bị ghi đè bằng bản mới hơn và bản tốt cũ mất khỏi slot.
- **Hai con số thời gian:** slide này là lần deploy commit `e6658dc` (khoảng 7 phút), slide job CD là run #8 (7m 55s). Cả hai đều là lần chạy thật.

## 13 · Flow CI/CD

### 🎤 Nói
> ▶ *Đi từ trái sang phải trên sơ đồ.*
> - Nhánh ngắn và hook ở máy.
> - Pull Request chạy CI.
> - Ruleset kiểm 8 trên 8. Đỏ thì sửa và push lại; xanh thì squash merge.
> - Merge kích hoạt CD: preflight, build và deploy staging, swap.
> - Production chạy đúng mã commit vừa merge.
>
> Toàn bộ đoạn từ merge tới production **không có thao tác tay nào**.

*→ "Đó là những gì đã xong. Tiếp theo em sẽ làm..."*

### 💡 Giải thích
- Sơ đồ vẽ bằng **Mermaid**, một cách viết sơ đồ bằng chữ. Mã nguồn nằm trong comment của file HTML, sửa và render lại được.
- Hai lối ra của CD: "Skip deploy" khi môi trường tắt hoặc thiếu, và "Production runs new SHA" khi đủ. Cả hai đều kết thúc xanh.

## 14 · Đang chuẩn bị làm gì

### 🎤 Nói
> ▶ *Chỉ lộ trình.*
> - **D17 · Safe swap:** swap an toàn. Thay 75 giây chờ bằng kiểm tra thật (đúng phiên bản, app khoẻ). Nếu production lỗi thì tự swap lại.
> - **D18 · Zero-downtime:** chứng minh không gián đoạn. Trong lúc swap, gọi app mỗi giây, yêu cầu 0 lỗi.
> - **D19 đến D22 · Autoscale, Cost report, Centralized logging, Alerts:** tự tăng máy khi tải cao (tối đa 2 máy), báo cáo chi phí, gom log, dựng dashboard và cảnh báo.
> - **D23–D25 · Least-privilege agent, Incident drill, Live demo.**
>
> ▶ *Chỉ ghi chú vàng.* Có một rủi ro về lịch: tài khoản Azure dùng thử hết hạn ngày 15/10, rơi đúng ngày 23. Em đang chờ mentor chốt subscription cho các ngày cuối.

### 💡 Giải thích
- **D17 · swap an toàn:**
  - health check path (Azure tự loại instance hỏng);
  - warm-up chỉ chấp nhận mã 200;
  - CD mở luật IP tạm cho máy runner để tự gọi kiểm tra staging, và **luôn** xoá luật đó kể cả khi job lỗi;
  - kiểm production sau swap, lỗi thì tự swap ngược.
- **D18 · zero-downtime:** script gọi `/version` mỗi giây, ghi lại giờ, mã HTTP, phiên bản. Đạt khi không có dòng nào khác 200, và phiên bản đổi từ A sang B.
- **D19 · autoscale:** CPU trên 70% trong 5 phút thì thêm 1 máy; dưới 30% trong 10 phút thì bớt. Tối đa 2 máy theo đề. Bớt chậm hơn thêm để tránh dao động liên tục.
- **D20–D22:** báo cáo chi phí thật từ Azure Cost Analysis; gom log vào Log Analytics; 3 cảnh báo (lỗi 5xx, CPU cao, kết nối MySQL) gửi email, và kích hoạt thật ít nhất 1 cái.

## 15 · Cảm ơn · Q&A

### 🎤 Nói
> Tóm lại: từ một commit trên nhánh ngắn tới production, có kiểm tra ở mọi bước, không mật khẩu, không thao tác tay.
>
> Em cảm ơn mọi người đã lắng nghe. Mọi người có câu hỏi gì không ạ?

---

## Chuẩn bị hỏi đáp

Trả lời ngắn trước, có người hỏi thêm thì lấy ý ở phần 💡 của slide tương ứng.

**Vì sao chọn trunk-based mà không dùng Git Flow?**
Đề bài yêu cầu. Và nó hợp với CD: `main` luôn deploy được, PR nhỏ nên review nhanh, ít xung đột. *(slide 3)*

**OIDC khác gì so với cất client secret trong GitHub?**
Không có secret dài hạn để lộ hay phải xoay vòng. Token chỉ sống ngắn và chỉ được cấp khi thẻ khớp đúng repo và nhánh. *(slide 7)*

**Vì sao CD build lại image mà không dùng image của CI?**
CI chạy trên code chưa duyệt nên không được push. CD build từ `main` sau khi merge, tag bằng mã commit. *(slide 10)*

**Vì sao chỉ chặn CRITICAL/HIGH?**
MEDIUM của backend nằm trong image nền của Microsoft, không tự vá được. Chặn luôn mức đó thì CI đỏ suốt. Vẫn quét và in đủ mọi mức để theo dõi. *(slide 5)*

**Tại sao user-assigned identity?**
Identity system-assigned không đi theo khi swap slot, quyền sẽ lệch. Một identity chung cho cả hai slot thì swap không đổi quyền. *(slide 8)*

**Deploy có làm người dùng bị gián đoạn không?**
Chưa đo, đó là bài D18. Về cơ chế, swap có warm-up và instance cũ vẫn phục vụ tới lúc đổi. *(slide 12)*

**Bản mới lỗi thì sao?**
Swap lại, khoảng 2–3 phút, vì bản cũ nằm ở staging. Hiện làm tay; D17 sẽ tự động. *(slide 12)*

**Vì sao không có nút duyệt tay trước production?**
Required reviewers là tính năng trả phí với repo private. Pipeline tự động hoàn toàn, khớp yêu cầu "merge là deploy, không thao tác tay". Chỗ đặt nút duyệt đã sẵn ở job swap. *(slide 8, 10)*

**Hạ tầng tạo bằng gì, mất hết thì dựng lại được không?**
Toàn bộ bằng Terraform. Ngày 10 em xoá sạch rồi dựng lại từ số 0: 24 phút, không thao tác tay, `plan` sau đó không còn thay đổi. State lưu trên Azure Storage, khoá bằng blob lease.

**Runner GitHub nằm ngoài whitelist IP, vậy CD vào app kiểm tra kiểu gì?**
Đúng, runner bị chặn 403. Deploy vẫn chạy được vì deploy đi qua control plane của Azure (API quản lý), không đi qua cửa web của app. D17 sẽ mở luật IP tạm cho runner và luôn xoá sau khi xong.

**Có điểm nào em biết là chưa tốt?** (nên chủ động nói nếu còn thời gian)
- CD chờ cố định 75 giây thay vì kiểm tra thật.
- Frontend staging gọi backend production, nên chưa thử hai bản mới với nhau trước khi swap.
- Có một lần CD báo xanh nhưng trang chủ frontend bị kẹt thông báo lỗi (bug #46, đã sửa). Nguyên nhân: lúc build image chưa có địa chỉ backend, Next.js lưu sẵn trang lỗi. Bài học: kiểm đúng phiên bản chưa đủ, phải kiểm app chạy được thật.
- Frontend chưa có unit test.
- Subject `pull_request` của CI khá rộng: một PR sửa `ci.yml` là chạy được dưới quyền của `id-gh-plan`.

**AI hỗ trợ thế nào?**
Từ ngày 7 em dùng AI và ghi rõ trong mục `## AI usage` của từng PR. Em ghi lại 30 lần AI sinh sai, kèm cách phát hiện và cách sửa, trong `ai-failure-log.md`.

---

## Bảng thuật ngữ

| Thuật ngữ | Nghĩa ngắn |
|---|---|
| CI | Tự động kiểm tra mỗi thay đổi trước khi merge |
| CD | Tự động đưa bản mới lên môi trường chạy sau khi merge |
| Workflow / job / step | File `.yml` / một khối việc chạy trên một máy / một lệnh trong khối đó |
| Trunk-based | Chỉ `main` sống lâu, nhánh phụ ngắn, gộp liên tục |
| Squash merge | Gộp cả nhánh thành một commit trên `main` |
| Ruleset | Luật GitHub đặt lên nhánh: bắt PR, bắt check xanh, cấm force push |
| Required check | Job CI mà đỏ là chặn merge |
| gitleaks | Công cụ quét mật khẩu, token trong code và lịch sử git |
| Trivy / CVE | Công cụ quét lỗ hổng trong image / mã của một lỗ hổng đã công bố |
| ACR | Azure Container Registry, kho chứa image Docker |
| App Service / slot | Dịch vụ chạy web app của Azure / bản sao phụ của app, có địa chỉ riêng |
| Swap | Đổi chỗ staging và production |
| OIDC / JWT | Chuẩn chứng minh danh tính bằng token có chữ ký / định dạng của token đó |
| iss · aud · sub | Ai phát thẻ · thẻ phát cho ai dùng · thẻ nói về ai (repo + nhánh) |
| Federated credential | Luật trên Azure: "tin thẻ nào có đúng iss, aud, sub này" |
| Entra ID | Hệ thống quản lý danh tính của Microsoft (trước gọi là Azure AD) |
| Managed identity | Danh tính do Azure quản lý, không có mật khẩu |
| RBAC / role / scope | Phân quyền theo vai trò / tập quyền / phạm vi áp dụng |
| Key Vault reference | Cấu hình app trỏ tới secret trong Key Vault thay vì ghi mật khẩu thật |
| Terraform / state / lock | Công cụ viết hạ tầng bằng code / sổ ghi hạ tầng đang có / khoá sổ để hai người không sửa cùng lúc |
| Environment (GitHub) | Nhóm job deploy, giới hạn nhánh được vào, có thể gắn nút duyệt |

# Base image khai báo bằng ARG để CI/registry mirror thay được mà không sửa file.
# Ghim tag cụ thể, không bao giờ dùng :latest — build phải tái lập được.
# alpine thay vì -slim/-bookworm: ít package OS hơn nên bề mặt CVE nhỏ hơn hẳn,
# đo bằng Trivy ở D14. Next 16 cần Node >= 20; ghim 24 cho khớp CI (ci.yml).
# alpine3.23 chứ không phải 3.22: bản 3.22 còn openssl 3.5.6-r0 với 2 CVE HIGH
# (CVE-2026-14456, CVE-2026-45447) đã có bản vá ở 3.5.7/3.5.8 — đo ở D14.
ARG NODE_IMAGE=node:24-alpine3.23

# ---------- Stage 1: build ----------
FROM ${NODE_IMAGE} AS builder
WORKDIR /src

# Layer cài phụ thuộc riêng: sửa code không phải tải lại toàn bộ node_modules.
# `ci` chứ không phải `install` — cài đúng cây trong lock file, giống ci.yml.
COPY package.json package-lock.json ./
RUN npm ci

COPY . .
# next.config.ts đặt output: "standalone" → build ra .next/standalone chứa sẵn
# server.js và đúng những package thực sự dùng, không phải cả node_modules.
RUN npm run build

# ---------- Stage 2: runtime ----------
FROM ${NODE_IMAGE}
WORKDIR /app

ENV NODE_ENV=production
# Không còn bước dịch nào chạy nữa; tắt telemetry để container không gọi ra ngoài.
ENV NEXT_TELEMETRY_DISABLED=1

# Hai thứ standalone KHÔNG tự gom vào: static assets và public/ phải copy tay,
# thiếu là trang vẫn lên nhưng mất sạch CSS/ảnh — lỗi im lặng, build vẫn xanh.
COPY --from=builder /src/.next/standalone ./
COPY --from=builder /src/.next/static ./.next/static
COPY --from=builder /src/public ./public

# npm đi kèm image node nhưng runtime KHÔNG dùng: standalone chạy `node server.js`,
# không cài gì lúc chạy. Để lại thì image gánh nguyên cây phụ thuộc của npm —
# đo ở D14: 10 CVE (1 CRITICAL trong `tar`, 4 HIGH) đều nằm ở
# /usr/local/lib/node_modules/npm, không có cái nào của app. Xoá là hết, và đây
# là cách đúng: giảm thứ có trong image, không phải nới chính sách quét.
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx

# Image node có sẵn user "node" (uid 1000) — dùng lại thay vì tạo user mới.
USER node

# SHA của commit, truyền lúc build: docker build --build-arg GIT_SHA=<sha>.
# Khai ARG ở ĐÂY chứ không ở đầu file: ARG chỉ có hiệu lực trong stage khai nó,
# và giá trị này phải tới được stage RUNTIME (route /api/version đọc bằng
# process.env lúc chạy). Đặt ở stage builder là nó biến mất sau FROM thứ hai.
# Cố ý KHÔNG truyền vào stage builder: `next build` mà thấy env đổi là mất cache
# layer, trong khi SHA không ảnh hưởng gì tới output của bước dịch.
ARG GIT_SHA
ENV GIT_SHA=${GIT_SHA:-dev}

# server.js chỉ nghe loopback nếu không khai HOSTNAME; đặt 0.0.0.0 để App Service
# (WEBSITES_PORT) gọi được vào từ ngoài container.
ENV PORT=3000 HOSTNAME=0.0.0.0
EXPOSE 3000

# Dạng exec: node là PID 1, nhận thẳng SIGTERM từ docker stop và App Service.
CMD ["node", "server.js"]

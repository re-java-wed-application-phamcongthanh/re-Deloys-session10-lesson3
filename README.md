# Bài 3: Tối Ưu Hóa Dung Lượng Image & Layer Caching Với Multi-Stage Build

## 🎯 1. Mục Tiêu
- Áp dụng kỹ thuật **Multi-stage Build** để tách biệt hoàn toàn môi trường đóng gói/cài đặt (`builder`) khỏi môi trường vận hành (`runtime`).
- Tận dụng cơ chế **Layer Caching** của Docker để rút ngắn thời gian build khi mã nguồn thay đổi nhưng dependencies giữ nguyên.
- So sánh định lượng giữa Single-stage Image (`hw-backend:single`) và Multi-stage Image (`hw-backend:multistage`) về dung lượng, cấu trúc layer và tính bảo mật.

---

## 📁 2. Cấu Trúc Thư Mục
```text
bai3/
├── .dockerignore          # Danh sách loại trừ khi gửi context
├── Dockerfile             # Multi-stage Dockerfile tối ưu cho Production
├── Dockerfile.single      # Single-stage Dockerfile dùng để đối sánh
├── package.json           # Khai báo dependencies
├── server.js              # Mã nguồn Express API
└── README.md              # Báo cáo kỹ thuật và so sánh định lượng
```

---

## 🛠️ 3. So Sánh Thiết Kế Dockerfile

### 3.1. Single-stage (`Dockerfile.single`)
```dockerfile
FROM node:18-alpine
WORKDIR /app
ENV PORT=3000
COPY . .
RUN npm install
EXPOSE 3000
CMD ["node", "server.js"]
```
- **Hạn chế**:
  - Gộp tất cả source code và npm cache trong cùng image cuối cùng.
  - Layer `COPY . .` đứng trước `RUN npm install` khiến mỗi lần sửa file `.js`, Docker bị vô hiệu hóa cache và phải tải lại toàn bộ dependencies từ đầu.

---

### 3.2. Multi-stage Build (`Dockerfile`)
```dockerfile
# ==========================================
# Stage 1: Build & Dependencies (Builder)
# ==========================================
FROM node:18-alpine AS builder

WORKDIR /app

# Tối ưu Docker Layer Caching: Copy package.json trước
COPY package*.json ./

# Cài đặt sạch các production dependencies và xóa cache
RUN npm install --only=production && npm cache clean --force

# Sao chép mã nguồn ứng dụng
COPY . .

# ==========================================
# Stage 2: Production Runtime (Siêu nhẹ)
# ==========================================
FROM node:18-alpine

WORKDIR /app

ENV PORT=3000
ENV NODE_ENV=production

# Chỉ trích xuất các tệp thành phẩm cần thiết từ stage builder
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/server.js ./

EXPOSE 3000

# Khởi chạy ứng dụng dạng exec form
CMD ["node", "server.js"]
```

---

## 📊 4. Bảng So Sánh Chi Tiết: Single-Stage vs Multi-Stage

Dữ liệu đo đạc thực tế trên hệ thống máy trạm Docker Engine:

| Tiêu chí | Single-stage (`hw-backend:single`) | Multi-stage (`hw-backend:multistage`) | Ý nghĩa kỹ thuật |
| :--- | :--- | :--- | :--- |
| **Dung lượng Image (Disk)** | **196 MB** | **186 MB** | Tiết kiệm ~10MB dữ liệu rác (loại bỏ npm cache, logs, metadata thừa). |
| **Kích thước Compressed (Download)** | **47.4 MB** | **45.6 MB** | Rút ngắn băng thông truyền tải trên CI/CD Registry. |
| **Kích thước Layer `node_modules`** | **12.8 MB** (`RUN npm install`) | **4.67 MB** (`COPY --from=builder`) | **Giảm hơn 63.5%** dung lượng thư viện nhờ lọc `--only=production` và dọn `npm cache`. |
| **Hiệu quả Docker Layer Caching** | **Kém**: Sửa code làm vô hiệu cache cài đặt. | **Tối ưu**: Sửa file `server.js` chỉ mất **0.5s** build vì layer cài đặt npm được tái sử dụng 100% từ Cache. |
| **Mức độ an toàn bảo mật** | Chứa file thừa và tool build. | Chỉ chứa artifact chạy cần thiết, giảm thiểu bề mặt tấn công (attack surface). |

---

## 🚀 5. Quy Trình Kiểm Thử Thực Tế

### Bước 1: Build cả 2 phiên bản Image
```bash
# Build Single-stage
docker build -f Dockerfile.single -t hw-backend:single .

# Build Multi-stage
docker build -f Dockerfile -t hw-backend:multistage .
```

### Bước 2: Kiểm tra danh sách dung lượng Image
```bash
docker images | grep hw-backend
```
**Kết quả Terminal:**
```text
REPOSITORY              TAG          IMAGE ID       CREATED          SIZE
hw-backend              multistage   862548714dc6   15 seconds ago   186MB
hw-backend              single       942c9a2fa6ce   28 seconds ago   196MB
```

---

### Bước 3: Khởi chạy và kiểm tra phản hồi API từ Multi-stage Container
```bash
docker run -d --name app-multistage -p 8082:3000 hw-backend:multistage
curl -i http://localhost:8082/
```

**Kết quả phản hồi:**
```http
HTTP/1.1 200 OK
X-Powered-By: Express
Content-Type: application/json; charset=utf-8
Content-Length: 69
ETag: W/"45-wSM7ueZvT1Rne9IqS7BouFhu8Ow"
Date: Mon, 12 Oct 2026 06:06:54 GMT
Connection: keep-alive
Keep-Alive: timeout=5

{"status":"success","message":"Hello from Docker Multi-stage Build!"}
```
> ✅ **Xác nhận**: Container Multi-stage khởi động ngay lập tức, phản hồi đúng mã `200 OK` và chuỗi JSON mong muốn.

---

### Bước 4: Dọn dẹp container thử nghiệm
```bash
docker stop app-multistage && docker rm app-multistage
```

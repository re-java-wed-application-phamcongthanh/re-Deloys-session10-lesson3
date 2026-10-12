# ==========================================
# Stage 1: Build & Dependencies (Builder)
# ==========================================
FROM node:18-alpine AS builder

WORKDIR /app

# Copy tệp khai báo phụ thuộc trước để tối đa hóa Docker Layer Caching
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

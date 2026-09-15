# Multi-stage build for Angular app
# Builder stage: Node.js 18 LTS (pinned)
FROM node:18.20.0-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

# Production stage: Nginx 1.27 stable (pinned)
# Using older version intentionally for trivy vulnerability demonstration
FROM nginx:1.27-alpine

# Copy built app
COPY --from=builder /app/dist/defectdojo-poc-app /usr/share/nginx/html

# Copy nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
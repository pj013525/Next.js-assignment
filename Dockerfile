# Stage 1: builder (install all deps & build)
FROM node:20-alpine AS builder
WORKDIR /app

# Copy package files and install dependencies (dev + prod)
COPY package*.json ./
RUN npm ci --legacy-peer-deps

# Copy everything and build
COPY . .
RUN npx next build

# Stage 2: runtime (smaller, uses built output & node_modules from builder)
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production

# Copy package.json (useful for metadata) and node_modules from builder
COPY --from=builder /app/package.json ./
COPY --from=builder /app/node_modules ./node_modules

# Copy Next.js build output and app/public folders
COPY --from=builder /app/.next .next
COPY --from=builder /app/app ./app
COPY --from=builder /app/public ./public
COPY --from=builder /app/next.config.ts ./

EXPOSE 3000
# Start the Next.js production server
CMD ["npx", "next", "start", "-p", "3000"]

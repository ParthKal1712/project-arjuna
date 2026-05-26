FROM node:26-alpine AS base

FROM base AS builder

RUN apk add --no-cache gcompat
WORKDIR /app

# Copy package files first to leverage Docker cache
COPY package.json pnpm-lock.yaml ./
COPY tsconfig.json ./

# Node 26 does not include corepack by default, so we need to install it manually
RUN npm install -g corepack

# Install dependencies
RUN corepack enable && \
    corepack prepare pnpm@latest --activate && \
    pnpm install --frozen-lockfile --ignore-scripts

# Copy source files and build
COPY src/ ./src/
RUN pnpm run build && \
    pnpm prune --prod

FROM base AS runner
WORKDIR /app

# Create non-root user
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 hono

# Copy built files from builder
COPY --from=builder --chown=hono:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=hono:nodejs /app/dist ./dist
COPY --from=builder --chown=hono:nodejs /app/package.json ./package.json

USER hono
EXPOSE 3500

CMD ["node", "dist/index.js"]
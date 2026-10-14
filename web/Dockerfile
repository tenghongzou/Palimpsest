FROM node:22-alpine AS builder

RUN corepack enable && corepack prepare pnpm@12.4.1 --activate

WORKDIR /app

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile

COPY . .
RUN pnpm build

FROM node:22-alpine

WORKDIR /app

COPY --from=builder --chown=node:node /app/.output .output

ENV HOST=0.0.0.0
ENV PORT=3000
# Backend address for the BFF; set at runtime (API_BASE_URL only applies at build time).
ENV NUXT_API_BASE_URL=http://localhost:8080

USER node

EXPOSE 3000

CMD ["node", ".output/server/index.mjs"]

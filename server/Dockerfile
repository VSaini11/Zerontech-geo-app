FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production

# Install curl for healthcheck
RUN apk add --no-cache curl

COPY package*.json ./
RUN npm ci --omit=dev

COPY src ./src

# Default port
EXPOSE 9000

# Container healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD curl -fsS http://localhost:9000/api/health || exit 1

CMD ["node", "src/server.js"]

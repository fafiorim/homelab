FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy application files
COPY server.js ./
COPY public ./public

# Install TMAS (Trend Micro Artifact Scanner) for model security scanning
RUN apk add --no-cache bash curl gcompat && \
    curl -sL "https://cli.artifactscan.cloudone.trendmicro.com/tmas-cli/latest/tmas-cli_Linux_x86_64.tar.gz" -o /tmp/tmas.tar.gz && \
    tar -xzf /tmp/tmas.tar.gz -C /tmp && \
    mv /tmp/tmas /usr/local/bin/tmas && \
    chmod +x /usr/local/bin/tmas && \
    tmas version && \
    rm -rf /tmp/*

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Run as non-root user
USER node

# Start the server
CMD ["node", "server.js"]

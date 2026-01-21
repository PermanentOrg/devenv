FROM node:22-alpine

WORKDIR /app

# Install dependencies
COPY package.json ./
RUN npm install

COPY tsconfig.json ./
COPY bridge.ts ./

# Build TypeScript
RUN npm run build
COPY config.json ./dist/

CMD ["node", "dist/bridge.js"]

FROM node:20-alpine

WORKDIR /app

COPY package.json package-lock.json* ./

# Install dependencies separately so this layer is cached
RUN npm ci

# Copy application code last to maximize cache reuse
COPY . .

EXPOSE 4000

CMD ["npm", "run", "dev"]

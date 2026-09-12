# Use a lightweight, supported Node.js base image
FROM node:20-alpine

# Set the application working directory
WORKDIR /app

# Copy dependency manifests first to maximize Docker layer caching
COPY package.json package-lock.json ./

# Install exact dependencies from package-lock.json
RUN npm ci

# Copy application source after dependencies
COPY app.js ./
COPY public ./public
COPY src ./src

# Document the application port
EXPOSE 8080

# Start the Express application
CMD ["npm", "start"]
# Use a lightweight, supported Node.js image
FROM node:20-alpine

# Set the correct working directory
WORKDIR /app

# Copy dependency manifests first for better layer caching
COPY package*.json ./

# Install application dependencies
RUN npm install --omit=dev

# Copy application files
COPY app.js ./app.js
COPY src/ ./src/
COPY public/ ./public/

# The application listens on port 8080
EXPOSE 8080

# Start the Express application
CMD ["npm", "start"]

# Stage 1: Build the Frontend
FROM node:18-alpine AS frontend-builder
WORKDIR /web
COPY web/package.json web/package-lock.json ./
RUN npm install
COPY web/ ./
RUN npm run build-prod

# Stage 2: Build the Backend
FROM golang:1.18-alpine AS backend-builder
WORKDIR /src

# Install statik tool
RUN go install github.com/rakyll/statik@v0.1.7

# Copy Go module files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY server/ ./server/
COPY utils/ ./utils/
COPY modules/ ./modules/
COPY --from=frontend-builder /web/dist ./web/dist

# Generate embedded assets
# Note: The original script uses relative paths. Adjusted for Docker layout.
RUN statik -m -src=./web/dist -f -dest=./server/embed -p web -ns web

# Build the server binary
# -s -w removes debug info for smaller binary
# jsoniter tag is used in the original build script
RUN go build -ldflags "-s -w" -tags=jsoniter -o spark-server Spark/server

# Stage 3: Runtime
FROM alpine:latest
WORKDIR /app

# Install basic dependencies (optional, but good for debugging)
RUN apk add --no-cache ca-certificates tzdata

# Copy binary from builder
COPY --from=backend-builder /src/spark-server .

# Create directory for logs if needed (config defaults to ./logs)
RUN mkdir logs

# Expose the default port
EXPOSE 8000

# Run the server
CMD ["./spark-server"]

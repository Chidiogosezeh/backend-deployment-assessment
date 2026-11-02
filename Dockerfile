# ---------- Stage 1: build ----------
FROM golang:1.25-alpine AS builder
WORKDIR /src

# Copy dependency files first so Docker can cache the download step
COPY app/go.mod app/go.sum ./
RUN go mod download

# Copy the source code and build a small static binary
COPY app/ ./
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /out/api ./cmd/api

# ---------- Stage 2: final lean image ----------
FROM alpine:3.20
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app

# Only the compiled binary is copied from the build stage
COPY --from=builder /out/api /app/api

USER app
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/health || exit 1

CMD ["/app/api"]
FROM golang:1.27.1-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /out/server ./cmd/server \
 && CGO_ENABLED=0 GOOS=linux go build -o /out/seed ./cmd/seed

FROM alpine:3.19

RUN apk --no-cache add ca-certificates tzdata \
 && adduser -D -H -u 10001 palimpsest
WORKDIR /app
COPY --from=builder /out/server /out/seed ./
USER palimpsest

EXPOSE 8080

# The image also contains ./seed for loading sample data:
#   docker run --rm -e SEED_ADMIN_PASSWORD=... <image> ./seed
CMD ["./server"]

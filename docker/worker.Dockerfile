# Build stage
FROM golang:1.21-alpine AS builder

RUN apk add --no-cache ca-certificates

WORKDIR /src
COPY app/go.mod app/go.sum ./
RUN go mod download

COPY app/ .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /worker ./cmd/worker

# Runtime stage
FROM gcr.io/distroless/static:nonroot

COPY --from=builder /worker /worker

USER nonroot:nonroot

ENTRYPOINT ["/worker"]

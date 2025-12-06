ARG GO_VERSION=1.25.5
FROM golang:${GO_VERSION}-bookworm AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y \
    libtesseract-dev \
    libleptonica-dev \
    gcc \
    g++ \
    && apt-get clean

COPY go.mod go.sum ./
RUN go mod download

COPY . .

ENV CGO_ENABLED=1
ENV GOOS=linux
ENV GOARCH=arm64

RUN go build -o ocr-backend ./cmd/app

FROM debian:bookworm-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    tesseract-ocr \
    ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/ocr-backend ./ocr-backend
COPY --from=builder /app/configs ./configs

COPY tessdata/ /app/tessdata/

ENV TESSDATA_PREFIX=/app/tessdata/

EXPOSE 8100

ENTRYPOINT ["./ocr-backend"]

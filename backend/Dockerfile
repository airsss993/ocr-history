ARG GO_VERSION=1.25.5
FROM golang:${GO_VERSION}-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

ENV CGO_ENABLED=0

RUN go build -o ocr-backend ./cmd/app

FROM gcr.io/distroless/base-debian12

WORKDIR /app

COPY --from=builder /app/ocr-backend ./ocr-backend
COPY --from=builder /app/configs ./configs

EXPOSE 8100

ENTRYPOINT ["./ocr-backend"]

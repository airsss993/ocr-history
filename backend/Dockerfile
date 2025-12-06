ARG GO_VERSION=1.25.5
FROM golang:${GO_VERSION}-alpine AS builder

WORKDIR /app

RUN apk add --no-cache git

COPY go.mod go.sum ./
RUN go mod download

COPY . .

ENV CGO_ENABLED=0
ENV GOOS=linux
ENV GOARCH=amd64

RUN go build -o ocr-backend ./cmd/app

FROM gcr.io/distroless/base-debian12

WORKDIR /app

COPY --from=builder /app/configs ./configs
COPY --from=builder /app/ocr-backend ./ocr-backend

EXPOSE 8100

ENTRYPOINT ["./ocr-backend"]

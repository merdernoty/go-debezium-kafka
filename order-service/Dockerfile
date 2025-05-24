FROM golang:1.20-alpine

RUN apk add --no-cache git \
 && go install github.com/air-verse/air/cmd/air@latest

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

CMD ["air", "-c", ".air.toml"]

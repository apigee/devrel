FROM golang:alpine as app-builder

WORKDIR /go/src/app
COPY . .

RUN CGO_ENABLED=0 go build -o grpcgateway .

FROM scratch
COPY --from=app-builder /go/src/app/grpcgateway /gateway

ENTRYPOINT ["/gateway"]
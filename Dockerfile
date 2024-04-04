FROM golang:1.22.2-bookworm

WORKDIR /usr/local
RUN apt-get update &&\
    apt-get install -y wget firejail libsqlite3-dev &&\
    wget https://ziglang.org/download/0.11.0/zig-linux-x86_64-0.11.0.tar.xz &&\
    xz -dc zig-linux-x86_64-0.11.0.tar.xz | tar -x &&\
    rm zig-linux-x86_64-0.11.0.tar.xz &&\
    mv zig-linux-x86_64-0.11.0 zig

ENV PATH="/usr/local/zig:$PATH"
COPY . .
RUN go mod download
RUN go build -o app

CMD ["./app"]

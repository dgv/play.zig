FROM golang:1.22.2-bookworm

RUN touch /var/run/utmp
RUN apt-get update &&\
    apt-get install -y wget firejail

RUN useradd -ms /bin/bash playzig
WORKDIR /playzig/app
COPY . /playzig/app
RUN ARCH=$(uname -m) &&\
    wget https://ziglang.org/download/0.13.0/zig-linux-$ARCH-0.13.0.tar.xz &&\
    xz -dc zig-linux-$ARCH-0.13.0.tar.xz | tar -x -C /playzig/app &&\
    rm zig-linux-$ARCH-0.13.0.tar.xz &&\
    mv zig-linux-$ARCH-0.13.0 zig
RUN go mod download
RUN go build -buildvcs=false -o play-zig

ENV PATH="/playzig/app/zig:$PATH"

CMD ["./play-zig"]

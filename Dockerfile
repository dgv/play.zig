FROM golang:1.22.2-bookworm

RUN touch /var/run/utmp
RUN apt-get update &&\
    apt-get install -y wget firejail

WORKDIR /home/playzig/app
COPY . /home/playzig/app
RUN ARCH=$(uname -m) &&\
    wget https://ziglang.org/download/0.11.0/zig-linux-$ARCH-0.11.0.tar.xz &&\
    xz -dc zig-linux-$ARCH-0.11.0.tar.xz | tar -x -C /home/playzig/app &&\
    rm zig-linux-$ARCH-0.11.0.tar.xz &&\
    mv zig-linux-$ARCH-0.11.0 zig
ENV PATH="/home/playzig/app/zig:$PATH"
RUN go mod download
RUN go build -buildvcs=false -o play-zig

CMD ["./play-zig"]

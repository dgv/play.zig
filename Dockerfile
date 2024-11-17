FROM debian:bookworm-slim
RUN apt update &&\
    apt install -y wget firejail git
ENV WORKDIR="/playzig/app"
WORKDIR $WORKDIR
COPY . $WORKDIR
RUN ARCH=$(uname -m) &&\
    wget https://ziglang.org/download/0.13.0/zig-linux-$ARCH-0.13.0.tar.xz &&\
    tar -xf zig-linux-$ARCH-0.13.0.tar.xz &&\
    rm zig-linux-$ARCH-0.13.0.tar.xz &&\
    mv zig-linux-$ARCH-0.13.0 zig
ENV PATH="$WORKDIR/zig:$PATH"
ENV TMPDIR="/tmp"
ENV LD_LIBRARY_PATH=$WORKDIR
RUN git clone https://codeberg.org/ziglings/exercises/ ziglings
RUN zig build -p . --prefix-exe-dir .
CMD ["./play-zig"]

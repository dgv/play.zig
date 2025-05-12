FROM debian:bookworm-slim
RUN apt update &&\
    apt install -y wget firejail git gcc
ENV WORKDIR="/playzig/app"
WORKDIR $WORKDIR
COPY . $WORKDIR
ENV ZIG_VERSION="0.14.1"
RUN ARCH=$(uname -m) &&\
    wget https://ziglang.org/download/$ZIG_VERSION/zig-$ARCH-linux-$ZIG_VERSION.tar.xz &&\
    tar -xf zig-$ARCH-linux-$ZIG_VERSION.tar.xz &&\
    rm zig-$ARCH-linux-$ZIG_VERSION.tar.xz &&\
    mv zig-$ARCH-linux-$ZIG_VERSION zig &&\
    git clone https://github.com/ziglang/zig zig2 -b $ZIG_VERSION &&\
    cd zig2; sed -i "s/0.14.0-dev.bootstrap/${ZIG_VERSION}/g" bootstrap.c; cc -o bootstrap bootstrap.c; ./bootstrap; mv zig2 ../zig/; cd $WORKDIR; rm -rf zig2/
ENV PATH="$WORKDIR/zig:$PATH"
ENV TMPDIR="/tmp"
ENV LD_LIBRARY_PATH=$WORKDIR
RUN git clone https://codeberg.org/ziglings/exercises/ ziglings
RUN zig build -p . --prefix-exe-dir .
CMD ["./play-zig"]

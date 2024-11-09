FROM debian:bookworm-slim
RUN apt update &&\
    apt install -y wget xz-utils bubblewrap git
ARG USER=nonuser
RUN useradd -ms /bin/bash $USER
WORKDIR /home/$USER
COPY . /home/$USER
RUN ARCH=$(uname -m) &&\
    wget https://ziglang.org/download/0.13.0/zig-linux-$ARCH-0.13.0.tar.xz &&\
    tar -xf zig-linux-$ARCH-0.13.0.tar.xz &&\
    rm zig-linux-$ARCH-0.13.0.tar.xz &&\
    mv zig-linux-$ARCH-0.13.0 zig
ENV PATH="/home/$USER/zig:$PATH"
ENV LD_LIBRARY_PATH="/home/$USER"
RUN git clone https://codeberg.org/ziglings/exercises/ ziglings
RUN zig build -p . --prefix-exe-dir .
USER $USER
CMD ["./play-zig"]

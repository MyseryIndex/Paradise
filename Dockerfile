FROM --platform=linux/amd64 node:20 AS tgui
WORKDIR /tgui
COPY /tgui /tgui
RUN bin/tgui

FROM bitnami/dotnet AS dme
WORKDIR /server
COPY . /server
RUN curl -O -L https://github.com/OpenDreamProject/OpenDream/releases/download/latest/DMCompiler_linux-x64.tar.gz && \
	tar -xf DMCompiler_linux-x64.tar.gz
RUN dotnet DMCompiler_linux-x64/DMCompiler.dll --suppress-unimplemented --version=516.1666 paradise.dme

FROM ubuntu:latest AS byond
RUN apt-get update && apt-get install -y \
	curl \
	unzip \
	make \
	&& rm -rf /var/lib/apt/lists/*
ENV TARGET_MAJOR="516" \
	TARGET_MINOR="1666"
WORKDIR /byond
RUN curl "http://www.byond.com/download/build/${TARGET_MAJOR}/${TARGET_MAJOR}.${TARGET_MINOR}_byond_linux.zip" -o byond.zip && \
	unzip byond.zip && \
	mv byond/* . && \
	rmdir byond && \
	rm byond.zip
RUN make here && \
	echo "$TARGET_MAJOR.$TARGET_MINOR" > "version.txt"

FROM rust:latest AS rust-builder
WORKDIR /rust
COPY /rust /rust
RUN rustup target add i686-unknown-linux-gnu
RUN apt-get update && apt-get install -y gcc-multilib clang libclang-dev
RUN cargo build --release --target i686-unknown-linux-gnu

FROM ubuntu:latest AS rustg-downloader
WORKDIR /libs
RUN apt-get update && apt-get install -y curl
RUN curl -L -o librust_g.so "https://github.com/ParadiseSS13/rust-g/releases/download/v3.4.0-P/librust_g.so"

FROM --platform=linux/amd64 bitnami/dotnet
WORKDIR /server
COPY --from=dme /server /server
COPY --from=tgui /tgui/public /server/tgui/public
COPY --from=rust-builder /rust/target/i686-unknown-linux-gnu/release/librustlibs.so /server/
COPY --from=rustg-downloader /libs/librust_g.so /server/
RUN curl -O -L https://github.com/OpenDreamProject/OpenDream/releases/download/latest/OpenDreamServer_linux-x64.tar.gz && \
	tar -xf OpenDreamServer_linux-x64.tar.gz
RUN mkdir -p config && cp config/example/config.toml config/config.toml

ENTRYPOINT ["OpenDreamServer_linux-x64/Robust.Server", "/server/paradise.json"]

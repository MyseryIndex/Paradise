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

FROM --platform=linux/amd64 bitnami/dotnet
WORKDIR /server
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y libc6:i386 libgcc-s1:i386 libstdc++6:i386 curl && \
    rm -rf /var/lib/apt/lists/*
COPY --from=dme /server /server
COPY --from=tgui /tgui/public /server/tgui/public
RUN curl -L -o librust_g.so "https://github.com/ParadiseSS13/rust-g/releases/download/v3.4.0-P/librust_g.so"
COPY tools/ci/librustlibs_ci.so /server/librustlibs.so
RUN curl -O -L https://github.com/OpenDreamProject/OpenDream/releases/download/latest/OpenDreamServer_linux-x64.tar.gz && \
	tar -xf OpenDreamServer_linux-x64.tar.gz
RUN mkdir -p config && cp config/example/config.toml config/config.toml

ENTRYPOINT ["OpenDreamServer_linux-x64/Robust.Server", "/server/paradise.json"]

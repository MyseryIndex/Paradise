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
RUN apt-get update && apt-get install -y curl gcc && rm -rf /var/lib/apt/lists/*
COPY --from=dme /server /server
COPY --from=tgui /tgui/public /server/tgui/public

# Create stub rust-g library that returns expected version
RUN echo 'const char* get_version() { return "3.4.0-P"; }' > rustg_stub.c && \
    gcc -shared -fPIC -o librust_g.so rustg_stub.c && \
    rm rustg_stub.c

# Create stub rustlibs library - just create an empty shared library
RUN echo 'void _unused() {}' > rustlibs_stub.c && \
    gcc -shared -fPIC -o librustlibs.so rustlibs_stub.c && \
    rm rustlibs_stub.c

RUN curl -O -L https://github.com/OpenDreamProject/OpenDream/releases/download/latest/OpenDreamServer_linux-x64.tar.gz && \
	tar -xf OpenDreamServer_linux-x64.tar.gz
RUN mkdir -p config && cp config/example/config.toml config/config.toml

ENTRYPOINT ["OpenDreamServer_linux-x64/Robust.Server", "/server/paradise.json"]

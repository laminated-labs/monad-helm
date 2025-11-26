FROM ubuntu:24.04

# Matches chart appVersion without the leading v (workflow strips it when building)
ARG VERSION=0.12.2

# aria2, rsync, zstd are used by monad init scripts
RUN apt update && apt install -yqq ca-certificates gnupg2 curl aria2 rsync zstd

RUN cat <<EOF > /etc/apt/sources.list.d/category-labs.sources
Types: deb
URIs: https://pkg.category.xyz/
Suites: noble
Components: main
Signed-By: /etc/apt/keyrings/category-labs.gpg
EOF

RUN cat <<EOF > /etc/apt/auth.conf.d/category-labs.conf
machine https://pkg.category.xyz/
login pkgs
password af078cc4157b45f29e279879840fd260
EOF

RUN curl -fsSL https://pkg.category.xyz/keys/public-key.asc | gpg --dearmor -o /etc/apt/keyrings/category-labs.gpg

# Enter in 1 Y to confirm with the install that hyperthreading is fine as we build on VMs but run elsewhere
RUN apt update && printf 'y\n' | apt install -yqq monad=${VERSION}

RUN rm -rf /var/cache/apk/* \
  && rm -rf /var/lib/apt/lists/* \
  && apt autoremove -y && apt clean

ENV RUST_LOG=info
ENV RUST_BACKTRACE=1

FROM node:20 AS node-base

FROM eclipse-temurin:17-jdk-noble

ARG TZ=Europe/London
ARG CLAUDE_CODE_VERSION=latest
ARG GIT_DELTA_VERSION=0.18.2
ARG ZSH_IN_DOCKER_VERSION=1.2.0
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

ENV TZ=${TZ}
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    git-lfs \
    curl \
    wget \
    sudo \
    vim \
    nano \
    zsh \
    jq \
    unzip \
    less \
    iptables \
    ipset \
    dnsutils \
    net-tools \
    ca-certificates \
    gnupg \
    openssh-client \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

# Copy Node.js from the node base image
COPY --from=node-base /usr/local/bin/node /usr/local/bin/node
COPY --from=node-base /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=node-base /usr/local/bin/npm /usr/local/bin/npm
COPY --from=node-base /usr/local/bin/npx /usr/local/bin/npx
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# Create non-root user (handle pre-existing GID/UID in base image)
RUN groupadd --gid $USER_GID $USERNAME 2>/dev/null || groupmod -n $USERNAME $(getent group $USER_GID | cut -d: -f1) \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /bin/zsh $USERNAME 2>/dev/null \
       || (usermod -l $USERNAME -d /home/$USERNAME -m $(getent passwd $USER_UID | cut -d: -f1) && usermod -s /bin/zsh $USERNAME) \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Install git-delta for better diffs
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then DELTA_ARCH="aarch64"; else DELTA_ARCH="x86_64"; fi && \
    curl -fsSL "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/delta-${GIT_DELTA_VERSION}-${DELTA_ARCH}-unknown-linux-gnu.tar.gz" \
    | tar -xz -C /tmp && \
    mv "/tmp/delta-${GIT_DELTA_VERSION}-${DELTA_ARCH}-unknown-linux-gnu/delta" /usr/local/bin/delta && \
    rm -rf /tmp/delta-*

# Install fzf
RUN git clone --depth 1 https://github.com/junegunn/fzf.git /home/$USERNAME/.fzf && \
    chown -R $USERNAME:$USERNAME /home/$USERNAME/.fzf && \
    su - $USERNAME -c '/home/$USERNAME/.fzf/install --all --no-update-rc'

# Install zsh-in-docker for a nice shell experience
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)" -- \
    -t robbyrussell \
    -p git \
    -p gradle \
    -p fzf

# Set up persistent command history
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
    && mkdir -p /commandhistory \
    && touch /commandhistory/.bash_history \
    && chown -R $USERNAME:$USERNAME /commandhistory \
    && echo "$SNIPPET" >> /home/$USERNAME/.bashrc \
    && echo "$SNIPPET" >> /home/$USERNAME/.zshrc

# Create workspace and claude config directories
RUN mkdir -p /workspace /home/$USERNAME/.claude /home/$USERNAME/.gradle /home/$USERNAME/.m2 \
    && chown -R $USERNAME:$USERNAME /workspace /home/$USERNAME/.claude /home/$USERNAME/.gradle /home/$USERNAME/.m2

# Install Claude Code CLI, WireMock CLI and Arazzo runner
RUN npm install -g \
    @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} \
    @wiremock/cli \
    @wiremock/arazzo-runner

# Set up firewall script
COPY init-firewall.sh /usr/local/bin/init-firewall.sh
RUN chmod +x /usr/local/bin/init-firewall.sh \
    && echo "$USERNAME ALL=(ALL) NOPASSWD: /usr/local/bin/init-firewall.sh" >> /etc/sudoers.d/$USERNAME

# Set default editors
ENV EDITOR=nano
ENV VISUAL=nano

USER $USERNAME
WORKDIR /workspace

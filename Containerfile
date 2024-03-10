ARG SOURCE_IMAGE="${SOURCE_IMAGE:-silverblue}"
ARG SOURCE_ORG="${SOURCE_ORG:-fedora-ostree-desktops}"
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-39}"
ARG BASE_IMAGE="quay.io/${SOURCE_ORG}/${SOURCE_IMAGE}"
ARG BASE_TAG="${BASE_TAG:-39}"

FROM ${BASE_IMAGE}:${BASE_TAG}

# Remove things I don't want from the base system
RUN rpm-ostree override remove \
	firefox \
	firefox-langpacks \
	gnome-tour \
	power-profiles-daemon

# Packages I want to install on the base system
RUN rpm-ostree install \
	bash-color-prompt \
	bat \
	gcc \
	git-delta \
        git-credential-libsecret \
	gnome-shell-extension-appindicator \
	gnome-shell-extension-blur-my-shell \
	gnome-shell-extension-dash-to-dock \
	gnome-tweaks \
	jetbrains-mono-fonts-all \
	make \
	mesa-libGLU \
	neovim \
	podman-compose \
	podman-plugins \
	podmansh \
	podman-tui \
	powerline-fonts \
	powertop \
	pulseaudio-utils \
	qemu \
	qemu-char-spice \
	qemu-device-display-virtio-gpu \
	qemu-device-display-virtio-vga \
	qemu-device-usb-redirect \
	qemu-img \
	qemu-system-x86-core \
	qemu-user-binfmt \
	qemu-user-static \
	restic \
	tmux \
	tuned \
	tuned-gtk \
	tuned-ppd \
	tuned-profiles-atomic \
	tuned-utils \
	virt-manager \
	virt-viewer \
	wireguard-tools \
	wl-clipboard \ 
	xprop 

# Setup trust for this repo
COPY cosign.pub /usr/etc/pki/containers/pepelepew-os.pub
COPY files/ /

# Setup 1password
COPY 1password/1password.repo /etc/yum.repos.d/1password.repo
COPY 1password/1password.asc /etc/pki/rpm-gpg/1password.asc

# Install tailscale
COPY tailscale/tailscale.repo /etc/yum.repos.d/tailscale.repo
COPY tailscale/tailscale.asc /etc/pki/rpm-gpg/tailscale.asc
RUN rpm-ostree install --disablerepo='*' --enablerepo='tailscale-stable' \
	tailscale && \
	systemctl enable tailscaled 

# Setup Flathub
COPY flathub/flathub.flatpakrepo /etc/flatpak/remotes.d/flathub.flatpakrepo

# Setup services
RUN systemctl enable tuned.service && \
	systemctl enable rpm-ostreed-automatic.timer 

# Clean up repos, everything is on the image so we don't need them
RUN rm -rf /tmp/* /var/* && \
    ostree container commit


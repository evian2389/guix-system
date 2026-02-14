# Makefile for Guix Configurations

GUIX_PROFILE ?= "/var/guix/profiles/system" # Default for system-level operations
GUIX_HOME_PROFILE ?= "$(HOME)/.guix-profile" # Default for user-level home operations

# Path to our config directory (relative to Makefile)
CONFIG_DIR := $(CURDIR)/config

# Default system and user for initial setup (can be overridden)
DEFAULT_SYSTEM ?= ser8
DEFAULT_USER ?= orka

.PHONY: all init install-system reconfigure-system reconfigure-home install-user-packages channel-update guix-pull clean

all: reconfigure-system reconfigure-home

init: guix-pull channel-update
	@echo "Initialization complete. Run 'make install-system' for a fresh install, or 'make all' to reconfigure an existing system."

install-system: guix-pull channel-update
	@echo "Installing Guix System to /mnt for $(DEFAULT_SYSTEM)..."
	sudo guix system init --channels=channels/channels-lock.scm $(CONFIG_DIR)/systems/$(DEFAULT_SYSTEM)/configuration.scm /mnt

reconfigure-system:
	@echo "Reconfiguring Guix System for $(DEFAULT_SYSTEM)..."
	sudo guix system reconfigure --channels=channels/channels-lock.scm $(CONFIG_DIR)/systems/$(DEFAULT_SYSTEM)/configuration.scm

reconfigure-home:
	@echo "Reconfiguring Guix Home for $(DEFAULT_USER)..."
	guix home reconfigure --channels=channels/channels-lock.scm -L $(CONFIG_DIR)/home-services -L $(CONFIG_DIR)/util -L $(CONFIG_DIR)/packages $(CONFIG_DIR)/users/$(DEFAULT_USER)/home.scm
	$(MAKE) install-user-packages

install-user-packages:
	@echo "Installing extra packages for user $(DEFAULT_USER)..."
	guix package -p $(HOME)/.guix-profiles/$(DEFAULT_USER)-extra -f $(CONFIG_DIR)/users/$(DEFAULT_USER)/manifest.scm

channel-update:
	@echo "Updating channels/channels-lock.scm with current pinned channels..."
	guix describe --format=channels > channels/channels-lock.scm
	@echo "channels/channels-lock.scm updated."

guix-pull:
	@echo "Running guix pull with channel definitions from channels/channels.scm..."
	guix pull --channels=channels/channels.scm
	@echo "guix pull complete."

clean:
	@echo "Cleaning up generated files..."
	rm -f channels/channels-lock.scm
	@echo "Clean complete."

# Helper for loading modules (for `guix lint`, `guix edit`, etc.)
# Usage: make -C config/modules GUILD_PATH_DIR=$(PWD)
# export GUILD_PATH=$$GUILD_PATH:$(abspath config/modules)
# Example: guix lint --load-path=$(CONFIG_DIR)/modules $(CONFIG_DIR)/users/$(DEFAULT_USER)/home.scm
# guix lint -L $(CONFIG_DIR)/modules $(CONFIG_DIR)/users/$(DEFAULT_USER)/home.scm

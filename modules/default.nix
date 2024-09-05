{config,lib,pkgs,...}: {
  options.remote_decryptor = with lib; with types; {
    listen = {
      address = mkOption {
        type = str;
        description = "ip the sshd (optionally behind wireguard) shall be reachable under";
        example = "1.2.3.4";
      };
      gateway = mkOption {
        type = nullOr str;
        description = "gateway the sshd/wireguard uses to connect to the internet (null if none is needed)";
        example = "192.168.0.1";
      };
      subnetMask = mkOption {
        type = str;
        example = "255.255.255.0";
      };
      interface = mkOption {
        # TODO interpret null properly and make it the default
        description = "interface the sshd/wireguard uses to connect to the internet (null for any)";
        example = "enp0s25";
        type = str;
      };
    };
    wireguard = {
      enable = mkOption {
        type = bool;
        default = true;
      };
      interface = mkOption {
        description = "wireguard interface name";
        default = "wg0";
        example = "wg-dallas0";
      };
      privateKey = mkOption {
        type = str;
        example = "/etc/wireguard/wg0-initrd.priv";
      };
      listener = mkOption {
        # TODO also allow specifiying on which interface to listen
        # and maybe v6 foo
        description = "wireguard listener configuration";
        type = types.submodule {
          options = {
            port = mkOption {
              type = port;
              example = 5555;
            };
          };
        };
        default = {
          port = 5555;
        };
      };
      tunnel = {
        local = mkOption {
          description = "wireguard tunnel configuration";
          type = types.submodule {
            options = {
              ip = mkOption {
                type = str;
              };
              mask = mkOption {
                type = int;
                example = 24;
              };
            };
          };
        };

        peers = mkOption {
          description = "peers that login via wireguard to decrypt";
          type = nonEmptyListOf (types.submodule {
            options = {
              address = mkOption {
                type = str;
                default = "10.0.0.5";
              };
              pubkey = mkOption {
                type = str;
                example = "wuIjYUxGXF/KnQN4OkEVLIjeO7fL0ncB9NMxtAWFKGg=";
              };
            };
          });
        };
      };
    };
    ssh = {
      # TODO allow paths too
      authorizedKeys = mkOption {
        type = nonEmptyListOf str;
      };
      # don't allow paths because that would mean
      # copy to the nix store which we want to avoid
      # if the user yet wants to do that hed prolly look
      # in here either way and see this notice
      hostKeys = mkOption {
        type = nonEmptyListOf str;
      };
    };
  };
  config = with config.remote_decryptor; {
    # V maybe move to doing this via "ip addr add" instead
    # to support more complex configurations
    boot.kernelParams = with listen; [
      ''ip=${address}::${lib.strings.optionalString (gateway != null) gateway}:${subnetMask}::${interface}''
      # TODO remove
      "boot.trace"
      "boot.debug1"
    ];

    # TODO do we need to explicitly
    # specify these here still?
    boot.initrd = {
      supportedFilesystems = [
        "ext4"
        "btrfs" # chose btrfs over zfs, was this wise?
        "vfat"
      ];

      # scp is needed for the server to accept scp file transfer of the header (its a serverside requirement too)
      # gpg TODO
      # kexec generally useful and worst case we can deny having an encrpyted drive and claim it the server was
      # running on a ramdisk
      # TODO reject icmp so were fully invisible on wg

      # TODO gnupg false by default other, scp and kexec true by default
      extraUtilsCommands = with lib.strings; ''
        ${optionalString wireguard.enable "copy_bin_and_libs ${pkgs.wireguard-tools}/bin/.wg-wrapped"}
        copy_bin_and_libs ${pkgs.kexec-tools}/bin/kexec
        copy_bin_and_libs ${pkgs.gnupg}/bin/gpg
        copy_bin_and_libs ${pkgs.openssh}/bin/scp
      '';

      luks = {
        # as we don't define a luks drive but instead manually mount it and supply the
        # header via scp we need to tell nix that despite not defining a luks drive
        # we still want to have cryptsetup present and stuff
        forceLuksSupportInInitrd = true;
      };

      kernelModules = [ 
        "e1000" # TODO don't hardcode (qemu)
        "e1000e" # leaseweb

        # system-x / iceland dell
        "tg3" # TODO what is this even

        # iceland dell (higher perf interface)
        # TODO don't hardcode
        "mlx5_core"

        # TODO make it optional to spawn a shell 
        # and thus only load these drivers if we want a shell
        # instead of purely network driven unlocking
        "usbhid" 
      ] ++ 
      # for hiding sshd behind wg
      (lib.lists.optional wireguard.enable "wireguard");

      # TODO remove unneeded to reduce attack sufrace 
      availableKernelModules = [
        "ata_piix"
        "floppy"
        "xhci_pci"
        "ehci_pci"
        "ahci"
        "usbhid"
        "usb_storage"
        "sd_mod"
        "sr_mod"
        "sdhci_pci"
        "mpt3sas"
      ];

      # TODO nftables filter icmp to be fully invisible until we accepted traffic on wg
      network = {
        enable = true;

        # we provide the ip via the ip= statement
        # TODO maybe don't even do that but hardcode them in ip a add statements
        # TODO V maybe allow the user to explicitly resort to dhcp based
        # networking (dosen't seem to work in iceland location)
        udhcpc.enable = false;

        postCommands = with wireguard; lib.strings.optionalString wireguard.enable ''
          ${pkgs.iproute2}/bin/ip link add dev ${wireguard.interface} type wireguard
          ${pkgs.iproute2}/bin/ip addr add ${tunnel.local.ip}/${toString tunnel.local.mask} dev ${wireguard.interface}
          ${pkgs.iproute2}/bin/ip link set dev ${wireguard.interface} up

          ln -s /bin/.wg-wrapped /bin/wg

          wg set ${wireguard.interface} private-key ${wireguard.privateKey} listen-port ${toString wireguard.listener.port}
        '' + (lib.strings.concatLines (lib.lists.forEach tunnel.peers
        (peer: "wg set ${wireguard.interface} peer ${peer.pubkey} allowed-ips ${peer.address}/32")));


        ssh = {
          enable = true;
          inherit (ssh) authorizedKeys hostKeys;

          # erros if hostKeys isn't provided as
          # boot.initrd.network.ssh.ignoreEmptyHostKeys

          # bind sshd only to wg's ip to not expose it
          # (TODO also configure ip/nftables to not respond to pings
          # in stealth mode)
          #extraConfig = lib.strings.optionalString wireguard.enable ''
          #  ListenAddress ${wireguard.tunnel.local.ip}
          #'';
          extraConfig = lib.strings.optionalString wireguard.enable ''
            ListenAddress 0.0.0.0
          '';
        };
      };

      # prevents the initrd from failing due to not finding /dev/mapper/root, at least until
      # we echo sth > /tmp/continue , but we just make sure /dev/mapper/root exists before
      # we echo something in there
      postDeviceCommands = ''
        mkfifo /tmp/continue
        cat /tmp/continue
      '';

      secrets = {
        # null copies from ${wireguard.privateKey} on the main system
        ${wireguard.privateKey} = null;
      };
    };
    /*
    assertions = [
      {
        assertion = config.boot.initrd.network.authorizedKeys == [];
        message = "no authorized keys specified to provide to the initrd sshd";
      }
    ];
    */
  };

}


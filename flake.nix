{

  outputs = {self}: {
    nixosModules.default = ./modules;
    # V example ( TODO move to readme )
    /*nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./modules/default.nix
        {
          remote_decryptor = {
            listen = {
              address = "1.2.3.4";
              gateway = null;
              subnetMask = "255.255.255.0";
              interface = "eth0";
            };
            wireguard = {
              enable = true;
              tunnel = {
                local = {
                  mask = 31;
                  ip = "10.0.0.4";
                };
                peers = [
                  {
                    address = "10.0.0.5";
                    pubkey = "wuIjYUxGXF/KnQN4OkEVLIjeO7fL0ncB9NMxtAWFKGg=";
                  }
                ];
              };
              privateKey = "/etc/wireguard/wg0-initrd.priv";
            };
            ssh = {
              authorizedKeys = [
                "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCYdEdmbD/hFDNhv1kBSQhfsIpb8jOQwiIGzfJkCjBchDs3uvsYYDj8imUThrSr4zn/P5/dcSuMFvFlx/CcCWx5/KMNxgArXb6PzYzRKfyzKtsKjZtQIaO4c/7fm9BzO9HuWFZzd3FCxqKbBUxYRMWDV8catvIDxD50Se5hPrTd7vQPFpKVf7MmLnLpNcn894WTSN86U5pZkXDrDxOWyv+lhbPzPgyXnQTWWTUlA9p4bU3tSi5iQBiH36voIbKckOIB2+m2dLBbNFs5B6d0SJDpH/xFCN/xqmpinGCNoRLqk0bKnfW4vKBVJ2h0YC0MJA9q+FjmAwCxC10azHNk8MFU2QlOawWp6gRimdmKcHc4DOcqt3ldeHOVORELy01Yy+FU0aOLHBaepSh8eB0GVjFHna4dexJ/rEzOa3ibYUSAcPN35wE0DsjZ981UjlouDl/isCm7nhqxg1j6Yt17rwySGnC8rswtMJ6qYAosrnIDV8rSOJuGArFk6635mHcCfzM= flandre@nixos"
              ];
              hostKeys = [
                  "/etc/secrets/initrd/ssh_host_rsa_key"
                  "/etc/secrets/initrd/ssh_host_ed25519_key"
              ];
            };
          };
        }
      ];
    };
    */
  };
}

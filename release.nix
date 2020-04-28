############################################################################
#
# Hydra release jobset.
#
# The purpose of this file is to select jobs defined in default.nix and map
# them to all supported build platforms.
#
############################################################################

# The project sources
{ cardano-db-sync ? { outPath = ./.; rev = "abcdef"; }

# Function arguments to pass to the project
, projectArgs ? {
    config = { allowUnfree = false; inHydra = true; };
    gitrev = cardano-db-sync.rev;
  }

# The systems that the jobset will be built for.
, supportedSystems ? [ "x86_64-linux" "x86_64-darwin" ]

# The systems used for cross-compiling
, supportedCrossSystems ? [ "x86_64-linux" ]

# A Hydra option
, scrubJobs ? true

# Dependencies overrides
, sourcesOverride ? {}

# Import pkgs, including IOHK common nix lib
, pkgs ? import ./nix { inherit sourcesOverride; }

}:

with (import pkgs.iohkNix.release-lib) {
  inherit pkgs;
  inherit supportedSystems supportedCrossSystems scrubJobs projectArgs;
  packageSet = import cardano-db-sync;
  gitrev = cardano-db-sync.rev;
};

with pkgs.lib;

let
  nixosTests = (import ./. {}).nixosTests;
  getArchDefault = system: let
    table = {
      x86_64-linux = import ./. { system = "x86_64-linux"; };
      x86_64-darwin = import ./. { system = "x86_64-darwin"; };
      x86_64-windows = import ./. { system = "x86_64-linux"; crossSystem = "x86_64-windows"; };
    };
  in table.${system};
  default = getArchDefault builtins.currentSystem;
  makeScripts = cluster: let
    getScript = name: {
      x86_64-linux = (getArchDefault "x86_64-linux").scripts.${cluster}.${name};
      x86_64-darwin = (getArchDefault "x86_64-darwin").scripts.${cluster}.${name};
    };
  in {
    node = getScript "node";
  };
  wrapDockerImage = cluster: let
    images = (getArchDefault "x86_64-linux").dockerImage;
    wrapImage = image: pkgs.runCommand "${image.name}-hydra" {} ''
      mkdir -pv $out/nix-support/
      cat <<EOF > $out/nix-support/hydra-build-products
      file dockerimage-${image.name} ${image}
      EOF
    '';
  in {
    node = wrapImage images.${cluster};
  };
  makeRelease = cluster: {
    name = cluster;
    value = {
      scripts = makeScripts cluster;
      dockerImage = wrapDockerImage cluster;
    };
  };
  extraBuilds = let
    # only build nixos tests for linux
    default = getArchDefault "x86_64-linux";
  in {
    inherit nixosTests;
  } // (builtins.listToAttrs (map makeRelease [
    "mainnet"
    "staging"
    "shelley_staging_short"
    "shelley_staging"
    "testnet"
  ]));

  testsSupportedSystems = [ "x86_64-linux" ];
  # Recurse through an attrset, returning all test derivations in a list.
  collectTests' = ds: filter (d: elem d.system testsSupportedSystems) (collect isDerivation ds);
  # Adds the package name to the test derivations for windows-testing-bundle.nix
  # (passthru.identifier.name does not survive mapTestOn)
  collectTests = ds: concatLists (
    mapAttrsToList (packageName: package:
      map (drv: drv // { inherit packageName; }) (collectTests' package)
    ) ds);

  inherit (systems.examples) mingwW64 musl64;

  jobs = {
    native = mapTestOn (__trace (__toJSON (packagePlatforms project)) (packagePlatforms project));
  } // (mkRequiredJob (
      collectTests jobs.native.checks ++
      collectTests jobs.native.benchmarks ++ [
      jobs.native.cardano-db-sync.x86_64-linux
      jobs.native.cardano-db-sync-extended.x86_64-linux
    ]));

in jobs

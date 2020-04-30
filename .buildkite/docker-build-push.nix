# This script will load nix-built docker image of latest-docker-dev applications
# into the Docker daemon (must be running), and then push to the Docker Hub.
# Credentials for the hub must already be installed with # "docker login".
#
# There is a little bit of bash logic to replace the default repo and
# tag from the nix-build (../nix/docker.nix).
#
# 1. The repo (default "inputoutput/latest-docker-dev") is changed to match
#    the logged in Docker user's credentials.
#
# 2. The tag (default "VERSION") is changed to reflect the
#    branch which is being built under this Buildkite pipeline.
#
#    - If this is a git tag build (i.e. release) then the docker tag
#      is left as-is.
#    - If this is a master branch build, then VERSION is replaced with
#      the git revision.
#    - Anything else is not tagged and not pushed.
#
# 3. After pushing the image to the repo, the "latest" tag is updated.
#
#    - "inputoutput/latest-docker-dev:latest" should point to the most VERSOIN
#      tag build.
#

{ dbSyncPackages ?  import ../. {}

# Build system's Nixpkgs. We use this so that we have the same docker
# version as the docker daemon.
, hostPkgs ? import <nixpkgs> {}

# Dockerhub repository for image tagging.
, dockerHubRepoName ? null
}:

with hostPkgs;
with hostPkgs.lib;

let
  image = impureCreated dbSyncPackages.dockerImage;

  # Override Docker image, setting its creation date to the current time rather than the unix epoch.
  impureCreated = image: image.overrideAttrs (oldAttrs: { created = "now"; }) // { inherit (image) version; };

in
  writeScript "docker-build-push" (''
    #!${runtimeShell}

    set -euo pipefail

    export PATH=${lib.makeBinPath [ docker gnused ]}

    ${if dockerHubRepoName == null then ''
    reponame=latest-docker-dev
    username="$(docker info | sed '/Username:/!d;s/.* //')"
    fullrepo="$username/$reponame"
    '' else ''
    fullrepo="${dockerHubRepoName}"
    ''}

  '' + concatMapStringsSep "\n" (image: ''
    branch="''${BUILDKITE_BRANCH:-}"
    event="''${GITHUB_EVENT_NAME:-}"

    gitrev="${image.imageTag}"

    ### HACK ###
    fullrepo="craigem/latest-docker-dev"
    ### HACK ###

    echo "Loading $fullrepo:$gitrev"
    docker load -i ${image}

    # Every commit gets a container with rev on end
    echo "Pushing $fullrepo:$gitrev"
    docker push "$fullrepo:$gitrev"

    # If there is a release, it needs to be tagged with the release
    # version (e.g. "v0.0.28") AND the "latest" tag
    if [[ "$event" = release ]]; then
      ref="''${GITHUB_REF:-}"
      version="$(echo $ref | sed -e 's/refs\/tags\///')"

      echo "Tagging with a version number: $fullrepo:$version"
      docker tag $fullrepo:$gitrev $fullrepo:$version
      echo "Pushing $fullrepo:$version"
      docker push "$fullrepo:$version"

      echo "Tagging as latest"
      docker tag $fullrepo:$version $fullrepo:latest
      echo "Pushing $fullrepo:latest"
      docker push "$fullrepo:latest"
    fi

    # Every commit to master needs to be tagged with master
    if [[ "$branch" = master ]]; then
      echo "Tagging as master"
      docker tag $fullrepo:$gitrev $fullrepo:$branch
      echo "Pushing $fullrepo:$branch"
      docker push "$fullrepo:$branch"
    fi

    echo "Cleaning up with docker system prune"
    docker system prune -f
  '') [ image ] )

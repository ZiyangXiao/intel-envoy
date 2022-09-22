#! /bin/bash

# Usage:
# ./.github/workflows/build.sh 

# this script will modified upper directory istio-proxy repo
# if self-used should attention that whether the upper directory have its own developing istio-proxy
#first build should give permission to docker volumes
#sudo chmod -R 777 /var/lib/docker/volumes 

branch_name=${branch_name:-"release-1.15-intel"}
cd ..
if [ ! -d "istio-proxy" ];
then
    git clone -b ${branch_name} https://github.com/intel/istio-proxy.git
else
    pushd istio-proxy
    git clean -fdx
    git fetch origin
    git reset --hard origin/${branch_name} 
    popd
fi
# To maintain build repo is latest
# should modified when pr to intel/envoy
cp -rf intel-envoy/ istio-proxy/ 
cd istio-proxy
if [ ! -d "istio" ];
then
    git clone -b ${branch_name} https://github.com/intel/istio.git
else
    pushd istio
    git clean -fdx
    git fetch origin
    git reset --hard origin/${branch_name} 
    popd
fi

# Replace upstream envoy with local envoy in build file
# In envoy repo we still use sed method because we need to catch PR. Only use update_envoy.sh cannot get pr patch.
cp -f WORKSPACE WORKSPACE.bazel
sed  -i '/http_archive(/{:a;N;/)/!ba;s/.*name = "envoy".*/local_repository(\
    name = "envoy",\
    path = "intel-envoy",\
)/g}' WORKSPACE.bazel

# build envoy binary in container with sgx
IMG="registry.fi.intel.com/xintongc/build-tools-proxy:master-latest-sgx" BUILD_WITH_CONTAINER=1 make build_envoy 
IMG="registry.fi.intel.com/xintongc/build-tools-proxy:master-latest-sgx" BUILD_WITH_CONTAINER=1 make exportcache
# build istio.istio
cd istio
# export env
export TAG=${TAG:-"pre-build"}
make build
# replace upstream envoy with local envoy in build proxyv2 image
cd  ..
cp -rf out/linux_amd64/envoy istio/out/linux_amd64/release/envoy
# build proxyv2 image
cd istio
make docker.proxyv2
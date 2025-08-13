ARG OS_IDENTIFIER=ubuntu
ARG OS_TAG=20.04
ARG PLATFORM=linux/amd64

FROM --platform=${PLATFORM} ${OS_IDENTIFIER}:${OS_TAG} AS builder

ENV LANG en_US.UTF-8

RUN apt-get update && apt-get install -y curl

# Install Miniconda and conda-build, which is needed to compile R packages
# for conda-forge 
ARG MINICONDA_VERSION=py38_4.9.2
ARG MINICONDA_INSTALLER=Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh
RUN curl -LO https://repo.anaconda.com/miniconda/${MINICONDA_INSTALLER} \
  && bash ${MINICONDA_INSTALLER} -p /miniconda -b \
  && rm ${MINICONDA_INSTALLER}
ENV PATH=/miniconda/bin:${PATH}
RUN conda install conda-build

# Mamba is much faster for installing packages, and boa lets us use it
# when building packages
RUN conda install -c conda-forge mamba boa

# conda-build (and its mamba equivalent) will always reach out to a repository
# to install dependencies, rather than using pre-installed packages. However,
# by installing r-base now we can cache the required packages, so that R
# doesn't have to be downloaded each time a package is built.
ENV R_VERSION=4.0.3
RUN mamba install -c conda-forge r-base=${R_VERSION}

# Compiled packages are outputted to this directory. When this container is run,
# /packages can be used as a target for -v 
RUN mkdir -p /packages/R-{$R_VERSION}

RUN echo "#!/bin/bash" > build_r_package.sh \
  && echo ' \n\
  package=$1 \n\
  version=$2 \n\
  if [[ -n "$2" ]]; then \n\
  echo "Building r-$package-$version" \n\
  conda skeleton cran --version $version $package \n\
  conda mambabuild --R ${R_VERSION} -c conda-forge --output-folder /packages/R-${R_VERSION} r-$package-$version \n\
  else \n\
  echo "Building r-$package" \n\
  conda skeleton cran $package \n\
  conda mambabuild --R ${R_VERSION} -c conda-forge --output-folder /packages/R-${R_VERSION} r-$package \n\
  fi ' >> build_r_package.sh \
  && chmod +x build_r_package.sh

FROM mcr.microsoft.com/devcontainers/base:bullseye AS runtime

# Set environment variables
ENV MINIFORGE_VERSION=4.10.3-0

# Copy R installation
COPY --from=builder /miniconda /miniconda

# Put julia directory in PATH
ENV PATH="/.julia/bin:${PATH}"

ENV PATH="/miniconda/bin:${PATH}"

# Initialize all the custom environments variables
ENV DATA_DIR /workspaces/MTR/src/data
ENV R_DIR /workspaces/MTR/src/R
# syntax=docker/dockerfile:1
# Description: Dockerfile for the R base image with the necessary dependencies for the GNN proportions project

ARG JULIA_VERSION=1.10.4
FROM condaforge/miniforge3:latest AS rbase

# Set environment variables
ENV CONDA_PREFIX="/opt/conda/"
ENV CONDA_ENV_FILE="R.yml"

# Create the necessary environment
COPY envs/${CONDA_ENV_FILE} /tmp/envs/
RUN conda env create -f /tmp/envs/${CONDA_ENV_FILE}

# Create a symlink to R and Rscript
RUN ln -s ${CONDA_PREFIX}envs/R/bin/R /usr/bin/R
RUN ln -s ${CONDA_PREFIX}envs/R/bin/Rscript /usr/bin/Rscript

# Clean up
RUN apt-get autoremove -y && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/* && \
    rm -rf /var/tmp/*

# Stage 2: Julia Build stage
FROM julia:${JULIA_VERSION} AS builder
ENV JULIA_PROJECT=/project


HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

WORKDIR ${JULIA_PROJECT}

# We also need clang to compile the system image
RUN apt-get update && \ 
    apt-get install -y \
    clang \
    libc6-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Disable automatic package precompilation. We'll control when packages are precompiled.
# ENV JULIA_PKG_PRECOMPILE_AUTO="0"

COPY Project.toml Manifest.toml ${JULIA_PROJECT}/

# We need the R instalation from rbase to compile the system image
COPY --from=rbase /opt/conda/envs/R /opt/conda/envs/R
RUN ln -s /opt/conda/envs/R/bin/R /usr/bin/R


## taken from https://discourse.julialang.org/t/proposed-julia-docker-workflow-to-use-a-persistent-depot/97963
# Switch the Julia depot to use the shared cache storage. As `.ji` files reference
# absolute paths to their included source files care needs to be taken to ensure the depot
# path used during package precompilation matches the final depot path used in the image.
# If a source file no longer resides at the expected location the `.ji` is deemed stale and
# will be recreated.
RUN ln -s /tmp/julia-cache ~/.julia


# Install Julia package registries.
RUN --mount=type=cache,sharing=locked,target=/tmp/julia-cache \
    julia -e "using Pkg; Pkg.Registry.add(\"General\"); \ 
    Pkg.activate(\".\"); Pkg.instantiate(); Pkg.precompile(strict=true); \
    using PackageCompiler; create_sysimage(;include_transitive_dependencies=false, sysimage_path=\"${JULIA_PROJECT}/sys.so\")"; 


ARG JULIA_VERSION=1.10.4
# Stage 3: Runtime stage
FROM julia:${JULIA_VERSION} AS runtime

ENV JULIA_PROJECT=/project

WORKDIR ${JULIA_PROJECT}

COPY Project.toml Manifest.toml ${JULIA_PROJECT}/

# Copy the system image from the builder stage.
COPY --from=builder /project/sys.so sys.so
COPY --from=builder /project/pkgs.txt pkgs.txt

# Copy the conda installation from the R base image
COPY --from=rbase /opt/conda /opt/conda
RUN ln -s /opt/conda/envs/R/bin/R /usr/bin/R

# User setup
RUN useradd -ms /bin/bash julia_user

# Give the user sudo privileges
RUN apt-get update && apt-get install -y sudo 
RUN usermod -aG sudo julia_user && \
    echo "julia_user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers 

# Create a startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh


# Set the user to the non-root user.
USER julia_user
ENTRYPOINT ["/start.sh"]


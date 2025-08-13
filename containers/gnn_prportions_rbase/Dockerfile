# Description: Dockerfile for the R base image with the necessary dependencies for the GNN proportions project
FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Set environment variables
ENV MINIFORGE_VERSION=4.10.3-0
ENV PATH="/opt/miniforge3/bin:${PATH}"
ENV CONDA_PREFIX="/opt/miniforge3/"
ENV CONDA_ENV_FILE="/tmp/envs/R.yml"

# Install wget and other dependencies
RUN apt-get update && \
    apt-get install -y wget bzip2 

# Download and install Miniforge
RUN wget https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-Linux-x86_64.sh && \
    chmod +x Miniforge3-Linux-x86_64.sh && \
    ./Miniforge3-Linux-x86_64.sh -b -p /opt/miniforge3 && \
    rm Miniforge3-Linux-x86_64.sh

# Create the necessary environment
COPY envs/ /tmp/envs/
RUN conda env create -f ${CONDA_ENV_FILE}

# Create a symlink to R and Rscript
RUN ln -s /opt/miniforge3/envs/R/bin/R /usr/bin/R
RUN ln -s /opt/miniforge3/envs/R/bin/Rscript /usr/bin/Rscript

# Clean up
RUN apt-get autoremove -y && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/* && \
    rm -rf /var/tmp/*
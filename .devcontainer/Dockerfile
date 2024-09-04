FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Set environment variables
ENV MINIFORGE_VERSION=4.10.3-0

# Install wget and other dependencies
RUN apt-get update && \
    apt-get install -y wget bzip2 

# Download and install Miniforge
RUN wget https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-Linux-x86_64.sh && \
    chmod +x Miniforge3-Linux-x86_64.sh && \
   ./Miniforge3-Linux-x86_64.sh -b -p /opt/miniforge3 && \
    rm Miniforge3-Linux-x86_64.sh

# Add conda to PATH and set CONDA_PREFIX
ENV PATH="/opt/miniforge3/bin:${PATH}"
ENV CONDA_PREFIX="/opt/miniforge3/"

# Install conda packages
ENV CONDA_ENVS_FILES /tmp/envs/
COPY envs/ /tmp/envs/

# Create all the necessary environments
RUN conda env create -f /tmp/envs/julia.yml
RUN conda env create -f /tmp/envs/R.yml

# Initialize all the custom environments variables
ENV DATA_DIR /workspaces/MTR/src/data
ENV R_DIR /workspaces/MTR/src/R

# Create a symlink to julia and R
RUN ln -s /opt/miniforge3/envs/julia/bin/julia /usr/bin/julia
RUN ln -s /opt/miniforge3/envs/R/bin/R /usr/bin/R
RUN ln -s /opt/miniforge3/envs/R/bin/Rscript /usr/bin/Rscript

# Clean up
RUN apt-get autoremove -y && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/* && \
    rm -rf /var/tmp/*
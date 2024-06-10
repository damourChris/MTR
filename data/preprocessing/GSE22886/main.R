# WORKING_DIRECTORY <- ""   # Replace with your working dir # nolint
# DATA_DIRECTORY <- ""      # **      **    **  data dir # nolint
# Load working and data directory variables
source("working_env.r")

setwd(WORKING_DIRECTORY)
source("cel_processing.R")

# Get the list of all files in the directory
all_files <- list.files(path = DATA_DIRECTORY)

# Filter for.cel files
cel_files <- grep(pattern = "\\.CEL$", x = all_files, value = TRUE)

# Set current working directory to data_directory
setwd(DATA_DIRECTORY)

# Combine cell files into one big matrix
res <- combine_cel_files(cel_files)

setwd(WORKING_DIRECTORY)

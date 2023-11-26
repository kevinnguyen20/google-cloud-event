FROM ubuntu:22.04

# Copy benchmark script to the container
COPY benchmark.sh /benchmark.sh

# Copy custom sources.list for apt with regional servers
# because the default ones in the image were slow and the build took an hour
COPY sources.list /etc/apt/sources.list

# To execute the benchmark script without changes sudo is required
# also preinstall sysbench to save time
RUN apt update \
  && apt install -y sudo sysbench

# Make the benchmark script executable
RUN chmod +x /benchmark.sh

# Use the benchmark script as entrypoint
ENTRYPOINT /benchmark.sh

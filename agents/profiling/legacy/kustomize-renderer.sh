#!/bin/bash
# Save stdin (the Helm output) to a file Kustomize can read
cat <&0 > all.yaml

# Run kustomize build to apply patches
kustomize build .

# Clean up
rm all.yaml
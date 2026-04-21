elm install --create-namespace -n=universal-profiling universal-profiling-agent \                                                      
--set "projectID=1,secretToken=" \
--set "collectionAgentHostPort=" \
--version=9.3.3 \
elastic/profiling-agent --post-renderer ./kustomize-renderer.sh

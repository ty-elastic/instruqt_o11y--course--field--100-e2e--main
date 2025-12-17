project="elastic-sa"
name="tbekiares-demo"
zone="us-central1-a"
labels="division=field,org=sa,team=pura,project=tyronebekiares"

regions=1

while getopts "p:n:z:l:r:" opt
do
   case "$opt" in
      p ) project="$OPTARG" ;;
      n ) name="$OPTARG" ;;
      z ) zone="$OPTARG" ;;
      l ) labels="$OPTARG" ;;
      r ) regions="$OPTARG" ;;
   esac
done

gcloud beta container clusters delete $name

gcloud beta container --project $project clusters create $name --zone $zone --tier "standard" --no-enable-basic-auth --release-channel "regular" --machine-type "n2-standard-4" --image-type "COS_CONTAINERD" --disk-type "pd-balanced" --disk-size "1000" --metadata disable-legacy-endpoints=true --num-nodes $regions --logging=NONE --enable-ip-alias --network "projects/$project/global/networks/default" --subnetwork "projects/$project/regions/us-central1/subnetworks/default" --no-enable-intra-node-visibility --default-max-pods-per-node "110" --enable-ip-access --security-posture=standard --workload-vulnerability-scanning=disabled --no-enable-google-cloud-access --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver --enable-autoupgrade --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 0 --labels $labels --binauthz-evaluation-mode=DISABLED --no-enable-managed-prometheus --enable-shielded-nodes --shielded-integrity-monitoring --no-shielded-secure-boot --node-locations $zone

gcloud container clusters get-credentials $name --zone $zone --project $project

#------- TOOLS

source ../../k8s/tools/ksm.sh

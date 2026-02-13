project="elastic-sa"
zone="us-central1-a"

while getopts "p:n:z:r:t:u:" opt
do
   case "$opt" in
      p ) project="$OPTARG" ;;
      n ) name="$OPTARG" ;;
      z ) zone="$OPTARG" ;;

      t ) team="$OPTARG" ;;
      u ) user="$OPTARG" ;;
   esac
done

labels="division=field,org=sa,team=$team,project=$user"
name="$user-superdemo"

gcloud beta container clusters delete $name --zone $zone

gcloud beta container --project $project clusters create $name --zone $zone --tier "standard" --no-enable-basic-auth --release-channel "regular" --machine-type "n2-standard-4" --image-type "COS_CONTAINERD" --disk-type "pd-balanced" --disk-size "1000" --metadata disable-legacy-endpoints=true --num-nodes 1 --logging=NONE --enable-ip-alias --network "projects/$project/global/networks/default" --subnetwork "projects/$project/regions/us-central1/subnetworks/default" --no-enable-intra-node-visibility --default-max-pods-per-node "110" --enable-ip-access --security-posture=standard --workload-vulnerability-scanning=disabled --no-enable-google-cloud-access --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver --enable-autoupgrade --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 0 --labels $labels --binauthz-evaluation-mode=DISABLED --no-enable-managed-prometheus --enable-shielded-nodes --shielded-integrity-monitoring --no-shielded-secure-boot --node-locations $zone

gcloud container clusters get-credentials $name --zone $zone --project $project

#------- TOOLS

source ../../k8s/tools/ksm.sh

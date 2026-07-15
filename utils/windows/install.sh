OPTIND=1
while getopts "4:5:6:7:c:" opt
do
   case "$opt" in
      4 ) windows_host_ip="$OPTARG" ;;
      5 ) windows_username="$OPTARG" ;;
      6 ) windows_password="$OPTARG" ;;
      7 ) script_path="$OPTARG" ;;
      c ) course="$OPTARG" ;;
   esac
done

envsubst '$COURSE' < $script_path > $script_path.tmp

sshpass -p $windows_password ssh -o StrictHostKeyChecking=no $windows_username@$windows_host_ip "powershell -ExecutionPolicy Bypass -Command -" < $script_path.tmp

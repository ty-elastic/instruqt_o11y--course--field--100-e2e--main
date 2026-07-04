arch=linux/amd64
build=true
branch=test

OPTIND=1
while getopts "a:b:r:" opt
do
   case "$opt" in
      a ) arch="$OPTARG" ;;
      b ) build="$OPTARG" ;;
      r ) branch="$OPTARG" ;;
   esac
done

# prep track sub

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

if [[ "$CURRENT_BRANCH" == "$branch" ]]; then
  echo "Current branch is correct: $CURRENT_BRANCH"
else
  echo "Error: Current branch is \"$CURRENT_BRANCH\", but expected \"$EXPECTED_BRANCH\"."
  exit 1
fi

if [ -n "$(git status --porcelain -uno)" ]; then
  echo "🔴 There are modified or untracked files."
  # Optional: list the modified files
  git status --porcelain
  exit 1
else
  echo "🟢 The working directory is clean."
fi

if [[ "$CURRENT_BRANCH" == "main" ]]; then
    course=o11y--course--field--100-e2e--serverless
else
    course=o11y--course--field--100-e2e--test
fi
echo $course

upload_bundle() {
  mkdir -p bundle
  git archive --format=tgz $branch -o bundle/$course.tgz

  ARTIFACT_VERSION=1.0

  gcloud artifacts versions delete $ARTIFACT_VERSION \
      --quiet \
      --package=$course \
      --location=us-central1 \
      --repository=tbekiares-instruqt

  gcloud artifacts generic upload \
      --source=bundle/$course.tgz \
      --package=$course \
      --version=$ARTIFACT_VERSION \
      --location=us-central1 \
      --repository=tbekiares-instruqt
}
upload_bundle

if [ "$build" = "true" ]; then
  ./build.sh -c $course -q true -b true -x true -s all
fi

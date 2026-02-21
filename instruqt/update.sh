arch=linux/amd64
build=true
course=o11y--course--field--100-e2e
track=o11y--course--field--100-e2e--serverless
while getopts "a:b:c:d:" opt
do
   case "$opt" in
      a ) arch="$OPTARG" ;;
      b ) build="$OPTARG" ;;
      c ) course="$OPTARG" ;;
      d ) track="$OPTARG" ;;
   esac
done

cd tools/pandoc
docker build --platform linux/amd64 -t pandoc-inter-custom .
cd ../..

upload_bundle() {
  mkdir -p bundle
  cd ..
  git archive --format=tgz HEAD -o instruqt/bundle/$course.tgz

  ARTIFACT_VERSION=1.0

  gcloud artifacts versions delete $ARTIFACT_VERSION \
      --quiet \
      --package=$course \
      --location=us-central1 \
      --repository=tbekiares-instruqt

  gcloud artifacts generic upload \
      --source=instruqt/bundle/$course.tgz \
      --package=$course \
      --version=$ARTIFACT_VERSION \
      --location=us-central1 \
      --repository=tbekiares-instruqt

  cd instruqt
}
upload_bundle

upload_script() {
  ARTIFACT_VERSION=1.0

  gcloud artifacts versions delete $ARTIFACT_VERSION \
      --quiet \
      --package=$course-script.pdf \
      --location=us-central1 \
      --repository=tbekiares-instruqt

  # curl -o test.pdf -v https://artifactregistry.googleapis.com/download/v1/projects/elastic-sa/locations/us-central1/repositories/tbekiares-instruqt/files/o11y--course--field--100-e2e-script.pdf:1.0:script.pdf:download\?alt\=media

  gcloud artifacts generic upload \
      --source=assets/script.pdf \
      --package=$course-script.pdf \
      --version=$ARTIFACT_VERSION \
      --location=us-central1 \
      --repository=tbekiares-instruqt
}

for dir in ./tracks/*/; do
  echo $dir
  if [[ -d "$dir" ]]; then
    current_track=$(basename "$dir")
    echo $current_track
    echo $track
    
    if [[ "$track" == "all" || "$track" == "$current_track" ]]; then

      if [ "$build" = "true" ]; then

        cd ../assets
        ./build.sh -c $course
        cd ../instruqt

        cd ../utils/remote
        ./build.sh -c $course
        cd ../../instruqt

        cd ../utils/cpuhog
        ./build.sh -c $course
        cd ../../instruqt

        cd ..
        ./build.sh -c $course -b true -x true -s all
        cd instruqt
      fi

      cd tracks/$current_track

      for diag in diagrams/*.mmd; do
        diag_base=$(basename "$diag")
        #mmdc -i $diag -o ./assets/$diag_base.svg
        docker run --rm -u `id -u`:`id -g` -v $PWD/diagrams:/diagrams -v $PWD/assets:/assets minlag/mermaid-cli -i /diagrams/$diag_base -o /assets/$diag_base.png
      done

      cat '01-setup/base.md' > '01-setup/assignment.md'
      for assignment in assignments/*.md; do
        cat $assignment >> '01-setup/assignment.md'
      done

      #docs
      title=$(yq .title track.yml)
      echo "![](./header.png)" > input.md
      echo "" >> input.md
      echo "# $title" >> input.md
      echo "" >> input.md
      for challenge in */; do
        echo $challenge
        if [ -f "$challenge/assignment.md" ]; then
          #echo "here"

          sed -n '/---/,/---/p' "$challenge/assignment.md" > input.yaml
          ch_title=$(yq .title input.yaml)
          ch_title=$(echo $ch_title | sed -e "s/--- null$//")
          echo $ch_title
          rm input.yaml

          echo "# $ch_title" >> input.md
          sed -e '/---/,/---/d' "$challenge/assignment.md" >> input.md
          echo "" >> input.md
          echo "___" >> input.md
          echo "" >> input.md
        fi
      done
      docker run --platform linux/amd64 --rm -v $PWD/assets:/assets -v $PWD:/data -u $(id -u):$(id -g) pandoc-inter-custom --pdf-engine xelatex --include-in-header /pandoc/pandoc.tex -V geometry:margin=0.25in -f markdown-implicit_figures --highlight-style=breezedark --resource-path=/assets --output=/assets/script.pdf /data/input.md
      rm -rf input.md
      docker run --platform linux/amd64 --rm -v $PWD/assets:/assets -v $PWD:/data -u $(id -u):$(id -g) pandoc-inter-custom --pdf-engine xelatex --include-in-header /pandoc/pandoc.tex -V geometry:margin=0.25in -f markdown-implicit_figures --highlight-style=breezedark --resource-path=/assets --output=/assets/brief.pdf /data/docs/brief.md
      docker run --platform linux/amd64 --rm -v $PWD/assets:/assets -v $PWD:/data -u $(id -u):$(id -g) pandoc-inter-custom --pdf-engine xelatex --include-in-header /pandoc/pandoc.tex -V geometry:margin=0.25in -f markdown-implicit_figures --highlight-style=breezedark --resource-path=/assets --output=/assets/notes.pdf /data/docs/notes.md

      upload_script

      instruqt track push --force
      cd ../..
    fi
  fi
done

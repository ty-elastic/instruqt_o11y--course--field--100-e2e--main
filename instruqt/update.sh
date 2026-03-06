arch=linux/amd64
build=true

branch=test

while getopts "a:b:c:r:" opt
do
   case "$opt" in
      a ) arch="$OPTARG" ;;
      b ) build="$OPTARG" ;;
      r ) branch="$OPTARG" ;;
   esac
done

# prep track sub

echo $branch

track_id=$(yq '.tracks[] | select(.branch == "'$branch'") | .id' tracks.yaml)
track_slug=$(yq '.tracks[] | select(.branch == "'$branch'") | .slug' tracks.yaml)
track_slug=$(yq '.tracks[] | select(.branch == "'$branch'") | .slug' tracks.yaml)
course=$(yq '.tracks[] | select(.branch == "'$branch'") | .course' tracks.yaml)
echo $track_slug
echo $track_id
echo $course

cd tools/pandoc
docker build --platform linux/amd64 -t pandoc-inter-custom .
cd ../..

upload_bundle() {
  mkdir -p bundle
  cd ..
  git archive --format=tgz $branch -o instruqt/bundle/$course.tgz

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

cd track

for script in track_scripts.tmpl/*.tmpl; do
  echo $script
  script_no_ext="${script%.*}"
  echo $script_no_ext
  script_base=$(basename "$script_no_ext")
  echo $script_base
  sed "s/{{COURSE}}/$course/g" $script > track_scripts/$script_base
done

sed "s/{{TRACK_SLUG}}/$track_slug/g" track.yml.tmpl > track.yml.tmp
sed "s/{{TRACK_ID}}/$track_id/g" track.yml.tmp > track.yml
rm track.yml.tmp

for diag in diagrams/*.mmd; do
  diag_base=$(basename "$diag")
  #mmdc -i $diag -o ./assets/$diag_base.svg
  docker run --rm -u `id -u`:`id -g` -v $PWD/diagrams:/diagrams -v $PWD/assets:/assets minlag/mermaid-cli -i /diagrams/$diag_base -o /assets/$diag_base.png
done

cat '01-setup/base.md' > '01-setup/assignment.md'
for assignment in assignments/*.md; do
  echo "" >> '01-setup/assignment.md'
  echo "___" >> '01-setup/assignment.md'
  echo "" >> '01-setup/assignment.md'
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

instruqt track push --force

cd ..

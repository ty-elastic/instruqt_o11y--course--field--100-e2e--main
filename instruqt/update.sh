arch=linux/amd64
build=true
course=all
while getopts "a:b:c:" opt
do
   case "$opt" in
      a ) arch="$OPTARG" ;;
      b ) build="$OPTARG" ;;
      c ) course="$OPTARG" ;;
   esac
done

cd tools/pandoc
docker build --platform linux/amd64 -t pandoc-inter .
cd ../..

cd ..
cd collector/_courses
./diff.sh
cd ../../instruqt

cd ..
cd k8s/yaml/_courses
./diff.sh
cd ../../../instruqt

cd ..
cd src/recorder-java/_courses
./diff.sh
cd ../../../instruqt

cd ..
cd src/router/_courses
./diff.sh
cd ../../../instruqt

cd ..
cd src/trader/_courses
./diff.sh
cd ../../../instruqt

for dir in ./tracks/*/; do
  echo $dir
  if [[ -d "$dir" ]]; then
    current_course=$(basename "$dir")
    echo $current_course
    echo $course
    
    if [[ "$course" == "all" || "$course" == "$current_course" ]]; then

      if [ "$build" = "true" ]; then
        cd ..
        ./build.sh -c $current_course -a $arch -v $current_course
        cd instruqt
      fi

      cd tracks/$current_course

      for diag in diagrams/*.mmd; do
        diag_base=$(basename "$diag")
        #mmdc -i $diag -o ./assets/$diag_base.svg
        docker run --rm -u `id -u`:`id -g` -v $PWD/diagrams:/diagrams -v $PWD/assets:/assets minlag/mermaid-cli -i /diagrams/$diag_base -o /assets/$diag_base.png
      done

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
      docker run --platform linux/amd64 --rm -v $PWD/assets:/assets -v $PWD:/data -u $(id -u):$(id -g) pandoc-inter --pdf-engine xelatex --include-in-header /pandoc/pandoc.tex -V geometry:margin=0.25in -f markdown-implicit_figures --highlight-style=breezedark --resource-path=/assets --output=/assets/script.pdf /data/input.md
      rm -rf input.md
      docker run --platform linux/amd64 --rm -v $PWD/assets:/assets -v $PWD:/data -u $(id -u):$(id -g) pandoc-inter --pdf-engine xelatex --include-in-header /pandoc/pandoc.tex -V geometry:margin=0.25in -f markdown-implicit_figures --highlight-style=breezedark --resource-path=/assets --output=/assets/brief.pdf /data/docs/brief.md
      docker run --platform linux/amd64 --rm -v $PWD/assets:/assets -v $PWD:/data -u $(id -u):$(id -g) pandoc-inter --pdf-engine xelatex --include-in-header /pandoc/pandoc.tex -V geometry:margin=0.25in -f markdown-implicit_figures --highlight-style=breezedark --resource-path=/assets --output=/assets/notes.pdf /data/docs/notes.md

      instruqt track push --force
      cd ../..
    fi
  fi
done






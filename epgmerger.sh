#!/bin/bash
set -euxo pipefail # Enable strict error checking and debugging

# VARIABLES
BASEPATH="$GITHUB_WORKSPACE" # Use absolute path
LISTS=(
  "https://epgshare01.online/epgshare01/epg_ripper_PT1.xml.gz"
  "https://epgshare01.online/epgshare01/epg_ripper_ES1.xml.gz"
)

fixall() {
  for xml in "$BASEPATH"/*.xml; do
    echo "Fixing $xml ..."
    sleep 1
    # Structural Fixes
    sed -i "/<url>/d" "$xml"
    sed -i "s/lang=\"\"/lang=\"pt-BR\"/g" "$xml"
    # Language Fixes (Might Not be Necessary)
    sed -i "s/<display-name>/<display-name lang=\"pt-BR\">/g" "$xml"
    sed -i "s/lang=\"pt\"/lang=\"pt-BR\"/g" "$xml"
  done
}

downloadepgs() {
  INDEX=1
  for list in "${LISTS[@]}"; do
    sleep 1
    dir="$(mktemp -d)" # Use mktemp without $PWD
    wget -q --show-progress -P "$dir" --content-disposition --trust-server-names "$list"
    regex="\?"
    for file in "$dir"/*; do
      if [[ "$file" =~ $regex ]]; then
        ext="xml"
      else
        ext="${file##*.}"
      fi
      echo "Extension = $ext, will rename it to $BASEPATH/$INDEX.$ext"
      mv "$file" "$BASEPATH/$INDEX.$ext"
    done
    rmdir "$dir"
    let INDEX=INDEX+1
  done
}

extractgz() {
  echo "Extracting compressed files..."
  gunzip -f "$BASEPATH"/*.gz
  find "$BASEPATH" -type f ! -name "*.*" -exec mv {} {}.xml \;
  sleep 2
  # workaround to fix unknown bug that causes the .xml extension not to be added to some files sometimes.
  INDEX=1
  for list in "${LISTS[@]}"; do
    mv "$BASEPATH/$INDEX" "$BASEPATH/$INDEX.xml"
    let INDEX=INDEX+1
  done
}

sortall() {
  for xml in "$BASEPATH"/*.xml; do
    echo "Sorting $xml ..."
    sleep 1
    tv_sort --by-channel --output "$xml" "$xml"
  done
}

mergeall() {
  fileslist=("$BASEPATH"/*.xml)

  # MERGE The First 2
  echo "Merging ${fileslist[0]} with ${fileslist[1]}"
  tv_merge -i "${fileslist[0]}" -m "${fileslist[1]}" -o "$BASEPATH/epg.xmltv"

  # Merge the Rest
  for i in $(seq 2 "${#fileslist[@]}"); do
    if [[ -n "${fileslist[$i]}" ]]; then
      echo "Merging ${fileslist[$i]} ..."
      tv_merge -i "$BASEPATH/epg.xmltv" -m "${fileslist[$i]}" -o "$BASEPATH/epg.xmltv"
    fi
  done
}

getall() {
  downloadepgs
  extractgz
}

getall
fixall
# sortall

# Remove old file
rm -f "$BASEPATH/epg.xmltv"

# Merge All the xml files into merged.xmltv
mergeall
gzip "$BASEPATH/epg.xmltv"

# Cleanup
echo "Cleaning Up..."
rm "$BASEPATH"/*.xml

echo "Done!"
sleep 3

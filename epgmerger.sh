#!/bin/bash

# This script downloads epg files and merges them into one file.

## VARIABLES
BASEPATH="./workspace"  # Temporary directory for processing files
OUTPUT_FILE="$BASEPATH/epg.xmltv.gz"

LISTS=(
    "https://epgshare01.online/epgshare01/epg_ripper_PT1.xml.gz"
    "https://epgshare01.online/epgshare01/epg_ripper_ES1.xml.gz"
)

# Create the workspace directory if it doesn't exist
mkdir -p $BASEPATH

fixall () {
    for xml in $BASEPATH/*.xml; do
        echo "Fixing $xml ... "
        sleep 1
        ## Structural Fixes
        sed -i "/<url>/d" "$xml"
        sed -i "s/lang=\"\"/lang=\"pt-BR\"/g" $xml
        ## Language Fixes (Might Not be Necessary)
        sed -i "s/<display-name>/<display-name lang=\"pt-BR\">/g" $xml
        sed -i "s/lang=\"pt\"/lang=\"pt-BR\"/g" $xml
    done    
}

downloadepgs () {
    INDEX=1
    for list in ${LISTS[*]}; do
        sleep 1
        dir="$(TMPDIR=$PWD mktemp -d)"  ## makes a temp dir so that we can download the file, rename it, and keep its extension.
        wget -q --show-progress -P $dir --content-disposition --trust-server-names ${list[*]}
        
        # Downloaded files may be gzipped, so extract and rename properly
        for file in $dir/*; do
            if [[ $file =~ \.gz$ ]]; then
                ext="gz"
                echo "Extracting $file"
                gunzip -c $file > $BASEPATH/$INDEX.xml  # Extract the .gz file and rename to .xml
            else
                ext="xml"
                mv $file $BASEPATH/$INDEX.$ext
            fi
            echo "Renamed to $BASEPATH/$INDEX.$ext"
        done
        rmdir "$dir"
        let INDEX=${INDEX}+1
    done
}

extractgz () {
    echo "Extracting compressed files..."
    # There's no need for this if we handle the extraction in the download step already.
}

sortall () {
    for xml in $BASEPATH/*.xml; do
        echo "Sorting $xml ..."
        sleep 1
        tv_sort --by-channel --output $xml $xml        
    done
}

mergeall () {
    fileslist=( $(ls $BASEPATH/*.xml) )
    
    # MERGE The First 2
    echo "Merging ${fileslist[0]} with ${fileslist[1]}"
    tv_merge -i ${fileslist[0]} -m ${fileslist[1]} -o $OUTPUT_FILE
    
    # Merge the Rest
    for i in $(seq 2 ${#fileslist[@]}); do
        if [ ! -z "${fileslist[$i]}" ]; then
            echo "Merging ${fileslist[$i]} ... "
        fi
        tv_merge -i $OUTPUT_FILE -m ${fileslist[$i]} -o $OUTPUT_FILE
    done
}

getall () {
    downloadepgs
}

getall
fixall

## Remove old file
rm -f $OUTPUT_FILE

## Merge All the xml files into merged.xmltv
mergeall
gzip $OUTPUT_FILE

## Cleanup
echo "Cleaning Up..."
rm $BASEPATH/*.xml

# Move the merged and gzipped file to the repository directory
mv $OUTPUT_FILE $GITHUB_WORKSPACE/epg.xmltv.gz

echo "Done!"
sleep 3

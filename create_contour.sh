#!/usr/bin/env bash

# exit script on error
# exit on undeclared variable
set -o errexit -o pipefail -o noclobber -o nounset

## Color Constants

# Reset
Color_Off='\033[0m'       # Text Reset

# Regular Colors
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Cyan='\033[0;36m'         # Cyan

#set Defaults
DEBUG="false"
INPUT_DIR=/data/mapping/AW3D30
OUTPUT_DIR=/data/mapping
WORKERS=`sysctl -n kern.smp.cpus`
INTERVAL=100
IMPERIAL="false"
VERBOSE="false"
OVERWRITE="false"
CLEAN="true"
# print a help message
function print_usage()
{
  echo "Usage: ${0} --input-dir ${JAXA_DIR} --output-dir ${OUTPUT_DIR} --workers ${WORKERS} --interval ${INTERVAL}"
  echo "  --input-dir:    the directory containing the jaxa DSM tiffs defaults"
  echo "                   to ${JAXA_DIR}"
  echo "  --output-dir:  the directory to put the resulting whole combined "
  echo "                   raster tile defaults to ${OUTPUT_DIR}."
  echo "  --workers:     the number of rgbify workers to run, defaults to the number of "
  echo "                   CPU thread's detected (${WORKERS})"
  echo "  --interval:    Interval between contour lines, defaults to 100"
  echo "  --imperial:    Turns on Imperial elevation generation"
  echo "  --verbose:     Turn on chattier output"
  echo "  --clean:       Attempt to reduce disk footprint"
  echo "  --overwrite:   Force the creation of all files, not just the missing/new ones"
  exit
}

# print a given text entirely in a given color
function color_echo()
{
    color=$1
    text=$2
    echo -e "${color}${text}${Color_Off}"
}

contour()
{
  filename=${1}
  OUTPUT_DIR=${2}
  INTERVAL=${3}
  CLEAN=${4}
  file=${filename##*/}
  path=${filename%/*}

  if [[ ${OVERWRITE} = "true" ]] || [[ ${filename} -nt ${OUTPUT_DIR}/${file}.shp ]]; then
    gdal_contour -q -a elev -i ${INTERVAL}    ${filename}     ${OUTPUT_DIR}/${file}.shp
    echo -n "."
  fi
  if [[ ${OVERWRITE} = "true" ]] || [[ ${OUTPUT_DIR}/${file}.shp -nt ${OUTPUT_DIR}/${file}.json ]]; then
    ogr2ogr -f GeoJSON  ${OUTPUT_DIR}/${file}.json ${OUTPUT_DIR}/${file}.shp
    echo -n "."
  fi
  if [[ ${OVERWRITE} = "true" ]] || [[ ${OUTPUT_DIR}/${file}.json -nt ${OUTPUT_DIR}/${file}.mbtiles ]]; then
     tippecanoe \
       --force \
       --read-parallel \
       --quiet --no-progress-indicator \
       --maximum-zoom=12 \
       --drop-fraction-as-needed \
       --maximum-tile-bytes=200000 \
       `# Keep only the elev attribute` \
       -y elev \
       `# Put contours into layer named 'contour_10m'` \
       -l contour_${INTERVAL}m \
       `# Filter contours at different zoom levels` \
       `# -C 'if [[ $1 -le 11 ]]; then jq "if .properties.ele_m % 50 == 0 then . else {} end"; elif [[ $1 -eq 12 ]]; then jq "if .properties.ele_m % 20 == 0 then . else {} end"; else jq "."; fi'` \
       `# Export to contour_10m.mbtiles` \
       -o ${OUTPUT_DIR}/${file}.mbtiles \
       ${OUTPUT_DIR}/${file}.json
    echo -n "."
  fi
  if [[ ${CLEAN} = "true" ]]; then
    rm ${OUTPUT_DIR}/${file}.shp ${OUTPUT_DIR}/${file}.shx ${OUTPUT_DIR}/${file}.prj ${OUTPUT_DIR}/${file}.dbf ${OUTPUT_DIR}/${file}.json
  fi
}

main ()
{
  echo "INPUT ${INPUT_DIR} OUTPUT ${OUTPUT_DIR}"

  [ -d "$OUTPUT_DIR" ] || mkdir -p $OUTPUT_DIR || { echo "error: $OUTPUT_DIR " 1>&2; exit 1; }
  rm ${OUTPUT_DIR}/JAXA_DSM.files
  find ${INPUT_DIR} -name \*_DSM.tif > ${OUTPUT_DIR}/JAXA_DSM.files

#  for i in `cat ${OUTPUT_DIR}/JAXA_DSM.files`; do
#    printf "%s\0%s\0%s\0%s\0" "${i}" "${OUTPUT_DIR}" "${INTERVAL}" "${CLEAN}"
#  done | xargs -0 -n 4 -P ${WORKERS} bash -c 'contour "$@"' --
  rm ${OUTPUT_DIR}/json.files
  rm ${OUTPUT_DIR}/mbtiles.files
  find ${OUTPUT_DIR}  -name \*.tif.json > ${OUTPUT_DIR}/json.files
  find ${OUTPUT_DIR}  -name \*.tif.mbtiles > ${OUTPUT_DIR}/mbtiles.files
  for i in `cat ${OUTPUT_DIR}/mbtiles.files`; do
    echo $i
    /home/darcy/src/github.com/dBiTech/tippecanoe/tile-join --no-tile-size-limit -o ${OUTPUT_DIR}/contours-${INTERVAL}.mbtiles -r ${OUTPUT_DIR}/mbtiles.files 2>&1 | sort -n
    if [[ ${CLEAN} = "true" ]]; then
      rm ${i}
    fi
  done;
}

export -f contour


if [ "$#" -eq 0 ]; then
    print_usage
    exit 0
fi
echo $#

# now enjoy the options in order and nicely split
while [ "$#" -gt 0 ]; do
    case "$1" in
        -c|--clean)
            CLEAN="true"
            shift;
            ;;
        -m|--imperial)
            IMPERIAL="true"
            shift
            ;;
        -n|--interval)
            INTERVAL="$2"
            shift 2
            ;;
        -i|--input-dir)
            INPUT_DIR="$2"
            shift 2
            ;;
        -f|--overwrite)
            OVERWRITE="true"
            shift
            ;;
        -w|--workers)
            WORKERS="$2"
            shift 2
            ;;
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE="true"
            shift
            ;;
        *)
            echo "Programming error"
            exit 3
            ;;
    esac
done

main

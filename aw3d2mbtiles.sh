#!/usr/bin/env bash


INPUT_DIR=./input
OUTPUT_DIR=./output
vrtfile=./input.vrt
mbtilesfile=${OUTPUT_DIR}/out.mbtiles


[ -d "$OUTPUT_DIR" ] || mkdir -p $OUTPUT_DIR || { echo "error: $OUTPUT_DIR " 1>&2; exit 1; }

gdalbuildvrt -overwrite -srcnodata -9999 -vrtnodata -9999 ${vrtfile} ${INPUT_DIR}/*_DSM.tif
gdal_translate ${vrtfile} ${mbtilesfile} -of MBTILES -co TILE_FORMAT=JPEG -tr 1 -1
gdaladdo -r average ${mbtilesfile} 2 4 8 16
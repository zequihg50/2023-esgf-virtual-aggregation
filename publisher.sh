#!/bin/bash

set -u

trap exit SIGINT SIGKILL

# defaults
columns=OPENDAP,size,replica,version,checksum,checksum_type,_eva_ensemble_aggregation,_eva_variable_aggregation
overwrite=0
ncmls=content/public
pickles=pickles
publisher=publisher
sources=""

usage() {
    echo "${0}"
}

while [[ $# -gt 0 ]]
do
    case "$1" in
    --columns)
        columns="$2"
        shift 2
        ;;
    -h | --help)
        usage >&2
        exit 1
        ;;
    --ncmls)
        ncmls="$2"
        shift 2
        ;;
    --overwrite)
        overwrite="1"
        shift 1
        ;;
    --pickles)
        pickles="$2"
        shift 2
        ;;
    --publisher)
        publisher="$2"
        shift 2
        ;;
    -*)
        echo 'Unknown option, use -h for help, exiting...'
        exit 1
        ;;
    *)
        sources="${sources} $1"
        shift 1
        ;;
    esac
done

mkdir -p ${pickles} ${ncmls}

if [ -z "${sources}" ] ; then
    cat <&0
else
    cat ${sources}
fi | while read csv
do
    basename=${csv##*/}
    ncml=${ncmls}/${basename}.ncml

    # If ncml exists, ignore
    if [ -f "${ncml}" ] && [ "${overwrite}" -eq 0 ] ; then
        echo "Ignoring ${ncml}..." >&2
    elif [ ! -s "${csv}" ] ; then
        echo "Size0 ${csv}..." >&2
    else
        python -W ignore ${publisher}/todf.py -f ${csv} --numeric size -v time --col 0 --cols ${columns} ${pickles}/${basename}
        echo ${pickles}/${basename} >&2
    fi
done | while read pickle
do
    python cmip6.py ${pickle}
done | while read pickle
do
    version="v$(date -u +%Y%m%d)"
    creation="$(date -u +%FT%T)Z"
    ncml="${ncmls}/{mip_era}/{institution_id}/${version}/{mip_era}_{activity_id}_{institution_id}_{source_id}_{table_id}_{grid_label}_v{version}.ncml"
    python ${publisher}/jdataset.py -d ${ncml} -o variable_col=variable_id -o eva_version=${version} -o creation=${creation} -t templates/cmip6.ncml.j2 ${pickle}
    #rm -f "${pickle}"
done
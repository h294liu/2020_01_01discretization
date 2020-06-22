#!/bin/bash
set -e

# This script is to merge DEM rasters and clip useful domain
work_dir=/glade/u/home/hongli/work/research/discretization/optimize_hru/model
input_dir=${work_dir}/input
slp_file=${input_dir}/slope_buf_100m.tif
# asp_file=${input_dir}/aspect_buf_100m.tif
asp_file=${input_dir}/aspect_neg11.tif
sx_file=${input_dir}/sx.tif
nodata=-9999
sub_shp=${input_dir}/subbasin
sub_shp_prj=${input_dir}/sub_prj
elev_file=${input_dir}/elev_class
land_file=${input_dir}/land_class

sub_dir=/glade/u/home/hongli/work/research/discretization/scripts/shapefile/subbasin_prj

s_srs=EPSG:4269 # Source CRS: NAD83. Valid for both DEM.tif and HUC12 shp. 
t_srs=EPSG:26913 #'+proj=utm +zone=13 +datum=NAD83' # Reproject/transform to this SRS on output.

slp_thrsh1=20
slp_thrsh2=45
slp_thrsh3=55
asp_thrsh1=45
asp_thrsh2=90
asp_thrsh3=123

temp_folder=${work_dir}/temp
if [ ! -d $temp_folder ]; then mkdir -p $temp_folder; fi
ofolder=${work_dir}/output
if [ ! -d $ofolder ]; then mkdir -p $ofolder; fi
for subfolder in slope aspect2; do
    if [ ! -d $temp_folder/$subfolder ]; then mkdir -p $temp_folder/$subfolder; fi
done

slp_class_raster=slp_class.tif
slp_raw_shp=slp_class_raw
slp_shp=slp_class

asp_class_raster=asp_class.tif
asp_raw_shp=asp_class_raw
asp_shp=asp_class

# load module
module unload netcdf
module gdal

# =====================reclassify slope=========================
echo reclassify slope

cd ${temp_folder}/slope

# slope range is [0,79]. Three thresholds: slp_thrsh1, slp_thrsh2, slp_thrsh3.
if [ -f ${slp_class_raster} ]; then rm ${slp_class_raster}; fi 
gdal_calc.py -A ${slp_file} --outfile=${slp_class_raster} --calc="1*((A>=0)*(A<=${slp_thrsh1}))+2*((A>${slp_thrsh1})*(A<=${slp_thrsh2}))+3*((A>${slp_thrsh2})*(A<=${slp_thrsh3}))+4*((A>${slp_thrsh3})*(A<=79))" --NoDataValue=${nodata} --quiet --overwrite

# subbasin process
FILES=( $(ls ${sub_dir}/*.gpkg) )
FILE_NUM=${#FILES[@]}
for i in $(seq 0 $(($FILE_NUM -1))); do
# for i in $(seq 0 2); do

    # idenfiy subbasin name
    FilePath=${FILES[${i}]} 
    FileName=${FilePath##*/} # get basename of filename
    FileNameShort="${FileName/.gpkg/}" # remove suffix ".txt"
    echo $FileNameShort
    
    # define files names
    sub_slp_raster=${FileNameShort}_slp.tif
    sub_slp_shp=${FileNameShort}_slp
    sub_slp_disslv=${FileNameShort}_slp_disslv

    # (1) clip subbasin's slope 
    gdalwarp -t_srs ${t_srs} -cutline $FilePath -srcnodata "-9999" -dstnodata "-9999" -overwrite ${slp_class_raster} ${sub_slp_raster}

    # (2) save raster to shapefile
    gdal_polygonize.py ${sub_slp_raster} -f "ESRI Shapefile" ${sub_slp_shp}.shp "" "slope"

    # (3) dissolve attribute
    echo dissolve ${FileNameShort} slope
    ogr2ogr -overwrite -f GPKG ${sub_slp_disslv}.gpkg ${sub_slp_shp}.shp -dialect sqlite -sql "SELECT ST_Union(geometry), slope FROM ${sub_slp_shp} GROUP BY slope"

    # remove unecessary files
    for file in ${sub_slp_raster} ${sub_slp_shp}.*; do 
        if [ -f ${file} ]; then rm -r ${file}; fi; 
    done
    
done

# =====================reclassify aspect=========================
echo reclassify aspect 

cd ${temp_folder}/aspect

# aspect range is [-1,180]. Three thresholds: slp_thrsh1, slp_thrsh2, slp_thrsh3.
if [ -f ${asp_class_raster} ]; then rm ${asp_class_raster}; fi  
gdal_calc.py -A ${asp_file} --outfile=${asp_class_raster} --calc="-1*(A==-1)+1*((A>=0)*(A<=${asp_thrsh1}))+2*((A>${asp_thrsh1})*(A<=${asp_thrsh2}))+3*((A>${asp_thrsh2})*(A<=${asp_thrsh3}))" --NoDataValue=${nodata} --quiet --overwrite

# subbasin process
FILES=( $(ls ${sub_dir}/*.gpkg) )
FILE_NUM=${#FILES[@]}
for i in $(seq 0 $(($FILE_NUM -1))); do
# for i in $(seq 0 2); do

    # idenfiy subbasin name
    FilePath=${FILES[${i}]} 
    FileName=${FilePath##*/} # get basename of filename
    FileNameShort="${FileName/.gpkg/}" # remove suffix ".txt"
    echo $FileNameShort
    
    # define files names
    sub_asp_raster=${FileNameShort}_asp.tif
    sub_asp_shp=${FileNameShort}_asp
    sub_asp_disslv=${FileNameShort}_asp_disslv 

    # (1) clip subbasin's aspect     
    gdalwarp -t_srs ${t_srs} -cutline $FilePath -srcnodata "-9999" -dstnodata "-9999" -overwrite ${asp_class_raster} ${sub_asp_raster} #-crop_to_cutline 

    # (2) save raster to shapefile
    gdal_polygonize.py ${sub_asp_raster} -f "ESRI Shapefile" ${sub_asp_shp}.shp "" "aspect"

    # (3) dissolve attribute
    echo dissolve ${FileNameShort} aspect
    ogr2ogr -overwrite -f GPKG ${sub_asp_disslv}.gpkg ${sub_asp_shp}.shp -dialect sqlite -sql "SELECT ST_Union(geometry), aspect FROM ${sub_asp_shp} GROUP BY aspect"

    # remove unecessary files
    for file in ${sub_asp_raster} ${sub_asp_shp}.*; do 
        if [ -f ${file} ]; then rm -r ${file}; fi; 
    done
    
done

cd ${work_dir}
echo Done

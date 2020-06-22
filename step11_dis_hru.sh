#!/bin/bash
set -e

# This script is to merge DEM rasters and clip useful domain
work_dir=/glade/u/home/hongli/work/research/discretization/optimize_hru/model
input_dir=${work_dir}/input

slp_file=${input_dir}/slope_buf_100m.tif
# asp_file=${input_dir}/aspect_buf_100m.tif
asp_file=${input_dir}/aspect_neg1.tif
sx_file=${input_dir}/sx.tif
nodata=-9999

sub_shp=${input_dir}/subbasin
sub_shp_prj=${input_dir}/sub_prj
elev_file=${input_dir}/elev_class
land_file=${input_dir}/land_class

s_srs=EPSG:4269 # Source CRS: NAD83. Valid for both DEM.tif and HUC12 shp. 
t_srs=EPSG:26913 #'+proj=utm +zone=13 +datum=NAD83' # Reproject/transform to this SRS on output.

slp_thrsh1=20
slp_thrsh2=45
slp_thrsh3=55
asp_thrsh1=60
asp_thrsh2=120
asp_thrsh3=180
asp_thrsh4=240
asp_thrsh5=320

temp_folder=${work_dir}/temp
if [ ! -d $temp_folder ]; then mkdir -p $temp_folder; fi
ofolder=${work_dir}/output
if [ ! -d $ofolder ]; then mkdir -p $ofolder; fi

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

cd ${temp_folder}

# slope range is [0,79]. Three thresholds: slp_thrsh1, slp_thrsh2, slp_thrsh3.
echo 1_reclassify
if [ -f ${slp_class_raster} ]; then rm ${slp_class_raster}; fi 
gdal_calc.py -A ${slp_file} --outfile=${slp_class_raster} --calc="1*((A>=0)*(A<=${slp_thrsh1}))+2*((A>${slp_thrsh1})*(A<=${slp_thrsh2}))+3*((A>${slp_thrsh2})*(A<=${slp_thrsh3}))+4*((A>${slp_thrsh3})*(A<=79))" --NoDataValue=${nodata} --quiet

# save raster to shapefile
echo 2_save to shapefile
if [ -f ${slp_raw_shp}.shp ]; then rm ${slp_raw_shp}.shp; fi 
gdal_polygonize.py ${slp_class_raster} -f "ESRI Shapefile" ${slp_raw_shp}.shp "" "slope"

# dissolve attribute
echo 3_dissolve slope
if [ -f ${slp_shp}.gpkg ]; then rm ${slp_shp}.gpkg; fi  
ogr2ogr -overwrite -f GPKG ${slp_shp}.gpkg ${slp_raw_shp}.shp -dialect sqlite -sql "SELECT ST_Union(geometry), slope FROM ${slp_raw_shp} GROUP BY slope"

# =====================reclassify aspect=========================
echo reclassify aspect 

cd ${temp_folder}

# aspect range is [0,360]. Five thresholds: slp_thrsh1, slp_thrsh2, slp_thrsh3,slp_thrsh4, slp_thrsh5.
echo 1_reclassify
if [ -f ${asp_class_raster} ]; then rm ${asp_class_raster}; fi  
gdal_calc.py -A ${asp_file} --outfile=${asp_class_raster} --calc="-1*(A==-1)+1*((A>=0)*(A<=${asp_thrsh1}))+2*((A>${asp_thrsh1})*(A<=${asp_thrsh2}))+3*((A>${asp_thrsh2})*(A<=${asp_thrsh3}))+4*((A>${asp_thrsh3})*(A<=${asp_thrsh4}))+5*((A>${asp_thrsh4})*(A<=${asp_thrsh5}))+6*((A>${asp_thrsh5})*(A<=360))" --NoDataValue=${nodata} --quiet

# save raster to shapefile
echo 2_save to shapefile
if [ -f ${asp_raw_shp}.* ]; then rm ${asp_raw_shp}.*; fi  
gdal_polygonize.py ${asp_class_raster} -f "ESRI Shapefile" ${asp_raw_shp}.shp "" "aspect"

# dissolve attribute
echo 3_dissolve slope
if [ -f ${asp_shp}.gpkg ]; then rm ${asp_shp}.gpkg; fi  
ogr2ogr -overwrite -f GPKG ${asp_shp}.gpkg ${asp_raw_shp}.shp -dialect sqlite -sql "SELECT ST_Union(geometry), aspect FROM ${asp_raw_shp} GROUP BY aspect"

cd ${work_dir}
echo Done

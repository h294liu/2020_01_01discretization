#!/bin/bash
set -e

# This script is to merge DEM rasters and clip useful domain
work_dir=/glade/u/home/hongli/work/research/discretization/scripts
input_dir=${work_dir}/input
slp_file=${input_dir}/slope.tif
asp_file=${input_dir}/aspect.tif
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

ofolder=${work_dir}/output
if [ ! -d $ofolder ]; then mkdir -p $ofolder; fi

slp_class_raster=slp_class.tif
slp_shp=slp_class_raw
slp_disslv_shp=slp_class

asp_class_raster=asp_class.tif
asp_shp=asp_class_raw
asp_disslv_shp=asp_class

# load module
module unload netcdf
module gdal

cd ${ofolder}
# =====================split subabsin=========================
echo split subabsin
# (1) project subbasin.shp to UTM 13N   
if [ ! -f ${sub_shp_prj} ]; then 
ogr2ogr -t_srs ${t_srs} -f "ESRI Shapefile" ${sub_shp_prj}.shp ${sub_shp}.shp 
fi

# # (2) split subbasin.shp into subbasins
# ogr2ogr -clipsrc spat_extent -clipsrcwhere

# =====================reclassify slope=========================
echo reclassify slope
for file in ${slp_class_raster} ${slp_shp}.shp ${slp_disslv_shp}.shp; do if [ -f ${file} ]; then rm ${file}; fi; done  

# (1) reclassify
# slope range is [0,79]. Three thresholds: slp_thrsh1, slp_thrsh2, slp_thrsh3.
gdal_calc.py -A ${slp_file} --outfile=${slp_class_raster} --calc="1*((A>=0)*(A<=${slp_thrsh1}))+2*((A>${slp_thrsh1})*(A<=${slp_thrsh2}))+3*((A>${slp_thrsh2})*(A<=${slp_thrsh3}))+4*((A>${slp_thrsh3})*(A<=79))" --NoDataValue=${nodata} --quiet

# (2) save raster to shapefile
gdal_polygonize.py ${slp_class_raster} -f "ESRI Shapefile" ${slp_shp}.shp

# (3) dissolve attribute
ogr2ogr ${slp_disslv_shp}.shp ${slp_shp}.shp -dialect sqlite -sql "SELECT ST_Union(geometry), DN FROM ${slp_shp} GROUP BY DN"

# =====================reclassify aspect=========================
echo reclassify aspect 
for file in ${asp_class_raster} ${asp_shp}.shp ${asp_disslv_shp}.shp; do if [ -f ${file} ]; then rm ${file}; fi; done  

# (1) reclassify
# aspect range is [0,360]. Five thresholds: slp_thrsh1, slp_thrsh2, slp_thrsh3,slp_thrsh4, slp_thrsh5.
gdal_calc.py -A ${asp_file} --outfile=${asp_class_raster} --calc="1*((A>=0)*(A<=${asp_thrsh1}))+2*((A>${asp_thrsh1})*(A<=${asp_thrsh2}))+3*((A>${asp_thrsh2})*(A<=${asp_thrsh3}))+4*((A>${asp_thrsh3})*(A<=${asp_thrsh4}))+5*((A>${asp_thrsh4})*(A<=${asp_thrsh5}))+6*((A>${asp_thrsh5})*(A<=360))" --NoDataValue=${nodata} --quiet

# (2) save raster to shapefile
gdal_polygonize.py ${asp_class_raster} -f "ESRI Shapefile" ${asp_shp}.shp

# (3) dissolve attribute
ogr2ogr ${asp_disslv_shp}.shp ${asp_shp}.shp -dialect sqlite -sql "SELECT ST_Union(geometry), DN FROM ${asp_shp} GROUP BY DN"

cd ${work_dir}
echo Done

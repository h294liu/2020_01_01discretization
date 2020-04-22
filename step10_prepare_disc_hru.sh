#!/bin/bash
set -e

# This script is to merge DEM rasters and clip useful domain
work_dir=/glade/u/home/hongli/work/research/discretization/scripts
dem_file=${work_dir}/step2_dem_postprocess/dem.tif
nodata=-9999

shp_dir=${work_dir}/shapefile
wtsh_shp=watershed
wtsh_shp_prj=watershed_prj
land_dir=${work_dir}/shapefile/NLCD_2016_Land_Cover_L48_20190424
land_file=NLCD_2016_Land_Cover_L48_20190424.img

s_srs=EPSG:4269 # Source CRS: NAD83. Valid for both DEM.tif and HUC12 shp. 
t_srs=EPSG:26913 #'+proj=utm +zone=13 +datum=NAD83' # Reproject/transform to this SRS on output.

ofolder=$work_dir/step10_prepare_disc_hru
if [ ! -d $ofolder ]; then mkdir -p $ofolder; fi
elev_class_raster=elev_class.tif
elev_shp=elev_class_raw
elev_disslv_shp=elev_class

land_raster=land.tif
land_class_raster=land_class.tif
land_shp=land_class_raw
land_disslv_shp=land_class

# load module
module unload netcdf
module gdal

# =====================reclassify elevation=========================
echo reclassify elevation
cd ${ofolder}
for file in ${elev_class_raster} ${elev_shp}.shp ${elev_disslv_shp}.shp; do if [ -f ${file} ]; then rm ${file}; fi; done  

# (1) reclassify
# DEM range is [2037, 3764]. Recalssify interval is 250m.
gdal_calc.py -A ${dem_file} --outfile=${elev_class_raster} --calc="2250*((A>2000)*(A<=2250))+2500*((A>2250)*(A<=2500))+2750*((A>2500)*(A<=2750))+3000*((A>2750)*(A<=3000))+3250*((A>3000)*(A<=3250))+3500*((A>3250)*(A<=3500))+3750*((A>3500)*(A<=3800))" --NoDataValue=${nodata} --quiet

# (2) save raster to shapefile
gdal_polygonize.py ${elev_class_raster} -f "ESRI Shapefile" ${elev_shp}.shp

# (3) dissolve attribute
ogr2ogr ${elev_disslv_shp}.shp ${elev_shp}.shp -dialect sqlite -sql "SELECT ST_Union(geometry), DN FROM ${elev_shp} GROUP BY DN"

cd ${work_dir}

# =====================reclassify landcover=========================
echo reclassify landcover 

# (1) project watershed.shp from NAD83 to UTM 13N   
if [ ! -f ${wtsh_shp_prj} ]; then 
ogr2ogr -s_srs ${s_srs} -t_srs ${t_srs} -f "ESRI Shapefile" ${shp_dir}/${wtsh_shp_prj}.shp ${shp_dir}/${wtsh_shp}.shp # ogr2ogr dst_datasource_name src_datasource_name
fi

cd ${ofolder}
for file in ${land_raster} ${land_class_raster} ${land_disslv_shp}.shp ${land_shp}.shp; do if [ -f ${file} ]; then rm ${file}; fi; done  

# (2) clip
gdalwarp -t_srs ${t_srs} -cutline ${shp_dir}/${wtsh_shp_prj}.shp -crop_to_cutline -srcnodata "0" -dstnodata "0" ${land_dir}/${land_file} ${land_raster} 

# (3) reclassify
# 10 Water. 20 Developed. 30 Barren. 40 Forest (42 evergreen forest). 50 Shrubland. 70 Herbaceous. 80 Planted/Cultivated. 90 Wetlands.
gdal_calc.py -A ${land_raster} --outfile=${land_class_raster} --calc="10*((A>=10)*(A<=19))+20*((A>=20)*(A<=29))+30*((A>=30)*(A<=39))+40*((A>=40)*(A<=41))+42*(A==42)+40*((A>=43)*(A<=49))+50*((A>=51)*(A<=59))+70*((A>=70)*(A<=79))+80*((A>=80)*(A<=89))+90*((A>=90)*(A<=99))" --NoDataValue=0 --quiet

# (4) save raster to shapefile
gdal_polygonize.py ${land_class_raster} -f "ESRI Shapefile" ${land_shp}.shp

# (5) dissolve attribute
ogr2ogr ${land_disslv_shp}.shp ${land_shp}.shp -dialect sqlite -sql "SELECT ST_Union(geometry), DN FROM ${land_shp} GROUP BY DN"

cd ${work_dir}
echo Done

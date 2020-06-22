#!/bin/bash
set -e

# This script is to merge DEM rasters and clip useful domain
work_dir=/glade/u/home/hongli/work/research/discretization/scripts
dem_file=${work_dir}/step2_dem_postprocess/dem_buf_100m.tif
nodata=-9999

shp_dir=${work_dir}/shapefile
wtsh_shp=watershed_buf_100m
sub_dir=${work_dir}/shapefile/subbasin_prj

land_file=${work_dir}/shapefile/land_cover_resample/buff_100m_resample.tif

s_srs=EPSG:4269 # Source CRS: NAD83. Valid for both DEM.tif and HUC12 shp. 
t_srs=EPSG:26913 #'+proj=utm +zone=13 +datum=NAD83' # Reproject/transform to this SRS on output.

ofolder=$work_dir/step10_dem_landcover_process_buf_100m_for_sub
if [ ! -d $ofolder ]; then mkdir -p $ofolder; fi

for subfolder in elevation land; do
    if [ ! -d $ofolder/$subfolder ]; then mkdir -p $ofolder/$subfolder; fi
done

elev_class_raster=elev_class.tif
elev_class_raw_shp=elev_class_raw
elev_class_shp=elev_class

land_raster=land.tif
land_class_raster=land_class.tif
land_class_raw_shp=land_class_raw
land_class_shp=land_class

sub_shp=${shp_dir}/subbasin
sub_shp_prj=${shp_dir}/subbasin_prj

# load module
module unload netcdf
module gdal

cd $ofolder

# =====================reclassify elevation=========================
echo reclassify elevation
cd ${ofolder}/elevation

# # (1) reclassify
# # DEM range is [2037, 3764]. Recalssify interval is 250m.
# for file in ${elev_class_raster}; do if [ -f ${file} ]; then rm ${file}; fi; done  
# gdal_calc.py -A ${dem_file} --outfile=${elev_class_raster} --calc="2250*((A>2000)*(A<=2250))+2500*((A>2250)*(A<=2500))+2750*((A>2500)*(A<=2750))+3000*((A>2750)*(A<=3000))+3250*((A>3000)*(A<=3250))+3500*((A>3250)*(A<=3500))+3750*((A>3500)*(A<=3800))" --NoDataValue=${nodata} --quiet

# (2) subbasin process
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
    sub_elev_raster=${FileNameShort}_elev.tif
    sub_elev_shp=${FileNameShort}_elev
    sub_elev_disslv=${FileNameShort}_elev_disslv

    # (1) clip subbasin's elev and land  
    echo clip
    gdalwarp -cutline $FilePath -srcnodata "-9999" -dstnodata "-9999" ${elev_class_raster} ${sub_elev_raster}

    # (2) save raster to shapefile
    echo save
    gdal_polygonize.py ${sub_elev_raster} -f "ESRI Shapefile" ${sub_elev_shp}.shp "" "elevation" #

    # (3) dissolve attribute
    echo dissolve ${FileNameShort} elevation
    ogr2ogr -overwrite -f GPKG ${sub_elev_disslv}.gpkg ${sub_elev_shp}.shp -dialect sqlite -sql "SELECT ST_Union(geometry), elevation FROM ${sub_elev_shp} GROUP BY elevation"

    # remove unecessary files
    for file in ${sub_elev_raster} ${sub_elev_shp}.*; do 
        if [ -f ${file} ]; then rm -r ${file}; fi; 
    done
    
done
cd ${work_dir}

# =====================reclassify landcover=========================
echo reclassify landcover 
cd ${ofolder}/land

for file in ${land_raster} ${land_class_raster}; do if [ -f ${file} ]; then rm ${file}; fi; done  

# (1) clip
gdalwarp -t_srs ${t_srs} -cutline ${shp_dir}/${wtsh_shp}.shp -srcnodata "0" -dstnodata "0" ${land_file} ${land_raster} 

# (2) reclassify
# 10 Water. 20 Developed. 30 Barren. 40 Forest (42 evergreen forest). 50 Shrubland. 70 Herbaceous. 80 Planted/Cultivated. 90 Wetlands.
gdal_calc.py -A ${land_raster} --outfile=${land_class_raster} --calc="10*((A>=10)*(A<=19))+20*((A>=20)*(A<=29))+30*((A>=30)*(A<=39))+40*((A>=40)*(A<=41))+42*(A==42)+40*((A>=43)*(A<=49))+50*((A>=51)*(A<=59))+70*((A>=70)*(A<=79))+80*((A>=80)*(A<=89))+90*((A>=90)*(A<=99))" --NoDataValue=0 --quiet

# (3) subbasin process
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
    sub_land_raster=${FileNameShort}_land.tif
    sub_land_shp=${FileNameShort}_land
    sub_land_disslv=${FileNameShort}_land_disslv 

    # (1) clip subbasin's land  
    echo clip
    gdalwarp -cutline $FilePath -srcnodata "-9999" -dstnodata "-9999" ${land_class_raster} ${sub_land_raster}

    # (2) save raster to shapefile
    echo save
    gdal_polygonize.py ${sub_land_raster} -f "ESRI Shapefile" ${sub_land_shp}.shp "" "land"

    # (3) dissolve attribute
    echo dissolve ${FileNameShort} land
    ogr2ogr -overwrite -f GPKG ${sub_land_disslv}.gpkg ${sub_land_shp}.shp -dialect sqlite -sql "SELECT ST_Union(geometry), land FROM ${sub_land_shp} GROUP BY land"

    # remove unecessary files
    for file in ${sub_land_raster} ${sub_land_shp}.*; do 
        if [ -f ${file} ]; then rm -r ${file}; fi; 
    done
    
done

cd ${work_dir}
echo Done


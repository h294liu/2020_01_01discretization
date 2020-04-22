#!/bin/bash
set -e

# This script is to merge DEM rasters and clip useful domain
work_dir=/glade/u/home/hongli/work/research/discretization/scripts
dem_dir=$work_dir/step1_download_dem
ofile_merge=merge.tif

shp_dir=${work_dir}/shapefile
wtsh_shp=watershed
wtsh_shp_prj=watershed_prj

s_srs=EPSG:4269 # Source CRS: NAD83. Valid for both DEM.tif and HUC12 shp. 
t_srs=EPSG:26913 #'+proj=utm +zone=13 +datum=NAD83' # Reproject/transform to this SRS on output.

ofolder=$work_dir/step2_dem_postprocess
if [ -d $ofolder ]; then rm -r $ofolder; fi; mkdir -p $ofolder
sub_file=$work_dir/shapefile/subbasin.shp
ofile_dem=dem.tif
ofile_slp=slope.tif
ofile_asp=aspect.tif

buf_dist=1000 #meter
wtsh_shp_buf=${wtsh_shp}_buf
ofile_dem_buf=dem_buf.tif
ofile_slp_buf=slope_buf.tif
ofile_asp_buf=aspect_buf.tif

# =====================preprocess=========================
# load module
module unload netcdf
module gdal

# merge downloaded DEM. Once for all.
if [ ! -f ${dem_dir}/${ofile_merge} ]; then
    echo merge dem
    gdal_merge.py -o ${dem_dir}/${ofile_merge} $(ls ${dem_dir}/USGS_13_*.tif)
fi

# =====================project and buffer=========================
echo project and buffer
# buffer watershed shapefile
cd ${shp_dir}
# project watershed.shp from NAD83 to UTM 13N   
if [ -f ${wtsh_shp_prj} ]; then rm ${wtsh_shp_prj}*; fi
ogr2ogr -s_srs ${s_srs} -t_srs ${t_srs} -f "ESRI Shapefile" ${wtsh_shp_prj}.shp ${wtsh_shp}.shp # ogr2ogr dst_datasource_name src_datasource_name

# buffer 
if [ -f ${wtsh_shp_buf} ]; then rm ${wtsh_shp_buf}*; fi
ogr2ogr -f "ESRI Shapefile" ${wtsh_shp_buf}.shp ${wtsh_shp_prj}.shp -dialect sqlite -sql "select ST_buffer(geometry, ${buf_dist}) as geometry FROM ${wtsh_shp_prj}"
cd ${work_dir}

# =====================raw raster process=========================
echo raw raster process
cd ${ofolder}
# clip
gdalwarp -t_srs ${t_srs} -cutline ${shp_dir}/${wtsh_shp_prj}.shp -crop_to_cutline -srcnodata "-999999" -dstnodata "-999999" ${dem_dir}/${ofile_merge} ${ofile_dem} #${sub_file}

# calculate slope and aspect 
gdaldem slope ${ofile_dem} ${ofile_slp}
gdaldem aspect ${ofile_dem} ${ofile_asp}
cd ${work_dir}

# =====================buffered raster process=========================
echo buffered raster process
cd ${ofolder}
# clip DEM based on buffered watershed
gdalwarp -t_srs ${t_srs} -cutline ${shp_dir}/${wtsh_shp_buf}.shp -crop_to_cutline -srcnodata "-999999" -dstnodata "-999999" ${dem_dir}/${ofile_merge} ${ofile_dem_buf} #-dstalpha

# calculate slope and aspect
gdaldem slope ${ofile_dem_buf} ${ofile_slp_buf}
gdaldem aspect ${ofile_dem_buf} ${ofile_asp_buf}
cd ${work_dir}

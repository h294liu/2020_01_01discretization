# -*- coding: utf-8 -*-
"""
Created on Mon Nov 25 10:06:53 2019

@author: hongl
"""

# This script is used to calcualte the CDF difference for shortwave radiation (Sw) and maximum upwind slope (Sx)

import os
import numpy as np
import pandas as pd
from osgeo import gdal
gdal.UseExceptions()

def read_raster(raster_file, var_name, area_name):
    r = gdal.Open(raster_file)
    band = r.GetRasterBand(1) 
    data = band.ReadAsArray().astype(np.float)
    data_1d = data[~np.isnan(data)]

    gt =r.GetGeoTransform()
    pixelWidth = gt[1] # unit: m
    pixelHeight = -gt[5]
    pixelArea = pixelWidth*pixelHeight    

    (unique, counts) = np.unique(data_1d, return_counts=True)
    frequencies = np.asarray((unique, counts)).T
    frequencies[:,1]=frequencies[:,1]*pixelArea

    df = pd.DataFrame(frequencies, columns = [var_name, area_name]) 
    return df   

def get_cdf_error(raw_df, raw_var, raw_area, dis_df, dis_var, dis_area):

    # get raw grid cell and hru numbers
    raw_num = len(raw_df)
    hru_num =  len(dis_df)

    # sort dataframe based on interested variable values
    raw_df_sort = raw_df.sort_values(by=[raw_var])
    dis_df_sort = dis_df.sort_values(by=[dis_var])
    
    # create evenly spaced variable values 
    line_var_num = 100
    line_var = np.reshape(np.linspace(0.9*np.minimum(np.amin(raw_df_sort[raw_var].values), np.amin(dis_df_sort[dis_var].values)),
                    1.1*np.maximum(np.amax(raw_df_sort[raw_var].values), np.amax(dis_df_sort[dis_var].values)),
                    num=line_var_num),[line_var_num,1])
    
    # calculate variable cdf in raw_cdf
    line_var_rep = np.repeat(line_var, raw_num, axis=1) # shape [line_var_num, raw_num]
    raw_var_rep = np.repeat(np.reshape(raw_df_sort[raw_var].values, [1, raw_num]), line_var_num, axis=0) 
    raw_area_rep =  np.repeat(np.reshape(raw_df_sort[raw_area].values, [1, raw_num]), line_var_num, axis=0)
    
    condition_area = np.where(line_var_rep>raw_var_rep, raw_area_rep, 0.0)
    condition_area_cumsum = np.sum(condition_area, axis=1)
    total_area = np.sum(raw_area_rep, axis=1)
    line_var_cdf_in_raw = np.divide(condition_area_cumsum,total_area)
    #line_var_cdf = np.divide(np.sum(np.where(line_var_rep>raw_var_rep, raw_area_rep, 0.0), axis=1), raw_num)
    del line_var_rep, raw_var_rep, raw_area_rep, condition_area, condition_area_cumsum, total_area
    
    # calculate variable in hru_cdf
    line_var_rep = np.repeat(line_var, hru_num, axis=1) # shape [line_var_num, hru_num]
    dis_var_rep = np.repeat(np.reshape(dis_df_sort[dis_var].values, [1, hru_num]), line_var_num, axis=0) 
    hru_area_rep =  np.repeat(np.reshape(dis_df_sort[dis_area].values, [1, hru_num]), line_var_num, axis=0)
    
    condition_area = np.where(line_var_rep>dis_var_rep, hru_area_rep, 0.0) # Area array with elements from hru_area_rep where condition is True, and 0 elsewhere.
    condition_area_cumsum = np.sum(condition_area, axis=1)
    total_area = np.sum(hru_area_rep, axis=1)
    line_var_cdf_in_hru = np.divide(condition_area_cumsum,total_area)
    del line_var_rep, dis_var_rep, hru_area_rep, condition_area, condition_area_cumsum, total_area
    
    # calucalte CDF difference
    cdf_dif = np.abs(line_var_cdf_in_raw-line_var_cdf_in_hru)
    line_var = np.reshape(line_var, np.shape(cdf_dif))
    var_error = np.trapz(cdf_dif, x=line_var)

    # relative error (normalized Wasserstein distance)     
    var_base = np.trapz(line_var_cdf_in_raw, x=line_var)    
    var_error_relative = var_error/var_base
    
    #  Kolmogorov–Smirnov statistic
    cdf_dif_max = max(cdf_dif)
    return var_error_relative, cdf_dif_max

root_dir = '/glade/u/home/hongli/work/research/discretization/scripts'
sw_raster = os.path.join(root_dir,'step9_merge_raw_Sw/sw_buf_100m.tif')
sx_raster = os.path.join(root_dir,'step7_merge_raw_Sx/sx_buf_100m.tif')
nodata=-9999
hru_file = os.path.join(root_dir,'stepx6_hru_attrib.csv')
ofile = os.path.join(root_dir,'Diagnostics.txt')

sw_var_raw = 'Sw'
sx_var_raw = 'Sx'
area_var_raw = 'area_m'

sw_var_dis = 'ZonalSw'
sx_var_dis = 'ZonalSx'
area_var_dis = 'area_m'

# read raw sw
raw_df_sw = read_raster(sw_raster, sw_var_raw, area_var_raw)
raw_df_sx = read_raster(sx_raster, sx_var_raw, area_var_raw)

# read discretization attributes
dis_df = pd.read_csv(hru_file, usecols=[area_var_dis, sw_var_dis, sx_var_dis])
    
# calculate cdf error
sw_error, sw_cdf_dif_max = get_cdf_error(raw_df_sw, sw_var_raw, area_var_raw, dis_df, sw_var_dis, area_var_dis)
sx_error, sx_cdf_dif_max = get_cdf_error(raw_df_sx, sx_var_raw, area_var_raw, dis_df, sx_var_dis, area_var_dis)

# output Diagnostics
f = open(ofile, 'w')
f.write('HRU_number, Sw_error, Sx_error, SW_cdf_dif_max, Sx_cdf_dif_max\n')
f.write('%d, ' % len(dis_df))
f.write('%.6f, ' % sw_error)
f.write('%.6f, ' % sx_error)
f.write('%.6f, ' % sw_cdf_dif_max)
f.write('%.6f' % sx_cdf_dif_max)
f.close()

del raw_df_sw, raw_df_sx, dis_df
print('Done')
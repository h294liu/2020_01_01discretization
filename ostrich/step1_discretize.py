#!/usr/bin/env python
# coding: utf-8

import arcpy, csv, os
from datetime import datetime
from glob import glob

begin_time = datetime.now()

arcpy.env.overwriteOutput = True
work_dir='C:/Users/hongl/Documents/2020-01-01Discretization/optimize_hru/trial1/model'

arcpy.env.workspace = os.path.join(work_dir,"temp")
arcpy.env.outputCoordinateSystem = arcpy.SpatialReference("NAD 1983 UTM Zone 13N")

arcpy_env_source =  os.path.join(work_dir,"input")
arcpy_env_output =  os.path.join(work_dir,"output")

subbasin_shp = os.path.join(arcpy_env_source, "sub_prj.shp")
elev_shp = os.path.join(arcpy_env_source, "elev_class_buf_100m.shp")
land_shp = os.path.join(arcpy_env_source, 'land_class_buf_100m.shp')

dem_raster = os.path.join(arcpy_env_source, 'dem_buf_100m.tif')
asp_raster = os.path.join(arcpy_env_source, 'aspect_buf_100m_arcgis_180scale.tif')
slp_raster = os.path.join(arcpy_env_source, 'slope_buf_100m.tif')
Sx_raster = os.path.join(arcpy_env_source, 'sx_buf_100m.tif')  
Sw_raster = os.path.join(arcpy_env_source, 'sw_buf_100m.tif')

slp_reclass = 'slope_class.tif'
slp_shp = 'slope_class.shp'

asp_reclass = 'aspect_class.tif'
asp_shp = 'aspect_class.shp'

union_shp = 'stepx2_hru_union.shp'
dissolveFields = ["SubID", "slope", "aspect", "elev", "land"] 
disslv_shp = 'stepx3_hru_disslv.shp'
disslv_lyr = "disslv_lyr"
hru_raw_shp = 'stepx4_hru_raw.shp'

hru_field = "HRU_ID"
hru_area_field = "area_m"
hru_lyr = 'hru_lyr'
elimn_lyr = 'elimn_lyr'
elimn_area_strict = 30*30 # m^2, one grid cell area. 
hru_shp = 'stepx5_hru.shp'

attributes=['ZonalElev', 'ZonalSlp', 'ZonalAspt', 'ZonalSx', 'ZonalSw']
attribute_rasters=[dem_raster, slp_raster, asp_raster, Sx_raster, Sw_raster]
tmp_hru_raster = 'tmp_raster.tif'
hru_attrib_shp = 'stepx6_hru_attrib.shp'
attrib_lyr_tmp='tmp_lyr'

if not os.path.exists(arcpy_env_output):
    os.makedirs(arcpy_env_output)
hru_csv = os.path.join(arcpy_env_output, hru_attrib_shp.split('.')[0]+'.csv')
csv_delimiter = ','

slp_thrsh1 = 1.000000E-03 #degree
slp_thrsh2 = 5.341419E+00
slp_thrsh3 = 1.204707E+01
asp_thrsh1 = 8.678029E+00 #degree
asp_thrsh2 = 1.139304E+02
asp_thrsh3 = 6.889857E+01
asp_thrsh4 = 7.5E+01
asp_thrsh5 = 4.0E+01
hru_area_percent_thrsh = 1.864107E-01 #percent of subbasin area

# Process starts
os.chdir(arcpy.env.workspace)

# Step 1. Reclassify slope into different categories
print('step1 reclassify slope')
if os.path.exists(slp_reclass):
    os.remove(slp_reclass)
slp_thrshs = map(float, [slp_thrsh1, slp_thrsh2, slp_thrsh3])
slp_thrshs.sort()
slope_reclass = arcpy.sa.Reclassify(slp_raster,
                                    "Value",arcpy.sa.RemapRange([[0,0,0],[0,slp_thrshs[0],1],
                                                                 [slp_thrshs[0],slp_thrshs[1],2],
                                                                 [slp_thrshs[1],slp_thrshs[2],3],
                                                                 [slp_thrshs[2],79,4]]))
slope_reclass.save(slp_reclass)

# Convert Raster to Shapefile and Save
tmp_slp_shp = arcpy.RasterToPolygon_conversion(slp_reclass, slp_shp,"NO_SIMPLIFY","Value")
arcpy.AddField_management(tmp_slp_shp, "slope", "SHORT")
arcpy.CalculateField_management(tmp_slp_shp, "slope", "!gridcode!", "PYTHON")

# Step 2. Reclassify aspect into different categories
print('step2 reclassify aspect')
if os.path.exists(asp_reclass):
    os.remove(asp_reclass)
asp_thrshs = map(float, [asp_thrsh1, asp_thrsh2, asp_thrsh3, asp_thrsh4, asp_thrsh5])
asp_thrshs.sort()
aspect_reclass = arcpy.sa.Reclassify(asp_raster,
                                     "Value",arcpy.sa.RemapRange([[-1,-1,-1],[0,asp_thrshs[0],1],
                                                                  [asp_thrshs[0],asp_thrshs[1],2],
                                                                  [asp_thrshs[1],asp_thrshs[2],3],
                                                                  [asp_thrshs[2],asp_thrshs[3],4],
                                                                  [asp_thrshs[3],asp_thrshs[4],5],
                                                                  [asp_thrshs[4],360,6]]))
aspect_reclass.save(asp_reclass)

# Convert Raster to Shapefile and Save
asp_reclass_shp = arcpy.RasterToPolygon_conversion(asp_reclass,asp_shp,"NO_SIMPLIFY","Value")
arcpy.AddField_management(asp_reclass_shp, "aspect", "SHORT")
arcpy.CalculateField_management(asp_reclass_shp, "aspect", "!gridcode!", "PYTHON")   

# Step 3. Union
print('step3 union')
inFeatures = [subbasin_shp, elev_shp, slp_shp, asp_shp, land_shp]
outFeatures = union_shp
arcpy.Union_analysis(inFeatures, outFeatures, "ALL")  

# Step 4: Dissolve
print('step4 dissolve')
arcpy.Dissolve_management(outFeatures, disslv_shp, dissolveFields)

# Step 5: Remove non-exisitng union area 
print('step5 remove non-existing HRU')
arcpy.MakeFeatureLayer_management(disslv_shp,disslv_lyr)
out_layer=arcpy.SelectLayerByAttribute_management(disslv_lyr, "NEW_SELECTION", ' "SubID" <> 0 AND "elev" <> 0.0 AND "slope" >= 0.0 AND "aspect" <> 0.0 AND "land" <> 0.0 ') 
arcpy.CopyFeatures_management(out_layer, hru_raw_shp)

#Step 6: Add Identifying Field
print('step6 identify HRU field')
arcpy.AddField_management(hru_raw_shp, hru_field,"TEXT",30)
arcpy.CalculateField_management(hru_raw_shp,hru_field,"'Sub' + str(!SubID!)  +'_E' +str(!elev!)+'_S' +str(!slope!)+'_A' +str(!aspect!)+'_L' +str(!land!)","PYTHON_9.3","")

# Step 7: Remove small HRUs less than threshold area
print('step7 remove small HRUs')

# Identify subbasins
sub_field = 'SubID'
valueList = []
rows = arcpy.SearchCursor(hru_raw_shp)
row = rows.next()
while row:
    aVal = row.getValue(sub_field)
    try:
        aVal = int(aVal)
    except ValueError:
        aVal = aVal    
    if aVal not in valueList:
        valueList.append(aVal)
    row = rows.next()

# Implement subbasin by subbasin
subShapeFiles = []
#for aVal in valueList:
for aVal in valueList:
    subShapeFile = 'Sub'+str(int(aVal))+'.shp'

    elimn_count = 0
    hru_shp_tmp = 'elimn_trial'+str(elimn_count)+'.shp'
    hru_lyr_tmp = 'elimn_lyr'+str(elimn_count) 
        
    whereClause = "%s = %s" % (sub_field, aVal)
    arcpy.MakeFeatureLayer_management(hru_raw_shp, "TempLayer", whereClause) #create layer for conditional features only
    arcpy.CopyFeatures_management("TempLayer", hru_shp_tmp) #save satisfying features into a shapefile
    arcpy.MakeFeatureLayer_management(hru_shp_tmp,hru_lyr_tmp) #create layer for the created shapefile

    # Calculate HRU area
    arcpy.AddField_management(hru_shp_tmp,hru_area_field,"DOUBLE")
    exp = "!SHAPE.AREA@SQUAREMETERS!"
    arcpy.CalculateField_management(hru_shp_tmp, hru_area_field, exp, "PYTHON_9.3")

    # Calculate subbasin area (only once before elimination)
    sub_area = 0
    with arcpy.da.SearchCursor(hru_shp_tmp, hru_area_field) as cursor:
        for row in cursor:
            sub_area = sub_area + row[0]
    hru_area_thrsh = sub_area*hru_area_percent_thrsh

    print(subShapeFile+', Sub area '+str(sub_area)+', Threshold area '+str(hru_area_thrsh)+ ' (m2)')

    # Identify initial eliminate HRUs        
    row_count = int(arcpy.GetCount_management(hru_lyr_tmp).getOutput(0))
    row_count_new = row_count
    
    arcpy.SelectLayerByAttribute_management(hru_lyr_tmp, "NEW_SELECTION", '"area_m" < '''+str(float(hru_area_thrsh)))
    sel_count = int(arcpy.GetCount_management(hru_lyr_tmp).getOutput(0))

    # Iterative elimination    
    print('Total HUR#, Target elimn HRU#, Actual elimn HRU#, New HRU# ') 
    while sel_count != 0 and elimn_count <= 15 and row_count_new > 1:
        
        # (1) eliminate
        hru_shp_tmp = 'elimn_trial'+str(elimn_count)+'.shp'
        hru_lyr_tmp = 'elimn_lyr'+str(elimn_count)

        elimn_count=elimn_count+1        
        hru_shp_tmp_new = 'elimn_trial'+str(elimn_count)+'.shp'       
        hru_lyr_tmp_new = 'elimn_lyr'+str(elimn_count)
        
        arcpy.MakeFeatureLayer_management(hru_shp_tmp, hru_lyr_tmp)
        row_count = int(arcpy.GetCount_management(hru_lyr_tmp).getOutput(0))
        arcpy.SelectLayerByAttribute_management(hru_lyr_tmp, "NEW_SELECTION", '"area_m" < '''+str(float(hru_area_thrsh)))
        arcpy.Eliminate_management(hru_lyr_tmp, hru_shp_tmp_new, "LENGTH")        
        
        # (2) update area
        exp = "!SHAPE.AREA@SQUAREMETERS!"
        arcpy.CalculateField_management(hru_shp_tmp_new, hru_area_field, exp, "PYTHON_9.3")
        arcpy.MakeFeatureLayer_management(hru_shp_tmp_new,hru_lyr_tmp_new)
        row_count_new = int(arcpy.GetCount_management(hru_lyr_tmp_new).getOutput(0))

        delta = row_count - row_count_new
        print(row_count, sel_count, delta, row_count_new)
      
        # (3) identify small HRUs
        arcpy.SelectLayerByAttribute_management(hru_lyr_tmp_new, "NEW_SELECTION", '"area_m" < '''+str(float(hru_area_thrsh)))
        sel_count = int(arcpy.GetCount_management(hru_lyr_tmp_new).getOutput(0))
    
    # Save eliminated subbasin shapefile
    if arcpy.Exists(subShapeFile):
        arcpy.Delete_management(subShapeFile)
    arcpy.CopyFeatures_management(hru_shp_tmp_new, subShapeFile)
        
    # Delete all temporaty files
    for tmp_file in glob(os.path.join(os.getcwd(), 'elimn_trial*.shp')): 
        arcpy.Delete_management(tmp_file)
    for tmp_file in glob(os.path.join(os.getcwd(), 'elimn_lyr*')): 
        arcpy.Delete_management(tmp_file) 
            
    # NOTE: Conduct a strict HRU area check ONLY IF ArcGIS fails detecting some small HRUs in zonal statistics
    elimn_count = 0
    hru_shp_tmp = 'strict_elimn_trial'+str(elimn_count)+'.shp'
    hru_lyr_tmp = 'strict_elimn_lyr'+str(elimn_count) 
    
    arcpy.CopyFeatures_management(subShapeFile, hru_shp_tmp)
    arcpy.MakeFeatureLayer_management(hru_shp_tmp,hru_lyr_tmp)

    row_count = int(arcpy.GetCount_management(hru_lyr_tmp).getOutput(0))
    row_count_new = row_count

    arcpy.SelectLayerByAttribute_management(hru_lyr_tmp, "NEW_SELECTION", 
                                                        '"area_m" < '''+str(float(elimn_area_strict)))
    sel_count = int(arcpy.GetCount_management(hru_lyr_tmp).getOutput(0))
    
    sel_count_initial = sel_count
    if sel_count_initial != 0 and row_count_new > 1 and sub_area > elimn_area_strict: #ONLY IF condition
        print('Strict eliminate')
        print('Total HUR#, Target elimn HRU#, Actual elimn HRU#, New HRU# ')
        while sel_count != 0 and elimn_count <= 15 and row_count_new > 1:

            # (1) eliminate
            hru_shp_tmp = 'strict_elimn_trial'+str(elimn_count)+'.shp'
            hru_lyr_tmp = 'strict_elimn_lyr'+str(elimn_count)
    
            elimn_count=elimn_count+1        
            hru_shp_tmp_new = 'strict_elimn_trial'+str(elimn_count)+'.shp'       
            hru_lyr_tmp_new = 'strict_elimn_lyr'+str(elimn_count)
            
            arcpy.MakeFeatureLayer_management(hru_shp_tmp, hru_lyr_tmp)
            row_count = int(arcpy.GetCount_management(hru_lyr_tmp).getOutput(0))
            arcpy.SelectLayerByAttribute_management(hru_lyr_tmp, "NEW_SELECTION", '"area_m" < '''+str(float(elimn_area_strict)))
            arcpy.Eliminate_management(hru_lyr_tmp, hru_shp_tmp_new, "LENGTH")        
            
            # (2) update area
            exp = "!SHAPE.AREA@SQUAREMETERS!"
            arcpy.CalculateField_management(hru_shp_tmp_new, hru_area_field, exp, "PYTHON_9.3")
            arcpy.MakeFeatureLayer_management(hru_shp_tmp_new,hru_lyr_tmp_new)
            row_count_new = int(arcpy.GetCount_management(hru_lyr_tmp_new).getOutput(0))
    
            delta = row_count - row_count_new
            print(row_count, sel_count, delta, row_count_new)
          
            # (3) identify small HRUs
            arcpy.SelectLayerByAttribute_management(hru_lyr_tmp_new, "NEW_SELECTION", '"area_m" < '''+str(float(elimn_area_strict)))
            sel_count = int(arcpy.GetCount_management(hru_lyr_tmp_new).getOutput(0))
            
        # Save eliminated subbasin shapefile
        if arcpy.Exists(subShapeFile):
            arcpy.Delete_management(subShapeFile)
        arcpy.CopyFeatures_management(hru_shp_tmp_new, subShapeFile)
            
        # Delete all temporaty files
        for tmp_file in glob(os.path.join(os.getcwd(), 'strict_elimn_trial*.shp')): 
            arcpy.Delete_management(tmp_file)
        for tmp_file in glob(os.path.join(os.getcwd(), 'strict_elimn_lyr*')): 
            arcpy.Delete_management(tmp_file) 
            
    subShapeFiles.append(subShapeFile)

# Merge all subbasins' HRUs into one shapefile
if arcpy.Exists(hru_shp):
    arcpy.Delete_management(hru_shp)
arcpy.Merge_management(subShapeFiles, hru_shp)

# Step 8: Zonal attribute
print('step8 zonal attribute')
# (1) Create an attribute shapefile, raster, and layer
if arcpy.Exists(hru_attrib_shp):
    arcpy.Delete_management(hru_attrib_shp) 
arcpy.CopyFeatures_management(hru_shp, hru_attrib_shp)
arcpy.MakeFeatureLayer_management(hru_attrib_shp, attrib_lyr_tmp) 

# (2) Calculate zonal statistics of elevation, slope, and aspect     
for j in range(len(attributes)):
    attrib = attributes[j]
    attribute_raster = attribute_rasters[j]

     # Add a new field        
    fieldnames = [field.name for field in arcpy.ListFields(hru_attrib_shp)]
    if not attrib in fieldnames:
        arcpy.AddField_management(hru_attrib_shp, attrib, "FLOAT")

    # Join the attribute feature layer to a zonal statistics table
    attrib_dbf = hru_attrib_shp.split('.')[0]+'_'+attrib+'_Stats.dbf'
    if arcpy.Exists(attrib_dbf):
        arcpy.Delete_management(attrib_dbf)
    OutStat = arcpy.sa.ZonalStatisticsAsTable(hru_attrib_shp, hru_field, attribute_raster, attrib_dbf, "DATA", "MEAN")
    arcpy.AddJoin_management(attrib_lyr_tmp, hru_field, attrib_dbf, hru_field)

    # Populate the newly created field with values from the joined table
    arcpy.CalculateField_management(attrib_lyr_tmp, attrib, "!MEAN!", "PYTHON_9.3")

    # Remove the join
    arcpy.RemoveJoin_management(attrib_lyr_tmp, attrib_dbf.split('.')[0])

# # (3) Calculate Centroid Longitude & Latitude
# fieldnames = [field.name for field in arcpy.ListFields(hru_attrib_shp)]
# if not "Longitude" in fieldnames:
#     arcpy.AddField_management(hru_attrib_shp,"Longitude","DOUBLE")
# expression = 'arcpy.PointGeometry(!Shape!.centroid,!Shape!.spatialReference).projectAs(arcpy.SpatialReference(4326)).centroid.X'
# arcpy.CalculateField_management(hru_attrib_shp, "Longitude", expression,"PYTHON_9.3")

# if not "Latitude" in fieldnames:
#     arcpy.AddField_management(hru_attrib_shp,"Latitude","DOUBLE")
# expression = 'arcpy.PointGeometry(!Shape!.centroid,!Shape!.spatialReference).projectAs(arcpy.SpatialReference(4326)).centroid.Y'
# arcpy.CalculateField_management(hru_attrib_shp, "Latitude", expression,"PYTHON_9.3")

# (4) Export attribute table to text
fld_list = arcpy.ListFields(hru_attrib_shp)
fld_names = [fld.name for fld in fld_list]

# Open the CSV file and write field names and data
with open(hru_csv, 'wb') as csv_file:
    writer = csv.writer(csv_file, delimiter=csv_delimiter)
    writer.writerow(fld_names)
    rows = arcpy.da.SearchCursor(hru_attrib_shp, fld_names)
    for row in rows:
        writer.writerow(row)
    del rows    

print('Done') 
print(datetime.now() - begin_time)  
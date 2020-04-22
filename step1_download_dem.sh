#!/bin/bash
set -e

# This script is to create and submit/run DEM download command
work_dir=/glade/u/home/hongli/work/research/discretization/scripts
script_dir=$work_dir #/glade/u/home/hongli/github/dem
script=step1_download_dem_function.py

url_file=$work_dir/ned16_20200324_173737.txt 

ofolder=$work_dir/step1_download_dem
if [ ! -d $ofolder ]; then mkdir -p $ofolder; fi

# command_folder=$work_dir/step1_download_dem_command
# if [ ! -d $command_folder ]; then mkdir -p $command_folder; fi
# cd $command_folder
# cp $script_dir/$script .

# Convert text files from the DOS format to the Unix
dos2unix $url_file

while IFS= read -r line
do
    url=$line
    echo $url
    
    # dem file name
    IFS='/' read -ra myarray1 <<< "$url"
    IFS='.' read -ra myarray2 <<< "${myarray1[-1]}"
    filename=${myarray2[0]}
    echo "$filename"
    
# 	# method 1: submit job	
#     # create job submission file
#     command_file=qsub_$filename.sh
#     if [ -e ${command_file} ]; then rm -rf ${command_file}; fi
    
# 	echo '#!/bin/bash' > ${command_file}
# 	echo "#PBS -N ${filename}" >> ${command_file}
# 	echo '#PBS -A P48500028' >> ${command_file}
# 	echo '#PBS -q regular' >> ${command_file}
# 	echo '#PBS -l walltime=00:10:00' >> ${command_file}
# 	echo '#PBS -l select=1:ncpus=1' >> ${command_file}
# 	echo '#PBS -j oe' >> ${command_file} # Merge output and error files
	
# 	echo 'export TMPDIR=/glade/scratch/hongli/tmp' >> ${command_file}
# 	echo 'mkdir -p $TMPDIR' >> ${command_file}
	
# 	echo "python ${script_dir}/${script} $url $ofolder" >> ${command_file}
# 	chmod 755 ${command_file}	
	
# 	#qsub ${command_file}
# 	sleep 0.2 
    
    # method 2: run command in login mode
    python ${script_dir}/${script} $url $ofolder
  
done < "$url_file"

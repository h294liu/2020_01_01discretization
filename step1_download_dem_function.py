# -*- coding: utf-8 -*-
"""
Created on Tue Oct 29 22:39:15 2019

@author: hongl
"""

import argparse, os
import urllib.request
import shutil

def process_command_line():
    '''Parse the commandline'''
    parser = argparse.ArgumentParser(description='Script to download TNM DEM.')
    parser.add_argument('url', 
                        help='url of DEM data.')
    parser.add_argument('opath',
                        help= 'output folder path.')
    args = parser.parse_args()
    return(args)

# main
if __name__ == '__main__':
    
    # process command line
    args = process_command_line()
    url = args.url
    opath = args.opath

    # Split on the rightmost / and take everything on the right side of that
    name = url.rsplit('/', 1)[-1]

    # use the urllib.request.urlopen to return a file-like object that represents an HTTP response 
    # copy it to a real file using shutil.copyfileobj
    # Download the file from `url` and save it locally under `filename`
    if name:
        print(name)
        filename = os.path.join(opath, name)
        with urllib.request.urlopen(url) as response, open(filename, 'wb') as out_file:
            shutil.copyfileobj(response, out_file)

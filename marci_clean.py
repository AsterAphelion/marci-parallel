import warnings
import sys
import numpy as np
from scipy import ndimage as ndi
import rasterio as rio

fname = sys.argv[1]

## Running this to silence a rasterio georeferencing warning that we don't really care about
## because it doesn't affect the processing. 
warnings.filterwarnings("ignore", category=rio.errors.NotGeoreferencedWarning)

a = rio.open(fname, mode='r+', driver='ISIS3')
b = a.read()

#Some code to find the summing mode and set size/cropping parameters accordingly.
im_width = b.shape[2]
summing = int(1024/im_width)
framelet_size = int(32/summing)
framelet_data = int(framelet_size/2)
start = np.where(b[0] > 0)[0][0] 
num_subframes = int(b[0, start::framelet_size].shape[0])
null_left = int(10/summing)
null_right = b.shape[2] - null_left

c = b.copy()

#first first row of valid pixels for each band in the cube
start_list = []

for i in range(b.shape[0]):
    
    start = np.where(b[i] > 0)[0][0] 
    finish = (framelet_size * num_subframes) + start
    crop = int(100/summing)
    working_copy = c[i, start:finish].copy()
    
    
    #Range 16 comes from the number of rows in a subframe. 32 is the number of rows in a subframe plus the number
    #of null pixels between subframes. Start from column 150 to avoid issues with the atmosphere and how it interacts
    #with the atmosphere.
    for j in range(framelet_data):
    
        size = working_copy[j::framelet_size]
        size = size.shape[0]

        lines = working_copy[j::framelet_size, null_left+crop:null_right-crop].copy()
        
        #First step: replace null pixels by averaging them with surrounding pixels
        
        lines[lines < 0] = -1
        null_inds = np.where(lines < 0)
        lines[null_inds[0], null_inds[1]] = (lines[null_inds[0], null_inds[1]-1] + 
                                            lines[null_inds[0], null_inds[1]+1]) / 2
        
        #Column bias removal. Technique: pull out each successive row, average all pixels in columns from all 
        #rows run a median filter to detect bright or dark columns, then remove column noise. Doing each 
        #individual row separately because I think this can remove some pixel level noise while we're at it.
        
        noise_det = np.average(lines, axis=0)
        med_filter = ndi.median_filter(noise_det, size=9, mode='nearest')
        noise_det = noise_det - med_filter
        lines = lines - noise_det

        working_copy[j::framelet_size, null_left+crop:null_right-crop] = lines
    
        
    c[i, start:finish] = working_copy

for i in range(c.shape[0]):
    a.write(c[i], i+1)

a.close()


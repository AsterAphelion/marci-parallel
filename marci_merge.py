import sys
import gc
import numpy as np
from scipy import ndimage as ndi
import rasterio as rio
from rasterio import shutil

fname1 = sys.argv[1]
fname2 = sys.argv[2]
fname3 = sys.argv[3]

#Open up our data files:
a = rio.open(fname1, mode='r', driver='ISIS3')
a1 = a.read()[0]

b = rio.open(fname2, mode='r', driver='ISIS3')
b1 = b.read()[0]
b.close
#keeping memory footprint as small as possible by deallocating the import
#objects and running garbage collection
del b 


#Create dummy cube to hold merged data
shutil.copy(a, fname3, driver='ISIS3')
a.close
del a
gc.collect()

#Mask arrays so we don't run into overflow errors with null values
a1 = np.ma.masked_where(a1 < 0, a1)
b1 = np.ma.masked_where(b1 < 0, b1)

 
#Trying to process the entire array at once tends to crash memory
#so we're going to take a divide and conquer approach by processing
#the array in six segments.

array_subdivs_x = np.linspace(0, a1.shape[1], num=8, dtype=int)
array_subdivs_y = np.linspace(0, a1.shape[0], num=4, dtype=int)


for i in range(len(array_subdivs_x)-1):
    for j in range(len(array_subdivs_y)-1):
        print("Section " + str(i) + " " + str(j))
        f1 = a1[array_subdivs_y[j]:array_subdivs_y[j+1], array_subdivs_x[i]:array_subdivs_x[i+1]].copy()
        f2 = b1[array_subdivs_y[j]:array_subdivs_y[j+1], array_subdivs_x[i]:array_subdivs_x[i+1]].copy()
        
        if ((np.all(f1.mask) == True) & (np.all(f2.mask) == True)):
            print("Skipped Section")
            continue

        mean_array = np.ma.array((f1, f2)).mean(axis=0)
        a1[array_subdivs_y[j]:array_subdivs_y[j+1], array_subdivs_x[i]:array_subdivs_x[i+1]] = mean_array.data
        del f1
        del f2
        del mean_array


a = rio.open(fname3, mode='r+', driver='ISIS3')
a.write(a1, 1)
a.close()

del a1
del b1
del a
gc.collect()

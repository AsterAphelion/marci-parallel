# marci-parallel
Parallelized processing pipeline for Mars Color Imager (MARCI) data.

## Requirements

- [ISIS3 installation](https://github.com/USGS-Astrogeology/ISIS3/blob/dev/README.md) with MRO SPICE Kernels downloaded
- [GNU Parallel package](https://www.gnu.org/software/parallel/)
- Python conda environment with [Rasterio](https://rasterio.readthedocs.io/en/latest/) (setup provided in requirements.txt)
- Lots of RAM (MARCI images are LARGE)

## Script Setup
This script needs to flip between running in a conda environment dedicated to ISIS and a separate environment for Python image processing. To do this you will need to change the path to the location of your conda startup script. I named the conda environments for ISIS3 and Python processing as 'isis' and 'images', respectively. If your conda environments are named differently, do a find and replace on these terms and change to match your conda environments for these tasks.

## Description
This is a shell script to process [Mars Color Imager](http://www.msss.com/all_projects/mro-marci.php) (MARCI) data from [NASA's Planetary Data System](https://pds-imaging.jpl.nasa.gov/volumes/mro.html) using ISIS3. The input is a MARCI .IMG file name (discard the file extension), and the outputs are 16-bit RGB .TIF files with the data in equirectangular global projection, and polar stereographic projection between latitude 60 and 90 for both north and south poles. MARCI has 5 bands in the VIS range; this script uses bands 1, 2, and 4, which correspond to the instrument's 425 nm, 550 nm, and 650 nm imaging channels.

This script is a parallelized version of a script [developed by Andy Britton](https://gist.github.com/KalofXeno/3f6ab83e4f8e49b53db5a5b67eac32a9). Standard processing with ISIS3 uses a single CPU core. This is a significant bottleneck at the map-projection stage, as each imaging band has two sets of images that need to be projected separately. It uses GNU Parallel to run multiple simultaneous map-projection processes to substantially reduce processing run-time. The script also calls a couple of Python scripts at different points to perform noise reduction and frame merging.

## Customization / Troubleshooting

### Dealing with crashes
Parallelization trades memory usage for improved run time. If parallelization exceeds available memory, the process will crash and throw an error. Should this occur, edit the script to adjust the number of simultaneous jobs (e.g. where it says 'parallel --jobs [#jobs]'). Crashing is most likely to occur during equirectangular map projection, as the large size of the image cubes at this step are memory intensive.

### Changing the bands used
At the 'crop' stage, change [.cub+#]. The numbers correspond to the following channels:

- 1: 425 nm
- 2: 550 nm
- 3: 600 nm
- 4: 650 nm
- 5: 725 nm

## Future improvements (?)

Here are some improvements I'd like to make to the pipeline. I am not sure that I can address these, but feel free to contact me if you have an approach that works. 

- **Photometric Correction for Opposition Effect** - Due to the slightly different look angle of each color channel, the opposition surge associated with the anti-solar point is spread out as a rainbow-colored streak. This can be reduced with a photometric correction algorithm in ISIS3, but requires more knowledge of photometric modeling than I currently have.

- **Oversaturated pixel correction** - Oversaturated pixels roll over to a DN value of 0. During image decompanding, these values are convolved with surrounding pixels, leading to large areas of dark, but non-0 DN values. These are difficult to filter and I am still experimenting with a way to handle these more accurately. 

- **Improved band merging** - MARCI is a pushframe imager, and because it is imaging the surface over a wide range of lighting conditions, small brightness gradients are typically present within each subframe. When these subframes are mosaicked together, they typically place a bright pixel on one subframe adjacent to a darker pixel in the next subframe to produce a barcode effect. The current Python script handles frame merging by averaging, which somewhat reduces the barcode effect, but it is still visible, especially when contrast enhancements are applied to the image. 

- **Automated SPICE Kernel smithing** - Small differences between the calculated and actual spacecraft orientation produce increasing geographic misalignment of color data away from nadir imaging. This might be addressable by measuring misalignment of these features and adjusting the pointing data accordingly. 

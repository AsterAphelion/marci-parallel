#$1 - File to Process (minus extension)
#2 - Storage Location

##Replace this with host directory for conda profile
source /home/justin/miniconda3/etc/profile.d/conda.sh

conda activate isis

# Generate the map templates

maptemplate map=$1_marci_eq.map projection=equirectangular londom=180 clon=0 clat=0 targopt=user targetname=mars rngopt=user rngopt=user minlat=-90 maxlat=90 minlon=-180 rngopt=user maxlon=180 resopt=mpp resolution=1000

maptemplate map=$1_marci_npole.map projection=polarstereographic clon=180 clat=90 targopt=user targetname=mars rngopt=user minlat=60 maxlat=90 minlon=0 maxlon=360 resopt=mpp resolution=1000

maptemplate map=$1_marci_spole.map projection=polarstereographic clon=180 clat=-90 targopt=user targetname=mars rngopt=user minlat=-90 maxlat=-60 minlon=0 maxlon=360 resopt=mpp resolution=1000

#MARCI IMG to Isis Cube
marci2isis from=$1.IMG to=$1  flip=no


#Update SPICE data for a camera cube
echo "Adding SPICE data"
echo "spiceinit from=$1.even.cub web=yes cknadir=yes shape=ellipsoid" > add_spice
echo "spiceinit from=$1.odd.cub web=yes cknadir=yes shape=ellipsoid" >> add_spice
parallel --jobs 2 < add_spice
rm add_spice

catlab from=$1.even.cub to=$1.proc.lbl

#Calibrate MARCI images
echo "Calibrating even and odd cubes" 
echo "marcical from=$1.even.cub to=$1.even.cal.cub" > calibrate_job
echo "marcical from=$1.odd.cub to=$1.odd.cal.cub" >> calibrate_job
parallel --jobs 2 < calibrate_job

#Remove intermediate files from import
rm calibrate_job
rm $1.even.cub
rm $1.odd.cub

catlab from=$1.even.cal.cub to=$1.proc.lbl append=true

#Now perform extra radiometric processing with custom python script
echo "Performing extra cleaning steps"
conda deactivate
conda activate images

python marci_clean.py $1.even.cal.cub
python marci_clean.py $1.odd.cal.cub

conda deactivate
conda activate isis

#Trim pixels outside of phase, incidence, and emission angles
echo "Performing photometric trimming"
echo "photrim maxemission=75 maxincidence=100 from=$1.even.cal.cub to=$1.even.trim.cub" > trim_job
echo "photrim maxemission=75 maxincidence=100 from=$1.odd.cal.cub to=$1.odd.trim.cub" >> trim_job
parallel --jobs 2 < trim_job

#Remove intermediate files from calibration step
rm trim_job
rm $1.even.cal.cub
rm $1.odd.cal.cub

catlab from=$1.even.trim.cub to=$1.proc.lbl append=true

echo "Cropping images and separating to multiple cubes"
echo "crop from=$1.even.trim.cub+4 to=$1.even.red.cub" > crop_job
echo "crop from=$1.even.trim.cub+2 to=$1.even.green.cub" >> crop_job
echo "crop from=$1.even.trim.cub+1 to=$1.even.blue.cub" >> crop_job
echo "crop from=$1.odd.trim.cub+4 to=$1.odd.red.cub" >> crop_job
echo "crop from=$1.odd.trim.cub+2 to=$1.odd.green.cub" >> crop_job
echo "crop from=$1.odd.trim.cub+1 to=$1.odd.blue.cub" >> crop_job

parallel --jobs 6 < crop_job

#Remove intermediate files from trimming step
rm crop_job
rm $1.even.trim.cub
rm $1.odd.trim.cub

catlab from=$1.even.red.cub to=$1.proc.lbl append=true


# Map project equatorial region 
# Project images
echo "Map projecting images"
echo "cam2map from=$1.even.red.cub map=$1_marci_eq.map pixres=map defaultrange=map trim=yes to=$1.even.red.eq.cub" > project_job
echo "cam2map from=$1.odd.red.cub map=$1_marci_eq.map pixres=map defaultrange=map trim=yes to=$1.odd.red.eq.cub" >> project_job
echo "cam2map from=$1.even.green.cub map=$1_marci_eq.map pixres=map defaultrange=map trim=yes to=$1.even.green.eq.cub" >> project_job
echo "cam2map from=$1.odd.green.cub map=$1_marci_eq.map pixres=map defaultrange=map trim=yes to=$1.odd.green.eq.cub" >> project_job
echo "cam2map from=$1.even.blue.cub map=$1_marci_eq.map pixres=map defaultrange=map trim=yes to=$1.even.blue.eq.cub" >> project_job
echo "cam2map from=$1.odd.blue.cub map=$1_marci_eq.map pixres=map defaultrange=map trim=yes to=$1.odd.blue.eq.cub" >> project_job

parallel --jobs 6 < project_job

catlab from=$1.proc.lbl to=$1.proc.eq.lbl
catlab from=$1.even.red.eq.cub to=$1.proc.eq.lbl append=true

echo "Merging even-odd frames"
conda deactivate
conda activate images
python marci_merge.py $1.even.red.eq.cub $1.odd.red.eq.cub $1.red.eq.cub
echo "Red cube merged"
python marci_merge.py $1.even.green.eq.cub $1.odd.green.eq.cub $1.green.eq.cub
echo "Green cube merged"
python marci_merge.py $1.even.blue.eq.cub $1.odd.blue.eq.cub $1.blue.eq.cub
echo "Blue cube merged"
conda deactivate
conda activate isis 


#Remove intermediate map-projection files
rm project_job
rm $1.even.red.eq.cub
rm $1.odd.red.eq.cub
rm $1.even.green.eq.cub
rm $1.odd.green.eq.cub
rm $1.even.blue.eq.cub
rm $1.odd.blue.eq.cub

echo "reduce from=$1.red.eq.cub to=$1.red.eq.browse.cub mode=total ons=3600 onl=1800" > reduce_job
echo "reduce from=$1.green.eq.cub to=$1.green.eq.browse.cub mode=total ons=3600 onl=1800" >> reduce_job
echo "reduce from=$1.blue.eq.cub to=$1.blue.eq.browse.cub mode=total ons=3600 onl=1800" >> reduce_job
parallel --jobs 3 < reduce_job

rm reduce_job

#Export equatorial image to a RGB product
echo "Exporting products"
isis2std red=$1.red.eq.cub green=$1.green.eq.cub blue=$1.blue.eq.cub to=$1_RGB_eq.tif mode=rgb format=tiff bittype=u16bit compression=lzw minpercent=0.2 maxpercent=99.7
isis2std red=$1.red.eq.browse.cub green=$1.green.eq.browse.cub blue=$1.blue.eq.browse.cub to=$1_RGB_browse_eq.jpg mode=rgb format=jpeg quality=95 minpercent=0.2 maxpercent=99.7


#Move files out of directory
mv $1_RGB_eq.tif $2

mv $1.proc.eq.lbl $2

#Remove intermediate files from merging cubes
rm $1.red.eq.cub
rm $1.green.eq.cub
rm $1.blue.eq.cub
rm $1.red.eq.browse.cub
rm $1.green.eq.browse.cub
rm $1.blue.eq.browse.cub
rm $1_RGB_eq.tfw
rm $1_RGB_eq.jgw 







# Map project south pole region 
# Project images
echo "Map projecting images"
echo "cam2map from=$1.even.red.cub map=$1_marci_spole.map pixres=map defaultrange=map trim=yes to=$1.even.red.spole.cub" > project_job
echo "cam2map from=$1.odd.red.cub map=$1_marci_spole.map pixres=map defaultrange=map trim=yes to=$1.odd.red.spole.cub" >> project_job
echo "cam2map from=$1.even.green.cub map=$1_marci_spole.map pixres=map defaultrange=map trim=yes to=$1.even.green.spole.cub" >> project_job
echo "cam2map from=$1.odd.green.cub map=$1_marci_spole.map pixres=map defaultrange=map trim=yes to=$1.odd.green.spole.cub" >> project_job
echo "cam2map from=$1.even.blue.cub map=$1_marci_spole.map pixres=map defaultrange=map trim=yes to=$1.even.blue.spole.cub" >> project_job
echo "cam2map from=$1.odd.blue.cub map=$1_marci_spole.map pixres=map defaultrange=map trim=yes to=$1.odd.blue.spole.cub" >> project_job

parallel --jobs 6 < project_job

catlab from=$1.proc.lbl to=$1.proc.spole.lbl
catlab from=$1.even.red.spole.cub to=$1.proc.spole.lbl append=true

echo "Merging even-odd frames"
conda deactivate
conda activate images
python marci_merge.py $1.even.red.spole.cub $1.odd.red.spole.cub $1.red.spole.cub
echo "Red cube merged"
python marci_merge.py $1.even.green.spole.cub $1.odd.green.spole.cub $1.green.spole.cub
echo "Green cube merged"
python marci_merge.py $1.even.blue.spole.cub $1.odd.blue.spole.cub $1.blue.spole.cub
echo "Blue cube merged"
conda deactivate
conda activate isis 

#Remove intermediate files from map projections
rm project_job
rm $1.even.red.spole.cub
rm $1.odd.red.spole.cub
rm $1.even.green.spole.cub
rm $1.odd.green.spole.cub
rm $1.even.blue.spole.cub
rm $1.odd.blue.spole.cub

echo "reduce from=$1.red.spole.cub to=$1.red.spole.browse.cub mode=total ons=1800 onl=1800" > reduce_job
echo "reduce from=$1.green.spole.cub to=$1.green.spole.browse.cub mode=total ons=1800 onl=1800" >> reduce_job
echo "reduce from=$1.blue.spole.cub to=$1.blue.spole.browse.cub mode=total ons=1800 onl=1800" >> reduce_job
parallel --jobs 3 < reduce_job

rm reduce_job

#Export equatorial image to a RGB product
echo "Exporting products"
isis2std red=$1.red.spole.cub green=$1.green.spole.cub blue=$1.blue.spole.cub to=$1_RGB_spole.tif mode=rgb format=tiff bittype=u16bit compression=lzw minpercent=0.2 maxpercent=99.7
isis2std red=$1.red.spole.browse.cub green=$1.green.spole.browse.cub blue=$1.blue.spole.browse.cub to=$1_RGB_browse_spole.jpg mode=rgb format=jpeg quality=95 minpercent=0.2 maxpercent=99.7


#Move files out of directory
mv $1_RGB_spole.tif $2
mv $1.proc.spole.lbl $2

#Remove intermediate files from merging cubes
rm $1.red.spole.cub
rm $1.green.spole.cub
rm $1.blue.spole.cub
rm $1.red.spole.browse.cub
rm $1.green.spole.browse.cub
rm $1.blue.spole.browse.cub
rm $1_RGB_spole.tfw
rm $1_RGB_browse_spole.jgw







# Map project north pole region 
# Project images
echo "Map projecting images"
echo "cam2map from=$1.even.red.cub map=$1_marci_npole.map pixres=map defaultrange=map trim=yes to=$1.even.red.npole.cub" > project_job
echo "cam2map from=$1.odd.red.cub map=$1_marci_npole.map pixres=map defaultrange=map trim=yes to=$1.odd.red.npole.cub" >> project_job
echo "cam2map from=$1.even.green.cub map=$1_marci_npole.map pixres=map defaultrange=map trim=yes to=$1.even.green.npole.cub" >> project_job
echo "cam2map from=$1.odd.green.cub map=$1_marci_npole.map pixres=map defaultrange=map trim=yes to=$1.odd.green.npole.cub" >> project_job
echo "cam2map from=$1.even.blue.cub map=$1_marci_npole.map pixres=map defaultrange=map trim=yes to=$1.even.blue.npole.cub" >> project_job
echo "cam2map from=$1.odd.blue.cub map=$1_marci_npole.map pixres=map defaultrange=map trim=yes to=$1.odd.blue.npole.cub" >> project_job

parallel --jobs 6 < project_job

catlab from=$1.proc.lbl to=$1.proc.npole.lbl
catlab from=$1.even.red.npole.cub to=$1.proc.npole.lbl append=true

# Combine even odd red
echo "Merging even-odd frames"
conda deactivate
conda activate images
python marci_merge.py $1.even.red.npole.cub $1.odd.red.npole.cub $1.red.npole.cub
echo "Red cube merged"
python marci_merge.py $1.even.green.npole.cub $1.odd.green.npole.cub $1.green.npole.cub
echo "Green cube merged"
python marci_merge.py $1.even.blue.npole.cub $1.odd.blue.npole.cub $1.blue.npole.cub
echo "Blue cube merged"

conda deactivate
conda activate isis 

#Remove intermediate files from map projections
rm project_job
rm $1.even.red.npole.cub
rm $1.odd.red.npole.cub
rm $1.even.green.npole.cub
rm $1.odd.green.npole.cub
rm $1.even.blue.npole.cub
rm $1.odd.blue.npole.cub

echo "reduce from=$1.red.npole.cub to=$1.red.npole.browse.cub mode=total ons=1800 onl=1800" > reduce_job
echo "reduce from=$1.green.npole.cub to=$1.green.npole.browse.cub mode=total ons=1800 onl=1800" >> reduce_job
echo "reduce from=$1.blue.npole.cub to=$1.blue.npole.browse.cub mode=total ons=1800 onl=1800" >> reduce_job
parallel --jobs 3 < reduce_job

rm reduce_job

#Export equatorial image to a RGB product
echo "Exporting products"
isis2std red=$1.red.npole.cub green=$1.green.npole.cub blue=$1.blue.npole.cub to=$1_RGB_npole.tif mode=rgb format=tiff bittype=u16bit compression=lzw minpercent=0.2 maxpercent=99.7
isis2std red=$1.red.npole.browse.cub green=$1.green.npole.browse.cub blue=$1.blue.npole.browse.cub to=$1_RGB_browse_npole.jpg mode=rgb format=jpeg quality=95 minpercent=0.2 maxpercent=99.7


conda deactivate

#Remove intermediate files from merging cubes
rm $1.red.npole.cub
rm $1.green.npole.cub
rm $1.blue.npole.cub
rm $1.red.npole.browse.cub
rm $1.green.npole.browse.cub
rm $1.blue.npole.browse.cub
rm $1_RGB_npole.tfw
rm $1_RGB_browse_npole.jgw

#Clean up directory by moving files to storage location
mv $1_RGB_npole.tif $2
mv $1.proc.npole.lbl $2


#Remove intermediate files
rm $1.even.red.cub
rm $1.odd.red.cub
rm $1.even.green.cub
rm $1.odd.green.cub
rm $1.even.blue.cub
rm $1.odd.blue.cub
rm $1_marci_eq.map
rm $1_marci_npole.map
rm $1_marci_spole.map
rm $1.proc.lbl

exit 0

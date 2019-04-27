ThermImageJ - Functions and Macros for ImageJ
================

ThermImageJ is a collection of ImageJ macros to allow for import and conversion of thermal image files to assist in extracting raw data from infrared thermal images and converting them to temperatures using standard equations in thermography.

ThermImageJ provides an open source tool for assisting with infrared thermographic analysis.

These macros will allow you to import most FLIR jpgs and videos and process the images in ImageJ.

ThermImageJ emerged from Thermimage (<https://github.com/gtatters/Thermimage>), an R package that has similar features, but with more emphasis on biological heat transfer analysis.

Version History
---------------

-   v 1.0: Released April, 2019

Compatibility
-------------

-   ThermImageJ was developed on OSX, and tested using ImageJ v1.52n. Many features require installation of command line tools that may present future challenges on different operating systems. Testing and troubleshooting is ongoing. Please report issues here: <https://github.com/gtatters/ThermImageJ/issues>

Requirements
------------

-   FIJI is Just ImageJ. Download instructions: <https://imagej.net/Fiji/Downloads>
-   Exiftool. Installation instructions: <http://www.sno.phy.queensu.ca/~phil/exiftool/install.html>
-   FFMPEG command line utility (static version). Download instructions: <https://ffmpeg.org/download.html>
-   Perl. Installation instructions: <https://www.perl.org/get.html>
-   A custom perl script, provided on this github repository, which can be downloaded and placed in a scripts folder with ImageJ. Link here: <https://github.com/gtatters/ThermImageJ/tree/master/scripts/split.pl/>
-   ThermImageJ macro toolset. A text file (.ijm) containing all the macros and functions: <https://github.com/gtatters/ThermImageJ/tree/master/toolsets/ThermImageJ.ijm/>
-   Additional Look Up Tables (LUTS), popularly used in thermal imaging, available on this github repository: <https://github.com/gtatters/ThermImageJ/tree/master/luts/>
-   Byte swapper plugin. Download instructions: <https://imagej.nih.gov/ij/plugins/swapper.html>

Installation Instructions
-------------------------

-   Install FIJI, exiftool, and perl according to the website instructions above.
-   Launch FIJI and follow any update instructions.
-   Launch FIJI--&gt;Help--&gt;Update, allow it to update any plug-ins, then while the update window is open, select **Manage update websites**, and ensure that the FFMPEG box is ticked. Select **ok**, then click the **Apply** option, and restart FIJI. This FFMPEG is required for importing avi files created during the conversion process, although it might require that you have FFMPEG installed .
-   Navigate to where FIJI is installed to find all the subfolders. On a Mac, you may need to right-click and click **Show Package Contents** to open up FIJI as a folder to reveal the various folders (macros, plugins, jars, etc..)
-   Download the **ThermImageJ.ijm** file from this site and copy into the FIJI/macros/toolsets folder.
-   Open the **ThermImageJ.ijm** file in any text editor, and verify the paths are properly set for your respective operating system. See the comments with the text file for guidance.
-   Download the additional **luts** files from this site and copy into your FIJI/luts folder. These are palettes that are commonly used in thermal imaging.
-   Download the perl script, **split.pl** from this site and copy into a FIJI/scripts folder.
-   Download **Byte\_Swapper.class** to the plugins folder.
-   Restart ImageJ.
-   If everything succeeded, the toolset should be installed and visible from your plugins menu.

Installation Checks
-------------------

Verify exiftool is installed by launching a terminal (or cmd prompt) window and typing the following bash commands:

``` bash
exiftool -ver
which exiftool
```

    ## 11.37
    ## /usr/local/bin/exiftool

If you see a version number (probably &gt; 10) and no error, then exiftool is installed properly. The second line will tell you the path to where it is installed.

Do the same for perl:

``` bash
perl -ver
which perl
```

    ## 
    ## This is perl 5, version 18, subversion 2 (v5.18.2) built for darwin-thread-multi-2level
    ## (with 2 registered patches, see perl -V for more detail)
    ## 
    ## Copyright 1987-2013, Larry Wall
    ## 
    ## Perl may be copied only under the terms of either the Artistic License or the
    ## GNU General Public License, which may be found in the Perl 5 source kit.
    ## 
    ## Complete documentation for Perl, including FAQ lists, should be found on
    ## this system using "man perl" or "perldoc perl".  If you have access to the
    ## Internet, point your browser at http://www.perl.org/, the Perl Home Page.
    ## 
    ## /usr/bin/perl

Verify no errors on your system to ensure perl is installed correctly.

Check that the perl script is accessible by:

``` bash
perl /Applications/Fiji.app/scripts/split.pl
```

You should see the following warning message:

*"Error: Please specify input file, output folder, the output filename base, pattern to split, and output file extension."*

This verifies that the perl script is installed where your machine can access it.

If you see:

*"Can't open perl script "/Applications/Fiji.app/scripts/split.pl": No such file or directory"*

you will need to re-check the location of the script or the path information provided at the top of the ThermImageJ.ijm file.

Now, do the same for ffmpeg:

``` bash
ffmpeg -version
which ffmpeg
```

    ## ffmpeg version 4.1 Copyright (c) 2000-2018 the FFmpeg developers
    ## built with Apple LLVM version 10.0.0 (clang-1000.11.45.5)
    ## configuration: --prefix=/usr/local/Cellar/ffmpeg/4.1_1 --enable-shared --enable-pthreads --enable-version3 --enable-hardcoded-tables --enable-avresample --cc=clang --host-cflags= --host-ldflags= --enable-ffplay --enable-gpl --enable-libmp3lame --enable-libopus --enable-libsnappy --enable-libtheora --enable-libvorbis --enable-libvpx --enable-libx264 --enable-libx265 --enable-libxvid --enable-lzma --enable-opencl --enable-videotoolbox
    ## libavutil      56. 22.100 / 56. 22.100
    ## libavcodec     58. 35.100 / 58. 35.100
    ## libavformat    58. 20.100 / 58. 20.100
    ## libavdevice    58.  5.100 / 58.  5.100
    ## libavfilter     7. 40.101 /  7. 40.101
    ## libavresample   4.  0.  0 /  4.  0.  0
    ## libswscale      5.  3.100 /  5.  3.100
    ## libswresample   3.  3.100 /  3.  3.100
    ## libpostproc    55.  3.100 / 55.  3.100
    ## /usr/local/bin/ffmpeg

Setting ThermImageJ Macros Up in FIJI/ImageJ
--------------------------------------------

Once you have installed everything above, and verified no errors, you can set the macros up in FIJI/ImageJ.

Launch FIJI, left click the **more-tools menu**, which is the **&gt;&gt;** on the far right side of the menu bar:

<img src="./images/toolbar-before-install.png" width="100%" />

Which will reveal any of the toolsets in the folder. Click on **ThermImageJ** to replace the present icons with ThermImageJ specific icons / macros:

<img src="./images/more-tools-toolsets-menu.png" width="50%" />

Once installed, the toolbar menu populate with new icons corresponding to the primary ThermImageJ functions:

<img src="./images/toolbar-after-install.png" width="100%" />

Once installed, the toolset should also populate the **Plugin Dropdown Menu** with the same, and some additional macros used less often:

<img src="./images/plugin-macro.png" width="50%" />

Main Functions and Features
---------------------------

### Lookup tables and adjusting colour ranges <img src='./images/PaletteChoices.gif' align="right" height="300">

-   LUT (Thermal Palette Look Up Table) menu <img src='./images/LUT.png'>
    -   for rapidly accessing different pseudocolour palettes
    -   Grays, Ironbow, and Rainbow are more commonly used in thermal imaging
    -   ImageJ's built in LUTs can be always be accessed from the Image-Lookup Tables Menu
-   Next LUT <img src='./images/NextLUT.png'>
    -   select the next LUT in the list of all ImageJ LUTs, including the ones in the Thermal LUT list
-   Previous LUT <img src='./images/PreviousLUT.png'>
    -   select the previous LUT in the list all ImageJ LUTs, including the ones in the Thermal LUT list
-   Invert LUT <img src='./images/InvertLUT.png'>
    -   invert the colour scale of the LUT
    -   this can be toggled
-   Brightness/Contrast <img src='./images/BrightContrast.png'>
    -   setting the min and max values of the pseudocolour scale
    -   set min equal to the lowest temperature desired on the lookup table scale
    -   set max equal to the highest temperature deisred on the lookup table scale
-   Add Calibration bar <img src='./images/Calbar.png'>
    -   makes use of the built-in Analyze-Tools-Calibration Bar
    -   use this after temperature conversion of image

### Direct Import of Raw Data

-   Raw Import RTV <img src='./images/ImportRTV.png'>
    -   custom macro to import an old Mikron Mikrospec R/T video format
    -   these files had simple encoding and are not likely in use any longer, except by the author
    -   see SampleFiles.zip for sample data
-   Raw Import SEQ <img src='./images/ImportSEQ.png'>
    -   custom macro to import FLIR SEQ using the Import-Raw command
    -   use only if you know the precise offset byte start and the number of bytes between frames.
    -   only works for certain SEQ files, and only formats where tiff format underlies the video
-   see SampleFiles.zip for sample data

### Bits and Bytes

-   Image Byte swap <img src='./images/ByteSwap.png'>
    -   simple call to the Byte Swapper plugin.
    -   since FLIR files are sometimes saved using little endian order (tiff) and big endian order (png), a short-cut to a pixel byte swap is a fast way to repair files that have byte order mixed up

### Imports that use Command Line Conversions

-   Convert FLIR JPG
    -   select a candidate JPG or folder of JPGs, and a call to the command line tool, exiftool, is performed to extract the raw-binary 16 bit pixel data, save this to a gray scale tif or png, placed into a 'converted' subfolder.
    -   subsequently the user can import these 16-bit grayscale images and apply custom transformations or custom Raw2Temp conversions.
    -   some images may be converted in reverse byte order due to FLIR conventions. These can be fixed with the Byte Swapper plugin after import.
-   Import FLIR JPG <img src='./images/ImportJPG.png'>
    -   select a candidate JPG, and a call to the command line tool, exiftool, is performed to extract the raw-binary 16 bit pixel data, temporarily save this to a gray scale tif or png, import that file, and calls the Raw2Temp function using the calibration constants derived from the FLIR JPG file.
-   Import FLIR SEQ <img src='./images/ConvertSEQ.png'>
    -   select a candidate SEQ file, and a call to the command line tools, exiftool, perl split.pl, and ffmpeg is performed to extract each video frame (.fff) file, extract the subsequent raw-binary 16 bit pixel data, save these as a series of gray scale files, and collate these into an .avi file or a new folder of png or tiff files. Subsequent .avi file is imported to ImageJ using the Import-Movies (FFMPEG) import tool.
    -   this may work FCF file types as well but has not been thoroughly tested
-   Import FLIR CSQ <img src='./images/ConvertCSQ.png'>
    -   select a candidate CSQ file, and a call to the command line tools, exiftool, perl split.pl, and ffmpeg is performed to extract each video frame (.fff) file, extract the subsequent raw-binary 16 bit pixel data, save these as a series of gray scale files, and collate these into an .avi file or a new folder of png or tiff files. Subsequent .avi file is imported to ImageJ using the Import-Movies (FFMPEG) import tool.

### Utilities

-   FLIR Calibrations <img src='./images/FLIRSettings.png'>
    -   select a candidate FLIR file (jpg, seq, csq) to display the calibration constants and built-in object parameters stored at image capture. Typically, the user would then use the Planck constants and Object Paramters in the Raw2Temp macro.
    -   use this function on the original FLIR file if you have a 16-bit grayscale image of the raw data in a separate file and need to convert to temperature under specified conditions.
-   FLIR Dates <img src='./images/DateTime.png'>
    -   user selects a candidate FLIR file (jpg, seq, csq) to have the Date/Time Original returned. Use this to quickly scan a file for capture times.

### Temperature Conversion

-   Raw2Temp <img src='./images/Raw2Temp.png'>
    -   converts a 16-bit grayscale thermal image (or image stack) into estimated temperature using standard equations used in infrared thermography.
    -   user must provide the camera calibration constants and object parameters that can be obtained using the FLIR Calibrations macro.
    -   various custom versions of Raw2Temp are included for different cameras the author has used, since the calibration constants do not change from image to image, and only when the camera is sent back to manufacturer for re-calibration.

Typical Workflow
----------------

-   Determine your FLIR camera's calibration constants (i.e. use the Calibration Values Tool)
-   Convert Image to a 16-bit Grayscale File (i.e. Convert FLIR JPG)
-   Import to ImageJ
-   Run Raw2Temp or one of the custom Raw2Temp macros for your particular camera
-   Choose your palette (LUT in ImageJ)
-   Use ImageJ ROI tools and Measurement tools

Video Workflow
--------------

-   Use the Import SEQ or Import CSQ functions that scan the file to determine calibration constants before import
-   Select the video import option and jpegls as the codec (i.e. the defaults) This will keep file size as small as possible and preserves compatibility with the ImageJ FFMPEG implementation
-   The Import SEQ and Import CSQ macros will automatically attempt to calculate temperature
-   Once the file is converted and imported, double check that the calibration constants and object parameters are appropriate and select ok. If you escape at this stage, you should still have a 16-bit grayscale image stack, and could run the Raw2Temp function later

ROI analysis
------------

-   First set the parameters you are interested in extracting in the Analyze-&gt;Set Measurements menu.
-   Typical values are min, max, mean, modal, median, standard deviation, but ImageJ offers so many other values.
-   In ImageJ terminology, "Intensity" or "Gray Value" corresponds to the number stored in each pixel. This might be the 16-bit raw value or it might be the 32-bit decimal converted temperature, depending on when analysis is performed.
-   Take advantage of all the ImageJ ROI tools, or Tools-&gt;ROI Manager to draw regions of interest over sites of interest.

Download and extract sample files to test:
------------------------------------------

<https://github.com/gtatters/ThermImageJ/blob/master/SampleFiles.zip>

Caution
-------

-   The maximum number of video frames (i.e. stacks) is limited by the CPU and speed of ImageJ macros.
-   Due to performance limitations, memory allocation, and file size of videos, users are recommended to delay converting their loaded video files to temperature, until files have been otherwise processed, as the memory required to is double that required to work with the 16-bit grayscale images.
-   Consider cropping videos, re-sampling fewer stacks if you have oversampled videos, or performing ROI analyses on the 16-bit raw data and then calculate temperature using the raw2temp function also available in an R package (Thermimage)
-   Finally, users are advised to verify that the values obtained with these macros are similar to the ones obtained using official thermal imaging software. See <https://github.com/gtatters/ThermimageCalibration> for details on performance accuracy.

References
----------

The following open source programs and programmers were crucial to the development of ThermImageJ.

-   Thermimage: <https://github.com/gtatters/Thermimage>

-   Exiftool: <http://www.sno.phy.queensu.ca/~phil/exiftool/>

-   Perl: <http://www.perl.org>

-   Discussions on the raw to temperature conversion: <http://u88.n24.queensu.ca/exiftool/forum/index.php?topic=4898.135>

-   Discussions on the file formats: <https://www.eevblog.com/forum/thermal-imaging/csq-file-format/>

Contributors
------------

ImageJ Macro Development occurred in association with:

-   Joshua Robertson (<https://github.com/joshuakrobertson>)

Command Line Development and Automation occurred in assocation with:

-   Ruger Porter (<https://www.ohio.edu/medicine/about/directory/profiles.cfm?profile=porterw1>)

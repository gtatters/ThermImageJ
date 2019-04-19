ThermImageJ - Macros for ImageJ
================

ThermImageJ is a collection of macros and command line tools to allow for import and conversion of thermal image files to assist in converting and extracting raw data from infrared thermal images and converting them to temperatures using standard equations in thermography. Provides an open source tool for assisting with infrared thermographic analysis.

Normally, these thermal images require access to software that only runs on Windows operating system, or has limited access to statistical image analysis. These macros will allow you to import most FLIR jpgs and videos and process the images in ImageJ.

Designed for use with FIJI/ImageJ.

Version History
---------------

-   v 1.0: Released April, 2019

Main Functions
--------------

-   LUT shortcuts
-   Raw Import Mikron RTV
-   Raw Import FLIR SEQ
-   Convert FLIR JPG
-   Import FLIR JPG
-   Import FLIR SEQ
-   Import FLIR CSQ
-   Raw2Temp
-   FLIR Calibration Values
-   FLIR Date Stamps

Compatibility
-------------

-   ThermImageJ was developed on OSX, and tested using ImageJ v 1.52n. Many features require installation of command line tools that may or may not work as effectively in different operating systems. Testing and troubleshooting is ongoing. Report issues here: <https://github.com/gtatters/ThermImageJ/issues>

Requirements
------------

-   FIJI is Just ImageJ. Download instructions: <https://imagej.net/Fiji/Downloads>
-   Exiftool. Installation instructions: <http://www.sno.phy.queensu.ca/~phil/exiftool/install.html>
-   FFMPEG command line utility. Download instructions: <https://ffmpeg.org/download.html>
-   Perl. Installation instructions: <https://www.perl.org/get.html>
-   A custom perl script, provided on this github repository, which can be downloaded and placed in a scripts folder with ImageJ. Link here: <https://github.com/gtatters/ThermImageJ/tree/master/scripts/split.pl/>
-   ThermImageJ macro toolset. A text file containing all the macros and functions: <https://github.com/gtatters/ThermImageJ/tree/master/toolsets/ThermImageJ.ijm/>
-   Additional Look Up Tables (LUTS), popularly used in thermal imaging available on this github repository: <https://github.com/gtatters/ThermImageJ/tree/master/luts/>
-   Byte swapper plugin. Download instructions: <https://imagej.nih.gov/ij/plugins/swapper.html>

Installation Instructions
-------------------------

-   Install FIJI, exiftool, and perl according to the website instructions above.
-   Launch FIJI and follow any update instructions.
-   Launch FIJI--&gt;Help--&gt;Update, allow it to update any plug-ins, then while the update window is open, select **Manage update websites**, and ensure that the FFMPEG box is ticked. Select ok, then click the **Apply** option, and restart FIJI. This FFMPEG is required for importing avi files created during the conversion process.
-   Navigate to where FIJI is installed to find all the subfolders. On a Mac, you may need to right-click and click **Show Package Contents** to open up FIJI as a folder to reveal the various folders (macros, plugins, jars, etc..)
-   Download the **ThermImageJ.ijm** file from this site and copy into the FIJI/macros/toolsets folder.
-   Download the **luts** files from this site and copy into the FIJI/luts folder.
-   Download the perl script, **split.pl** from this site and copy into a FIJI/scripts folder.
-   Download **Byte\_Swapper.class** to the plugins folder.
-   Restart ImageJ.

Installation Checks
-------------------

Verify exiftool is installed by launching a terminal (or cmd prompt) window and typing:

``` bash
exiftool -ver
which exiftool
```

    ## 10.67
    ## /usr/local/bin/exiftool

If you see a version number (probably &gt; 10) and no error, exiftool is installed. The second line will tell you the path to where it is installed.

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

Check that the perl script is installed by:

``` bash
perl /Applications/Fiji.app/scripts/split.pl
```

You should see the following warning message:

*"Error: Please specify input file, output folder, the output filename base, pattern to split, and output file extension."*

This verifies that the perl script is installed where your machine can access it.

If you see:

*"Can't open perl script "/Applications/Fiji.app/scripts/split2.pl": No such file or directory"*

you will need to re-check the location of the script or the path information provided.

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

Launch FIJI, find the **more-tools menu**, which is the **&gt;&gt;** on the far right side of the menu bar, and click on **ThermImageJ**

<img src="./images/toolbar-before-install.png" width="100%" />

<img src="./images/more-tools-toolsets-menu.png" width="50%" />

Once installed, the toolbar menu populate with new icons corresponding to the primary ThermImageJ functions:

<img src="./images/toolbar-after-install.png" width="100%" />

Once installed, the toolset should also populate the **Plugin Dropdown Menu** with the same, and some additional macros used less often:

<img src="./images/plugin-macro.png" width="50%" />

### Download and extract sample files to test:

<https://github.com/gtatters/Thermimage/blob/master/Uploads/SampleFLIR.zip>

### References

The following open source programs and programmers were critical to the development of ThermImageJ.

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

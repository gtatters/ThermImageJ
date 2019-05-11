///////////////////////////////////////////////////////////////////////////////////////////////////////
////                                                                                               ////
////    This ImageJ toolset allows to access ImageJ macros for working with thermal images.        ////
////        Main Features: import, conversion, and transformation of thermal images.               ////
////                           Requires: exiftool, ffmpeg, perl                                    ////
////                                Glenn J. Tattersall                                            ////
////                             April, 2019 - Version 1.0                                         ////
////                                                                                               ////
///////////////////////////////////////////////////////////////////////////////////////////////////////

var luts = getLutMenu();
var lCmds = newMenu("LUT Menu Tool", luts);
var palettetypes=newArray("Grays", "Ironbow", "Rainbow", "Spectrum", "Thermal", "Yellow", "Yellow Hot", "Green Fire Blue", "Red/Green", "5 Ramps", "6 Shades");
var defaultpalette="Grays";
var thermlCmds = newMenu("Thermal LUT Menu Tool", palettetypes);
var lut = -1;
var lutdir = getDirectory("luts");
var list;
var color = 0;
var colors = newArray("Red", "Green", "Blue", "Cyan", "Magenta", "Yellow");

// the following persistent variable are updated on the user's ImageJ once Raw2Temp is performed on a file
var PR1 = parseFloat(call("ij.Prefs.get", "PR1.persistent","17998.529")); 
var PR2 = parseFloat(call("ij.Prefs.get", "PR2.persistent","015145967")); 
var PB = parseFloat(call("ij.Prefs.get", "PB.persistent","1453.1")); 
var PF = parseFloat(call("ij.Prefs.get", "PF.persistent","1")); 
var PO = parseFloat(call("ij.Prefs.get", "PO.persistent","-5854")); 
var E = parseFloat(call("ij.Prefs.get", "E.persistent","0.95")); 
var OD = parseFloat(call("ij.Prefs.get", "OD.persistent","1")); 
var RTemp = parseFloat(call("ij.Prefs.get", "RTemp.persistent","20")); 
var ATemp = parseFloat(call("ij.Prefs.get", "ATemp.persistent","20")); 
var IRWTemp = parseFloat(call("ij.Prefs.get", "IRWTemp.persistent","20")); 
var IRT = parseFloat(call("ij.Prefs.get", "IRT.persistent","1")); 
var RH = parseFloat(call("ij.Prefs.get", "RH.persistent","50.0")); 
var imagewidth=parseInt(call("ij.Prefs.get", "imagewidth.persistent","640"));
var imageheight=parseInt(call("ij.Prefs.get", "imageheight.persistent","480")); 

///////////////////////////////////////////////////////////////////////////////////////////////////////
////                                                                                               ////
////      User should verify the following path locations for their operating system:              ////
////                                                                                               ////
///////////////////////////////////////////////////////////////////////////////////////////////////////

// The following will set the perl script path to the location of your ImageJ folder's scripts subfolder
var perlscriptpath=getDirectory("imageJ") + "scripts" + File.separator;  			  // <- VERIFY THIS

// ROI commands will automatically save a ROI_Results file to user's desktop folder 
var desktopdir= getInfo("user.home") + File.separator + "Desktop" + File.separator;  // <- VERIFY THIS

// full path to the split.pl script
var perlsplit=perlscriptpath + "split.pl";	

// Extract Operating system user is on.  
// OS will be used in most macros calling command line tools
var OS=getInfo("os.name");

// OSX Users verify these settings:									 // <- VERIFY THIS
var perlpathOSX="/usr/local/bin/";
var exiftoolpathOSX="/usr/local/bin/";
var exiftoolOSX="exiftool";
var ffmpegpathOSX="/usr/local/bin/";

// Linux Users verify these settings:								 // <- VERIFY THIS
var perlpathLinux="/usr/bin/";
var exiftoolpathLinux="/usr/bin/";
var exiftoolLinux="exiftool";
var ffmpegpathLinux="/usr/bin/";

// Windows Users verify these settings:								 // <- VERIFY THIS
var perlpathWindows="c:/Perl64/bin/";
var exiftoolpathWindows="c:/windows/";
var exiftoolWindows="exiftool.exe";
var ffmpegpathWindows="c:/FFmpeg/bin/";

	
//////////////////////////////////////// Functions ///////////////////////////////////////////////

// Based on the LUTFileTool by Gabriel Landini
function cycleLUTs(inc) {
       if (lut==-1)
           createLutList();
       if (nImages==0) {
          call("ij.gui.ImageWindow.centerNextImage");
          newImage("LUT", "8-bit ramp", 480, 64, 1);
          run("Rotate 90 Degrees Left");
          setColor(0);
          setLineWidth(2);
          drawRect(0, 0, 64, 480);
       }
       if (bitDepth==24)
           exit("RGB images do not have LUTs");
       if (isKeyDown("alt"))
           lut = 0;
       else
          lut += inc;
      if (lut<0) lut = list.length-1;
      if (lut>list.length-1) lut = 0;
      name = list[lut];
      run("LUT... ", "open=["+lutdir+name+"]");
      name = substring(name, 0, lengthOf(name)-4);
      if (getWidth==64 && getHeight==480){
      	 setColor(0);
         setLineWidth(2);
         drawRect(0, 0, 64, 480);
      	 rename(name);
      }
           
      showStatus((lut+1) + ". " + name);
  }

function createLutList() {
      err = "No LUTs in the '/ImageJ/luts' folder";
      if (!File.exists(lutdir))
           exit(err);
      rawlist = getFileList(lutdir);
      if (rawlist.length==0)
          exit(err);
      count = 0;
      for (i=0; i< rawlist.length; i++) {
          if (endsWith(rawlist[i], ".lut")) count++;
      }
      if (count==0)
          exit(err);
      list = newArray(count);
      index = 0;
      for (i=0; i< rawlist.length; i++) {
          if (endsWith(rawlist[i], ".lut"))
              list[index++] = rawlist[i];
      }
  }


function getLutMenu() {
	list = getLutList();
	menu = newArray(16+list.length);
	menu[0] = "Invert LUT"; menu[1] = "Apply LUT"; menu[2] = "-";
	menu[3] = "Fire"; menu[4] = "Grays"; menu[5] = "Ice";
	menu[6] = "Spectrum"; menu[7] = "3-3-2 RGB"; menu[8] = "Red";
	menu[9] = "Green"; menu[10] = "Blue"; menu[11] = "Cyan";
	menu[12] = "Magenta"; menu[13] = "Yellow"; menu[14] = "Red/Green";
	menu[15] = "-";
	for (i=0; i<list.length; i++)
		menu[i+16] = list[i];
	return menu;
}

function getLutList() {
	lutdir = getDirectory("luts");
	list = newArray("No LUTs in /ImageJ/luts");
	if (!File.exists(lutdir))
		return list;
	rawlist = getFileList(lutdir);
	if (rawlist.length==0)
		return list;
	count = 0;
	for (i=0; i< rawlist.length; i++)
		if (endsWith(rawlist[i], ".lut")) count++;
	if (count==0)
		return list;
	list = newArray(count);
	index = 0;
	for (i=0; i< rawlist.length; i++) {
		if (endsWith(rawlist[i], ".lut"))
			list[index++] = substring(rawlist[i], 0, lengthOf(rawlist[i])-4);
	}
	return list;
}


// function to add leading zeros to a string (usually a number) - for file saving or slice label consistency
function leadzero(val, digits){
	newval=val;
	digitdiff=digits - lengthOf(val);
	for(i = 1; i <= digitdiff; i++){
		newval="0" + newval;
	}
	return newval;
}

// simple byte swap for 8 bit string representation.  ie. "8002" --> "0280"  
function swap(val){
	newval=substring(val, 2, 4) + substring(val, 0,2);
	return newval;
}

// Simple math functions: Sum, SumXY, SumX2, SumY2, Pearson
function Sum(ArrayX){
	sum=0;  
	for (i=0; i<lengthOf(ArrayX); i++){ 
 		sum=sum+ArrayX[i]; 
	} 	
	return sum;
}

// Returns the sum of the X data * Y data (i.e. the sum of XY)
function SumXY(ArrayX, ArrayY){
	n=ArrayX.length;
	XY=newArray(n);
	for (i=0; i<n; i++){ 
        XY[i] = ArrayX[i] * ArrayY[i];
	} 
	sumxy=Sum(XY);
	return sumxy;	
}

// Returns the sum of squares of the X array
function SumX2(ArrayX){
	n=ArrayX.length;
	X2=newArray(n);
	for (i=0; i<n; i++){
		X2[i] = ArrayX[i]*ArrayX[i];  
	}
	sumx2=Sum(X2);
	return sumx2;
}

// Returns the sum of squares of the Y array (this is the same as the SumX2 function)
function SumY2(ArrayY){
	n=ArrayY.length;
	Y2=newArray(n);
	for (i=0; i<n; i++){
		Y2[i] = ArrayY[i]*ArrayY[i]; 
	}
	sumy2=Sum(Y2);
	return sumy2;
}

// Returns the Pearon correlation coefficient for x and y (need to be the same length)
function Pearson(ArrayX, ArrayY){
	n=ArrayX.length;
	r = (n*SumXY(ArrayX, ArrayY) - Sum(ArrayX)*Sum(ArrayY)) / sqrt((n*SumX2(ArrayX) - pow(Sum(ArrayX),2)) * (n*SumY2(ArrayY) - pow(Sum(ArrayY),2)));	
	return r;
}

// function to import an rtv file using imageJ raw import option
function RawImportMikronRTV() {

	print("Running RawImportRTV function");
	
	var offsetbyte = 42; 
	// offsetbyte is 1540528 for SEQ files recorded to a FLIR SC660
	// offsetbyte is 1372 for SEQ files recorded to computer (works for at least two diff cameras)
	// offsetbyte is 1542956 or 1540480 for SEQ files recorded to a FLIR SC640
	var gapbytes = 42;
	// gapbytes is 3020 for direct SEQ recorded files
	// gapbytes is 1424 for thermacam researcher pro captured seq files
	var nframes = 10000;
	var imagewidth = 320;
	var imageheight = 240;
	var converttotemperature = 0;
	var usevirtual = 0;
	var minpix=1;
	var maxpix=65535;
	
	//Create Dialog Box	
	Dialog.create("Information for Mikron RTV Video Import");
	Dialog.addMessage("This macro directly imports the RAW pixel data from a Mikron RTV file");
	Dialog.addMessage("The user must input the starting offset bytes and frame gaps");
	Dialog.addMessage("This filetype is preserved as a legacy option");
	Dialog.addMessage("\n"); 	
	Dialog.addNumber("Offset Bytes", offsetbyte, 0, 8, "bytes"); 
	Dialog.addNumber("Gaps Between Frames:", gapbytes, 0, 8, "bytes");
	Dialog.addNumber("Number of Frames: ", nframes, 0, 8, "frames");
	Dialog.addNumber("Image Width:", imagewidth, 0, 6, "pixels");
	Dialog.addNumber("Image Height:", imageheight, 0, 6, "pixels");
	Dialog.addCheckbox("Convert to Temperature on Import", converttotemperature);
	Dialog.addCheckbox("Use Virtual Stack", usevirtual);
    Dialog.show();
    
	//Define Variable for Import
	var offsetbyte = Dialog.getNumber(); 
	var gapbytes = Dialog.getNumber();
	var nframes = Dialog.getNumber();
	var imagewidth = Dialog.getNumber(); 
	var imageheight = Dialog.getNumber();
	var converttotemperature = Dialog.getCheckbox();
	var usevirtual = Dialog.getCheckbox();
	
	filepath=File.openDialog("Select a File"); 
	file=File.openAsString(filepath); 
	print("Loading: ", filepath);
	print("\n");

	run("Raw...", "open=filepath image=[16-bit Unsigned] width=imagewidth height=imageheight offset=offsetbyte number=nframes gap=gapbytes little-endian use=usevirtual");

	// Mikron RTV files are simply stored as Temperature in Kelvin * 10 and thus range from 10 to ~3000 (but still stored or imported as 16 bit integer)
	// conversion here will not be accurate, nor will it take into account atmospheric and reflected conditions.
	
	if(converttotemperature) {
		run("32-bit");
		run("Macro...", "code=v=v/10-273.15 stack");
		}
	
	run(defaultpalette);
	
	Stack.getStatistics(count, mean, min, max, std);
		var minpix=min;
		var maxpix=max;
		setMinAndMax(minpix, maxpix);
	
	print("Done");
	print("\n");
	
}


function RawImportFLIRSEQ() {
	
	print("Running RawImporFLIRSEQ function");
	
	var offsetbyte = 1372; 
	// offsetbyte is 1540528 for SEQ files recorded to a FLIR SC660
	// offsetbyte is 1372 for SEQ files recorded to computer (works for at least two diff cameras)
	// offsetbyte is 1542956 or 1540480 for SEQ files recorded to a FLIR SC640
	var gapbytes = 1424;
	// gapbytes is 3020 for direct SEQ recorded files
	// gapbytes is 1424 for thermacam researcher pro captured seq files
	var nframes = 10000;
	var imagewidth = 640;
	var imageheight = 480;
	var converttotemperature = 1;
	var usevirtual = 0;
	var minpix=1;
	var maxpix=65535;
	
	//Create Dialog Box	
	Dialog.create("Information for FLIR SEQ Video Import"); 
	Dialog.addMessage("This macro directly imports the RAW pixel data from a SEQ file");
	Dialog.addMessage("The user must input the starting offset bytes and frame gaps");
	Dialog.addMessage("Use the Convert & Import FLIR SEQ macro if you do not have this information");
	Dialog.addMessage("\n");
	Dialog.addNumber("Offset Bytes", offsetbyte, 0, 8, "bytes"); 
	Dialog.addNumber("Gaps Between Frames:", gapbytes, 0, 8, "bytes");
	Dialog.addNumber("Number of Frames: ", nframes, 0, 8, "frames");
	Dialog.addNumber("Image Width:", imagewidth, 0, 6, "pixels");
	Dialog.addNumber("Image Height:", imageheight, 0, 6, "pixels");
	Dialog.addCheckbox("Convert to Temperature on Import", converttotemperature);
	Dialog.addCheckbox("Use Virtual Stack", usevirtual);
    Dialog.show();
    
	//Define Variable for Import
	var offsetbyte = Dialog.getNumber(); 
	var gapbytes = Dialog.getNumber();
	var nframes = Dialog.getNumber();
	var imagewidth = Dialog.getNumber(); 
	var imageheight = Dialog.getNumber();
	var converttotemperature = Dialog.getCheckbox();
	var usevirtual = Dialog.getCheckbox();
	
	filepath=File.openDialog("Select a File"); 
	file=File.openAsString(filepath); 
	print("Loading: ", filepath);
	print("\n");

	run("Raw...", "open=filepath image=[16-bit Unsigned] width=imagewidth height=imageheight offset=offsetbyte number=nframes gap=gapbytes little-endian use=usevirtual");
	
	//OS=getInfo("os.name");
	
	if(OS=="Mac OS X"){
		flirvals=exec("/usr/local/bin/exiftool",  "-Planck*", "-*Emissivity", "-*Distance", "-*Temperature", "-*Transmission",  "-*Humidity", "-*Height", "-*Width", "-*Original", "-*Date",  filepath);
	}

	if(OS=="Linux"){
		flirvals=exec("/usr/local/bin/exiftool",  "-Planck*", "-*Emissivity", "-*Distance", "-*Temperature", "-*Transmission",  "-*Humidity", "-*Height", "-*Width", "-*Original", "-*Date",  filepath);
	}
	
	if(substring(OS, 0, 5)=="Windo"){
		flirvals=exec("c:/Windows/exiftool.exe", "-Planck*", "-*Emissivity", "-*Distance", "-*Temperature", "-*Transmission",  "-*Humidity", "-*Height", "-*Width", "-*Original", "-*Date",  filepath);
	}
        var PR1 = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Planck R1"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Planck R1")) ));
		var PB = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Planck B"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Planck B")) ));
		var PF = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Planck F"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Planck F")) ));
		var PO = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Planck O"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Planck O")) ));
		var PR2 = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Planck R2"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Planck R2")) ));
		var E = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Emissivity"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Emissivity")) ));
		var OD = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Object Distance"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Object Distance")) ));
		var RTemp = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Reflected Apparent Temperature"))+1, indexOf(flirvals, "C\n", indexOf(flirvals, "Reflected Apparent Temperature")) ));
		var ATemp = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Atmospheric Temperature"))+1, indexOf(flirvals, "C\n", indexOf(flirvals, "Atmospheric Temperature")) ));
		var IRWTemp = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "IR Window Temperature"))+1, indexOf(flirvals, "C\n", indexOf(flirvals, "IR Window Temperature")) ));
		var IRT = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "IR Window Transmission"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "IR Window Transmission")) ));
		var RH = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Relative Humidity"))+1, indexOf(flirvals, "%\n", indexOf(flirvals, "Relative Humidity")) ));
		var imagewidth = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Width"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Width")) ));
		var imageheight = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Height"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Height")) ));

		print("Camera Calibration Constants:");
		//print(flirvals);
		setFont("SansSerif", 12);
		print("Planck R1: ", d2s(PR1,9));
		print("Planck B: ", d2s(PB,9));
		print("Planck F: ", d2s(PF,0));
		print("Planck O: ", d2s(PO,0));
		print("Planck R2: ", d2s(PR2,9));
		print("Thermal Image Width: ", imagewidth);
		print("Thermal Image Height: ", imageheight);
		
		print("\n");
		print("Default Object Parameters:");
		print("Emissivity: ", d2s(E,2));
		print("Object Distance: ", d2s(OD,2));
		print("Reflected Apparent Temperature: ", d2s(RTemp,2));
		print("Atmospheric Temperature: ", d2s(ATemp,2));
		print("IR Window Temperature: ", d2s(IRWTemp,2));
		print("IR Window Transmission: ", d2s(IRT,3));
		print("Relative Humidity: ", d2s(RH,2));
		print("\n");
	
	Stack.getStatistics(count, mean, min, max, std);
		var minpix=min;
		var maxpix=max;
		setMinAndMax(minpix, maxpix);
		
	if(converttotemperature) {
		run("Raw2Temp SC660");
	}

		print("Done");
		print("\n");

}



function ConvertImportFLIRJPG() {
	
	print("Running ConvertImportFLIRJPG function");
	
	if(OS=="Mac OS X"){
		var perlpath=perlpathOSX;
		var exiftoolpath=exiftoolpathOSX;
		var exiftool=exiftoolOSX;
		var ffmpegpath=ffmpegpathOSX;
	}

	if(OS=="Linux"){
		var perlpath=perlpathLinux;
		var exiftoolpath=exiftoolpathLinux;
		var exiftool=exiftoolOSX;
		var ffmpegpath=ffmpegpathLinux;
	}
	
	if(substring(OS, 0, 5)=="Windo"){
		var perlpath=perlpathWindows;
		var exiftoolpath=exiftoolpathWindows;
		var exiftool=exiftoolWindows;
		var ffmpegpath=ffmpegpathWindows;
	}

	var filepath=File.openDialog("Select a JPG File"); 
	
	print("Loading: ", filepath);
	print("Extracting calibration and image settings");
	
	// populate an array called flirvals with 14 entries to accept the array output from the flirvalues function
	flirvals=newArray(14);

	var printvalues="No";
	
	flirvals=flirvalues(filepath, printvalues);
	
	// define the constants extracted from the flir values function
	PR1=flirvals[0];
	PB=flirvals[1];
	PF=flirvals[2];
	PO=flirvals[3];
	PR2=flirvals[4];
	E=flirvals[5];
	OD=flirvals[6];
	RTemp=flirvals[7];
	ATemp=flirvals[8];
	IRWTemp=flirvals[9];
	IRT=flirvals[10];
	RH=flirvals[11];
	imagewidth=flirvals[12];
	imageheight=flirvals[13];
	
	filedir=File.getParent(filepath);
	filename=File.getName(filepath);

	tempfolder=filedir + File.separator + "temp";
	//print("the temp folder is" + tempfolder);
	File.makeDirectory(tempfolder);

	templist = getFileList(tempfolder);
	// In case during a previous import, the temp folder is not empty, we will remove any files currently in the temp folder.  Normally this only happens
	// if there was a crash of macro failure during a previous import.
	for (i = 0; i < templist.length; i++)
      tempfilesdelete_success=File.delete(tempfolder + File.separator + templist[i]);	

	// run Exiftool to return the meta tags with the word "RawThermalImageType".  It should be either TIFF or PNG.
	//flirimageraw = exec("/usr/local/bin/exiftool", "-RawThermalImageType", filepath);	
  	print(exiftoolpath+exiftool);

	var RawThermalType=""; // set RawThermalType as blank to start
	
	flirimageraw = exec(exiftoolpath + exiftool, "-RawThermalImageType", filepath);
	RawThermalType = substring(flirimageraw, indexOf(flirimageraw, ":")+1 );
	
	// determine the data storage format of the flir jpg.  Either tiff or png	
	RawThermalType=replace(RawThermalType, "\n", "");
	RawThermalType=replace(RawThermalType, " ", "");

	if(RawThermalType=="  " || RawThermalType==" " || RawThermalType==""){
		print("Raw Thermal Type Unknown. Setting it to png");
		RawThermalType="png";
	}
	
	fileout=File.nameWithoutExtension + "." + toLowerCase(RawThermalType);
	fileout=replace(fileout, " ", "");
	fileout=replace(fileout, ".tiff", ".tif");
	fileout=replace(fileout, ".TIFF", ".tif");
	fileout=replace(fileout, ".PNG", ".png");

	// Define the syntax for the exec command to convert the jpg file into a png for import
	//convertjpg =  exiftoollocation + exiftool + " " + filepath + " -b -RawThermalImage | convert - gray:- | convert -depth 16 -endian lsb -size 640x480 gray:- " + filedir + "/temp/" + "filename.png";
	// I cannot get double or single pipes to convert to work when called from imageJ, so I revert to this method:
	
	convertjpg =  exiftoolpath + exiftool + " '" + filepath + "' -b -RawThermalImage > '" + tempfolder + File.separator + fileout + "'";

	// print(convertjpg);

	// Execute the convert command
	// Difficulty getting the Piping to work with the default exec command.  See: http://imagej.1557.x6.nabble.com/macro-Redirection-in-exec-UNIX-binary-td3687463.html
	// Execute the combine command this way (not sure it will work in Windows):

	// The following is verified to work in Mac
	
	if(OS=="Mac OS X"){
		exec("/bin/sh", "-c", convertjpg);
	}

	if(OS=="Linux"){
		exec("/bin/sh", "-c", convertjpg);
	}
	
	// experimenting with this:
	if(substring(OS, 0, 5)=="Windo"){
		exec("cmd", "/c", exiftoolpath + exiftool, filepath, "-b", "-RawThermalImage", ">", tempfolder + File.separator + fileout);
	}
	
	fileoutpath=filedir + File.separator + "temp" + File.separator + fileout;
	
	print("Temporary file saved to:", fileoutpath);
	
	fileoutpathexist=File.exists(fileoutpath);

	if(fileoutpathexist==1){
	    open(fileoutpath); 
	    print("FLIR JPG loaded");
	    title=getTitle();
	    selectWindow(title);
	}
	
	byteorder=newArray("Default", "Swap");
	
	if(RawThermalType=="TIFF"){
		defaultbyteorder="Default";		
	}
	
	if(RawThermalType=="PNG"){
		defaultbyteorder="Swap";
	}
	
	// Create a prompt dialog to ask user to verify the values to be used in the calculations below
	Dialog.create("Verify Camera and Object Parameters");
	Dialog.addMessage("TIFF file pixel byte are usually little endian\nPNG file pixel bytes are usually big endian");
	Dialog.addMessage("Byte swap should be peformed on the 16-bit\nimage before converting to temperature");
	Dialog.addChoice("Swap byte order before conversion?", byteorder, defaultbyteorder); 
	Dialog.addMessage("Camera Calibration Constants obtained from Exiftool:");
	Dialog.addNumber("Planck R1:", PR1, 2, 12, "unitless"); //21106.77 //21546.203
	Dialog.addNumber("Planck R2:", PR2, 8, 12, "unitless"); //0.012545258 //0.016229488 
	Dialog.addNumber("Planck B:", PB, 0, 5, "unitless");  //1501 //1507.2
	Dialog.addNumber("Planck F:", PF, 0, 2, "unitless");  //1
    Dialog.addNumber("Planck O:", PO, 0, 5, "unitless"); //-7340 //-6331
    Dialog.addMessage("Object Parameters obtained from Exiftool:");
    Dialog.addNumber("Object Emissivity:", E, 3, 6, "unitless");
    Dialog.addNumber("Object Distance:", OD, 1, 6, "m");
    Dialog.addNumber("Reflected Temperature (C):", RTemp, 2, 6, "C");
    Dialog.addNumber("Atmospheric Temperature (C):", ATemp, 2, 6, "C");
    Dialog.addNumber("Window Temperature (C):", IRWTemp, 2, 6, "C");
    Dialog.addNumber("Window Transmittance:", IRT, 3, 6, "unitless");
    Dialog.addNumber("Relative Humidity:", RH, 2, 6, "%");
    Dialog.addChoice("Palette", palettetypes, defaultpalette);
	Dialog.show();

	var ByteOrder=Dialog.getChoice();
	var PR1 = Dialog.getNumber();
	var PR2 = Dialog.getNumber();
	var PB = Dialog.getNumber();
	var PF = Dialog.getNumber();
	var PO = Dialog.getNumber();
	var E = Dialog.getNumber();
	var OD = Dialog.getNumber();
	var RTemp = Dialog.getNumber();
	var ATemp = Dialog.getNumber();
	var IRWTemp = Dialog.getNumber();
	var IRT = Dialog.getNumber();
	var RH = Dialog.getNumber();
	var palettetype = Dialog.getChoice();

	if(fileoutpathexist==1){
		filedelete_success=File.delete(fileoutpath);
		folderdelete_success=File.delete(filedir + File.separator + "temp" + File.separator );
	}
	
	if(ByteOrder == "Swap"){
		run("Byte Swapper");
	}

	if(filedelete_success + folderdelete_success==2){
		print("Temporary file and folder deleted.");
	}
		Raw2Temp(PR1, PR2, PB, PF, PO, E, OD, RTemp, ATemp, IRWTemp, IRT, RH, palettetype, "No");
	
	print("Done");
	print("\n");
}



function ConvertFLIRJPGs() {
	
	print("Running ConvertFLIRJPGs function");
	
	if(OS=="Mac OS X"){
		var perlpath=perlpathOSX;
		var exiftoolpath=exiftoolpathOSX;
		var exiftool=exiftoolOSX;
		var ffmpegpath=ffmpegpathOSX;
	}

	if(OS=="Linux"){
		var perlpath=perlpathLinux;
		var exiftoolpath=exiftoolpathLinux;
		var exiftool=exiftoolLinux;
		var ffmpegpath=ffmpegpathLinux;
	}
	
	if(substring(OS, 0, 5)=="Windo"){
		var perlpath=perlpathWindows;
		var exiftoolpath=exiftoolpathWindows;
		var exiftool=exiftoolWindows;
		var ffmpegpath=ffmpegpathWindows;
	}
	
	Dialog.create("Convert FLIR JPGs");
	Dialog.addMessage("This macro will convert FLIR JPGs into TIFF or PNG files");
	Dialog.addMessage("Depending on the particular FLIR camera storage method.");
	Dialog.addMessage("Converted files will be placed in a subfolder 'converted'.");
	Dialog.addMessage("Select whether want to convert a file or a folder:");
	Dialog.addMessage("\n");
	Dialog.addRadioButtonGroup("Folder or File", newArray("Folder", "File"), 1, 2, "Folder");
	Dialog.show();

	whichtype=Dialog.getRadioButton();
	
	if(whichtype=="Folder"){
		var dirpath=getDirectory("Select an Input Folder of FLIR JPGs"); 
		filelist=getFileList(dirpath);	
	}

	if(whichtype=="File"){
		var filelist=newArray(File.openDialog("Select a FLIR JPG"));
		dirpath=File.getParent(filelist[0]);
	}
	
	convertfolder=dirpath + "converted";
	File.makeDirectory(convertfolder);

	for (i = 0; i < filelist.length; i++){
		
		showProgress(i/filelist.length);
		
		filepath=dirpath + filelist[i];
		
		if (endsWith(toLowerCase(filepath), ".jpg")) {
			
		filename=File.getName(filepath);
		filename=substring(filename, 0, lengthOf(filename)-4);
	
		// run Exiftool to return the meta tags with the word "RawThermalImageType".  It should be either TIFF or PNG.	
		
		flirimageraw = exec(exiftoolpath + exiftool, "-RawThermalImageType", filepath);
		RawThermalType = substring(flirimageraw, indexOf(flirimageraw, ":")+1 );
		
		// determine the data storage format of the flir jpg.  Either tiff or png	
		RawThermalType=replace(RawThermalType, "\n", "");
		RawThermalType=replace(RawThermalType, " ", "");
		
		if(RawThermalType=="  " || RawThermalType==" " || RawThermalType==""){
			print("Raw Thermal Type Unknown. Setting it to tiff");
			RawThermalType="tiff";
		}
		
		print("Raw Thermal Type: " , RawThermalType);
		
		fileout=filename + "." + toLowerCase(RawThermalType);
		fileout=replace(fileout, " ", "");
		fileout=replace(fileout, ".tiff", ".tif");
		fileout=replace(fileout, ".TIFF", ".tif");
		fileout=replace(fileout, ".PNG", ".png");

		print("Converting " + filename + ".jpg" + " to " + fileout);
		
		// Define the syntax for the exec command to convert the jpg file into a png or tiff file for import
		convertjpg =  exiftoolpath + exiftool + " '" + filepath + "' -b -RawThermalImage > '" + convertfolder + File.separator + fileout + "'";
		print(convertjpg);
		
		// Execute the convert command
		if(OS=="Mac OS X"){
			exec("/bin/sh", "-c", convertjpg);	
		}

		if(OS=="Linux"){
			exec("/bin/sh", "-c", convertjpg);	
		}

		if(substring(OS, 0, 5)=="Windo"){
			exec("cmd", "/c", exiftoolpath + exiftool, filepath, "-b", "-RawThermalImage", ">", convertfolder + File.separator + fileout);
		}

		// print(fileout + " saved to: ", convertfolder);
		}
	}
	
	print("FLIR JPG files converted into " + RawThermalType + " format.  Import these and convert to temperature using the Raw2Temp macro.");
	print("All files saved to: " + convertfolder);
	print("Use the File->Import->Image Sequence function to load in images");
	print("Some images may require that the pixel byte order be swapped.  Use the Byte Swapper plugin after importing if necessaary");
	print("Done");
	print("\n");
	
}

function ConvertFLIRVideo(vidtype, outtype, outcodec, converttotemperature, usevirtual) {

	print("Running ConvertFLIRVideo function");
	
	// vidtype should be seq or csq
	// outtype should be avi, png, or tiff (this will be the file extension for the final file)
	// outcodec is the type of file compression needed for avi files - usually jpegls, but png or tiff will work on some OS.
	// Using command line tools: perl, a perl split.pl script, exiftool and ffmpeg, this macro will convert a SEQ file into
	// a 16-bit avi file in png format to subsquently be imported using import-ffmpeg
	// converttotemperature = 1 will run the Raw2Temp function upon import
	// usevirtual = 1 will import the avi as a virtual stack
	
	
	if(vidtype=="seq"){
		RawThermalType="tiff";		
	}
	if(vidtype=="csq"){
		RawThermalType="jpegls";
	}	

	// Define where the perl executable is installed
	
	if(OS=="Mac OS X"){
		var perlpath=perlpathOSX;
		var exiftoolpath=exiftoolpathOSX;
		var exiftool=exiftoolOSX;
		var ffmpegpath=ffmpegpathOSX;
	}

	if(OS=="Linux"){
		var perlpath=perlpathLinux;
		var exiftoolpath=exiftoolpathLinux;
		var exiftool=exiftoolOSX;
		var ffmpegpath=ffmpegpathLinux;
	}
	
	if(substring(OS, 0, 5)=="Windo"){
		var perlpath=perlpathWindows;
		var exiftoolpath=exiftoolpathWindows;
		var exiftool=exiftoolWindows;
		var ffmpegpath=ffmpegpathWindows;
	}
	
	// Define where the perl is located
	perl=perlpath + "perl";

	// define the executable for ffmpeg
	ffmpeg=ffmpegpath + "ffmpeg";

	// Select an video file to be converted
	filepath=File.openDialog("Select a" + vidtype + "File"); 
	//file=File.openAsString(filepath); 

	// filedir = the directory where the file is located
	filedir=File.getParent(filepath);
	
	//	make a temporary folder within the directory
	tempfolder=filedir + File.separator + "temp";
	File.makeDirectory(tempfolder);
	
	print("Loading: ", filepath);
	
	print("Extracting calibration and image settings");
	
	// populate an array called flirvals with 14 entries to accept the array output from the flirvalues function
	flirvals=newArray(14);

	var printvalues="No";
	
	flirvals=flirvalues(filepath, printvalues);
	
	// define the constants extracted from the flir values function
	var PR1=flirvals[0];
	var PB=flirvals[1];
	var PF=flirvals[2];
	var PO=flirvals[3];
	var PR2=flirvals[4];
	var E=flirvals[5];
	var OD=flirvals[6];
	var RTemp=flirvals[7];
	var ATemp=flirvals[8];
	var IRWTemp=flirvals[9];
	var IRT=flirvals[10];
	var RH=flirvals[11];
	var imagewidth=flirvals[12];
	var imageheight=flirvals[13];
	
	Array.print(flirvals);
	
	if(outtype=="avi"){
		fileout=File.nameWithoutExtension + "." + outtype; // outtype should be "avi"
	}

	var pixfmt="gray16be";
	
	if(outcodec=="tiff"){
		pixfmt="gray16le";
	}
	
	if(outtype=="png"){
		outputfolder=filedir + File.separator + File.nameWithoutExtension;
		//print(outputfolder);
		File.makeDirectory(outputfolder);
		fileout=File.nameWithoutExtension + File.separator + File.nameWithoutExtension + "_%05d" + "." + outtype; // outtype should be "png"
		pixfmt="gray16be";
	}
    
	if(outtype=="tiff"){
		outputfolder=filedir + File.separator + File.nameWithoutExtension;
		//print(outputfolder);
		File.makeDirectory(outputfolder);
		fileout=File.nameWithoutExtension + File.separator + File.nameWithoutExtension + "_%05d" + "." + outtype; // outtype should be "tiff"
		pixfmt="gray16le";
	}
	
	// Define the syntax for the exec command to split the sequence file into .fff files
	splitfffexeccmd = perlpath + "perl " + perlsplit + " -i " + filepath + " -o " + tempfolder + " -b frame -p fff -x fff";
	print("Splitting the video file into its .fff files with: ");
	print(splitfffexeccmd);

	// Execute the split.pl script on the SEQ file to create fff files
	exec(perl, perlsplit, "-i", filepath, "-o", tempfolder, "-b", "frame", "-p", "fff", "-x", "fff");

	// Extract Date/Time Original from the .fff files
	timefind =  exiftoolpath + exiftool + " -*Original* " + tempfolder + File.separator + "*.fff -r -q";
	print("Extracting frame times with: ");
	print(timefind);
	
	// Execute the timefind command
	//	flirvals=exec("/bin/sh", "-c", timefind);
	
	if(OS=="Mac OS X"){
		flirvals=exec("/bin/sh", "-c", timefind);	
	}

	if(OS=="Linux"){
		flirvals=exec("/bin/sh", "-c", timefind);		
	}

	if(substring(OS, 0, 5)=="Windo"){
		flirvals=exec("cmd", "/c", timefind);
	}

	flirvals=replace(flirvals, "Date/Time Original", "");
	flirvals=replace(flirvals, "  ", ""); // 2 spaces replace with null
	flirvals=replace(flirvals, ": ", ""); // 2 spaces replace with null
	nframes=lengthOf(flirvals)/30; // 30 characters per line, will allow to calculate the number of frames
	timeoriginal=newArray(nframes+1);
		
	// 29 characters per line (30, including \n)
	// Date is character 0 through 10
	// Time is character 11 through 23
	
	dateoriginal=replace(substring(flirvals, 0, 10), ":", "-");

	for(i = 1; i <=nframes; i++){
		timeoriginal[i]=substring(flirvals, 11+(i-1)*30, 23+(i-1)*30);
	}

	maxnumframe=minOf(11, nframes);
	sec=newArray(maxnumframe);
	//min=newArray(maxnumframe);
	//hour=newArray(maxnumframe);
	
	for(i=0; i<maxnumframe; i++){
		//day[i]=parseFloat(
		//hour[i]=parseFloat(substring(timeoriginal[i], 0, 2));
		//min[i]=parseFloat(substring(timeoriginal[i], 3, 5)); 
		sec[i]=parseFloat(substring(timeoriginal[i+1], 6, 12));
	}

	framediff=newArray(maxnumframe-1);
	for(i=0; i<maxnumframe-1; i++){
		framediff[i]=sec[i+1] - sec[i];
		if(framediff[i]<0){
			rem=60*abs(round(framediff[i]/60));
			framediff[i]=framediff[i]+rem;
		}
	}
	
	Array.print(framediff);
	Array.getStatistics(framediff, mean);
	meanframediff=mean;

	print("Video frame time difference is: " + meanframediff + " seconds");
	
	// Combine fff files into thermalvid.raw using exiftool raw binary extraction function
	// Difficulty getting the piping (> or |) to work with the default exec command. 
	// See: http://imagej.1557.x6.nabble.com/macro-Redirection-in-exec-UNIX-binary-td3687463.html
	
	rawcombinecmd = exiftoolpath + exiftool +  " -b -RawThermalImage " + tempfolder + File.separator + "*.fff > " + filedir + File.separator + "thermalvid.raw";
	print("Combine the fff files into a thermalvid.raw file with: ");
	print(rawcombinecmd);
	
	if(OS=="Mac OS X"){
		exec("/bin/sh", "-c", rawcombinecmd);	
	}

	if(OS=="Linux"){
		exec("/bin/sh", "-c", rawcombinecmd);		
	}

	if(substring(OS, 0, 5)=="Windo"){
		exec("cmd", "/c", exiftoolpath + exiftool, "-b", "-RawThermalImage", tempfolder + File.separator + "*.fff", ">", filedir + File.separator + "thermalvid.raw");
	}

	// Execute the split.pl script on thermalvid.raw to create tiff (or jpegls) files
	splittiffexeccmd = perlpath + "perl " + perlsplit + " -i " + filedir + "/thermalvid.raw" + " -o " + filedir + "/temp -b frame -p " + RawThermalType + " -x " + RawThermalType;
	print("Splitting the thermalvid.raw file into " + RawThermalType + " files with: ");
	print(splittiffexeccmd);
	
	if(vidtype=="seq"){
		exec(perl, perlsplit, "-i", filedir + File.separator + "thermalvid.raw", "-o", filedir + File.separator + "temp", "-b", "frame", "-p", "tiff", "-x", "tiff");
	}
	
	if(vidtype=="csq"){
		exec(perl, perlsplit, "-i", filedir + File.separator + "thermalvid.raw", "-o", filedir + File.separator + "temp", "-b", "frame", "-p", "jpegls", "-x", "jpegls");
	}

	// Execute the ffmpeg command to assimilate all the tiff files into one avi file
	print("Combining the " + RawThermalType + " files into " + outcodec + " files ready for import with: ");
	tiffcombinecmd = ffmpeg + " -f" + " image2" + " -vcodec" + " " + RawThermalType + " -r" + " 30" + " -i " + tempfolder + File.separator + "frame%05d." + RawThermalType + " -pix_fmt" + " gray16be" + " -vcodec " + outcodec + " " + filedir + File.separator + fileout + " -y";   
    print(tiffcombinecmd);    
    
    exec(ffmpeg, "-f", "image2", "-vcodec", RawThermalType, "-r", "30", "-i", tempfolder + File.separator + "frame%05d." + RawThermalType, "-pix_fmt", pixfmt, "-vcodec", outcodec, filedir + File.separator + fileout, "-y");
	
	templist = getFileList(tempfolder);
	for (i = 0; i < templist.length; i++){
      tempfilesdelete_success=File.delete(tempfolder + File.separator + templist[i]);	
	}	
	
	thermalviddelete_success=File.delete(filedir + File.separator + "thermalvid.raw");
	tempfolderdelete_success=File.delete(filedir + File.separator + "temp" + File.separator );
		
	if(tempfilesdelete_success + tempfolderdelete_success + thermalviddelete_success==3){
		print("Temporary files and folder deleted");
	}


	if(outtype=="png"){
		print("Importing Image Sequence of PNG files");
		pngsequenceimportarguments="open=" + outputfolder + " sort";
		run("Image Sequence...", pngsequenceimportarguments);
	}

	if(outtype=="tiff"){
		print("Importing Image Sequence of TIFF files");
		tiffsequenceimportarguments="open=" + outputfolder + " sort";
		run("Image Sequence...", tiffsequenceimportarguments);
	}

	if(outtype=="avi"){
		print("Importing AVI file");
		ffmpegimportarguments = "choose=" + filedir + File.separator + fileout + " first_frame=0 last_frame=-1";
		
		if(usevirtual==1){
		   ffmpegimportarguments = "choose=" + filedir + File.separator + fileout + " use_virtual_stack first_frame=0 last_frame=-1";
		}
		
		run("Movie (FFMPEG)...", ffmpegimportarguments);
	}

	print("Adding file time origin as slice label");
	for (i=1; i<=nSlices; i++) { 
		setSlice(i);
		run("Set Label...", "label=" + timeoriginal[i]);
	}
	
	//run("Raw2Temp Tool");
	if(converttotemperature==1){
		print("Converting file to temperature");
		print("\n");
		Raw2Temp(PR1, PR2, PB, PF, PO, E, OD, RTemp, ATemp, IRWTemp, IRT, RH, defaultpalette, "Yes");		
	}
	
	print("Done");
	print("\n");
	
}


function Raw2Temp(PR1, PR2, PB, PF, PO, E, OD, RTemp, ATemp, IRWTemp, IRT, RH, palettetype, dialogprompt) {

	print("Running Raw2Temp function");
	
	if(is("Virtual Stack")==true){
		run("Duplicate...", "duplicate");
	}
	
	if(dialogprompt=="Yes"){
		
		byteorder=newArray("Default", "Swap");
		defaultbyteorder="Default";
		// Create a prompt dialog to ask user to verify the values to be used in the calculations below
		Dialog.create("Verify Camera and Object Parameters");
		Dialog.addMessage("Camera parameters can be stored to memory using the FLIR Calibration Values Tool");
		Dialog.addMessage("Note: TIFF file pixel byte are usually little endian\nPNG file pixel bytes are usually big endian");
		Dialog.addChoice("Swap Byte Order?", byteorder, defaultbyteorder); 
		Dialog.addMessage("Camera Calibration Constants:");
		Dialog.addNumber("Planck R1:", PR1, 2, 12, "unitless"); //21106.77 //21546.203
		Dialog.addNumber("Planck R2:", PR2, 8, 12, "unitless"); //0.012545258 //0.016229488 
		Dialog.addNumber("Planck B:", PB, 0, 5, "unitless"); //1501 //1507.2
		Dialog.addNumber("Planck F:", PF, 0, 2, "unitless");//1
  		Dialog.addNumber("Planck O:", PO, 0, 5, "unitless"); //-7340 //-6331
    	Dialog.addMessage("Object Parameters:");
   		Dialog.addNumber("Object Emissivity:", E, 3, 6, "unitless");
    	Dialog.addNumber("Object Distance:", OD, 1, 6, "m");
    	Dialog.addNumber("Reflected Temperature (C):", RTemp, 2, 6, "C");
    	Dialog.addNumber("Atmospheric Temperature (C):", ATemp, 2, 6, "C");
   	 	Dialog.addNumber("Window Temperature (C):", IRWTemp, 2, 6, "C");
    	Dialog.addNumber("Window Transmittance:", IRT, 3, 6, "unitless");
    	Dialog.addNumber("Relative Humidity:", RH, 2, 6, "%");
    	Dialog.addChoice("Palette", palettetypes, defaultpalette);
		Dialog.show();

		var ByteOrder=Dialog.getChoice();
		var PR1 = Dialog.getNumber();
		var PR2 = Dialog.getNumber();
		var PB = Dialog.getNumber();
		var PF = Dialog.getNumber();
		var PO = Dialog.getNumber();
		var E = Dialog.getNumber();
		var OD = Dialog.getNumber();
		var RTemp = Dialog.getNumber();
		var ATemp = Dialog.getNumber();
		var IRWTemp = Dialog.getNumber();
		var IRT = Dialog.getNumber();
		var RH = Dialog.getNumber();
		var palettetype = Dialog.getChoice();
	}
	
	//setBatchMode(true);
	
	ATA1 = 0.006569; //Atmospheric Trans Alpha 1
	ATA2 = 0.012620; //Atmospheric Trans Alpha 2 
	ATB1 = -0.002276; //Atmospheric Trans Beta 1
	ATB2 = -0.006670; //Atmospheric Trans Beta 2 
	ATX =  1.900000; //Atmospheric Trans X

	emisswind = 1- IRT; 
  	reflwind = 0; // anti-reflective coating on window
 	h2o = (RH/100)*exp(1.5587+0.06939*(ATemp)-0.00027816*(ATemp*ATemp)+0.00000068455*(ATemp*ATemp*ATemp)); // converts relative humidity into water vapour pressure (I think in units mmHg)
  	tau1 = ATX*exp(-sqrt(OD/2)*(ATA1+ATB1*sqrt(h2o)))+(1-ATX)*exp(-sqrt(OD/2)*(ATA2+ATB2*sqrt(h2o))); // atmos transmittance from object to window
  	tau2 = ATX*exp(-sqrt(OD/2)*(ATA1+ATB1*sqrt(h2o)))+(1-ATX)*exp(-sqrt(OD/2)*(ATA2+ATB2*sqrt(h2o))); // atmos transmittance from window to camera

	rawrefl1= PR1/(PR2*(exp(PB/(RTemp+273.15))-PF))-PO;   // radiance reflecting off the object before the window
	rawrefl1attn = (1-E)/E*rawrefl1;   // attn = the attenuated radiance (in raw units) 

	rawatm1 = PR1/(PR2*(exp(PB/(ATemp+273.15))-PF))-PO; // radiance from the atmosphere (before the window)
	rawatm1attn = (1-tau1)/E/tau1*rawatm1; // attn = the attenuated radiance (in raw units) 

	rawwind = PR1/(PR2*(exp(PB/(IRWTemp+273.15))-PF))-PO;
	rawwindattn = emisswind/E/tau1/IRT*rawwind; 

	rawrefl2 = PR1/(PR2*(exp(PB/(RTemp+273.15))-PF))-PO;   
	rawrefl2attn = reflwind/E/tau1/IRT*rawrefl2;

	rawatm2 = PR1/(PR2*(exp(PB/(ATemp+273.15))-PF))-PO;
	rawatm2attn = (1-tau2)/E/tau1/IRT/tau2*rawatm2;

	rawsubtract = (rawatm1attn + rawatm2attn + rawwindattn + rawrefl1attn + rawrefl2attn);
	rawdivisor = E*tau1*IRT*tau2;
	
	//a = newArray(65536); 
	//templookup=newArray(65536);
	//for (i=1; i<65536; i++) {
	//	a[i]=i; 	
	//	templookup[i] = 1500/log(21000/(0.012*(a[i]/0.9-100-7300))+1)-273.15;
		//templookup = PB/log(PR1/(PR2*(a[i]/rawdivisor-rawsubtract+PO))+PF)-273.15;
	//}
	
	
	if(nSlices()>1){
		run("32-bit", "stack");
		run("Macro...", "code=v=" +PB+ "/log(" +PR1+ "/(" +PR2+ "*(v/" +rawdivisor+ "-" +rawsubtract+ "+" +PO+ "))+" +PF+ ")-273.15 stack");
		Stack.getStatistics(count, mean, min, max, std);
		mintemp=min;
		maxtemp=max;
	}

	if(nSlices()==1){
		run("32-bit");	
		run("Macro...", "code=v=" +PB+ "/log(" +PR1+ "/(" +PR2+ "*(v/" +rawdivisor+ "-" +rawsubtract+ "+" +PO+ "))+" +PF+ ")-273.15");
		getStatistics(count, mean, min, max, std);
		mintemp=min;
		maxtemp=max;
	}
	
	//setBatchMode(false);
	//mintemp=PB/log(PR1/(PR2*(minpix/rawdivisor-rawsubtract+PO))+PF)-273.15;
	//maxtemp=PB/log(PR1/(PR2*(maxpix/rawdivisor-rawsubtract+PO))+PF)-273.15;

	setMinAndMax(mintemp, maxtemp);	
	run(palettetype);
}


function flirvalues(filepath, printvalues){

	print("Running flirvalues function");
	
	if(OS=="Mac OS X"){
		var perlpath=perlpathOSX;
		var exiftoolpath=exiftoolpathOSX;
		var exiftool=exiftoolOSX;
		var ffmpegpath=ffmpegpathOSX;
	}

	if(OS=="Linux"){
		var perlpath=perlpathLinux;
		var exiftoolpath=exiftoolpathLinux;
		var exiftool=exiftoolOSX;
		var ffmpegpath=ffmpegpathLinux;
	}
	
	if(substring(OS, 0, 5)=="Windo"){
		var perlpath=perlpathWindows;
		var exiftoolpath=exiftoolpathWindows;
		var exiftool=exiftoolWindows;
		var ffmpegpath=ffmpegpathWindows;
	}
	
	flirvals=exec(exiftoolpath + exiftool,  "-Planck*", "-*Emissivity", "-*Distance", "-*Temperature", "-*Transmission",  "-*Humidity", "-*Height", "-*Width", "-*Original", "-*Date",  filepath);
	
         PR1 = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Planck R1"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Planck R1")) ));
		 PB = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Planck B"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Planck B")) ));
		 PF = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Planck F"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Planck F")) ));
		 PO = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Planck O"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Planck O")) ));
		 PR2 = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Planck R2"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Planck R2")) ));
		 E = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Emissivity"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Emissivity")) ));
		 OD = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Object Distance"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Object Distance")) ));
		 RTemp = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Reflected Apparent Temperature"))+1, indexOf(flirvals, "C\n", indexOf(flirvals, "Reflected Apparent Temperature")) ));
		 ATemp = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Atmospheric Temperature"))+1, indexOf(flirvals, "C\n", indexOf(flirvals, "Atmospheric Temperature")) ));
		 IRWTemp = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "IR Window Temperature"))+1, indexOf(flirvals, "C\n", indexOf(flirvals, "IR Window Temperature")) ));
		 IRT = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "IR Window Transmission"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "IR Window Transmission")) ));
		 RH = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Relative Humidity"))+1, indexOf(flirvals, "%\n", indexOf(flirvals, "Relative Humidity")) ));
		 imagewidth = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Width"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Width")) ));
		 imageheight = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Height"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Height")) ));

		if(printvalues == "Yes"){
			Dialog.create("FLIR Values Extracted from: " + File.getName(filepath));
			Dialog.addMessage("- Camera Calibration Constants -");
			Dialog.addMessage("      Plank R1: " + PR1);
			Dialog.addMessage("      Plank R2: " + PR2);
			Dialog.addMessage("      Plank B " + PB);
			Dialog.addMessage("      Plank F: " + PF);
			Dialog.addMessage("      Plank O: " + PO);
			Dialog.addMessage("- Default Object Parameters -");
			Dialog.addMessage("      Emissivity: " + d2s(E,2));
			Dialog.addMessage("      Object Distance: " + d2s(OD,2));
			Dialog.addMessage("      Reflected Apparent Temperature: " + d2s(RTemp,2));
			Dialog.addMessage("      Atmospheric Temperature: " + d2s(ATemp,2));
			Dialog.addMessage("      IR Window Temperature: " + d2s(IRWTemp,2));
			Dialog.addMessage("      IR Window Transmission: " + d2s(IRT,3));
			Dialog.addMessage("      Relative Humidity: " + d2s(RH,2));
			Dialog.addMessage("      Thermal Image Width: " + imagewidth);
			Dialog.addMessage("      Thermal Image Height: " + imageheight);
			Dialog.addMessage("Press OK to export results to log window\nand store parameters for future Raw2Temp call");
			Dialog.show()
			
			print("\n");
			print("FLIR Values Extracted from: " + filepath + "\n");
			print("Camera Calibration Constants:");
			//print(flirvals);
			setFont("SansSerif", 12);
			print("Planck R1: ", d2s(PR1,9));
			print("Planck R2: ", d2s(PR2,9));
			print("Planck B: ", d2s(PB,9));
			print("Planck F: ", d2s(PF,0));
			print("Planck O: ", d2s(PO,0));
			print("Thermal Image Width: ", imagewidth);
			print("Thermal Image Height: ", imageheight + "\n");
			print("Default Object Parameters:");
			print("Emissivity: ", d2s(E,2));
			print("Object Distance: ", d2s(OD,2));
			print("Reflected Apparent Temperature: ", d2s(RTemp,2));
			print("Atmospheric Temperature: ", d2s(ATemp,2));
			print("IR Window Temperature: ", d2s(IRWTemp,2));
			print("IR Window Transmission: ", d2s(IRT,3));
			print("Relative Humidity: ", d2s(RH,2));
			print("\n");
		
		}

		output=newArray(14);
		output=newArray(PR1, PB, PF, PO, PR2, E, OD, RTemp, ATemp, IRWTemp, IRT, RH, imagewidth, imageheight);
 
        call("ij.Prefs.set", "PR1.persistent",toString(PR1)); 
		call("ij.Prefs.set", "PB.persistent",toString(PB)); 
		call("ij.Prefs.set", "PF.persistent",toString(PF)); 
		call("ij.Prefs.set", "PR2.persistent",toString(PR2)); 
		call("ij.Prefs.set", "PO.persistent",toString(PO)); 
		call("ij.Prefs.set", "E.persistent",toString(E)); 
		call("ij.Prefs.set", "OD.persistent",toString(OD)); 
		call("ij.Prefs.set", "RTemp.persistent",toString(RTemp)); 
		call("ij.Prefs.set", "ATemp.persistent",toString(ATemp)); 
		call("ij.Prefs.set", "IRWTemp.persistent",toString(IRWTemp)); 
		call("ij.Prefs.set", "IRT.persistent",toString(IRT)); 
		call("ij.Prefs.set", "RH.persistent",toString(RH)); 
		call("ij.Prefs.set", "imagewidth.persistent",toString(imagewidth)); 
		call("ij.Prefs.set", "imageheight.persistent",toString(imageheight)); 
		
		return output;	
}



function flirdate(filepath, printvalues){

	print("Running flirdate function");
	
	if(OS=="Mac OS X"){
		var perlpath=perlpathOSX;
		var exiftoolpath=exiftoolpathOSX;
		var exiftool=exiftoolOSX;
		var ffmpegpath=ffmpegpathOSX;
	}

	if(OS=="Linux"){
		var perlpath=perlpathLinux;
		var exiftoolpath=exiftoolpathLinux;
		var exiftool=exiftoolOSX;
		var ffmpegpath=ffmpegpathLinux;
	}
	
	if(substring(OS, 0, 5)=="Windo"){
		var perlpath=perlpathWindows;
		var exiftoolpath=exiftoolpathWindows;
		var exiftool=exiftoolWindows;
		var ffmpegpath=ffmpegpathWindows;
	}

	flirvals=exec(exiftoolpath + exiftool, "-*Original*",  filepath);
	
    datetimeoriginal=substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Original"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Original")) );
    dateoriginal=substring(datetimeoriginal, 1, 11);
    dateoriginal=replace(dateoriginal, ":", "-");
    timeoriginal=substring(datetimeoriginal, 12,24);
  
		if(printvalues == "Yes"){
			Dialog.create("Date/Time Information:");
			Dialog.addMessage("Date Original: " + dateoriginal);
			Dialog.addMessage("Time Original: " + timeoriginal);
			Dialog.addMessage("Press OK to export results to Log window");
			Dialog.show()

			print("\n");
			print("Date/Time Information:");
			setFont("SansSerif", 12);
			print("Date Original: ", dateoriginal);
			print("Time Original: ", timeoriginal);
			print("\n");
		}

		output=newArray(2);
		output=newArray(dateoriginal, timeoriginal);
		return output;	
}




function addMeasurementLabel(type, units, decimals, colour, addROI, drawx, drawy) {

	print("Running addMeasurementLabel function");
	
	// type should be one of: Mean StdDev Min Max Mode Median Skew or Kurt
	// but will be converted to: mean min standard modal median skewness kurtosis
	
	resulttype=type;

	if(type=="Mean"){
		measuretype="mean";
	}
	if(type=="StdDev"){
		measuretype="standard";
	}
	if(type=="Min"){
		measuretype="min";
	}
	if(type=="Max"){
		measuretype="min";
	}
	if(type=="Mode"){
		measuretype="modal";
	}
	if(type=="Median"){
		measuretype="median";
	}
	if(type=="Skewness"){
		measuretype="skewness";
		resulttype="Skew";
	}
	if(type=="Kurtosis"){
		measuretype="kurtosis";
		resulttype="Kurt";
	}
	
	measurement=measuretype + " redirect=None decimal=" + decimals;
	n = nSlices;
	getSelectionBounds(x, y, width, height);

	run("Clear Results");
	run("Set Measurements...", measurement);
	
     	 for (slice=1; slice<=n; slice++) {
        	showProgress(slice, n);
         	setSlice(slice);
		 	rownum=getSliceNumber()-1;
        	run("Measure");
        	label = type + ": " + d2s(getResult(resulttype, nResults-1), 2) + " " + units;
 			setColor(colour, colour, colour);
  			setFont("SansSerif", 14);
         	drawString(label, drawx, drawy);
     	 }
     	 
	if(addROI==1){
		 Roi.setStrokeColor(colour, colour, colour);
     	 Overlay.addSelection;     	 
	}
     	
}


/////////////////////////////////////////////// Macros //////////////////////////////////////////////////////

// This will call a subset of LUTs that are more appropriate for thermal imaging.
macro "Thermal LUT Menu Tool - C037T0b11LT6b09UTcb09T" {
      cmd = getArgument();
          run(cmd);
}

macro "Grayscale LUT" {
        run("Grays");
        if (getWidth==64 && getHeight==480)
            rename("Grayscale");
}

macro "Adjust Brightness and Contrast Action Tool - C037D04D05D06D07D08D09D0aD0bD0cD14D18D1cD24D28D2cD34D38D3cD45D46D47D49D4aD4bD6bD6cD76D77D78D79D7aD84D85Da6Da7Da8Da9DaaDb5DbbDc4DccDd4DdcDe5DebDf6Dfa" {
        run("Enhance Contrast", "saturated=0.35");
        run("Brightness/Contrast...");
}

macro "Previous LUT Action Tool - C037T4d14<" {
        cycleLUTs(-1);
}

macro "Previous LUT" {
        cycleLUTs(-1);
}

macro "Next LUT Action Tool - C037T4d14>" {
        cycleLUTs(1);
}

macro "Next LUT" {
        cycleLUTs(1);
}

macro "Invert LUT Action Tool - C037R12ccL12cc" {
        run("Invert LUT");
}

macro "Invert LUT" {
        run("Invert LUT");
}

macro "Add Calibration Bar Action Tool - C000D10D11D12D13D14D15D16D17D18D19D1aD1bD1cD1dD1eD1fD20D2dD2eD2fD30D3dD3eD3fD40D4dD4eD4fD50D5dD5eD5fD60D61D62D63D64D65D66D67D68D69D6aD6bD6cD6dD6eD6fD70D72D74D76D78D7aD7cD7eD80D82D84D86D88D8aD8cD8eDa4Da5Da6Da9DaaDabDacDadDb3Db7Db9DbbDc3Dc7Dc9DcbDd4Dd6Dd9C001C002C003C004C005C006C007C107C108C208C308C309C409D2bD2cD3bD3cD4bD4cD5bD5cC409C509C609C709C809C909Ca09D29D2aD39D3aD49D4aD59D5aCa09Cb09Cc09Cc08Cc18Cc17Cd17Cd26D27D28D37D38D47D48D57D58Cd26Cd25Cd34Cd33Ce33Ce32Ce41Ce40Ce50Ce60D25D26D35D36D45D46D55D56Ce60Cf60Cf70Cf80Cf90Cfa0D23D24D33D34D43D44D53D54Cfa0Cfb0Cfc0Cfd0Cfd1D21D22D31D32D41D42D51D52Cfd1Cfe2Cfe3Cfe4Cfe5Cfe6Cff6Cff7Cff8Cff9CffaCffbCffcCffdCffeCfff"{
	run("32-bit");
	run("Calibrate...", "function=None");
	run("Calibration Bar...", "location=[Upper Right] fill=None label=White number=5 decimal=1 font=12 zoom=1 overlay=1");
}

macro "Add Calibration Bar"{
	//w=getWidth();
	//h=getHeight();
	getMinAndMax(min, max);
	range=max-min;
	
	//   	newImage("LUT", "16-bit ramp", 480, 32, 1);
	//newwidth=w+69;
	//run("Canvas Size...", "width=" + newwidth + " height=" + h + " position=Center-Left");
	run("32-bit");
	run("Calibrate...", "function=None");
	run("Calibration Bar...", "location=[Upper Right] fill=None label=White number=5 decimal=1 font=12 zoom=1 overlay=1");
}

macro "-" {} //menu divider

macro "Raw Import Mikron RTV Action Tool - C000D00D01D02D03D04D05D06D09D0aD0bD0cD0dD0eD0fD10D13D19D1cD20D23D24D25D29D2cD2dD2eD30D31D32D33D35D36D39D3aD3bD3cD3eD3fD54D55D56D59D61D62D63D64D69D70D71D74D76D77D79D7aD7bD7cD7dD7eD7fD81D82D83D84D89D94D95D96D99Db0Db1Db2Db3Db9DbaDbbDc3Dc4Dc5Dc6DcbDccDcdDd1Dd2Dd3Dd4DddDdeDdfDe3De4De5De6DebDecDedDf0Df1Df2Df3Df9DfaDfbC000C111C222C333C444C555C666C777C888C999D67D78D87C999CaaaCbbbCcccCdddCeeeCfff" {
	RawImportMikronRTV();
}

macro "Raw Import Mikron RTV" {
	RawImportMikronRTV();
}

macro "Raw Import FLIR SEQ Action Tool - C000D00D01D02D03D04D05D06D0aD0bD0fD10D13D19D1cD1fD20D23D24D25D29D2cD2fD30D31D32D33D35D36D39D3dD3eD3fD54D55D56D59D5aD5bD5cD5dD5eD5fD61D62D63D64D69D6cD6fD70D71D74D76D77D79D7cD7fD81D82D83D84D89D8cD8fD94D95D96D99D9fDb0Db1Db2Db3DbaDbbDbcDbdDbeDc3Dc4Dc5Dc6Dc9DcfDd1Dd2Dd3Dd4Dd9DdeDdfDe3De4De5De6DeaDebDecDedDeeDefDf0Df1Df2Df3DffC000C111C222C333C444C555C666C777C888C999D67D78D87C999CaaaCbbbCcccCdddCeeeCfff" {
	RawImportFLIRSEQ();
}

macro "Raw Import FLIR SEQ" {
	RawImportFLIRSEQ();
}

macro "-" {} //menu divider

macro "Image Byte Swap Action Tool - C000D12D13D1cD1dD21D24D25D26D27D28D29D2aD2bD2eD31D34D35D36D37D38D39D3aD3bD3eD42D43D4cD4dD82D83D91D92D93D94Da0Da1Da2Da3Da4Da5Db2Db3Dc2Dc3DccDcdDd2Dd3Dd4Dd5Dd6Dd7Dd8Dd9DdaDdbDdeDe2De3De4De5De6De7De8De9DeaDebDeeDfcDfdC000C111C222C333C444C555C666C777C888C999CaaaD1bD4bCaaaD11D14DcbDceDfbDfeCaaaD1eD4eCaaaD41D44CbbbCcccD2dD3dCcccD22DddDedCcccD32CcccD72D73CcccDc4CcccCdddD23D2cD3cDdcDecCdddDb1CdddD33CeeeDb0CeeeD8cD8dDb4DbcDbdCeeeCfffD20D30Df5CfffDc7CfffD17D18D47D48Dc6Dc8Df6Df7Df8CfffD16D19D46D49Dc9Df9CfffDf4CfffDb5CfffDc1"{
	run("Byte Swapper");
}
macro "Image Byte Swap"{
	run("Byte Swapper");
}

macro "-" {} //menu divider

macro "Convert FLIR JPG(s)"{
	ConvertFLIRJPGs();
}

macro "Import FLIR JPG Action Tool - C000D1eD2eD38D3eD43D48D49D4aD4bD4cD4dD54D65D68D69D6aD6bD6cD6dD6eD70D71D72D73D74D75D76D78D7bD80D81D82D83D84D85D86D88D8bD95D98D99D9aDa4Db3Db9DbaDbbDbcDbdDc8DceDd8DdcDdeDecDedDeeC000C111C222C333C444C555C666C777C888C999CaaaCbbbCcccCdddCeeeCfff"{
	ConvertImportFLIRJPG();
}

macro "Import FLIR JPG"{
	ConvertImportFLIRJPG();
}

macro "Import/Convert FLIR SEQ Action Tool - C000D19D1aD1eD28D2bD2eD38D3bD3eD43D48D4cD4dD4eD54D65D68D69D6aD6bD6cD6dD6eD70D71D72D73D74D75D76D78D7bD7eD80D81D82D83D84D85D86D88D8bD8eD95D98D9eDa4Db3Db9DbaDbbDbcDbdDc8DceDd8DdeDe9DeaDebDecDedDeeDefDfeDffC000C111C222C333C444C555C666C777C888C999CaaaCbbbCcccCdddCeeeCfff" {
	
	var converttotemperature = 1;
	var usevirtual = 0;
	
	Dialog.create("Select a FLIR SEQ File");
	Dialog.addMessage("Define parameters for Video Import");
	Dialog.addMessage("If you choose file type 'Video', a single .avi file\nwill be created and imported using Import-MOVIE (FFMPEG)");
	Dialog.addMessage("If you choose file type 'PNG', a separate PNG files\nwill be created for each SEQ frame");
	Dialog.addMessage("If you choose file type 'TIFF', a separate TIFF files\nwill be created for each SEQ frame");
	Dialog.addChoice("Output File Type (avi, png, tiff)", newArray("avi", "png", "tiff"), "avi");
	Dialog.addChoice("Video Image Encoding (ignored if choosing file)", newArray("jpegls", "png"), "jpegls");
	Dialog.addCheckbox("Convert to Temperature on Import", converttotemperature);
	Dialog.addMessage("Unselect Convert to Temperature for faster loading.\nThe imported file will be a virtual stack.");
	Dialog.show();
	
	var outtypechoice=Dialog.getChoice();
	var encodetypechoice = Dialog.getChoice();
	var converttotemperature = Dialog.getCheckbox();

	if(outtypechoice=="avi"){
		var outtype="avi";
		var outcodec=encodetypechoice;
	}

	if(outtypechoice=="png"){
		var outtype="png";
		var outcodec="png";
	}

	if(outtypechoice=="tiff"){
		var outtype="tiff";
		var outcodec="tiff";
	}

	if(converttotemperature==0){
		var usevirtual=1;
	}
	
	ConvertFLIRVideo("seq", outtype, outcodec, converttotemperature, usevirtual);
}

macro "Import/Convert FLIR SEQ" {
	
	var converttotemperature = 1;
	var usevirtual = 0;
	
	Dialog.create("Select a FLIR SEQ File");
	Dialog.addMessage("Define parameters for Video Import");
	Dialog.addMessage("If you choose file type 'Video', a single .avi file\nwill be created and imported using Import-MOVIE (FFMPEG)");
	Dialog.addMessage("If you choose file type 'PNG', a separate PNG files\nwill be created for each SEQ frame");
	Dialog.addMessage("If you choose file type 'TIFF', a separate TIFF files\nwill be created for each SEQ frame");
	Dialog.addChoice("Output File Type (avi, png, tiff)", newArray("avi", "png", "tiff"), "avi");
	Dialog.addChoice("Video Image Encoding (ignored if choosing file)", newArray("jpegls", "png"), "jpegls");
	Dialog.addCheckbox("Convert to Temperature on Import", converttotemperature);
	Dialog.addMessage("Unselect Convert to Temperature for faster loading.\nThe imported file will be a virtual stack.");
	Dialog.show();
	
	var outtypechoice=Dialog.getChoice();
	var encodetypechoice = Dialog.getChoice();
	var converttotemperature = Dialog.getCheckbox();

	if(outtypechoice=="avi"){
		var outtype="avi";
		var outcodec=encodetypechoice;
	}

	if(outtypechoice=="png"){
		var outtype="png";
		var outcodec="png";
	}

	if(outtypechoice=="tiff"){
		var outtype="tiff";
		var outcodec="tiff";
	}

	if(converttotemperature==0){
		var usevirtual=1;
	}
	
	ConvertFLIRVideo("seq", outtype, outcodec, converttotemperature, usevirtual);
}

macro "Import/Convert FLIR CSQ Action Tool - C000D19D1aD1bD1cD1dD28D2eD38D3eD43D48D4eD54D65D69D6aD6eD70D71D72D73D74D75D76D78D7bD7eD80D81D82D83D84D85D86D88D8bD8eD95D98D9cD9dD9eDa4Db3Db9DbaDbbDbcDbdDc8DceDd8DdeDe9DeaDebDecDedDeeDefDfeDffC000C111C222C333C444C555C666C777C888C999CaaaCbbbCcccCdddCeeeCfff" {
	
	
	var converttotemperature = 1;
	var usevirtual = 0;
	
	Dialog.create("Select a FLIR CSQ File");
	Dialog.addMessage("Define parameters for Video Import");
	Dialog.addMessage("If you choose file type 'Video', a single .avi file\nwill be created and imported using Import-MOVIE (FFMPEG)");
	Dialog.addMessage("If you choose file type 'PNG', a separate PNG files\nwill be created for each SEQ frame");
	Dialog.addMessage("If you choose file type 'TIFF', a separate TIFF files\nwill be created for each SEQ frame");
	Dialog.addChoice("Output File Type (avi, png, tiff)", newArray("avi", "png", "tiff"), "avi");
	Dialog.addChoice("Video Image Encoding (ignored if choosing file)", newArray("jpegls", "png"), "jpegls");
	Dialog.addCheckbox("Convert to Temperature on Import", converttotemperature);
	Dialog.addMessage("Unselect Convert to Temperature for faster loading.\nThe imported file will be a virtual stack.");
	Dialog.show();
	
	var outtypechoice=Dialog.getChoice();
	var encodetypechoice = Dialog.getChoice();
	var converttotemperature = Dialog.getCheckbox();

	if(outtypechoice=="avi"){
		var outtype="avi";
		var outcodec=encodetypechoice;
	}

	if(outtypechoice=="png"){
		var outtype="png";
		var outcodec="png";
	}

	if(outtypechoice=="tiff"){
		var outtype="tiff";
		var outcodec="tiff";
	}

	if(converttotemperature==0){
		var usevirtual=1;
	}
	
	ConvertFLIRVideo("csq", outtype, outcodec, converttotemperature, usevirtual);
}

macro "Import/Convert FLIR CSQ" {
	
	var converttotemperature = 1;
	var usevirtual = 0;
	
	Dialog.create("Select a FLIR CSQ File");
	Dialog.addMessage("Define parameters for Video Import");
	Dialog.addMessage("If you choose file type 'Video', a single .avi file\nwill be created and imported using Import-MOVIE (FFMPEG)");
	Dialog.addMessage("If you choose file type 'PNG', a separate PNG files\nwill be created for each SEQ frame");
	Dialog.addMessage("If you choose file type 'TIFF', a separate TIFF files\nwill be created for each SEQ frame");
	Dialog.addChoice("Output File Type (avi, png, tiff)", newArray("avi", "png", "tiff"), "avi");
	Dialog.addChoice("Video Image Encoding (ignored if choosing file)", newArray("jpegls", "png"), "jpegls");
	Dialog.addCheckbox("Convert to Temperature on Import", converttotemperature);
	Dialog.addMessage("Unselect Convert to Temperature for faster loading.\nThe imported file will be a virtual stack.");
	Dialog.show();
	
	var outtypechoice=Dialog.getChoice();
	var encodetypechoice = Dialog.getChoice();
	var converttotemperature = Dialog.getCheckbox();

	if(outtypechoice=="avi"){
		var outtype="avi";
		var outcodec=encodetypechoice;
	}

	if(outtypechoice=="png"){
		var outtype="png";
		var outcodec="png";
	}

	if(outtypechoice=="tiff"){
		var outtype="tiff";
		var outcodec="tiff";
	}

	if(converttotemperature==0){
		var usevirtual=1;
	}
	
	ConvertFLIRVideo("csq", outtype, outcodec, converttotemperature, usevirtual);
}

macro "-" {} //menu divider

macro "FLIR Date Stamps Action Tool - C000D08D09D0aD0bD0cD17D1dD26D2eD35D3eD45D4fD55D57D58D59D5aD5fD65D6aD6fD72D73D75D7aD7eD82D86D8aD8eD90D91D92D94D97D9dDa2Da8Da9DaaDabDacDb2Db4Db6Dc2Dc8Dd0Dd1Dd2Dd4Dd6Dd8De2De8Df2Df3Df4Df5Df6Df7Df8C000C111C222C333C444C555C666C777C888C999CaaaCbbbCcccDc1CcccDd7CcccD83CcccD81CcccDe1CcccCdddD56CdddDe7CdddDa1CdddDb3CdddDc7CdddD16CdddD2dCdddD1eD48D4eDb7CdddD69CdddD49D7bCdddCeeeD46Dc4CeeeD6bDc6CeeeD6eCeeeD93Dc3CeeeDe3CeeeDe9CeeeDa3CeeeDd9CeeeDd3CeeeD99Db5CeeeD74CeeeD1bD2fD54D8fCeeeD19D85Dd5CeeeD25D96Db1De4CeeeDa4Db8CeeeDe6CfffD9bDbaCfffD5eD79CfffDe5CfffD8bCfffD68DadCfffD0dCfffD07D64CfffD1aD63D89Da7Dc5CfffD9aCfffD44D5bDb9De0CfffD84Da0DbbCfffD4aD80Da5Dc0Dc9Df1CfffD62D71Df9CfffD47" {
	filepath=File.openDialog("Select a FLIR Image or Video File"); 
	printvalues="Yes";
	if(File.exists(filepath)){
		flirdate(filepath, printvalues);
	}
}

macro "FLIR Date Stamps" {
	filepath=File.openDialog("Select a FLIR Image or Video File"); 
	printvalues="Yes";
	if(File.exists(filepath)){
		flirdate(filepath, printvalues);
	}
	
}

macro "FLIR Calibration Values Action Tool - C000D00D01D02D03D04D05D10D16D20D22D23D24D27D2dD2eD30D32D34D36D37D38D39D3aD3bD3cD3fD40D42D44D47D4fD50D52D54D56D57D58D59D5aD5bD5cD5fD60D62D63D64D67D6dD6eD70D76D80D81D82D83D84D85DbbDbcDbdDbeDc1Dc2Dc3Dc4Dc5Dc6Dc7Dc8Dc9DcaDcbDcfDd0DdfDe1De2De3De4De5De6De7De8De9DeaDebDefDf3Df5Df7Df9DfbDfcDfdDfeCfffD06D07D08D09D0aD0bD0cD0dD0eD0fD11D12D13D14D15D17D18D19D1aD1bD1cD1dD1eD1fD21D25D26D28D29D2aD2bD2cD2fD31D33D35D3dD3eD41D43D45D46D48D49D4aD4bD4cD4dD4eD51D53D55D5dD5eD61D65D66D68D69D6aD6bD6cD6fD71D72D73D74D75D77D78D79D7aD7bD7cD7dD7eD7fD86D87D88D89D8aD8bD8cD8dD8eD8fD90D91D92D93D94D95D96D97D98D99D9aD9bD9cD9dD9eD9fDa0Da1Da2Da3Da4Da5Da6Da7Da8Da9DaaDabDacDadDaeDafDb0Db1Db2Db3Db4Db5Db6Db7Db8Db9DbaDbfDc0Dd1Dd2Dd3Dd4De0Df0Df1Df2Df4Df6Df8DfaDffCc10DccDcdDceDd5Dd6Dd7Dd8Dd9DdaDdbDdcDddDdeDecDedDee" {
	filepath=File.openDialog("Select a FLIR Image or Video File"); 
	printvalues="Yes";
	if(File.exists(filepath)){
		flirvalues(filepath, printvalues);
	}
}

macro "FLIR Calibration Values" {
	filepath=File.openDialog("Select a FLIR Image or Video File"); 
	printvalues="Yes";
	if(File.exists(filepath)){
		flirvalues(filepath, printvalues);
	}
}


macro "-" {} //menu divider

macro "Raw2Temp Action Tool - C000D00D01D02D03D04D05D06D07D10D13D14D20D23D24D25D30D33D35D36D40D41D42D43D46D47D59D63D6aD6cD74D76D7bD7cD85D86D88D8aD8bD8cD94D95D96D98Da8Db8Dc8Dd8De8Df8Ce50DbaDcaCfc0DbdDcdCf80DbbDcbCff7DbfDcfCd17Db9Dc9Cfe2DbeDceCfb0DbcDcc"{

	// Planck Constants after Recalibration and Service with New Lens in November 2018:
	 //var PR1=17998.529;
	 //var PR2=0.015145967;
	 //var PB=1453.1; 
	 //var PF=1;
	 //var PO=-5854;
	
	// var E = 0.95;
	 //var OD = 1;
	 //var RTemp = 20.0;
	 //var ATemp = 20.0;
	 //var IRWTemp = 20.0;
	 //var IRT = 1.0;
	 //var RH = 50.0;

	byteorder=newArray("Default", "Swap");
	defaultbyteorder="Default";
	
	// Create a prompt dialog to ask user to verify the values to be used in the calculations below
	Dialog.create("Verify Camera and Object Parameters");
	Dialog.addMessage("If Calibration constants are unknown, run the FLIR Calibration Values Tool first!");
	Dialog.addMessage("TIFF file pixel byte are usually little endian\nPNG file pixel bytes are usually big endian");
	Dialog.addChoice("Swap Byte Order?", byteorder, defaultbyteorder); 
	Dialog.addMessage("Camera Calibration Constants:");
	Dialog.addNumber("Planck R1:", PR1, 2, 12, "unitless"); //21106.77 //21546.203
	Dialog.addNumber("Planck R2:", PR2, 8, 12, "unitless"); //0.012545258 //0.016229488 
	Dialog.addNumber("Planck B:", PB, 0, 5, "unitless"); //1501 //1507.2
	Dialog.addNumber("Planck F:", PF, 0, 2, "unitless");//1
    Dialog.addNumber("Planck O:", PO, 0, 5, "unitless"); //-7340 //-6331
    Dialog.addMessage("Object Parameters:");
    Dialog.addNumber("Object Emissivity:", E, 3, 6, "unitless");
    Dialog.addNumber("Object Distance:", OD, 1, 6, "m");
    Dialog.addNumber("Reflected Temperature (C):", RTemp, 2, 6, "C");
    Dialog.addNumber("Atmospheric Temperature (C):", ATemp, 2, 6, "C");
    Dialog.addNumber("Window Temperature (C):", IRWTemp, 2, 6, "C");
    Dialog.addNumber("Window Transmittance:", IRT, 3, 6, "unitless");
    Dialog.addNumber("Relative Humidity:", RH, 2, 6, "%");
    Dialog.addChoice("Palette", palettetypes, defaultpalette);
	Dialog.show();

	var ByteOrder=Dialog.getChoice();
	var PR1 = Dialog.getNumber();
	var PR2 = Dialog.getNumber();
	var PB = Dialog.getNumber();
	var PF = Dialog.getNumber();
	var PO = Dialog.getNumber();
	var E = Dialog.getNumber();
	var OD = Dialog.getNumber();
	var RTemp = Dialog.getNumber();
	var ATemp = Dialog.getNumber();
	var IRWTemp = Dialog.getNumber();
	var IRT = Dialog.getNumber();
	var RH = Dialog.getNumber();
	var palettetype = Dialog.getChoice();
	
	if(ByteOrder == "Swap"){
		run("Byte Swapper");
	}

	Raw2Temp(PR1, PR2, PB, PF, PO, E, OD, RTemp, ATemp, IRWTemp, IRT, RH, palettetype, "No");
}
	
macro "Raw2Temp Tool"{

	byteorder=newArray("Default", "Swap");
	defaultbyteorder="Default";
	
	// Create a prompt dialog to ask user to verify the values to be used in the calculations below
	Dialog.create("Verify Camera and Object Parameters");
	Dialog.addMessage("If Calibration constants are unknown, run the FLIR Calibration Values Tool first!");
	Dialog.addMessage("TIFF file pixel byte are usually little endian\nPNG file pixel bytes are usually big endian");
	Dialog.addChoice("Swap Byte Order?", byteorder, defaultbyteorder); 
	Dialog.addMessage("Camera Calibration Constants:");
	Dialog.addNumber("Planck R1:", PR1, 2, 12, "unitless"); //21106.77 //21546.203
	Dialog.addNumber("Planck R2:", PR2, 8, 12, "unitless"); //0.012545258 //0.016229488 
	Dialog.addNumber("Planck B:", PB, 0, 5, "unitless"); //1501 //1507.2
	Dialog.addNumber("Planck F:", PF, 0, 2, "unitless");//1
    Dialog.addNumber("Planck O:", PO, 0, 5, "unitless"); //-7340 //-6331
    Dialog.addMessage("Object Parameters:");
    Dialog.addNumber("Object Emissivity:", E, 3, 6, "unitless");
    Dialog.addNumber("Object Distance:", OD, 1, 6, "m");
    Dialog.addNumber("Reflected Temperature (C):", RTemp, 2, 6, "C");
    Dialog.addNumber("Atmospheric Temperature (C):", ATemp, 2, 6, "C");
    Dialog.addNumber("Window Temperature (C):", IRWTemp, 2, 6, "C");
    Dialog.addNumber("Window Transmittance:", IRT, 3, 6, "unitless");
    Dialog.addNumber("Relative Humidity:", RH, 2, 6, "%");
    Dialog.addChoice("Palette", palettetypes, defaultpalette);
	Dialog.show();

	var ByteOrder=Dialog.getChoice();
	var PR1 = Dialog.getNumber();
	var PR2 = Dialog.getNumber();
	var PB = Dialog.getNumber();
	var PF = Dialog.getNumber();
	var PO = Dialog.getNumber();
	var E = Dialog.getNumber();
	var OD = Dialog.getNumber();
	var RTemp = Dialog.getNumber();
	var ATemp = Dialog.getNumber();
	var IRWTemp = Dialog.getNumber();
	var IRT = Dialog.getNumber();
	var RH = Dialog.getNumber();
	var palettetype = Dialog.getChoice();
	
	if(ByteOrder == "Swap"){
		run("Byte Swapper");
	}

	Raw2Temp(PR1, PR2, PB, PF, PO, E, OD, RTemp, ATemp, IRWTemp, IRT, RH, palettetype, "No");

}

macro "Raw2Temp SC660" {
	
	byteorder=newArray("Default", "Swap");
	defaultbyteorder="Default";
	
	// Create a prompt dialog to ask user to verify the values to be used in the calculations below
	Dialog.create("Verify Camera and Object Parameters");
	Dialog.addMessage("TIFF file pixel byte are usually little endian\nPNG file pixel bytes are usually big endian");
	Dialog.addChoice("Swap Byte Order?", byteorder, defaultbyteorder); 
	Dialog.addMessage("Camera Calibration Constants:");
	Dialog.addNumber("Planck R1:", PR1, 2, 12, "unitless");
	Dialog.addNumber("Planck R2:", PR2, 8, 12, "unitless");
	Dialog.addNumber("Planck B:", PB, 0, 5, "unitless");
	Dialog.addNumber("Planck F:", PF, 0, 2, "unitless");
    Dialog.addNumber("Planck O:", PO, 0, 5, "unitless"); 
    Dialog.addMessage("Object Parameters:");
    Dialog.addNumber("Object Emissivity:", E, 3, 6, "unitless");
    Dialog.addNumber("Object Distance:", OD, 1, 6, "m");
    Dialog.addNumber("Reflected Temperature (C):", RTemp, 2, 6, "C");
    Dialog.addNumber("Atmospheric Temperature (C):", ATemp, 2, 6, "C");
    Dialog.addNumber("Window Temperature (C):", IRWTemp, 2, 6, "C");
    Dialog.addNumber("Window Transmittance:", IRT, 3, 6, "unitless");
    Dialog.addNumber("Relative Humidity:", RH, 2, 6, "%");
    Dialog.addChoice("Palette", palettetypes, defaultpalette);
	Dialog.show();

	var ByteOrder=Dialog.getChoice();
	var PR1 = Dialog.getNumber();
	var PR2 = Dialog.getNumber();
	var PB = Dialog.getNumber();
	var PF = Dialog.getNumber();
	var PO = Dialog.getNumber();
	var E = Dialog.getNumber();
	var OD = Dialog.getNumber();
	var RTemp = Dialog.getNumber();
	var ATemp = Dialog.getNumber();
	var IRWTemp = Dialog.getNumber();
	var IRT = Dialog.getNumber();
	var RH = Dialog.getNumber();
	var palettetype = Dialog.getChoice();
	
	if(ByteOrder == "Swap"){
		run("Byte Swapper");
	}

	Raw2Temp(PR1, PR2, PB, PF, PO, E, OD, RTemp, ATemp, IRWTemp, IRT, RH, palettetype, "No");
	
}

macro "Raw2Temp T1030" {

	// Initial Planck Constants from Purchase Date in 2017 to Re-calibration in Nov 2018:		
	var PR1=21546.203;
	var PR2=0.016229488;
	var PB=1507.2; 
	var PF=1;
	var PO=-6331;

	// Planck Constants after Recalibration and Service with New Lens in November 2018:
	var PR1=17998.529;
	var PR2=0.015145967;
	var PB=1453.1; 
	var PF=1;
	var PO=-5854;
	
	var E = 0.95;
	var OD = 1.5;
	var RTemp = 30.0;
	var ATemp = 30.0;
	var IRWTemp = 30.0;
	var IRT = 1.0;
	var RH = 80.0;

	byteorder=newArray("Default", "Swap");
	defaultbyteorder="Default";
	
	// Create a prompt dialog to ask user to verify the values to be used in the calculations below
	Dialog.create("Verify Camera and Object Parameters");
	Dialog.addMessage("TIFF file pixel byte are usually little endian\nPNG file pixel bytes are usually big endian");
	Dialog.addChoice("Swap Byte Order?", byteorder, defaultbyteorder); 
	Dialog.addMessage("Camera Calibration Constants:");
	Dialog.addNumber("Planck R1:", PR1, 2, 12, "unitless"); //21106.77 //21546.203
	Dialog.addNumber("Planck R2:", PR2, 8, 12, "unitless"); //0.012545258 //0.016229488 
	Dialog.addNumber("Planck B:", PB, 0, 5, "unitless"); //1501 //1507.2
	Dialog.addNumber("Planck F:", PF, 0, 2, "unitless");//1
    Dialog.addNumber("Planck O:", PO, 0, 5, "unitless"); //-7340 //-6331
    Dialog.addMessage("Object Parameters:");
    Dialog.addNumber("Object Emissivity:", E, 3, 6, "unitless");
    Dialog.addNumber("Object Distance:", OD, 1, 6, "m");
    Dialog.addNumber("Reflected Temperature (C):", RTemp, 2, 6, "C");
    Dialog.addNumber("Atmospheric Temperature (C):", ATemp, 2, 6, "C");
    Dialog.addNumber("Window Temperature (C):", IRWTemp, 2, 6, "C");
    Dialog.addNumber("Window Transmittance:", IRT, 3, 6, "unitless");
    Dialog.addNumber("Relative Humidity:", RH, 2, 6, "%");
    Dialog.addChoice("Palette", palettetypes, defaultpalette);
	Dialog.show();

	var ByteOrder=Dialog.getChoice();
	var PR1 = Dialog.getNumber();
	var PR2 = Dialog.getNumber();
	var PB = Dialog.getNumber();
	var PF = Dialog.getNumber();
	var PO = Dialog.getNumber();
	var E = Dialog.getNumber();
	var OD = Dialog.getNumber();
	var RTemp = Dialog.getNumber();
	var ATemp = Dialog.getNumber();
	var IRWTemp = Dialog.getNumber();
	var IRT = Dialog.getNumber();
	var RH = Dialog.getNumber();
	var palettetype = Dialog.getChoice();
	
	if(ByteOrder == "Swap"){
		run("Byte Swapper");
	}

	Raw2Temp(PR1, PR2, PB, PF, PO, E, OD, RTemp, ATemp, IRWTemp, IRT, RH, palettetype, "No");
	
}

macro "Raw2Temp FlirVueProR" {
	
	// Written for a FlirVueProR 		
	var PR1=17096.453;
	var PR2=0.04351538;
	var PB=1428; 
	var PF=1;
	var PO=-55;
	var E = 0.95;
	var OD = 1.5;
	var RTemp = 20.0;
	var ATemp = 20.0;
	var IRWTemp = 20.0;
	var IRT = 1.0;
	var RH = 50.0;
	
	byteorder=newArray("Default", "Swap");
	defaultbyteorder="Default";
	
	// Create a prompt dialog to ask user to verify the values to be used in the calculations below
	Dialog.create("Verify Camera and Object Parameters");
	Dialog.addMessage("TIFF file pixel byte are usually little endian\nPNG file pixel bytes are usually big endian");
	Dialog.addChoice("Swap Byte Order?", byteorder, defaultbyteorder); 
	Dialog.addMessage("Camera Calibration Constants:");
	Dialog.addNumber("Planck R1:", PR1, 2, 12, "unitless"); //21106.77 //21546.203
	Dialog.addNumber("Planck R2:", PR2, 8, 12, "unitless"); //0.012545258 //0.016229488 
	Dialog.addNumber("Planck B:", PB, 0, 5, "unitless"); //1501 //1507.2
	Dialog.addNumber("Planck F:", PF, 0, 2, "unitless");//1
    Dialog.addNumber("Planck O:", PO, 0, 5, "unitless"); //-7340 //-6331
    Dialog.addMessage("Object Parameters:");
    Dialog.addNumber("Object Emissivity:", E, 3, 6, "unitless");
    Dialog.addNumber("Object Distance:", OD, 1, 6, "m");
    Dialog.addNumber("Reflected Temperature (C):", RTemp, 2, 6, "C");
    Dialog.addNumber("Atmospheric Temperature (C):", ATemp, 2, 6, "C");
    Dialog.addNumber("Window Temperature (C):", IRWTemp, 2, 6, "C");
    Dialog.addNumber("Window Transmittance:", IRT, 3, 6, "unitless");
    Dialog.addNumber("Relative Humidity:", RH, 2, 6, "%");
    Dialog.addChoice("Palette", palettetypes, defaultpalette);
	Dialog.show();

	var ByteOrder=Dialog.getChoice();
	var PR1 = Dialog.getNumber();
	var PR2 = Dialog.getNumber();
	var PB = Dialog.getNumber();
	var PF = Dialog.getNumber();
	var PO = Dialog.getNumber();
	var E = Dialog.getNumber();
	var OD = Dialog.getNumber();
	var RTemp = Dialog.getNumber();
	var ATemp = Dialog.getNumber();
	var IRWTemp = Dialog.getNumber();
	var IRT = Dialog.getNumber();
	var RH = Dialog.getNumber();
	var palettetype = Dialog.getChoice();
	
	if(ByteOrder == "Swap"){
		run("Byte Swapper");
	}

	Raw2Temp(PR1, PR2, PB, PF, PO, E, OD, RTemp, ATemp, IRWTemp, IRT, RH, palettetype, "No");
		
}


macro "Raw2Temp E40" {
			
	var PR1=15759.339;
	var PR2=0.011213507;
	var PB=1413.2; 
	var PF=1;
	var PO=-6030;
	var E = 0.95;
	var OD = 1;
	var RTemp = 20.0;
	var ATemp = 20.0;
	var IRWTemp = 20.0;
	var IRT = 1.0;
	var RH = 50.0;
	
	byteorder=newArray("Default", "Swap");
	defaultbyteorder="Default";
	
	// Create a prompt dialog to ask user to verify the values to be used in the calculations below
	Dialog.create("Verify Camera and Object Parameters");
	Dialog.addMessage("TIFF file pixel byte are usually little endian\nPNG file pixel bytes are usually big endian");
	Dialog.addChoice("Swap Byte Order?", byteorder, defaultbyteorder); 
	Dialog.addMessage("Camera Calibration Constants:");
	Dialog.addNumber("Planck R1:", PR1, 2, 12, "unitless"); //21106.77 //21546.203
	Dialog.addNumber("Planck R2:", PR2, 8, 12, "unitless"); //0.012545258 //0.016229488 
	Dialog.addNumber("Planck B:", PB, 0, 5, "unitless"); //1501 //1507.2
	Dialog.addNumber("Planck F:", PF, 0, 2, "unitless");//1
    Dialog.addNumber("Planck O:", PO, 0, 5, "unitless"); //-7340 //-6331
    Dialog.addMessage("Object Parameters:");
    Dialog.addNumber("Object Emissivity:", E, 3, 6, "unitless");
    Dialog.addNumber("Object Distance:", OD, 1, 6, "m");
    Dialog.addNumber("Reflected Temperature (C):", RTemp, 2, 6, "C");
    Dialog.addNumber("Atmospheric Temperature (C):", ATemp, 2, 6, "C");
    Dialog.addNumber("Window Temperature (C):", IRWTemp, 2, 6, "C");
    Dialog.addNumber("Window Transmittance:", IRT, 3, 6, "unitless");
    Dialog.addNumber("Relative Humidity:", RH, 2, 6, "%");
    Dialog.addChoice("Palette", palettetypes, defaultpalette);
	Dialog.show();

	var ByteOrder=Dialog.getChoice();
	var PR1 = Dialog.getNumber();
	var PR2 = Dialog.getNumber();
	var PB = Dialog.getNumber();
	var PF = Dialog.getNumber();
	var PO = Dialog.getNumber();
	var E = Dialog.getNumber();
	var OD = Dialog.getNumber();
	var RTemp = Dialog.getNumber();
	var ATemp = Dialog.getNumber();
	var IRWTemp = Dialog.getNumber();
	var IRT = Dialog.getNumber();
	var RH = Dialog.getNumber();
	var palettetype = Dialog.getChoice();
	
	if(ByteOrder == "Swap"){
		run("Byte Swapper");
	}

	Raw2Temp(PR1, PR2, PB, PF, PO, E, OD, RTemp, ATemp, IRWTemp, IRT, RH, palettetype, "No");
	
	//a = newArray(65536); 
	//templookup=newArray(65536);
	//for (i=1; i<65536; i++) {
	//	a[i]=i; 	
	//	templookup[i] = 1500/log(21000/(0.012*(a[i]/0.9-100-7300))+1)-273.15;
		//templookup = PB/log(PR1/(PR2*(a[i]/rawdivisor-rawsubtract+PO))+PF)-273.15;
	//}
	
}



macro "-" {} //menu divider

macro "ROI 1 Results [1]" { // 
	
	getStatistics(area, mean, min, max, std, histogram);
	
	type = selectionType(); 
	if(type==-1) exit("No ROI selection specified");
	
	updateResults();

	rownum=getSliceNumber()-1;
	
	// this will allow you to skip aheaad to a new slice, do the analysis, then scroll back
	for (i=0; i<getSliceNumber(); i++) { 	
		setResult("Blank", i, "");
	}
	
	setResult("Slice Label", rownum, getMetadata("label"));
	setResult("Slice", rownum, getSliceNumber());
	setResult("ROI 1 Mean", rownum, mean);
	setResult("ROI 1 Min", rownum, min);
	setResult("ROI 1 Max", rownum, max);
	setResult("ROI 1 SD", rownum, std);
	setResult("ROI 1 Area", rownum, area);
	
	updateResults();
	saveAs("Results", desktopdir + File.separator + "ROI_Results.csv");
}

macro "ROI 2 Results [2]" {
	
	getStatistics(area, mean, min, max, std, histogram);
	
	type = selectionType(); 
	if(type==-1) exit("No ROI selection specified");

	updateResults();
	rownum=getSliceNumber()-1;
	
	// this will allow you to skip aheaad to a new slice, do the analysis, then scroll back
	for (i=0; i<getSliceNumber(); i++) { 	
		setResult("Blank", i, "");
	}

	setResult("Slice Label", rownum, getMetadata("label"));
	setResult("Slice", rownum, getSliceNumber());
	setResult("ROI 2 Mean", rownum, mean);
	setResult("ROI 2 Min", rownum, min);
	setResult("ROI 2 Max", rownum, max);
	setResult("ROI 2 SD", rownum, std);
	setResult("ROI 2 Area", rownum, area);
	
	updateResults();
	saveAs("Results", desktopdir + File.separator + "ROI_Results.csv");
}


macro "ROI 3 Results [3]" { // 
	
	getStatistics(area, mean, min, max, std, histogram);
	
	type = selectionType(); 
	if(type==-1) exit("No ROI selection specified");
	
	updateResults();

	rownum=getSliceNumber()-1;
	
	// this will allow you to skip aheaad to a new slice, do the analysis, then scroll back
	for (i=0; i<getSliceNumber(); i++) { 	
		setResult("Blank", i, "");
	}

	setResult("Slice Label", rownum, getMetadata("label"));
	setResult("Slice", rownum, getSliceNumber());
	setResult("ROI 3 Mean", rownum, mean);
	setResult("ROI 3 Min", rownum, min);
	setResult("ROI 3 Max", rownum, max);
	setResult("ROI 3 SD", rownum, std);
	setResult("ROI 3 Area", rownum, area);
	
	updateResults();
	saveAs("Results", desktopdir + File.separator + "ROI_Results.csv");
}


macro "ROI 4 Results [4]" { // 
	
	getStatistics(area, mean, min, max, std, histogram);
	
	type = selectionType(); 
	if(type==-1) exit("No ROI selection specified");
	
	updateResults();

	rownum=getSliceNumber()-1;
	
	// this will allow you to skip aheaad to a new slice, do the analysis, then scroll back
	for (i=0; i<getSliceNumber(); i++) { 	
		setResult("Blank", i, "");
	}

	setResult("Slice Label", rownum, getMetadata("label"));
	setResult("Slice", rownum, getSliceNumber());
	setResult("ROI 4 Mean", rownum, mean);
	setResult("ROI 4 Min", rownum, min);
	setResult("ROI 4 Max", rownum, max);
	setResult("ROI 4 SD", rownum, std);
	setResult("ROI 4 Area", rownum, area);
	
	updateResults();
	saveAs("Results", desktopdir + File.separator + "ROI_Results.csv");
}


macro "Add ROI Measurement" {
	w=getWidth();
	h=getHeight();
	leftx=0;
	rightx=w;
	topy=0;
	bottomy=h;
		
	items=newArray("Mean", "StdDev", "Min", "Max", "Mode", "Median", "Skewness", "Kurtosis");
	Dialog.create("Choose Measurement Type");
	Dialog.addChoice("Measure Type", items);
	Dialog.addString("Measurement Units", "°C");
	Dialog.addNumber("Decimal Places", 3);
	Dialog.addNumber("Text Colour 0-255: Black-White", 255);
	Dialog.addCheckbox("Add ROI to Image?", 1);
	Dialog.addMessage("Where to place label (X,Y)?");
	Dialog.addMessage("Top Left = " + leftx + ", " + topy);
	Dialog.addMessage("Top Right = " + rightx + ", " + topy);
	Dialog.addMessage("Bottom Left = " + leftx + ", " + bottomy);
	Dialog.addMessage("Bottom Right = " + rightx + ", " + bottomy);
	Dialog.addMessage("\n");
	Dialog.addNumber("X Position", floor(w/20));
	Dialog.addNumber("Y Position", floor(h/20));
	Dialog.show();
	
	var type=Dialog.getChoice();
	var units=Dialog.getString();
	var decimals=Dialog.getNumber();
	var colour=Dialog.getNumber();
	var addROI=Dialog.getCheckbox();
	var drawx=Dialog.getNumber();
	var drawy=Dialog.getNumber();
	
	addMeasurementLabel(type, units, decimals, colour, addROI, drawx, drawy);
}


macro "-" {} //menu divider



///////////////////////////////////////////////////////////////////////////////////////////////////////
////                                                                                               ////
////    This ImageJ toolset allows to access ImageJ macros for working with thermal images.        ////
////        Main Features: import, conversion, and transformation of thermal images.               ////
////                    Requires: exiftool, ffmpeg, perl                                           ////
////                            Glenn J. Tattersall                                                ////
////                         April, 2019 - Version 1.0                                             ////
////                                                                                               ////
///////////////////////////////////////////////////////////////////////////////////////////////////////

var luts = getLutMenu();
var lCmds = newMenu("LUT Menu Tool", luts);
var lut = -1;
var lutdir = getDirectory("luts");
var list;
var color = 0;
var colors = newArray("Red", "Green", "Blue", "Cyan", "Magenta", "Yellow");

var perlscriptpath="/Applications/Fiji.app/scripts/";
var perlsplit=perlscriptpath + "split.pl";	

var OS=getInfo("os.name");
// OSX Users verify these settings:
var perlpathOSX="/usr/local/bin/";
var exiftoolpathOSX="/usr/local/bin/";
var exiftoolOSX="exiftool";
var ffmpegpathOSX="/usr/local/bin/";

// Linux Users verify these settings:
var perlpathLinux="/usr/local/bin/";
var exiftoolpathLinux="/usr/local/bin/";
var exiftoolLinux="exiftool";
var ffmpegpathLinux="/usr/local/bin/";

// Windows Users verify these settings:
var perlpath="c:/windows/";
var exiftoolpath="c:/windows/";
var exiftool="exiftool.exe";
var ffmpegpath="C:/FFmpeg/bin/";


macro "LUT Menu Tool - C037T0b11LT6b09UTcb09T" {
	cmd = getArgument();
	if (cmd!="-") run(cmd);
}

macro "Grayscale LUT Action Tool - C111F123dC444F423dC888F723dCbbbFa23dCeeeFd23d" {
        run("Grays");
        if (getWidth==256 && getHeight==32)
            rename("Grayscale");
}

macro "Grayscale LUT" {
        run("Grays");
        if (getWidth==256 && getHeight==32)
            rename("Grayscale");
}

macro "Adjust Brightness and Contrast Action Tool - C037D04D05D06D07D08D09D0aD0bD0cD14D18D1cD24D28D2cD34D38D3cD45D46D47D49D4aD4bD6bD6cD76D77D78D79D7aD84D85Da6Da7Da8Da9DaaDb5DbbDc4DccDd4DdcDe5DebDf6Dfa" {
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


macro "-" {} //menu divider

  // Based on the LUTFileTool by Gabriel Landini
  function cycleLUTs(inc) {
       if (lut==-1)
           createLutList();
       if (nImages==0) {
          call("ij.gui.ImageWindow.centerNextImage");
          newImage("LUT", "8-bit ramp", 256, 32, 1);
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
      if (getWidth==256 && getHeight==32)
            rename(name);
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


macro "Raw Import Mikron RTV Action Tool - C000D18D19D1aD1bD1cD1dD1eD28D2bD38D3bD3cD3dD43D48D49D4aD4bD4dD4eD54D65D68D70D71D72D73D74D75D76D78D79D7aD7bD7cD7dD7eD80D81D82D83D84D85D86D88D95Da4Da8Da9DaaDb3DbaDbbDbcDccDcdDceDdaDdbDdcDe8De9DeaC000C111C222C333C444C555C666C777C888C999CaaaCbbbCcccCdddCeeeCfff" {
	RawImportMikronRTV();
}

macro "Raw Import Mikron RTV" {
	RawImportMikronRTV();
}

function RawImportMikronRTV() {
	
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
	var converttotemperature = 1;
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
	//Dialog.addCheckbox("Use Virtual Stack", usevirtual);
    Dialog.show();
    
	//Define Variable for Import
	offsetbyte = Dialog.getNumber(); 
	gapbytes = Dialog.getNumber();
	nframes = Dialog.getNumber();
	imagewidth = Dialog.getNumber(); 
	imageheight = Dialog.getNumber();
	converttotemperature = Dialog.getCheckbox();
	//usevirtual = Dialog.getCheckbox();
	
	filepath=File.openDialog("Select a File"); 
	file=File.openAsString(filepath); 
	//print("Loading: ", filepath);
	//print("\n");

	run("Raw...", "open=filepath image=[16-bit Unsigned] width=imagewidth height=imageheight offset=offsetbyte number=nframes gap=gapbytes little-endian use=usevirtual");

	// Mikron RTV files are simply stored as Temperature in Kelvin * 10 and thus range from 10 to ~3000 (but still stored or imported as 16 bit integer)
	// conversion here will not be accurate, nor will it take into account atmospheric and reflected conditions.
	
	if(converttotemperature) {
		run("32-bit");
		run("Macro...", "code=v=v/10-273.15 stack");
		}
	
	run("HighContrastRainbow1234 256");
	
	Stack.getStatistics(count, mean, min, max, std);
		var minpix=min;
		var maxpix=max;
		setMinAndMax(minpix, maxpix);
	
	//run("Calibration Bar...", "location=[Upper Right] fill=White label=Black number=5 decimal=1 font=10 zoom=0.5 bold overlay");
}


macro "Raw Import FLIR SEQ Action Tool - C000D19D1aD1eD28D2bD2eD38D3bD3eD43D48D4cD4dD54D65D68D69D6aD6bD6cD6dD6eD70D71D72D73D74D75D76D78D7bD7eD80D81D82D83D84D85D86D88D8bD8eD95D98D9eDa4Db3Db9DbaDbbDbcDbdDc8DceDd8DddDdeDe9DeaDebDecDedDeeDefDffC000C111C222C333C444C555C666C777C888C999CaaaCbbbCcccCdddCeeeCfff" {
	RawImportFLIRSEQ();
}

macro "Raw Import FLIR SEQ" {
	RawImportFLIRSEQ();
}

function RawImportFLIRSEQ() {
	
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
	var usevirtual = 1;
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
	offsetbyte = Dialog.getNumber(); 
	gapbytes = Dialog.getNumber();
	nframes = Dialog.getNumber();
	imagewidth = Dialog.getNumber(); 
	imageheight = Dialog.getNumber();
	converttotemperature = Dialog.getCheckbox();
	usevirtual = Dialog.getCheckbox();
	
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
	
	if(substring(OS, 0, 7)=="Windows"){
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

	//run("HighContrastRainbow1234 256");
	
	Stack.getStatistics(count, mean, min, max, std);
		var minpix=min;
		var maxpix=max;
		setMinAndMax(minpix, maxpix);
		
	if(converttotemperature) {
		run("Raw2TempSC660");
	}

	//run("Calibration Bar...", "location=[Upper Right] fill=White label=Black number=5 decimal=1 font=12 zoom=1 bold overlay");

}


macro "-" {} //menu divider

macro "Byte Swap Action Tool - C000D12D13D1cD1dD21D24D25D26D27D28D29D2aD2bD2eD31D34D35D36D37D38D39D3aD3bD3eD42D43D4cD4dD82D83D91D92D93D94Da0Da1Da2Da3Da4Da5Db2Db3Dc2Dc3DccDcdDd2Dd3Dd4Dd5Dd6Dd7Dd8Dd9DdaDdbDdeDe2De3De4De5De6De7De8De9DeaDebDeeDfcDfdC000C111C222C333C444C555C666C777C888C999CaaaD1bD4bCaaaD11D14DcbDceDfbDfeCaaaD1eD4eCaaaD41D44CbbbCcccD2dD3dCcccD22DddDedCcccD32CcccD72D73CcccDc4CcccCdddD23D2cD3cDdcDecCdddDb1CdddD33CeeeDb0CeeeD8cD8dDb4DbcDbdCeeeCfffD20D30Df5CfffDc7CfffD17D18D47D48Dc6Dc8Df6Df7Df8CfffD16D19D46D49Dc9Df9CfffDf4CfffDb5CfffDc1"{
	run("Byte Swapper");
}

macro "Byte Swap Tool"{
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


function ConvertImportFLIRJPG() {

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
	
	if(substring(OS, 0, 7)=="Windows"){
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

	flirimageraw = exec(exiftoolpath + exiftool, "-RawThermalImageType", filepath);
	RawThermalType = substring(flirimageraw, indexOf(flirimageraw, ":")+1 );
	
	// determine the data storage format of the flir jpg.  Either tiff or png	
	RawThermalType=replace(RawThermalType, "\n", "");
	RawThermalType=replace(RawThermalType, " ", "");
	
	fileout=File.nameWithoutExtension + "." + toLowerCase(RawThermalType);
	fileout=replace(fileout, " ", "");
	fileout=replace(fileout, ".tiff", ".tif");
	fileout=replace(fileout, ".TIFF", ".tif");
	fileout=replace(fileout, ".PNG", ".png");

	// Define the syntax for the exec command to convert the jpg file into a png for import
	//convertjpg =  exiftoollocation + exiftool + " " + filepath + " -b -RawThermalImage | convert - gray:- | convert -depth 16 -endian lsb -size 640x480 gray:- " + filedir + "/temp/" + "filename.png";
	// I cannot get double or single pipes to convert to work when called from imageJ, so I revert to this method:
	
	convertjpg =  exiftoolpath + exiftool + " '" + filepath + "' -b -RawThermalImage > '" + filedir + "/temp/" + fileout + "'";

	// print(convertjpg);

	// Execute the convert command
	// Difficulty getting the Piping to work with the default exec command.  See: http://imagej.1557.x6.nabble.com/macro-Redirection-in-exec-UNIX-binary-td3687463.html
	// Execute the combine command this way (not sure it will work in Windows):

	exec("/bin/sh", "-c", convertjpg);

	fileoutpath=filedir + File.separator + "temp" + File.separator + fileout;
	
	print("Temporary file saved to:", fileoutpath);
	
	fileoutpathexist=File.exists(fileoutpath);

	if(fileoutpathexist==1){
	    open(fileoutpath); 
	    print("FLIR JPG loaded");
	    title=getTitle();
	    selectWindow(title);
	}
	
	palettetypes=newArray("Greyscale", "FLIR", "Rainbow");
	byteorder=newArray("Default", "Swap");
	
	if(RawThermalType=="TIFF"){
		defaultbyteorder="Default";		
	}
	
	if(RawThermalType=="PNG"){
		defaultbyteorder="Swap";
	}
	
	// Create a prompt dialog to ask user to verify the values to be used in the calculations below
	Dialog.create("Camera and Object Parameters");
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
    Dialog.addChoice("Palette", palettetypes, "Rainbow");
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
	var palettetypechoice = Dialog.getChoice();

	if(palettetypechoice=="Greyscale"){
		var palettetype="Grays";
	}
	
	if(palettetypechoice=="FLIR"){
		var palettetype="Ironbow";
	}
	
	if(palettetypechoice=="Rainbow"){
		var palettetype="HighContrastRainbow1234 256";
	}
	
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
	
		Raw2Temp(PR1, PR2, PB, PF, PO, E, OD, RTemp, ATemp, IRWTemp, IRT, RH, palettetype);	

}



function ConvertFLIRJPGs() {

	var OS=getInfo("os.name");
	
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
	
	if(substring(OS, 0, 7)=="Windows"){
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
	
	convertfolder=dirpath + File.separator + "converted";
	File.makeDirectory(convertfolder);

	for (i = 0; i < filelist.length; i++){
		
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
		
		fileout=filename + "." + toLowerCase(RawThermalType);
		fileout=replace(fileout, " ", "");
		fileout=replace(fileout, ".tiff", ".tif");
		fileout=replace(fileout, ".TIFF", ".tif");
		fileout=replace(fileout, ".PNG", ".png");

		print("Converting " + filename + ".jpg" + " to " + fileout);
		// Define the syntax for the exec command to convert the jpg file into a png or tiff file for import
		convertjpg =  exiftoolpath + exiftool + " '" + filepath + "' -b -RawThermalImage > '" + convertfolder + File.separator + fileout + "'";

		// Execute the convert command
		exec("/bin/sh", "-c", convertjpg);

		// print(fileout + " saved to: ", convertfolder);
		}
	}
	
	print("FLIR JPG files converted into " + RawThermalType + " format.  Import these and convert to temperature using the Raw2Temp macro.");
	print("All files saved to: " + convertfolder);
	print("Note: Some images may require that the pixel byte order be swapped.  Use the Byte Swapper plugin after importing if necessaary");
	
}




macro "Import FLIR SEQ Action Tool - C000D04D0bD0cD0dD0eD13D14D1bD1cD1dD22D23D25D26D27D29D2bD2dD32D35D37D39D3dD41D42D45D47D48D49D4dD4eD51D5eD60D61D65D66D67D68D69D6eD6fD70D75D77D79D7fD80D85D87D89D8fD90D91D9eD9fDa1Da5Da6Da7Da8Da9DaeDb1Db2Db5Db9DbdDbeDc2Dc5Dc6Dc7Dc8Dc9DcaDcdDd2Dd4Dd9DdaDdcDddDe2De3De4DebDecDf1Df2Df3Df4DfbC000C111C222C333C444C555C666C777C888C999CaaaCbbbCcccCdddCeeeCfff" {
	ConvertFLIRVideo("seq", "avi", "png");
}

macro "Import FLIR SEQ" {
	ConvertFLIRVideo("seq", "avi", "png");
}

macro "Import FLIR CSQ Action Tool - C000D04D0bD0cD0dD0eD13D14D1bD1cD1dD22D23D25D26D27D28D29D2bD2dD32D35D39D3dD41D42D45D49D4dD4eD51D5eD60D61D65D66D67D69D6eD6fD70D75D77D79D7fD80D85D87D88D89D8fD90D91D9eD9fDa1Da5Da6Da7Da8Da9DaeDb1Db2Db5Db9DbdDbeDc2Dc5Dc6Dc7Dc8Dc9DcaDcdDd2Dd4Dd9DdaDdcDddDe2De3De4DebDecDf1Df2Df3Df4DfbC000C111C222C333C444C555C666C777C888C999CaaaCbbbCcccCdddCeeeCfff" {
	ConvertFLIRVideo("csq", "avi", "copy");
}

macro "Import FLIR CSQ" {
	ConvertFLIRVideo("csq", "avi", "copy");
}

function ConvertFLIRVideo(vidtype, outtype, outcodec) {
	// vidtype should be seq or csq
	// outtype should be avi or png
	// outcodec is the type of file compression needed for avi files - usually png.
	// Using command line tools: perl, a perl split.pl script, exiftool and ffmpeg, this macro will convert a SEQ file into an 16-bit avi file in png format
	// to subsquently be imported using import-ffmpeg
	
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
	
	if(substring(OS, 0, 7)=="Windows"){
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

	fileout=File.nameWithoutExtension + "." + outtype;
    
    // this is the syntax that works.
    //exec("perl split.pl -i Rec-1.seq -o temp -b frame -p fff -x fff");

	// Define the syntax for the exec command to split the sequence file into .fff files
	splitfffexeccmd = perlpath + "perl " + perlsplit + " -i " + filepath + " -o " + tempfolder + " -b frame -p fff -x fff";
	print("Split the video file into its .fff files with: ");
	print(splitfffexeccmd);

	// Execute the split.pl script on the SEQ file to create fff files
	exec(perl, perlsplit, "-i", filepath, "-o", tempfolder, "-b", "frame", "-p", "fff", "-x", "fff");

	// Extract Date/Time Original from the .fff files
	timefind =  exiftoolpath + exiftool + " -*Original* " + tempfolder + File.separator + "*.fff -r -q";
	
	flirvals=exec("/bin/sh", "-c", timefind);
	
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
	
	secoriginal=newArray(11);
	for(i=0; i<11; i++){
		secoriginal[i]=parseFloat(substring(timeoriginal[i+1], 6, 12));
	}
	
	framediff=newArray(10);
	for(i=0; i<10; i++){
		framediff[i]=secoriginal[i+1] - secoriginal[i];
	}
	
	Array.getStatistics(framediff, mean);
	meanframediff=mean;

	print("Video frame time difference is: " + meanframediff + " seconds");
	
	// Combine fff files into thermalvid.raw using exiftool raw binary extraction function
	// Difficulty getting the piping (> or |) to work with the default exec command. 
	// See: http://imagej.1557.x6.nabble.com/macro-Redirection-in-exec-UNIX-binary-td3687463.html
	// Execute the combine command using the "/bin/sh" way (still need to confirm if this will work in Windows)
	rawcombinecmd = exiftoolpath + exiftool +  " -b -RawThermalImage " + tempfolder + "/*.fff > " + filedir + File.separator + "thermalvid.raw";
	print("Combine the fff files into a thermalvid.raw file with: ");
	print(rawcombinecmd);
	exec("/bin/sh", "-c", rawcombinecmd);
	//exec(exiftoolpath + exiftool, "-b", "-RawThermalImage", filedir + File.separator + "temp" + File.separator + "*.fff", ">", filedir + File.separator + "thermalvid.raw");


	// Execute the split.pl script on thermalvid.raw to create tiff (or jpegls) files
	splittiffexeccmd = perlpath + "perl " + perlsplit + " -i " + filedir + "/thermalvid.raw" + " -o " + filedir + "/temp -b frame -p " + RawThermalType + " -x " + RawThermalType;
	print("Split the thermalvid.raw file into " + RawThermalType + " files with: ");
	print(splittiffexeccmd);
	
	if(vidtype=="seq"){
		exec(perl, perlsplit, "-i", filedir + File.separator + "thermalvid.raw", "-o", filedir + File.separator + "temp", "-b", "frame", "-p", "tiff", "-x", "tiff");
	}
	
	if(vidtype=="csq"){
		exec(perl, perlsplit, "-i", filedir + File.separator + "thermalvid.raw", "-o", tempfolder + "-b", "frame", "-p", "jpegls", "-x", "jpegls");
	}

	// Execute the ffmpeg command to assimilate all the tiff files into one avi file
	tiffcombinecmd = "/usr/local/bin/ffmpeg" + " -f" + " image2" + " -vcodec" + " " + RawThermalType + " -r" + " 30" + " -i " + tempfolder + File.separator + "frame%05d." + RawThermalType + " -pix_fmt" + " gray16be" + " -vcodec " + outcodec + " " + filedir + File.separator + fileout + " -y";   
    print(tiffcombinecmd);    
    exec(ffmpeg, "-f", "image2", "-vcodec", RawThermalType, "-r", "30", "-i", tempfolder + File.separator + "frame%05d." + RawThermalType, "-vcodec", outcodec, filedir + File.separator + fileout, "-y");

	templist = getFileList(tempfolder);
	for (i = 0; i < templist.length; i++)
      tempfilesdelete_success=File.delete(tempfolder + File.separator + templist[i]);	
	
	thermalviddelete_success=File.delete(filedir + File.separator + "thermalvid.raw");
	tempfolderdelete_success=File.delete(filedir + File.separator + "temp" + File.separator );
		
	if(tempfilesdelete_success + tempfolderdelete_success + thermalviddelete_success==3){
		print("Temporary files and folder deleted.");
	}

	ffmpegimportarguments = "choose=" + filedir + File.separator + fileout + " first_frame=0 last_frame=-1";
	
	run("Movie (FFMPEG)...", ffmpegimportarguments);

	for (i=1; i<=nSlices; i++) { 
		setSlice(i);
		run("Set Label...", "label=" + timeoriginal[i]);
	}
}

macro "-" {} //menu divider

macro "FLIR Calibration Values Action Tool - C000D00D01D02D03D04D05D10D16D20D22D23D24D27D2dD2eD30D32D34D36D37D38D39D3aD3bD3cD3fD40D42D44D47D4fD50D52D54D56D57D58D59D5aD5bD5cD5fD60D62D63D64D67D6dD6eD70D76D80D81D82D83D84D85DbbDbcDbdDbeDc1Dc2Dc3Dc4Dc5Dc6Dc7Dc8Dc9DcaDcbDcfDd0DdfDe1De2De3De4De5De6De7De8De9DeaDebDefDf3Df5Df7Df9DfbDfcDfdDfeCfffD06D07D08D09D0aD0bD0cD0dD0eD0fD11D12D13D14D15D17D18D19D1aD1bD1cD1dD1eD1fD21D25D26D28D29D2aD2bD2cD2fD31D33D35D3dD3eD41D43D45D46D48D49D4aD4bD4cD4dD4eD51D53D55D5dD5eD61D65D66D68D69D6aD6bD6cD6fD71D72D73D74D75D77D78D79D7aD7bD7cD7dD7eD7fD86D87D88D89D8aD8bD8cD8dD8eD8fD90D91D92D93D94D95D96D97D98D99D9aD9bD9cD9dD9eD9fDa0Da1Da2Da3Da4Da5Da6Da7Da8Da9DaaDabDacDadDaeDafDb0Db1Db2Db3Db4Db5Db6Db7Db8Db9DbaDbfDc0Dd1Dd2Dd3Dd4De0Df0Df1Df2Df4Df6Df8DfaDffCc10DccDcdDceDd5Dd6Dd7Dd8Dd9DdaDdbDdcDddDdeDecDedDee" {
	filepath=File.openDialog("Select a FLIR Image or Video File"); 
	printvalues="Yes";
	flirvalues(filepath, printvalues);
}

macro "FLIR Calibration Values" {
	filepath=File.openDialog("Select a FLIR Image or Video File"); 
	printvalues="Yes";
	flirvalues(filepath, printvalues);
}

macro "FLIR Date Stamps Action Tool - C000D08D09D0aD0bD0cD17D1dD26D2eD35D3eD45D4fD55D57D58D59D5aD5fD65D6aD6fD72D73D75D7aD7eD82D86D8aD8eD90D91D92D94D97D9dDa2Da8Da9DaaDabDacDb2Db4Db6Dc2Dc8Dd0Dd1Dd2Dd4Dd6Dd8De2De8Df2Df3Df4Df5Df6Df7Df8C000C111C222C333C444C555C666C777C888C999CaaaCbbbCcccDc1CcccDd7CcccD83CcccD81CcccDe1CcccCdddD56CdddDe7CdddDa1CdddDb3CdddDc7CdddD16CdddD2dCdddD1eD48D4eDb7CdddD69CdddD49D7bCdddCeeeD46Dc4CeeeD6bDc6CeeeD6eCeeeD93Dc3CeeeDe3CeeeDe9CeeeDa3CeeeDd9CeeeDd3CeeeD99Db5CeeeD74CeeeD1bD2fD54D8fCeeeD19D85Dd5CeeeD25D96Db1De4CeeeDa4Db8CeeeDe6CfffD9bDbaCfffD5eD79CfffDe5CfffD8bCfffD68DadCfffD0dCfffD07D64CfffD1aD63D89Da7Dc5CfffD9aCfffD44D5bDb9De0CfffD84Da0DbbCfffD4aD80Da5Dc0Dc9Df1CfffD62D71Df9CfffD47" {
	filepath=File.openDialog("Select a FLIR Image or Video File"); 
	printvalues="Yes";
	flirdate(filepath, printvalues);
}

macro "FLIR Date Stamps" {
	filepath=File.openDialog("Select a FLIR Image or Video File"); 
	printvalues="Yes";
	flirdate(filepath, printvalues);
}


macro "-" {} //menu divider

macro "Raw2Temp Action Tool - C000D00D01D02D03D04D05D06D07D10D13D14D20D23D24D25D30D33D35D36D40D41D42D43D46D47D59D63D6aD6cD74D76D7bD7cD85D86D88D8aD8bD8cD94D95D96D98Da8Db8Dc8Dd8De8Df8Ce50DbaDcaCfc0DbdDcdCf80DbbDcbCff7DbfDcfCd17Db9Dc9Cfe2DbeDceCfb0DbcDcc"{

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

	palettetypes=newArray("Greyscale", "FLIR", "Rainbow");
	byteorder=newArray("Default", "Swap");
	defaultbyteorder="Default";
	
	// Create a prompt dialog to ask user to verify the values to be used in the calculations below
	Dialog.create("Camera and Object Parameters");
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
    Dialog.addChoice("Palette", palettetypes, "Rainbow");
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
	var palettetypechoice = Dialog.getChoice();

	if(palettetypechoice=="Greyscale"){
		var palettetype="Grays";
	}
	
	if(palettetypechoice=="FLIR"){
		var palettetype="Ironbow";
	}
	
	if(palettetypechoice=="Rainbow"){
		var palettetype="HighContrastRainbow1234 256";
	}
	
	if(ByteOrder == "Swap"){
		run("Byte Swapper");
	}

	Raw2Temp(PR1, PR2, PB, PF, PO, E, OD, RTemp, ATemp, IRWTemp, IRT, RH, palettetype);

}
	

macro "Raw2Temp Tool"{

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

	palettetypes=newArray("Greyscale", "FLIR", "Rainbow");
	byteorder=newArray("Default", "Swap");
	defaultbyteorder="Default";
	
	// Create a prompt dialog to ask user to verify the values to be used in the calculations below
	Dialog.create("Camera and Object Parameters");
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
    Dialog.addChoice("Palette", palettetypes, "Rainbow");
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
	var palettetypechoice = Dialog.getChoice();

	if(palettetypechoice=="Greyscale"){
		var palettetype="Grays";
	}
	
	if(palettetypechoice=="FLIR"){
		var palettetype="Ironbow";
	}
	
	if(palettetypechoice=="Rainbow"){
		var palettetype="HighContrastRainbow1234 256";
	}
	
	if(ByteOrder == "Swap"){
		run("Byte Swapper");
	}

	Raw2Temp(PR1, PR2, PB, PF, PO, E, OD, RTemp, ATemp, IRWTemp, IRT, RH, palettetype);

}

macro "Raw2Temp SC660" {
			
	var PR1=21106.77;
	var PR2=0.012545258;
	var PB=1501; 
	var PF=1;
	var PO=-7340;
	var E = 0.95;
	var OD = 1.0;
	var RTemp = 20.0;
	var ATemp = 20.0;
	var IRWTemp = 20.0;
	var IRT = 1.0;
	var RH = 50.0;

	palettetypes=newArray("Greyscale", "FLIR", "Rainbow");
	byteorder=newArray("Default", "Swap");
	defaultbyteorder="Default";
	
	// Create a prompt dialog to ask user to verify the values to be used in the calculations below
	Dialog.create("Camera and Object Parameters");
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
    Dialog.addChoice("Palette", palettetypes, "Rainbow");
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
	var palettetypechoice = Dialog.getChoice();

	if(palettetypechoice=="Greyscale"){
		var palettetype="Grays";
	}
	
	if(palettetypechoice=="FLIR"){
		var palettetype="Ironbow";
	}
	
	if(palettetypechoice=="Rainbow"){
		var palettetype="HighContrastRainbow1234 256";
	}
	
	if(ByteOrder == "Swap"){
		run("Byte Swapper");
	}

	Raw2Temp(PR1, PR2, PB, PF, PO, E, OD, RTemp, ATemp, IRWTemp, IRT, RH, palettetype);
	
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

	palettetypes=newArray("Greyscale", "FLIR", "Rainbow");
	byteorder=newArray("Default", "Swap");
	defaultbyteorder="Default";
	
	// Create a prompt dialog to ask user to verify the values to be used in the calculations below
	Dialog.create("Camera and Object Parameters");
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
    Dialog.addChoice("Palette", palettetypes, "Rainbow");
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
	var palettetypechoice = Dialog.getChoice();

	if(palettetypechoice=="Greyscale"){
		var palettetype="Grays";
	}
	
	if(palettetypechoice=="FLIR"){
		var palettetype="Ironbow";
	}
	
	if(palettetypechoice=="Rainbow"){
		var palettetype="HighContrastRainbow1234 256";
	}
	
	if(ByteOrder == "Swap"){
		run("Byte Swapper");
	}

	Raw2Temp(PR1, PR2, PB, PF, PO, E, OD, RTemp, ATemp, IRWTemp, IRT, RH, palettetype);
	
}

macro "Raw2Temp FlirVueProR" {
			
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
	
	palettetypes=newArray("Greyscale", "FLIR", "Rainbow");
	byteorder=newArray("Default", "Swap");
	defaultbyteorder="Default";
	
	// Create a prompt dialog to ask user to verify the values to be used in the calculations below
	Dialog.create("Camera and Object Parameters");
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
    Dialog.addChoice("Palette", palettetypes, "Rainbow");
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
	var palettetypechoice = Dialog.getChoice();

	if(palettetypechoice=="Greyscale"){
		var palettetype="Grays";
	}
	
	if(palettetypechoice=="FLIR"){
		var palettetype="Ironbow";
	}
	
	if(palettetypechoice=="Rainbow"){
		var palettetype="HighContrastRainbow1234 256";
	}
	
	if(ByteOrder == "Swap"){
		run("Byte Swapper");
	}

	Raw2Temp(PR1, PR2, PB, PF, PO, E, OD, RTemp, ATemp, IRWTemp, IRT, RH, palettetype);
		
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
	
	
	palettetypes=newArray("Greyscale", "FLIR", "Rainbow");
	byteorder=newArray("Default", "Swap");
	defaultbyteorder="Default";
	
	// Create a prompt dialog to ask user to verify the values to be used in the calculations below
	Dialog.create("Camera and Object Parameters");
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
    Dialog.addChoice("Palette", palettetypes, "Rainbow");
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
	var palettetypechoice = Dialog.getChoice();

	if(palettetypechoice=="Greyscale"){
		var palettetype="Grays";
	}
	
	if(palettetypechoice=="FLIR"){
		var palettetype="Ironbow";
	}
	
	if(palettetypechoice=="Rainbow"){
		var palettetype="HighContrastRainbow1234 256";
	}
	
	if(ByteOrder == "Swap"){
		run("Byte Swapper");
	}

	Raw2Temp(PR1, PR2, PB, PF, PO, E, OD, RTemp, ATemp, IRWTemp, IRT, RH, palettetype);
	
	//a = newArray(65536); 
	//templookup=newArray(65536);
	//for (i=1; i<65536; i++) {
	//	a[i]=i; 	
	//	templookup[i] = 1500/log(21000/(0.012*(a[i]/0.9-100-7300))+1)-273.15;
		//templookup = PB/log(PR1/(PR2*(a[i]/rawdivisor-rawsubtract+PO))+PF)-273.15;
	//}
	
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



function Raw2Temp(PR1, PR2, PB, PF, PO, E, OD, RTemp, ATemp, IRWTemp, IRT, RH, palettetype) {

	if(is("Virtual Stack")==true){
		run("Duplicate...", "duplicate");
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
		Stack.getStatistics(count, mean, min, max, std);
		minpix=min;
		maxpix=max;
		run("Macro...", "code=v=" +PB+ "/log(" +PR1+ "/(" +PR2+ "*(v/" +rawdivisor+ "-" +rawsubtract+ "+" +PO+ "))+" +PF+ ")-273.15 stack");
	}

	if(nSlices()==1){
		run("32-bit");	
		getStatistics(count, mean, min, max, std);
		minpix=min;
		maxpix=max;
		run("Macro...", "code=v=" +PB+ "/log(" +PR1+ "/(" +PR2+ "*(v/" +rawdivisor+ "-" +rawsubtract+ "+" +PO+ "))+" +PF+ ")-273.15");
	}
	
	//setBatchMode(false);
	mintemp=PB/log(PR1/(PR2*(minpix/rawdivisor-rawsubtract+PO))+PF)-273.15;
	maxtemp=PB/log(PR1/(PR2*(maxpix/rawdivisor-rawsubtract+PO))+PF)-273.15;
	setMinAndMax(mintemp, maxtemp);
	run(palettetype);
	//run("HighContrastRainbow1234 256");
}



function flirvalues(filepath, printvalues){

	// OS=getInfo("os.name");
	
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
	
	if(substring(OS, 0, 7)=="Windows"){
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
			Dialog.create("Camera Calibration Constants");
			Dialog.addMessage("Plank R1: " + PR1);
			Dialog.addMessage("Plank R2: " + PR2);
			Dialog.addMessage("Plank B " + PB);
			Dialog.addMessage("Plank F: " + PF);
			Dialog.addMessage("Plank O: " + PO);
			Dialog.addMessage("Thermal Image Width: " + imagewidth);
			Dialog.addMessage("Thermal Image Height: " + imageheight);
			Dialog.show()
			
			print("\n");
			print("Camera Calibration Constants:");
			//print(flirvals);
			setFont("SansSerif", 12);
			print("Planck R1: ", d2s(PR1,9));
			print("Planck R2: ", d2s(PR2,9));
			print("Planck B: ", d2s(PB,9));
			print("Planck F: ", d2s(PF,0));
			print("Planck O: ", d2s(PO,0));
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
		
		}

		output=newArray(14);
		output=newArray(PR1, PB, PF, PO, PR2, E, OD, RTemp, ATemp, IRWTemp, IRT, RH, imagewidth, imageheight);
		
		//output[0]=PR1;
		//output[1]=PB;
		//output[2]=PF;
		//output[3]=PO;
		//output[4]=PR2;
		//output[5]=E;
		//output[6]=OD;
		//output[7]=RTemp;
		//output[8]=ATemp;
		//output[9]=IRWTemp;
		//output[10]=IRT;
		//output[11]=RH;
		//output[12]=imagewidth;
		//output[13]=imageheight;
		
		return output;	
}



function flirdate(filepath, printvalues){

	//filepath=File.openDialog("Select a FLIR Image or Video File"); 
	//exiftoolpath="/usr/local/bin/";
	///exiftool="exiftool";
	
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
	
	if(substring(OS, 0, 7)=="Windows"){
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





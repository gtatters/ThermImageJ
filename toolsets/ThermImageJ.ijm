///////////////////////////////////////////////////////////////////////////////////////////////////////
////                                                                                               ////
////    This ImageJ toolset allows to access ImageJ macros for working with thermal images.        ////
////        Main Features: import, conversion, and transformation of thermal images.               ////
////                           Requires: exiftool, ffmpeg, perl, xxd                               ////
////                                Glenn J. Tattersall                                            ////
////                               July, 2026 - Version 4.0                            	           ////
////            - Highlights: added functionality for MWIR ATS/ATS-JPG files	                   ////
////            - fixed error in Raw2Temp atmospheric transmittance calculations that would        ////
////				have led to errors for object distances >10 m and with IR windows			   ////
///////////////////////////////////////////////////////////////////////////////////////////////////////
 
///////////////////////////////////////////////////////////////////////////////////////////////////////
////                                                                                               ////
////      User should verify the following path locations for their operating system:              ////
////                                                                                               ////
///////////////////////////////////////////////////////////////////////////////////////////////////////

// Customised Path Locations for Command Line Tools
// There is no easy approach to adding essential command line tools to the FIJI path, so 
// each user should customise the following 4 variables to be pointing toward the appropriate intallation
// location for your respective operating system.
// These path variables can be changed depending on where you have installed perl, ffmpeg and exiftool.
// But these are the recommended folder locations where functionality has been tested

// OSX Users verify these settings:									 // <- VERIFY THIS
var perlpathOSX="/usr/bin/";    	 								// or "/usr/local/bin"
var exiftoolpathOSX="/usr/local/bin/";			
var exiftoolOSX="exiftool";
var ffmpegpathOSX="/usr/local/bin/";

// Linux Users verify these settings:								 // <- VERIFY THIS
var perlpathLinux="/usr/bin/";
var exiftoolpathLinux="/usr/bin/";
var exiftoolLinux="exiftool";
var ffmpegpathLinux="/usr/bin/";

// Windows Users verify these settings:								 // <- VERIFY THIS
var perlpathWindows="c:/Perl64/perl/bin/"; 		 // this might be c:/Perl/perl/bin or c:/Perl64/perl/bin
var exiftoolpathWindows="c:/windows/"; 			 // recommended location: c:/windows folder
var exiftoolWindows="exiftool.exe";
var ffmpegpathWindows="c:/FFmpeg/bin/";			 // ffmpeg.exe should be in c:/FFmpeg/bin folder

///////////////////////////////////////////////////////////////////////////////////////////////////////
////                                                                                               ////
////      There are 20 possible short cut ROI macros. Customise the names below to your preference ////
////       			 Each short-cut is activated by one of the keys: 1,2,3,......0                 ////
////                 Q,W,E,R,T,Y,U,I,O,P (note that caps-lock will not work for these letters      ////
///////////////////////////////////////////////////////////////////////////////////////////////////////

// USER SHOULD CUSTOMISED THE REGION OF INTEREST NAMES BELOW
// related to above, there are currently 20 numbered/lettered ROI extraction routines.  
// Give labels to them here by editing the words in quote below, which will be saved in the ROI file.
// Note that the letter short cuts are all capital letters activated with the shift-key: QWERTYUIOP
var ROI1="Head"; 			// Short cut 1
var ROI2="Eyeskin"; 		// Short cut 2
var ROI3="Eyeball";			// Short cut 3
var ROI4="EarInside";		// Short cut 4 
var ROI5="NoseTip";			// Short cut 5
var ROI6="BodyVentral";		// Short cut 6
var ROI7="BodyDorsal";		// Short cut 7
var ROI8="BodyLateral";		// Short cut 8
var ROI9="LegInside";		// Short cut 9
var ROI10="LegOutside";		// Short cut 0

var ROI11="PawsFront";		// Short cut Q (shift-q)
var ROI12="PawsBack";		// Short cut W (shift-w)
var ROI13="TailFull";		// Short cut E (shift-e)
var ROI14="TailFlesh";		// Short cut R (shift-r)
var ROI15="Groin";			// Short cut T (shift-t)
var ROI16="Testes";			// Short cut Y (shift-y)
var ROI17="PartedBodyFur";	// Short cut U (shift-u)
var ROI18="Ground";			// Short cut I (shift-i)
var ROI19="Unknown1";		// Short cut O (shift-o)
var ROI20="Unknown2";		// Short cut P (shift-p)

// set the following value to "no" if you want to use the ROI tool without automatically advancing to next slice
// set the following value to "yes" if you want to use the ROI tool with automatical advancement to next slice
var autoadvanceslice=call("ij.Prefs.get", "autoadvanceslice", "no");

// Note: This is a sample of how you could re-name the 7 ROI names:
// Simply remove the // in front of each variable name and reboot ImageJ
//var ROI1="UpperBill";
//var ROI2="LowerBill";
//var ROI3="Head";
//var ROI4="Back";
//var ROI5="Belly";
//var ROI6="Foot";

///////////////////////////////////////////////////////////////////////////////////////////////////////
////                                                                                               ////
////      User may choose to change the following path locations for their operating system:       ////
////                                                                                               ////
///////////////////////////////////////////////////////////////////////////////////////////////////////

// The following will set the perl script path to the location of your ImageJ folder's scripts subfolder
var perlscriptpath=getDirectory("imageJ") + "scripts" + File.separator;  			  // <- CHANGE THIS IF YOU COPY SPLIT.PL TO A DIFFERENT FOLDER

// ROI commands will automatically save a ROI_Results file to user's desktop folder 
var desktopdir= getInfo("user.home") + File.separator + "Desktop" + File.separator;  // <- CHANGE THIS IF YOU WANT ANALYSIS FILES SAVED SOMEWHERE ELSE

// ROI exported file can be autonamed so as not to overwrite
// leave defaultroifilename blank and a filename will be generated based on the current open image
// otherwise set this to var defaultroifilename="ROI_Results.csv";
var defaultroifilename="";  													     // <- CHANGE THIS IF YOU WANT A DIFFERENT DEFAULT FILENAME FOR ROI OUTPUTS	

var macropath=getDirectory("macros");

// full path to the split.pl script
var perlsplit=perlscriptpath + "split.pl";	

// full path to the ats-split.pl script
var perlsplitats=perlscriptpath + "ats-split.pl"

// full path to the ats-repair.pl script to convert ats-jpgs
var perlrepairats = perlscriptpath + "ats-repair.pl";

// Extract Operating system user is on.  
// OS will be used in most macros calling command line tools
var OS=getInfo("os.name");

//setOption("ExpandableArrays", true);

// Global Parameters
var luts = getLutMenu();
var lCmds = newMenu("LUT Menu Tool", luts);
var palettetypes=newArray("Grays", "Ironbow", "Rainbow", "Spectrum", "Thermal", "Yellow", "Yellow Hot", "Green Fire Blue", "Red/Green", "5 Ramps", "6 Shades");
var defaultpalette="Grays";
var thermlCmds = newMenu("Thermal LUT Menu Tool", palettetypes);
var ImportCmds = newMenu("Import Menu Tool",
      newArray("Raw Import Mikron RTV", "-", "Convert FLIR JPG(s)", "Import FLIR JPG", "Import FLIR JPG with defaults", "-", "Import FLIR ATS JPG", "Import FLIR ATS JPG with Defaults", "-", "Import Image Sequence", "Import CSV Image Sequence", "-", "Raw Import FLIR SEQ", "Import FLIR SEQ", "Import FLIR CSQ", "-", "Import 16-bit AVI", "-",  "Import FLIR ATS" ));
var lut = -1;
var lutdir = getDirectory("luts");
var list;
var color = 0;
var colors = newArray("Red", "Green", "Blue", "Cyan", "Magenta", "Yellow");

// the following persistent variable are updated on the user's ImageJ once Raw2Temp or FlirValues is performed on a file
// This will help for continuity when analysing files in between imagej sessions
// User may wish to update these values to reflect their own commonly used thermal camera in order to streamline 
// calculations:

var PR1 = parseFloat(call("ij.Prefs.get", "PR1.persistent", "17998.529")); 
var PR2 = parseFloat(call("ij.Prefs.get", "PR2.persistent", "0.015145967")); 
var PB = parseFloat(call("ij.Prefs.get", "PB.persistent", "1453.1")); 
var PF = parseFloat(call("ij.Prefs.get", "PF.persistent", "1")); 
var PO = parseFloat(call("ij.Prefs.get", "PO.persistent", "-5854"));
 
var ATA1 = parseFloat(call("ij.Prefs.get", "ATA1.persistent", "0.006569")); 
var ATA2 = parseFloat(call("ij.Prefs.get", "ATA2.persistent", "0.01262")); 
var ATB1 = parseFloat(call("ij.Prefs.get", "ATB1.persistent", "-0.002276"));
var ATB2 = parseFloat(call("ij.Prefs.get", "ATB2.persistent", "-0.00667")); 
var ATX = parseFloat(call("ij.Prefs.get", "ATX.persistent", "1.9")); 
var E = parseFloat(call("ij.Prefs.get", "E.persistent", "0.95")); 
var OD = parseFloat(call("ij.Prefs.get", "OD.persistent", "1")); 
var RTemp = parseFloat(call("ij.Prefs.get", "RTemp.persistent", "20")); 
var ATemp = parseFloat(call("ij.Prefs.get", "ATemp.persistent", "20")); 
var IRWTemp = parseFloat(call("ij.Prefs.get", "IRWTemp.persistent", "20")); 
var IRT = parseFloat(call("ij.Prefs.get", "IRT.persistent", "1")); 
var RH = parseFloat(call("ij.Prefs.get", "RH.persistent", "50.0")); 
var imagewidth=parseInt(call("ij.Prefs.get", "imagewidth.persistent", "640"));
var imageheight=parseInt(call("ij.Prefs.get", "imageheight.persistent", "480")); 
var magicbyte=call("ij.Prefs.get", "magicbyte.persistent", "02008002e001");
var frameinterval=parseFloat(call("ij.Prefs.get", "frameinterval.persistent", "0.03333333333"));
var imagetemperaturemin=parseInt(call("ij.Prefs.get", "imagetemperaturemin.persistent", "-20"));
var imagetemperaturemax=parseInt(call("ij.Prefs.get", "imagetemperaturemax.persistent", "60")); 
var usevirtual=parseInt(call("ij.Prefs.get", "usevirtual.persistent", "1")); 
var addtimestamp=parseInt(call("ij.Prefs.get", "addtimestamp.persistent", "0")); 
var converttotemperature=parseInt(call("ij.Prefs.get", "converttotemperature.persistent", "1")); 
var deletetempfiles=parseInt(call("ij.Prefs.get", "deletetempfiles.persistent", "1")); 
var offsetbyte=parseInt(call("ij.Prefs.get", "offsetbyte.persistent", "1372")); 
var gapbytes=parseInt(call("ij.Prefs.get", "gapbytes.persistent", "1424")); 
var nframes=parseInt(call("ij.Prefs.get", "nframes.persistent", "20000")); 
var thermalcameratype=call("ij.Prefs.get", "thermalcameratype.persistent", "LWIR");

// TO DO!!!!!: REMOVE TEST MACROS, Replace Raw2Temp macros with Raw2temp2 macros
// Add file checks to raw2temp to remind user about MWIR vs LWIR!!!
// LOOK INTO FAST CALCULATION FOR MWIR TO NARROW THE RANGE

// FLIR ATS (NicevilleFactoryCal-derived) calibration constants and
// default object parameters, persistent between ImageJ sessions --
// companion block to the flirvalues()-related PR1/PR2/PB/PF/PO/etc
// declarations above. Deliberately uses Nfc-prefixed names throughout
// (NfcB/NfcR/NfcF rather than PB/PR1/PF) since these come from a
// DIFFERENT, 3-constant Planck-on-radiance calibration model (no
// offset term) than exiftool's 5-constant Planck R1/R2/B/F/O tags --
// see fliratsvalues()'s own header comment for the full explanation.
// Defaults below are deliberately generic/sensible placeholders (not
// taken from any specific camera) since, unlike flirvalues()'s
// defaults, there isn't yet an established "typical" default for
// these tags -- they will be overwritten with real values the first
// time fliratsvalues() is run on an actual file.

var NfcB = parseFloat(call("ij.Prefs.get", "NfcB.persistent", "3115.716309000"));
var NfcR = parseFloat(call("ij.Prefs.get", "NfcR.persistent", "5.936986446"));
var NfcF = parseFloat(call("ij.Prefs.get", "NfcF.persistent", "1.000000000"));
var NfcC0 = parseFloat(call("ij.Prefs.get", "NfcC0.persistent", "-0.00004238"));
var NfcC1 = parseFloat(call("ij.Prefs.get", "NfcC1.persistent", "4.2897E-8"));
var NfcC2 = parseFloat(call("ij.Prefs.get", "NfcC2.persistent", "-2.1557E-13"));
var NfcMinTemp = parseFloat(call("ij.Prefs.get", "NfcMinTemp.persistent", "-20"));
var NfcMaxTemp = parseFloat(call("ij.Prefs.get", "NfcMaxTemp.persistent", "55"));
var NfcMinCounts = parseFloat(call("ij.Prefs.get", "NfcMinCounts.persistent", "1559"));
var NfcMaxCounts = parseFloat(call("ij.Prefs.get", "NfcMaxCounts.persistent", "12092"));

var NfcATA1 = parseFloat(call("ij.Prefs.get", "NfcATA1.persistent", "0.00506228"));
var NfcATA2 = parseFloat(call("ij.Prefs.get", "NfcATA2.persistent", "0.201436371"));
var NfcATB1 = parseFloat(call("ij.Prefs.get", "NfcATB1.persistent", "0.002819395"));
var NfcATB2 = parseFloat(call("ij.Prefs.get", "NfcATB2.persistent", "0.008017067"));
var NfcATX = parseFloat(call("ij.Prefs.get", "NfcATX.persistent", "0.906783402"));
var NfcE = parseFloat(call("ij.Prefs.get", "NfcE.persistent", "0.95"));
var NfcOD = parseFloat(call("ij.Prefs.get", "NfcOD.persistent", "1"));
var NfcRTemp = parseFloat(call("ij.Prefs.get", "NfcRTemp.persistent", "20"));
var NfcATemp = parseFloat(call("ij.Prefs.get", "NfcATemp.persistent", "20"));
var NfcIRWTemp = parseFloat(call("ij.Prefs.get", "NfcIRWTemp.persistent", "20"));
var NfcIRT = parseFloat(call("ij.Prefs.get", "NfcIRT.persistent", "1"));
var NfcRH = parseFloat(call("ij.Prefs.get", "NfcRH.persistent", "50.0"));
var atsimagewidth = parseInt(call("ij.Prefs.get", "atsimagewidth.persistent", "1280"));
var atsimageheight = parseInt(call("ij.Prefs.get", "atsimageheight.persistent", "1024"));

//////////////////////////////////////// Functions ///////////////////////////////////////////////

// Searches typical folders for whether a specific program is installed.
// Designed to help troubleshoot installations for users less familiar with folder designation nomenclature

function WhereProgram(){
	
	programselect=newArray("exiftool", "perl", "ffmpeg", "xxd");
	Dialog.create("Search Installation Locations"); 
	Dialog.addMessage("This macro will search for the path for one of the essential command line programs.");
	Dialog.addMessage("Select from exiftool, perl, ffmpeg, or xxd.");
	Dialog.addChoice("Program", programselect);
    Dialog.show();
	
	program=Dialog.getChoice();
	
	if(OS=="Mac OS X"){
		command="export PATH=$PATH:/usr/local/bin:/opt/local/bin:/usr/bin:/usr/sbin; which " + program;
		whereoutput=exec("/bin/sh", "-c", command);
	}

	if(OS=="Linux"){
		command="export PATH=$PATH:/usr/local/bin:/opt/local/bin:/usr/bin:/usr/sbin; which " + program;
		whereoutput=exec("/bin/sh", "-c", command);	
	}
	
	if(substring(OS, 0, 5)=="Windo"){
		program=program + ".exe";
		additionalPaths = "%USERPROFILE%/Desktop;c:/windows;c:/windows/system32;c:/windows/system;c:/Perl64/bin;c:/Perl64/perl/bin;c:/Perl/perl/bin;c:/FFmpeg/bin;c:/Strawberry/perl/bin;C:/ActiveState/perl/bin";
		// Construct the command for finding the program in the PATH
		command = "where " + program;
		// Execute the command using cmd.exe
		whereoutput = exec("cmd.exe", "/c", "set PATH=%PATH%;" + additionalPaths + " && " + command);
	}
	
	//print(whereoutput);
	whereoutput=replace(whereoutput, "\\/n", "");
	//print(whereoutput);
	whereoutput=replace(whereoutput, program, "");
	
	if(whereoutput==""){
		Dialog.create("Installation Location");
		Dialog.addMessage(program + " cannot be found at any typical locations.");
		Dialog.addMessage("Please consider re-installing " + program + " according to the installation instructions.");
		Dialog.show()
		print("Cannot find " + program + " installed in any typical path locations.");
	}
	else{
		Dialog.create("Installation Location");
		Dialog.addMessage(program + " is located in the following path:" + whereoutput);
		Dialog.addMessage("Edit the Thermimage.ijm file (line 24-40) to change your path to the appropriate folder\nif this tool is not working properly.");
		Dialog.show()
		print(program + " is located in the following path:" + whereoutput);
	}

	return whereoutput;
}


function InstallChecks(){
	
	installsuccess=0;
	
	if(OS=="Mac OS X"){
		var perlpath=perlpathOSX;
		var exiftoolpath=exiftoolpathOSX;
		var exiftool=exiftoolOSX;
		var ffmpegpath=ffmpegpathOSX;
		exiftoolcheck=exec(exiftoolpath + exiftool,  "-ver"); // should just return version number, i.e. 12.62
		perlcheck=exec(perlpath + "perl", "-v"); // returns a verbose output "This is perl ..."
		splitcheck=splitcheck=File.exists(perlscriptpath + File.separator + "split.pl");
		ffmpegcheck=exec(ffmpegpath + "ffmpeg", "-version"); // returns a verbose output starting with "ffmpeg version ..."
	}

	if(OS=="Linux"){
		var perlpath=perlpathLinux;
		var exiftoolpath=exiftoolpathLinux;
		var exiftool=exiftoolOSX;
		var ffmpegpath=ffmpegpathLinux;
		exiftoolcheck=exec(exiftoolpath + exiftool,  "-ver"); // should just return version number, i.e. 12.62
		perlcheck=exec(perlpath + "perl", "-v"); // returns a verbose output "This is perl ..."
		splitcheck=File.exists(perlscriptpath + File.separator + "split.pl");
		ffmpegcheck=exec(ffmpegpath + "ffmpeg", "-version"); // returns a verbose output starting with "ffmpeg version ..."
	}
	
	if(substring(OS, 0, 5)=="Windo"){
		var perlpath=perlpathWindows;
		var exiftoolpath=exiftoolpathWindows;
		var exiftool=exiftoolWindows;
		var ffmpegpath=ffmpegpathWindows;
		exiftoolcheck=exec("cmd", "/c", exiftoolpath + exiftool,  "-ver"); // should just return version number, i.e. 12.62
		perlcheck=exec("cmd", "/c", perlpath + "perl", "-v"); // returns a verbose output "This is perl ..."
		splitcheck=File.exists(perlscriptpath + File.separator + "split.pl");
		ffmpegcheck=exec("cmd", "/c", ffmpegpath + "ffmpeg", "-version"); // returns a verbose output starting with "ffmpeg version ..."	
	}	
	
		exiftoolcheck=parseFloat(exiftoolcheck);
		if(lengthOf(perlcheck)>13){
			perlcheck=replace(perlcheck, "\n", "");
			perlcheck=substring(perlcheck, 0, 12); // if successful this should simply read "This is perl"
		}
		if(lengthOf(ffmpegcheck)>15){
			ffmpegcheck=substring(ffmpegcheck, 0, 14); // if successful this should simply read: "ffmpeg version"
		}
		
		if(exiftoolcheck>10){  // requires exiftool version>10
			exiftoolinstall = "Installed at: " + exiftoolpath;
			installsuccess=installsuccess+1;
		}
		else{
			exiftoolinstall = "Could not find exiftool installation in: " + exiftoolpath;
		}
				
		if(perlcheck=="This is perl"){
			perlinstall = "Installed at: " + perlpath;
			installsuccess=installsuccess+1;
		}
		else{
			perlinstall = "Could not find perl installation in: " + perlpath;
		}
					
		if(splitcheck==1){
			splitinstall = "Installed at: " + perlscriptpath;
			installsuccess=installsuccess+1;
		}
		else{
			splitinstall = "Could not find split.pl file in: " + perlscriptpath;
		}
				
		if(ffmpegcheck=="ffmpeg version"){
			ffmpeginstall = "Installed at: " + ffmpegpath;
			installsuccess=installsuccess+1;
		}
		else{
			ffmpeginstall = "Could not find ffmpeg installation in: " + ffmpegpath;
		}
		
		Dialog.create("Installation Checks");
		Dialog.addMessage("Exiftool: " + exiftoolinstall);
		Dialog.addMessage("Perl: " + perlinstall);
		Dialog.addMessage("Split.pl: " + splitinstall);
		Dialog.addMessage("FFmpeg: " + ffmpeginstall);
		Dialog.show()
		
		print("Installation Checks:");
		setFont("SansSerif", 12);
		print(exiftoolinstall);
		print(perlinstall);
		print(splitinstall);
		print(ffmpeginstall);	
		
		
		if(installsuccess==1){
			print("Only one installation check passed.");
			print("For those unsuccessful installations,\nplease edit the ThermimageJ.ijm file to specify the proper path.\nThis information can be found in the first 100 lines of code");
		}
		
		if(installsuccess==2){
			print("Two installations checks passed.");
			print("For those unsuccessful installations,\nplease edit the ThermimageJ.ijm file to specify the proper path.\nThis information can be found in the first 100 lines of code");
		}
		
		if(installsuccess==3){
			print("Three installation checks passed.");
			print("For those unsuccessful installations,\nplease edit the ThermimageJ.ijm file to specify the proper path.\nThis information can be found in the first 100 lines of code");
		}
		
		if(installsuccess==4){
			print("All four installation checks have passed.\nIt appears that all 4 programs are installed in the proper folders.");
		}
		
		print("\n");

}

function ImportImageSequence(){
	
	run("Image Sequence...");
}


//function ImportCSVImageSequence(){
//	dir = getDirectory("Choose directory");
//	list = getFileList(dir);
//	run("Close All");
//	setBatchMode(true);
//	for (i=0; i<list.length; i++) {
// 		file = dir + list[i];
// 		run("Text Image... ", "open=&file");
//	}
//	run("Images to Stack", "use");
//	setBatchMode(false);
//}

function ImportCSVImageSequence(){
    dir = getDirectory("Choose directory");
    list = getFileList(dir);
    
    // Filter to only CSV files and count them
    csvList = newArray(list.length);
    csvCount = 0;
    for (i = 0; i < list.length; i++) {
        if (endsWith(toLowerCase(list[i]), ".csv")) {
            csvList[csvCount] = list[i];
            csvCount++;
        }
    }
    // Trim array to actual CSV count
    csvList = Array.trim(csvList, csvCount);
    
    // Prompt user for Start, Count, and Step
    Dialog.create("CSV Import Options");
    Dialog.addMessage("Total CSV files found: " + csvCount);
    Dialog.addNumber("Start (1-based index):", 1, 0, 5, "");
    Dialog.addNumber("Count (number of files to import):", csvCount, 0, 5, "");
    Dialog.addNumber("Step (interval between files):", 1, 0, 5, "");
    Dialog.show();
    
    startIdx = Dialog.getNumber() - 1; // Convert to 0-based index
    userCount = Dialog.getNumber();
    step = Dialog.getNumber();
    
    // Validate inputs
    if (startIdx < 0 || startIdx >= csvCount) {
        exit("Start index is out of range. Must be between 1 and " + csvCount + ".");
    }
    if (step < 1) {
        exit("Step must be at least 1.");
    }
    if (userCount < 1) {
        exit("Count must be at least 1.");
    }
    
    run("Close All");
    setBatchMode(true);
    
    imported = 0;
    for (i = startIdx; i < csvCount && imported < userCount; i += step) {
        file = dir + csvList[i];
        run("Text Image... ", "open=&file");
        imported++;
    }
    
    run("Images to Stack", "use");
    setBatchMode(false);
    
    showMessage("Import Complete", imported + " file(s) imported into stack.");
}


// Based on the LUTFileTool by Gabriel Landini
function cycleLUTs(inc) {
       if (lut==-1)
           createLutList();
       if (nImages==0) {
          call("ij.gui.ImageWindow.centerNextImage");
          newImage("LUT", "8-bit ramp", 750, 32, 1);
          run("Rotate 90 Degrees Left");
          setColor(0);
          setLineWidth(2);
          drawRect(0, 0, 32, 750);
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


// for a 4 byte/32 bit integer, swap it so that it is the reverse endian order
function swapEndian(intValue, numBytes) {
    // Perform byte swapping based on the number of bytes
    if (numBytes == 2) {
        byte0 = (intValue >> 8) & 0xFF;
        byte1 = intValue & 0xFF;
        
        // Reassemble in reversed order
        return (byte1 << 8) | byte0;
    } else if (numBytes == 4) {
        byte0 = (intValue >> 24) & 0xFF;
        byte1 = (intValue >> 16) & 0xFF;
        byte2 = (intValue >> 8) & 0xFF;
        byte3 = intValue & 0xFF;
        
        // Reassemble in reversed order
        return (byte3 << 24) | (byte2 << 16) | (byte1 << 8) | byte0;
    } else {
        // Unsupported number of bytes
        return NaN;
    }
}




// simple byte swap for 8 bit string representation.  ie. "8002" --> "0280"
// hexString is a string, representing the hexadecimal value
function swapHex(hexString){
	swappedValue=substring(hexString, 2, 4) + substring(hexString, 0, 2);
	return swappedValue;	
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

// Returns the regression slope of y on x
function Slope(ArrayX, ArrayY){
	Array.getStatistics(ArrayX, mean, min, max, std);
	meanx=mean;
	sx=std;
	Array.getStatistics(ArrayY, mean, min, max, std);
	meany=mean;
	sy=std;
	slp=Pearson(ArrayX, ArrayY)*sy/sx;
	return slp;
}

// Returns the regression intercept of y on x
function Intercept(ArrayX, ArrayY){
	Array.getStatistics(ArrayX, mean, min, max, std);
	meanx=mean;
	Array.getStatistics(ArrayY, mean, min, max, std);
	meany=mean;
	slp=Slope(ArrayX, ArrayY);
	b=meany - slp * meanx;
	return b;
}

// create a random sequence of numbers.  assume gaussian.  provide mean and sd
function randomseq(n, mean, sd){
	rn=newArray(n);
	for (i=0; i<n; i++) 
       rn[i] = random("gaussian") * sd + mean;
    return rn; 
}

// calculate a cumulative sum array
function cumsum(ArrayX){
	n=ArrayX.length;
	csum=newArray(n);
	csum[0]=ArrayX[0];
	for(i=1; i<n; i++){
		csum[i] = csum[i-1] + ArrayX[i];
	}
	return csum;
}

// calculate moving average of an Array.
function movavg(ArrayX, n){
	// ArrayX is the array of data you want to average over.
	// n is the number of samples.  Better to use odd numbers, like 3, 5, 7, etc.
	len=ArrayX.length;
	cx = cumsum(ArrayX);
	//Array.print(cx);
	rsum=newArray(len);
	rsum=ArrayX;
	
	for (i = n; i < len; i++) {
		rsum[i] = (cx[i] - cx[i-n])/n;	
	}
	
	Array.getStatistics(ArrayX, mean);
	mean=mean;
	movingaverage=newArray(len);
	
	// go through index, shift to centre the moving average (first n/2 entries and last n/2 entries set to mean)
	// this is a work in progress.  Might not be perfectly centered over data
	for (i = 0; i < len; i++) {
		
		movingaverage[i]=rsum[n];
		
		if(i>floor(n/2)){
			movingaverage[i]=rsum[i];
		}
		if(i>len-floor(n/2)-1){
			movingaverage[i]=rsum[len-n];
		}
	}

	return movingaverage;
}


// faster calculation of median - but may only be approximate
function MedianFast(){
	getStatistics(area, mean, min, max, std, histogram);
	pixelmin=min;
	pixelhist=histogram;
	length=pixelhist.length;
	binwidth=(max-min)/256;
	vals=Array.getSequence(length);	
	
	cumulsumhist=cumsum(pixelhist);
	Array.getStatistics(cumulsumhist, min, max, mean, stdDev);
	midpoint=floor(max/2);
	
	for(i=0; i<pixelhist.length; i++){
		vals[i]=vals[i]*binwidth+pixelmin;
		print(vals[i]);
		//print(cumulsumhist[i]);
		med=vals[i];
		if(cumulsumhist[i]>=midpoint){
			med=vals[i];
			i=1000;
		}
	}
	return med;
}


// calculates median by sorting the data and taking the middle point
function Median(ArrayX){
	len=ArrayX.length;
	x=Array.sort(ArrayX);
	middleindex=floor(len/2);
	med=ArrayX[middleindex];
	return med;
}

// percentile of an array
function percentile(ArrayX, P){
	len=ArrayX.length;
	x=Array.sort(ArrayX);
	Pindex=floor(P*len);
	pcntile=ArrayX[Pindex];
	return pcntile;
}

// outlier remove from an array
function removeoutliers(ArrayX){
	qnt25=percentile(ArrayX, 0.25);
	qnt75=percentile(ArrayX, 0.75);
	H=1.5 * (qnt75-qnt25);
	med=Median(ArrayX);

	print(med);
	print(qnt25);
	print(qnt75);
	
	for(i=0; i < ArrayX.length; i++){
		if(ArrayX[i] < (qnt25-H)){
			print("too low");
			ArrayX[i]=med;	
		}
		if(ArrayX[i] > (qnt75+H)){
			print("too high");
			ArrayX[i]=med;
		}
	}
	return ArrayX;
}

// root mean square of an Array:
function RMS(ArrayX){
	len=ArrayX.length;
	//print(len);
	crossprod=newArray(len);
	sum=0;
	for(i=0; i<len; i++){
		crossprod[i]=ArrayX[i]*ArrayX[i];
		sum += crossprod[i];
	}
	rms_data=sqrt(sum/len);	
	return rms_data;
}


// Returns the current image pixel values as an array
function getPixelArray(){
	getStatistics(area, mean, min, max, std, histogram);
	pixelhist=histogram;
	x=cumsum(pixelhist);
	
	binwidth=(max-min)/256;
	length=pixelhist.length;
	vals=Array.getSequence(length);
	w=getWidth();
	h=getHeight();
	pixeldata=newArray(0);
	
	for (i = 0; i < length; i++) {
		vals[i]=vals[i]*binwidth+min;
		temp=newArray(pixelhist[i]);
		temp=Array.fill(temp, vals[i]);
		pixeldata=Array.concat(pixeldata, temp);
	}
	return pixeldata;
}


// doSort will return the rank positions for the original array, where smallest values have rank zero
function doSort(theArray){
	sortedValues = Array.copy(theArray);
	sortedValues=Array.sort(sortedValues);
	rankPosArr = Array.rankPositions(theArray);
	
	//ranks = Array.rankPositions(rankPosArr);
	
	//print ("Original array:");
	//for (jj = 0; jj < theArray.length; jj++){
	//	print(jj, ": ", theArray[jj]);
	//}
	
	//print ("\nSorted array (starting with smallest value):");
	//for (jj = 0; jj < theArray.length; jj++){
	//	print(sortedValues[jj]);
	//}
	
	//print ("\nRank Positions (starting with index of smallest value):");
	//for (jj = 0; jj < theArray.length; jj++){
	//	print(rankPosArr[jj]);
	//}
	
	
	//print ("\nRanks (starting with rank of first value):");
	//for (jj = 0; jj < theArray.length; jj++){
	//	print(ranks[jj]);
	//}
	
	//print ("\n- Smallest value is defined to have rank zero");
	//print ("- Use Array.invert to change between ascending and descending order.");
	//print ("- String sorting ignores case.");
	return rankPosArr;
}


function entropy(){
	// Objective: solve Shannon's Entropy for a given Region of Interest or Image
	// Formula: H = - sum(p(Si) * log2(p(Si))
	// summing across all n elements in a histogram of roi
	// where p(Si) is the probability of event Si occurring, where i is ith element of n.	
	// log2 is log base 2
	// I was going to use this for assessment of randomness or structure in an image but I think it won't work
	getStatistics(area, mean, min, max, std, histogram);
	pixelhist=histogram;
	length=pixelhist.length;
	p=newArray(length);
	
	total=0;
	for (i=0;i<length;i++){
	 	total=total+pixelhist[i];
	}
	
	for (i=0;i<length;i++){
	 	p[i]=pixelhist[i]/total;
	}
	
	//binwidth=(max-min)/length;
	
	p=Array.deleteValue(p, 0);

	H=0;
	
	for (i = 0; i < lengthOf(p); i++) {
		//if(p[i]==0) {
		//	i++;
		//}
		H=H+p[i]*log(p[i])/log(2); // to calculate log base 2, compute log(x)/log(2)
		//print(p[i]);
	}
	// H is Shannon's Entropy
	H=-1*H;
	print(H);
}


	
// returns a random number, 0 <= k < n
function randomInt(n) {
   return n * random();
}

function shuffle(array) {
	// will shuffle an array and return it. 
	// needs the randomInt() function
	//array = newArray(2.2, 3.3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97);
	//shuffle(primes);
	//Array.print(array);
    n = array.length;  // The number of items left to shuffle (loop invariant).
    // newarray=newArray(n);
 
   while (n > 1) {
      k = randomInt(n);     // 0 <= k < n.
      n--;                  // n is now the last pertinent index;
      temp = array[n];  // swap array[n] with array[k] (does nothing if k==n).
      array[n] = array[k];
      array[k] = temp;
   }	
}


function ImageRestructure(){
	//getStatistics(area, mean, min, max, std, histogram);
	
	roivalues=getPixelArray();
	length=lengthOf(roivalues);
	index=newArray(length);
	for (i = 0; i < length; i++) {
		index[i]=i;
	}
	
	shuffle(index);
		
	roivaluesrandom=newArray(length);
	for (i = 0; i < length; i++) {
		roivaluesrandom[i]=roivalues[index[i]];
	}

    euclid=newArray(length);
    euclid2=newArray(length);
    
	for (i=0; i<length; i++){
		//print(roivaluesrandom[i]);
	 	euclid[i]=roivalues[i] - roivaluesrandom[i];
	 	euclid2[i]=euclid[i]*euclid[i];
	    //print(euclid2[i]);
	}

	// Sum the euclidean differences squared and normalise to length then take squareroot
	// this provides a standard deviation from the random restructured image
	sdrandomdiff=sqrt(Sum(euclid2)/length);
	varrandomdiff=Sum(euclid2)/length;
	// get raw roi statistics
	Array.getStatistics(roivalues, min, max, mean, stdDev);

	roivar=stdDev*stdDev;
	print(varrandomdiff);
	print(roivar);
	print(varrandomdiff/roivar);
	
	return sdrandomdiff;
}


// Generic Region of Interest Function / Generic ROI Function
// given an roilabel selected from the list of 20 rois at the beginning of this toolset
// this function will export to a results table the mean, min, max, sd, and area of the ROI
// if the ROI is not drawn, user will be given an option to overwrite 0 values to the results table
// if the user has only been drawn a single point ROI, only 0 values will be exported
function RegionOfInterest(roilabel){
		
	if(defaultroifilename=="") {
		roifilename=getTitle() + "_roi_results.csv";
	}
	else{
		roifilename="Roi_results.csv";
	}
	
	if (selectionType() == -1) {
		ROIproceedchoice=newArray("Yes", "No");	
		ROIProceed="Yes";
		Dialog.create("Region of Interest Result Control"); 
    	Dialog.addMessage("You are seeing this pop-up because no " + roilabel + " is currently drawn.");
		Dialog.addMessage("Would you like to overwrite existing results for " + roilabel + " with NaN values?");
		Dialog.addMessage("\n"); 	
		Dialog.addChoice("Would you like to proceed (hit enter for Yes)?", newArray("Yes", "No"), "Yes");
		Dialog.show();
		ROIProceed=Dialog.getChoice();
		area=NaN;
		mean=NaN;
		min=NaN;
		max=NaN;
		std=NaN;
   	} else {
     	roitype=Roi.getType();
     	getSelectionBounds(xleft, yupper, wd, ht); // provides the upper left most cursor position
		getSelectionCoordinates(xCoordinates, yCoordinates);
		len=xCoordinates.length;
		getCursorLoc(x2, y2, z2, flags); // obtains the final cursor postion
		x1=xCoordinates[0];
		y1=yCoordinates[0];
		x2=xCoordinates[len-1];
		y2=yCoordinates[len-1];
		//theta=180/PI*atan2((y2-y1), (x2-x1));
		hypotenuse=sqrt((wd*wd + ht*ht));
		getStatistics(area, mean, min, max, std, histogram);
   	}
		filename=getTitle; 
	
		//type = selectionType(); 
		//if(type==-1) exit("No ROI selection specified");
	
	updateResults();

	rownum=getSliceNumber()-1;
	
	// this will allow you to skip aheaad to a new slice, do the analysis, then scroll back
	for (i=0; i<getSliceNumber(); i++) { 	
		setResult("Filename", i, "");
	}
	
	if(area<=1) { // this means that if you select a single point ROI, it will set all results to 0
		//mean=0;
		//min=0;
		//max=0;
		//std=0;
	}

	op=pasteobjectparameters();
	setResult("Filename", rownum, filename);
	setResult("SliceLabel", rownum, getMetadata("label"));
	setResult("Slice", rownum, getSliceNumber());
	setResult("ObjectParam", rownum, op);	
	setResult(roilabel + "Mean", rownum, mean);
	setResult(roilabel + "Min", rownum, min);
	setResult(roilabel + "Max", rownum, max);
	setResult(roilabel + "SD", rownum, std);
	setResult(roilabel + "Area", rownum, area);
		
	updateResults();
	
	saveAs("Results", desktopdir + File.separator + File.getName(roifilename));
	
	if(autoadvanceslice=="yes" && getSliceNumber()<nSlices()){
		setSlice(getSliceNumber()+1);
	}
	
	if(File.exists(desktopdir + File.separator + File.getName(roifilename))==1){
		wait(10);	
	}
	
	wait(500);
	
}



function pasteobjectparameters(){
	// extract the object parameters currently in use
	// to export easily to spreadsheet
	op="E=" + E + " OD=" + OD + " RTemp=" + RTemp + " ATemp=" + ATemp + " IRWTemp=" + IRWTemp + " IRT=" + IRT + " RH=" + RH;	
	return op;
}


// search files for first 3 characters for FFF and return that list of files
function GetFileListFilter(directory, searchlength, filterstring){
	filelist=getFileList(directory);
	newfilelist=newArray(filelist.length);
	j=0;
	for(i=0; i<filelist.length; i++){
		filepath=directory + File.separator + filelist[i];
		first3=File.openAsRawString(filepath, searchlength);
		if(first3 == filterstring){
			newfilelist[j]=filepath;
			j++;	
		}
	}
	return newfilelist;	
}


// Returns a new list of files in directory of a certain extension.
// e.g. set extension to "fff" to only return .fff files
function GetFileListByExtension(directory, extension){
	filelist=getFileList(directory);
	newfilelist=filelist;
	for(i=0; i<filelist.length; i++){
		doesfilepathendinextension=endsWith(filelist[i], extension);
		if(doesfilepathendinextension == 0){
			//print(filelist[i]);
			//print(newfilelist[i]);
			newfilelist=Array.deleteValue(newfilelist, filelist[i]);			
		}
	}
	return newfilelist;
}

// Search a particular folder and count the number of files that have the given extension.  I.e. used to count up # of .fff files
function CountFilesByExtension(directory, extension){
	filenames=getFileList(directory);
	counter=0;
	for (i = 0; i < filenames.length; i++) {
		//print(filenames[i]);
		if(endsWith(filenames[i], extension)){
			counter=counter+1;
		}
}
return counter;
}


// Given a directory, it will GetFileListByExtension from directory, of specified file extension (e.g. "fff") and remove every nth file determined by the step value. 
// Step=1 will not delete any files. Step=2 will delete every other file, Step=3 will delete every ... 
// Note: directory needs to end in a file.separator or result from a getDirectory() dialog prompt.
function RemoveEveryNthFFF(directory, step){
	// directory needs to end in file.separator
	if(endsWith(directory, File.separator)==0){
		directory=directory + File.separator;
	}
	
	filenames=GetFileListByExtension(directory, "fff");
	if(step>1){ // if step=1, this function should not do anything.
		// create an index array that corresponds to the length of the filenames array
		inputArray = Array.getSequence(filenames.length);  // ie. [0,1,2,3,4,5,...]
 		finalArray = Array.getSequence(filenames.length); // ie. [0,1,2,3,4,5,...]
		
		// Initialize the keep array
 		keepArray = newArray(); // this is the index array of filenames to keep. Starts out blank, but gets built in loop below
 		
 		// Loop through the input array   i.e. keep array might look like [0,2,4,6,...] if step = 2
		for (i = 0; i < inputArray.length; i=i+step) {
  		    // Add every nth number to the keep array, according to the step value
 			// this keeparray correspondes to indexes in the filenames array that will be kept, not deleted.
 			keepArray = Array.concat(keepArray, inputArray[i]);
 			 }
		// Loop through the keepArray and remove these from the final array i.e. final array would look like [1,3,5,7,...] if step = 2
		// finalArray corresponds to indexes in the filenames array that will be deleted
		for(i=0; i < keepArray.length; i++){
			//print(directory + File.separator + filenames[i]);
		    //print(keepArray[i]);
		    finalArray=Array.deleteValue(finalArray, keepArray[i]);
		    //FileDeleteSuccess=File.delete(directory + filenames[]);	
		}
		
		for(i=0; i < finalArray.length; i++){
			//print(directory + File.separator + filenames[i]);
		    //print(finalArray[i]);
		    showProgress(i);
		    //print("Should delete: " + directory + filenames[finalArray[i]]);
		    FileDeleteSuccess=File.delete(directory + filenames[finalArray[i]]);	
		}
		
	print("Starting number of fff files: " + inputArray.length);
	print("Nnumber of fff files removed: " + finalArray.length);
	print("Remaining fff files: " + inputArray.length - finalArray.length);	
	print("Removed fff files corresponding to the provided step value of: " + step);
   }
}

///RemoveEveryNthFFF("~/Desktop/test/", 1);

// put Atmospheric Trans constants into an array to pass fewer numbers to raw2temp, since ImageJ limits parameters to 20 or fewer
function AtmosphericTransVals(ATA1, ATA2, ATB1, ATB2, ATX){
	//ATvals=newArray(5);
	ATvals=newArray(ATA1, ATA2, ATB1, ATB2, ATX);
	return ATvals;
}

// clean up the temp folder at end of video conversion and provide feedback on success
function deletetempfolder(tempfolder){
	templist = getFileList(tempfolder);
	tempfilesdelete_success = 0;
	tempfolderdelete_success = 0;
	
	for (i = 0; i < templist.length; i++){
	  showProgress(i/templist.length);
      tempfilesdelete_success=File.delete(tempfolder + File.separator + templist[i]);	
	}	
	
	thermalviddelete_success=File.delete(tempfolder + "thermalvid.raw");
	tempfolderdelete_success=File.delete(tempfolder);
	
	if(tempfilesdelete_success + tempfolderdelete_success ==2){
		print("Temporary files and folder deleted");
	}
}

// Checks if filesize is 0 bytes.  Returns 1 if this is true, returns 0 if this is false.
// filenamewithpath should be supplied with full path for given operating system, preferrably without spaces
// Function to be used to assess if a converted file is present in the folder but has no content, so it can then be
// deleted.
function CheckFileSizeZero(filenamewithpath){
	
	//filename="~/Desktop/temp/frame000002.jpegls";

	command="if [ -s " + filenamewithpath + " ]; then echo 0; else echo 1; fi";
	commandwin="for %I in (" + filenamewithpath + ") do @if %~zI GTR 0 (echo 0) else (echo 1)";
	
	if(OS=="Mac OS X"){
		//print("Checking if filesize is zero, returns 1 if size=0");
		//print("Using the following bash command: ");
		//print(command);
		res=exec("/bin/sh", "-c", command);
	}

	if(OS=="Linux"){
		//print("Checking if filesize is zero, returns 1 if size=0");
		//print("Using the following bash command: ");
		//print(command);
		res=exec("/bin/sh", "-c", command);
	}

	if(substring(OS, 0, 5)=="Windo"){
		//print("Checking if filesize is zero, returns 1 if size=0");
		//print("Using the following command: ");
		//print(command);
		res=exec("cmd", "/c", commandwin);
	}

return parseInt(res);

}


// function to import an rtv file using imageJ raw import option
function RawImportMikronRTV() {

	print("\n------ Running RawImportRTV function ------");
	
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
	//var converttotemperature = 0; // now is a persistent variable 
	var usevirtual = 0;
	var minpix=1;
	var maxpix=65535;
	
	// Create Dialog Box	
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
	
	call("ij.Prefs.set", "usevirtual.persistent",toString(usevirtual)); 
	call("ij.Prefs.set", "converttotemperature.persistent",toString(converttotemperature)); 
	
	
	filepath=File.openDialog("Select a File"); 
	file=File.openAsString(filepath); 
	print("Loading: ", filepath);
	print("\n");

	run("Raw...", "open=[filepath] image=[16-bit Unsigned] width=imagewidth height=imageheight offset=offsetbyte number=nframes gap=gapbytes little-endian use=usevirtual");

	// Mikron RTV files are simply stored as Temperature in Kelvin * 10 and thus range from 10 to ~3000 (but still stored or imported as 16 bit integer)
	// conversion here will not be accurate, nor will it take into account atmospheric and reflected conditions.
	
	if(converttotemperature) {
		run("Calibrate...", "function=None");
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


// function to import an rtv/sit file using imageJ raw import option
function RawImportMikronSIT() {

	print("\n------ Running RawImportMikronSIT function ------");
	
	var offsetbyte = 1024;
	var gapbytes = 42;
	// gapbytes is 3020 for direct SEQ recorded files
	// gapbytes is 1424 for thermacam researcher pro captured seq files
	var nframes = 1;
	var imagewidth = 320;
	var imageheight = 240;
	//var converttotemperature = 0; // now is a persistent variable
	//var usevirtual = 0;
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
	
	call("ij.Prefs.set", "usevirtual.persistent",toString(usevirtual)); 
	call("ij.Prefs.set", "converttotemperature.persistent",toString(converttotemperature)); 

	filepath=File.openDialog("Select a File"); 
	file=File.openAsString(filepath); 
	print("Loading: ", filepath);
	print("\n");

	run("Raw...", "open=[filepath] image=[16-bit Unsigned] width=imagewidth height=imageheight offset=offsetbyte number=nframes gap=gapbytes little-endian use=usevirtual");

	// Mikron SIT files are simply stored as Temperature in Kelvin * 10 and thus range from 10 to ~3000 (but still stored or imported as 16 bit integer)
	// conversion here will not be accurate, nor will it take into account atmospheric and reflected conditions.
	
	if(converttotemperature) {
		//run("Calibrate...", "function=None");
		run("32-bit");
		run("Macro...", "code=v=v/100-273.15"); // Have not worked out the formula to convert SIT files.
		}
	
	run(defaultpalette);
	
	getStatistics(count, mean, min, max, std);
		var minpix=min;
		var maxpix=max;
		setMinAndMax(minpix, maxpix);
	
	print("Done");
	print("\n");
	
}


function RawImportFLIRSEQ() {
	
	print("\n------ Running RawImportFLIRSEQ function ------");
	
	//var offsetbyte = 1372; 
	// offsetbyte is 1540528 for SEQ files recorded to a FLIR SC660
	// offsetbyte is 1372 for SEQ files recorded to computer (works for at least two diff cameras)
	// offsetbyte is 1542956 or 1540480 for SEQ files recorded to a FLIR SC640
	//var gapbytes = 1424;
	// gapbytes is 3020 for direct SEQ recorded files
	// gapbytes is 1424 for thermacam researcher pro captured seq files
	//var nframes = 10000;
	//var imagewidth = 640;
	//var imageheight = 480;
	//var converttotemperature = 1; // now is a persistent variable
	//var usevirtual = 0;
	var minpix=1;
	var maxpix=65535;
	
	//Create Dialog Box	
	Dialog.create("RAW import of FLIR SEQ File"); 
	Dialog.addMessage("This macro directly imports the RAW pixel data from a SEQ file\n assuming the user knows the offset and frame gap byte information.");
	Dialog.addMessage("The user must input the starting offset bytes and frame gaps.");
	Dialog.addMessage("You may first try to use the Frame Byte Start macro estimate what these values are\nalthough there is no guarantee this will work for all SEQ files.");
	Dialog.addMessage("Please Use the Import FLIR SEQ Macro if you do not have accurate information on the start and frame gap bytes.");
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
	
	call("ij.Prefs.set", "imagewidth.persistent",toString(imagewidth)); 
	call("ij.Prefs.set", "imageheight.persistent",toString(imageheight)); 
	call("ij.Prefs.set", "usevirtual.persistent",toString(usevirtual)); 
	call("ij.Prefs.set", "offsetbyte.persistent",toString(offsetbyte)); 
	call("ij.Prefs.set", "gapbytes.persistent",toString(gapbytes)); 
	call("ij.Prefs.set", "nframes.persistent",toString(nframes)); 
	call("ij.Prefs.set", "converttotemperature.persistent",toString(converttotemperature)); 
	
	filepath=File.openDialog("Select a File"); 
	
	//file=File.openAsString(filepath); 
	
	print("Loading: ", filepath);
	print("\n");
	
	if(usevirtual==1){
		var rawimportoptions = "open=[" + filepath + "] image=[16-bit Unsigned] width=" + imagewidth + " height=" + imageheight + " offset=" + offsetbyte + " number=" + nframes + " gap=" + gapbytes + " little-endian use";	
	}
	if(usevirtual==0){
		var rawimportoptions = "open=[" + filepath + "] image=[16-bit Unsigned] width=" + imagewidth + " height=" + imageheight + " offset=" + offsetbyte + " number=" + nframes + " gap=" + gapbytes + " little-endian";	
	}
	
	//print(rawimportoptions);
	
	run("Raw...", rawimportoptions);
	
	if(File.exists(filepath)){
		flirvals=flirvalues(filepath, "No");
	}
	
	if(OS=="Mac OS X"){		
		flirvals=exec(exiftoolpathOSX + exiftoolOSX,  "-Planck*", "-*AtmosphericTrans*", "-*Emissivity", "-*Distance", "-*Temperature", "-*Transmission",  "-*Humidity", "-*Height", "-*Width", "-*Original", "-*Date",  filepath);
	}

	if(OS=="Linux"){
		flirvals=exec(exiftoolpathLinux + exiftoolLinux,  "-Planck*", "-*AtmosphericTrans*", "-*Emissivity", "-*Distance", "-*Temperature", "-*Transmission",  "-*Humidity", "-*Height", "-*Width", "-*Original", "-*Date",  filepath);
	}
	
	if(substring(OS, 0, 5)=="Windo"){
		flirvals=exec("cmd", "/c", exiftoolpathWindows + exiftoolWindows, "-Planck*", "-*AtmosphericTrans*", "-*Emissivity", "-*Distance", "-*Temperature", "-*Transmission",  "-*Humidity", "-*Height", "-*Width", "-*Original", "-*Date",  filepath);
	}
	
        PR1 = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Planck R1"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Planck R1")) ));
		PB = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Planck B"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Planck B")) ));
		PF = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Planck F"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Planck F")) ));
		PO = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Planck O"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Planck O")) ));
		PR2 = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Planck R2"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Planck R2")) ));
		ATA1 = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Atmospheric Trans Alpha 1"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Atmospheric Trans Alpha 1")) ));
		ATA2 = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Atmospheric Trans Alpha 2"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Atmospheric Trans Alpha 2")) ));
		ATB1 = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Atmospheric Trans Beta 1"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Atmospheric Trans Beta 1")) ));
		ATB2 = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Atmospheric Trans Beta 2"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Atmospheric Trans Beta 2")) ));
		ATX = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Atmospheric Trans X"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Atmospheric Trans X")) ));
		E = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Emissivity"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Emissivity")) ));
		OD = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Object Distance"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Object Distance")) ));
		RTemp = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Reflected Apparent Temperature"))+1, indexOf(flirvals, "C\n", indexOf(flirvals, "Reflected Apparent Temperature")) ));
		ATemp = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Atmospheric Temperature"))+1, indexOf(flirvals, "C\n", indexOf(flirvals, "Atmospheric Temperature")) ));
		IRWTemp = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "IR Window Temperature"))+1, indexOf(flirvals, "C\n", indexOf(flirvals, "IR Window Temperature")) ));
		IRT = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "IR Window Transmission"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "IR Window Transmission")) ));
		RH = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Relative Humidity"))+1, indexOf(flirvals, "%\n", indexOf(flirvals, "Relative Humidity")) ));
		imagewidth = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Width"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Width")) ));
		imageheight = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Height"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Height")) ));
		
		print("Camera Calibration Constants:");
		//print(flirvals);
		setFont("SansSerif", 12);
		print("Planck R1: ", d2s(PR1,9));
		print("Planck B: ", d2s(PB,9));
		print("Planck F: ", d2s(PF,0));
		print("Planck O: ", d2s(PO,0));
		print("Planck R2: ", d2s(PR2,9));
		print("Atmospheric Trans Alpha 1: ", d2s(ATA1,12));
		print("Atmospheric Trans Alpha 2: ", d2s(ATA2,12));
		print("Atmospheric Trans Beta 1: ", d2s(ATB1,12));
		print("Atmospheric Trans Beta 2: ", d2s(ATB2,12));
		print("Atmospheric Trans X: ", d2s(ATX,12));				
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
	
		//Stack.getStatistics(count, mean, min, max, std);
		//	var minpix=min;
		//	var maxpix=max;
		//	setMinAndMax(minpix, maxpix);
	
		if(converttotemperature==1){
			print("Converting file to temperature");
			ObjectParameters=Raw2Temp(PR1, PR2, PB, PF, PO, AtmosphericTransVals(ATA1, ATA2, ATB1, ATB2, ATX), E, OD, RTemp, ATemp, IRWTemp, IRT, RH, defaultpalette, "Yes", "Fast", imagetemperaturemin, imagetemperaturemax);	
			// after running raw2temp, the function will return the object parameter and flir values that were used
    	
    		// Commit objective parameters to memory
    	//	ObjectCameraParameterPersist(ObjectParameters);
    	
		}
		
    	
		print("Done");
		print("\n");

}


function ObjectCameraParameterPersist(ObjectParameters){
		//Array.print(ObjectParameters);
    	print("Committing object parameters and camera calibration constants to persistent memory");
	
		PR1=ObjectParameters[0];
    	PR2=ObjectParameters[1];
    	PB=ObjectParameters[2];
    	PF=ObjectParameters[3];
    	PO=ObjectParameters[4];
    	ATA1=ObjectParameters[5];
    	ATA2=ObjectParameters[6];
    	ATB1=ObjectParameters[7];
    	ATB2=ObjectParameters[8];
    	ATX=ObjectParameters[9];
    	E=ObjectParameters[10];
    	OD=ObjectParameters[11];
    	RTemp=ObjectParameters[12];
    	ATemp=ObjectParameters[13];
    	IRWTemp=ObjectParameters[14];
    	IRT=ObjectParameters[15];
    	RH=ObjectParameters[16];
    	
    	setFont("SansSerif", 12);
		print("Planck R1: ", d2s(PR1,9));
		print("Planck R2: ", d2s(PR2,9));
		print("Planck B: ", d2s(PB,9));
		print("Planck F: ", d2s(PF,0));
		print("Planck O: ", d2s(PO,0));	
		print("Atmospheric Trans Alpha 1: ", d2s(ATA1,12));
		print("Atmospheric Trans Alpha 2: ", d2s(ATA2,12));
		print("Atmospheric Trans Beta 1: ", d2s(ATB1,12));
		print("Atmospheric Trans Beta 2: ", d2s(ATB2,12));
		print("Atmospheric Trans X: ", d2s(ATX,12));				
		
		print("\n");
		print("Object Parameters:");
		print("Emissivity: ", d2s(E,2));
		print("Object Distance: ", d2s(OD,2));
		print("Reflected Apparent Temperature: ", d2s(RTemp,2));
		print("Atmospheric Temperature: ", d2s(ATemp,2));
		print("IR Window Temperature: ", d2s(IRWTemp,2));
		print("IR Window Transmission: ", d2s(IRT,3));
		print("Relative Humidity: ", d2s(RH,2));
		print("Thermal Image Width: ", imagewidth);
		print("Thermal Image Height: ", imageheight);
		print("\n");
    
        call("ij.Prefs.set", "imagetemperaturemin.persistent",toString(imagetemperaturemin)); 
		call("ij.Prefs.set", "imagetemperaturemax.persistent",toString(imagetemperaturemax)); 
		call("ij.Prefs.set", "imagewidth.persistent",toString(imagewidth)); 
		call("ij.Prefs.set", "imageheight.persistent",toString(imageheight)); 
		call("ij.Prefs.set", "PR1.persistent",toString(PR1)); 
		call("ij.Prefs.set", "PB.persistent",toString(PB)); 
		call("ij.Prefs.set", "PF.persistent",toString(PF)); 
		call("ij.Prefs.set", "PR2.persistent",toString(PR2)); 
		call("ij.Prefs.set", "PO.persistent",toString(PO));
		call("ij.Prefs.set", "ATA1.persistent",toString(ATA1));
		call("ij.Prefs.set", "ATA2.persistent",toString(ATA2));
		call("ij.Prefs.set", "ATB1.persistent",toString(ATB1));
		call("ij.Prefs.set", "ATB2.persistent",toString(ATB2));
		call("ij.Prefs.set", "ATX.persistent",toString(ATX));
		call("ij.Prefs.set", "E.persistent",toString(E)); 
		call("ij.Prefs.set", "OD.persistent",toString(OD)); 
		call("ij.Prefs.set", "RTemp.persistent",toString(RTemp)); 
		call("ij.Prefs.set", "ATemp.persistent",toString(ATemp)); 
		call("ij.Prefs.set", "IRWTemp.persistent",toString(IRWTemp)); 
		call("ij.Prefs.set", "IRT.persistent",toString(IRT)); 
		call("ij.Prefs.set", "RH.persistent",toString(RH)); 
}
    	
function ATSObjectCameraParameterPersist(ObjectParameters){
		Array.print(ObjectParameters);
    	print("Committing object parameters and camera calibration constants to persistent memory");

	// ATS/MWIR equivalent of ObjectCameraParameterPersist().
    // Saves all Nfc* camera constants and object parameters persistently.
    // Unlike the LWIR version, this does NOT parse a positional array --
    // it saves each named global directly, avoiding any ordering assumptions.
    call("ij.Prefs.set", "NfcB.persistent",        toString(NfcB));
    call("ij.Prefs.set", "NfcR.persistent",        toString(NfcR));
    call("ij.Prefs.set", "NfcF.persistent",        toString(NfcF));
    call("ij.Prefs.set", "NfcC0.persistent",       toString(NfcC0));
    call("ij.Prefs.set", "NfcC1.persistent",       toString(NfcC1));
    call("ij.Prefs.set", "NfcC2.persistent",       toString(NfcC2));
    call("ij.Prefs.set", "NfcMinTemp.persistent",  toString(NfcMinTemp));
    call("ij.Prefs.set", "NfcMaxTemp.persistent",  toString(NfcMaxTemp));
    call("ij.Prefs.set", "NfcMinCounts.persistent",toString(NfcMinCounts));
    call("ij.Prefs.set", "NfcMaxCounts.persistent",toString(NfcMaxCounts));
    call("ij.Prefs.set", "NfcATA1.persistent",     toString(NfcATA1));
    call("ij.Prefs.set", "NfcATA2.persistent",     toString(NfcATA2));
    call("ij.Prefs.set", "NfcATB1.persistent",     toString(NfcATB1));
    call("ij.Prefs.set", "NfcATB2.persistent",     toString(NfcATB2));
    call("ij.Prefs.set", "NfcATX.persistent",      toString(NfcATX));
    call("ij.Prefs.set", "NfcE.persistent",        toString(NfcE));
    call("ij.Prefs.set", "NfcOD.persistent",       toString(NfcOD));
    call("ij.Prefs.set", "NfcRTemp.persistent",    toString(NfcRTemp));
    call("ij.Prefs.set", "NfcATemp.persistent",    toString(NfcATemp));
    call("ij.Prefs.set", "NfcIRWTemp.persistent",  toString(NfcIRWTemp));
    call("ij.Prefs.set", "NfcIRT.persistent",      toString(NfcIRT));
    call("ij.Prefs.set", "NfcRH.persistent",       toString(NfcRH));
    call("ij.Prefs.set", "atsimagewidth.persistent", toString(atsimagewidth));
    call("ij.Prefs.set", "atsimageheight.persistent",toString(atsimageheight));
   
    	
   	setFont("SansSerif", 12);
	print("Nfc B: ", d2s(NfcB,9));
	print("Nfc R: ", d2s(NfcR,9));
	print("Nfc F: ", d2s(NfcF,9));
	print("Nfc Co: ", NfcC0);
	print("Nfc C1: ", NfcC1);	
	print("Nfc C2: ", NfcC2);	
	print("Nfc Atmospheric Trans Alpha 1: ", d2s(NfcATA1,12));
	print("Nfc Atmospheric Trans Alpha 2: ", d2s(NfcATA2,12));
	print("Nfc Atmospheric Trans Beta 1: ", d2s(NfcATB1,12));
	print("Nfc Atmospheric Trans Beta 2: ", d2s(NfcATB2,12));
	print("Nfc Atmospheric Trans X: ", d2s(NfcATX,12));	
	print("Nfc MinCounts: ", d2s(NfcMinCounts,0));
	print("Nfc MaxCounts: ", d2s(NfcMaxCounts,0));				
		
	print("\n");
	print("Object Parameters:");
	print("Emissivity: ", d2s(NfcE,2));
	print("Object Distance: ", d2s(NfcOD,2));
	print("Reflected Apparent Temperature: ", d2s(NfcRTemp,2));
	print("Atmospheric Temperature: ", d2s(NfcATemp,2));
	print("IR Window Temperature: ", d2s(NfcIRWTemp,2));
	print("IR Window Transmission: ", d2s(NfcIRT,3));
	print("Relative Humidity: ", d2s(NfcRH,2));
	print("Thermal Image Width: ", atsimagewidth);
	print("Thermal Image Height: ", atsimageheight);
	print("\n");
  
}
    	
	
		
		

function ConvertImportFLIRJPG(ConvertWithDefault) {
	
	print("\n------ Running ConvertImportFLIRJPG function ------");
	
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

	//filepath=replace(filepath, " ", "\ ");

	// populate an array called flirvals with 14 entries to accept the array output from the flirvalues function
	flirvals=newArray(19);

	var printvalues="No";
	
	flirvals=flirvalues(filepath, printvalues);
	
	// define the constants extracted from the flir values function
	PR1=flirvals[0];
	PB=flirvals[1];
	PF=flirvals[2];
	PO=flirvals[3];
	PR2=flirvals[4];
	ATA1=flirvals[5];
	ATA2=flirvals[6];
	ATB1=flirvals[7];
	ATB2=flirvals[8];
	ATX=flirvals[9];
	E=flirvals[10];
	OD=flirvals[11];
	RTemp=flirvals[12];
	ATemp=flirvals[13];
	IRWTemp=flirvals[14];
	IRT=flirvals[15];
	RH=flirvals[16];
	imagewidth=flirvals[17];
	imageheight=flirvals[18];
	
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

	var RawThermalType=""; // set RawThermalType as blank to start

	if(OS=="Mac OS X"){		
		flirimageraw = exec(exiftoolpath + exiftoolOSX, "-RawThermalImageType", filepath);
		}

	if(OS=="Linux"){
		flirimageraw = exec(exiftoolpath + exiftoolLinux, "-RawThermalImageType", filepath);
		}
	
	if(substring(OS, 0, 5)=="Windo"){
		flirimageraw = exec("cmd", "/c", exiftoolpath + exiftoolWindows, "-RawThermalImageType", filepath);
		}
	
	//flirimageraw = exec(exiftoolpath + exiftool, "-RawThermalImageType", filepath);
	
	RawThermalType = substring(flirimageraw, indexOf(flirimageraw, ":")+1 );
	
	// determine the data storage format of the flir jpg.  Either tiff or png	
	RawThermalType=replace(RawThermalType, "\n", "");
	RawThermalType=replace(RawThermalType, " ", "");

	if(RawThermalType=="  " || RawThermalType==" " || RawThermalType==""){
		print("-- Warning -- Raw Thermal Type Unknown. This file might not be a radiometric JPG.");
		print("Setting Raw Thermal Type to png and attempting conversion. If resulting file is 0 bytes, the jpg cannot be converted.");
		print("Examine the settings on your camera to ensure radiometric jpgs are being saved.");		
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
		var defaultbyteorder="Default";		
	}
	
	if(RawThermalType=="PNG"){
		var defaultbyteorder="Swap";
	}
	
	// Create a prompt dialog to ask user to verify the values to be used in the calculations below
	byteorder=newArray("Default", "Swap");
	fastslowchoice=newArray("Fast", "Slow");
	fastslowchoicedefault="Slow";
	
	if(ConvertWithDefault=="yes"){
		var palettetype = defaultpalette;
		var FastSlow="Slow";
	}
		
	if(ConvertWithDefault=="no"){
	
	// Create a prompt dialog to ask user to verify the values to be used in the calculations below
	
	Dialog.create("Verify Camera and Object Parameters");
	Dialog.addMessage("If Calibration constants are unknown, run the FLIR Calibration Values Tool first!");
	Dialog.addMessage("TIFF file pixel byte are usually little endian, PNG file pixel bytes are usually big endian");
	Dialog.addChoice("Keep Default or Swap Byte Order?", byteorder, defaultbyteorder);
	Dialog.addMessage("Fast calculation is approximate but repeatable. Slow is accurate but not reversible");
	Dialog.addChoice("Fast or\nSlow Calculation?", fastslowchoice, fastslowchoicedefault); 
	Dialog.addNumber("Estimated Image Temperature  Minimum:", imagetemperaturemin, 0, 5, "C");
 	Dialog.addNumber("Estimated Image Temperature  Maximum:", imagetemperaturemax, 0, 5, "C");
 	 
    Dialog.addMessage("Object Parameters:");
    Dialog.addNumber("Object Emissivity:", E, 3, 6, "unitless");
    Dialog.addToSameRow();
    Dialog.addNumber("Object Distance:", OD, 1, 6, "m");
    Dialog.addNumber("Reflected Temperature (C):", RTemp, 2, 6, "C");
    Dialog.addToSameRow();
    Dialog.addNumber("Atmospheric Temperature (C):", ATemp, 2, 6, "C");
    Dialog.addNumber("Window Temperature (C):", IRWTemp, 2, 6, "C");
    Dialog.addToSameRow();
    Dialog.addNumber("Window Transmittance:", IRT, 3, 6, "unitless");
    Dialog.addNumber("Relative Humidity:", RH, 2, 6, "%");
    Dialog.addChoice("Palette", palettetypes, defaultpalette);
    
	Dialog.addMessage("Camera Calibration Constants:");
	Dialog.addNumber("Planck R1:", PR1, 8, 15, "unitless"); //21106.77 //21546.203
	Dialog.addToSameRow();
	Dialog.addNumber("Planck R2:", PR2, 8, 15, "unitless"); //0.012545258 //0.016229488 
	Dialog.addNumber("Planck B:", PB, 8, 15, "unitless"); //1501 //1507.2
	Dialog.addToSameRow();
	Dialog.addNumber("Planck F:", PF, 8, 15, "unitless");//1
    Dialog.addNumber("Planck O:", PO, 8, 15, "unitless"); //-7340 //-6331
    Dialog.addNumber("Atmospheric Trans Alpha 1:", ATA1, 8, 12, "unitless");
    Dialog.addToSameRow();
    Dialog.addNumber("Atmospheric Trans Alpha 2:", ATA2, 8, 12, "unitless");
    Dialog.addNumber("Atmospheric Trans Beta 1:", ATB1, 8, 12, "unitless");
    Dialog.addToSameRow();
    Dialog.addNumber("Atmospheric Trans Beta 2:", ATB2, 8, 12, "unitless");
    Dialog.addNumber("Atmospheric Trans X:", ATX, 8, 12, "unitless");
  
	Dialog.show();

	ByteOrder=Dialog.getChoice();
	FastSlow=Dialog.getChoice();
	imagetemperaturemin = Dialog.getNumber();
	imagetemperaturemax = Dialog.getNumber();
	E = Dialog.getNumber();
	OD = Dialog.getNumber();
	RTemp = Dialog.getNumber();
	ATemp = Dialog.getNumber();
	IRWTemp = Dialog.getNumber();
	IRT = Dialog.getNumber();
	RH = Dialog.getNumber();
	palettetype = Dialog.getChoice();

	PR1 = Dialog.getNumber();
	PR2 = Dialog.getNumber();
	PB = Dialog.getNumber();
	PF = Dialog.getNumber();
	PO = Dialog.getNumber();
	ATA1 =  Dialog.getNumber();
	ATA2 =  Dialog.getNumber();
	ATB1 =  Dialog.getNumber();
	ATB2 =  Dialog.getNumber();
	ATX =  Dialog.getNumber();
	
	if(ByteOrder == "Swap"){
		run("Byte Swapper");
	}
	
	}
	
	if(RawThermalType == "PNG" && ConvertWithDefault == "yes"){
		run("Byte Swapper");
	}
	
	call("ij.Prefs.set", "imagetemperaturemin.persistent",toString(imagetemperaturemin)); 
	call("ij.Prefs.set", "imagetemperaturemax.persistent",toString(imagetemperaturemax)); 
	
	if(fileoutpathexist==1){
		filedelete_success=File.delete(fileoutpath);
		folderdelete_success=File.delete(filedir + File.separator + "temp" + File.separator );
	}
	

	if(filedelete_success + folderdelete_success==2){
		print("Temporary file and folder deleted.");
	}	
	
		Raw2Temp(PR1, PR2, PB, PF, PO, AtmosphericTransVals(ATA1, ATA2, ATB1, ATB2, ATX), E, OD, RTemp, ATemp, IRWTemp, IRT, RH, palettetype, "No", FastSlow, imagetemperaturemin, imagetemperaturemax);

	print("Done");
	print("\n");
}



// ============================================================
// ConvertImportFLIRATSJPG(ConvertWithDefault)
//
// ConvertWithDefault = "yes" : skip dialog, use persistent/stored values
// ConvertWithDefault = "no"  : show full dialog for user to verify values
// ============================================================

function ConvertImportFLIRATSJPG(ConvertWithDefault) {

	print("\n------ Running ConvertImportFLIRATSJPG function ------");

	// ---- OS-specific paths ----
	if(OS == "Mac OS X"){
		var perlpath = perlpathOSX;
	}
	if(OS == "Linux"){
		var perlpath = perlpathLinux;
	}
	if(substring(OS, 0, 5) == "Windo"){
		var perlpath = perlpathWindows;
	}

	perl = perlpath + "perl";

	// ---- Select file ----
	filepath = File.openDialog("Select a FLIR ATS-JPG / MWIR Radiometric JPG File");
	filedir  = File.getParent(filepath);
	filename = File.getName(filepath);

	// ---- Sanity check ----
	result     = IsFLIRfile(filepath);
	pipepos    = indexOf(result, "|");
	cameratype = substring(result, pipepos+1);
	if(cameratype != "MWIR"){
		print("WARNING: selected file does not appear to be an ATS/MWIR file.");
		print("IsFLIRfile() returned: " + result);
		print("Proceeding anyway -- check results carefully.");
	}

	print("Loading: " + filepath);
	print("Extracting ATS calibration and image settings via fliratsvalues()");

	// ---- Extract calibration constants ----
	var printvalues = "No";
	atsvals = fliratsvalues(filepath, printvalues);

	NfcB          = atsvals[0];
	NfcR          = atsvals[1];
	NfcF          = atsvals[2];
	NfcC0         = atsvals[3];
	NfcC1         = atsvals[4];
	NfcC2         = atsvals[5];
	NfcMinTemp    = atsvals[6];
	NfcMaxTemp    = atsvals[7];
	NfcMinCounts  = atsvals[8];
	NfcMaxCounts  = atsvals[9];
	NfcATA1       = atsvals[10];
	NfcATA2       = atsvals[11];
	NfcATB1       = atsvals[12];
	NfcATB2       = atsvals[13];
	NfcATX        = atsvals[14];
	NfcE          = atsvals[15];
	NfcOD         = atsvals[16];
	NfcRTemp      = atsvals[17];
	NfcATemp      = atsvals[18];
	NfcIRWTemp    = atsvals[19];
	NfcIRT        = atsvals[20];
	NfcRH         = atsvals[21];
	atsimagewidth  = atsvals[22];
	atsimageheight = atsvals[23];

	// ---- Run ats-repair.pl to extract raw pixels ----
	// Default output: replaces .jpg extension with .raw in the same folder.
	// No temp folder needed -- the .raw lives alongside the .jpg permanently.
	// Width and height are parsed from stdout ("Image dimensions: W x H").
	// exec() with separate arguments is reliable on Mac (no shell redirect needed
	// since we don't need to redirect output -- stdout is captured directly).
	print("Extracting raw pixel data with ats-repair.pl");
	print("Command: " + perl + " " + perlrepairats + " -i " + filepath);

	repairoutput = exec(perl, perlrepairats, "-i", filepath);
	print(repairoutput);

	// ---- Parse width and height from ats-repair.pl stdout ----
	// "Image dimensions    : W x H"
	// (use fliratsvalues() values as fallback if parsing fails)
	rawwidth  = atsimagewidth;
	rawheight = atsimageheight;
	if(indexOf(repairoutput, "Image dimensions") >= 0){
		dimpos   = indexOf(repairoutput, "Image dimensions");
		colonpos = indexOf(repairoutput, ":", dimpos);
		endpos   = indexOf(repairoutput, "\n", dimpos);
		dimstr   = trim(substring(repairoutput, colonpos+1, endpos));
		// dimstr is now "W x H"
		xpos      = indexOf(dimstr, "x");
		rawwidth  = parseInt(trim(substring(dimstr, 0, xpos)));
		rawheight = parseInt(trim(substring(dimstr, xpos+1)));
		print("Parsed image dimensions from ats-repair.pl: " + rawwidth + " x " + rawheight);
	} else {
		print("WARNING: could not parse dimensions from ats-repair.pl output.");
		print("Using dimensions from fliratsvalues(): " + rawwidth + " x " + rawheight);
	}

	// ---- Derive .raw output path (ats-repair.pl default: same dir, .raw extension) ----
	rawpath = filedir + File.separator + File.nameWithoutExtension + ".raw";

	if(File.exists(rawpath) == 0){
		exit("ERROR: ats-repair.pl did not produce a .raw file at: " + rawpath
			+ "\nCheck the command printed above and verify:\n"
			+ "  1. ats-repair.pl is in your Fiji/scripts folder\n"
			+ "  2. perl is accessible at: " + perl);
	}

	// ---- Import the .raw file ----
	// 16-bit unsigned, little-endian, no header, single frame (number=1)
	print("\nImporting raw pixel data");
	importarguments = "open=[" + rawpath + "] image=[16-bit Unsigned] width=" + rawwidth + " height=" + rawheight + " number=1 little-endian";
	print("Import arguments: " + importarguments);
	run("Raw...", importarguments);

	// ---- Dialog or defaults ----
	fastslowchoice        = newArray("Fast", "Slow");
	fastslowchoicedefault = "Slow";  // default to Slow for single frame

	if(ConvertWithDefault == "yes"){
		var FastSlow   = "Slow";
		var palettetype = defaultpalette;
	}

	if(ConvertWithDefault == "no"){
		fastslowchoicedefault="Fast";
		fastslowchoice=newArray("Fast", "Slow");
		
		Dialog.create("Verify ATS Camera and Object Parameters");
		Dialog.addMessage("If Calibration constants are unknown, run the FLIR Calibration Values Tool first!");
		Dialog.addMessage("Fast calculation is approximate but repeatable. Slow is accurate but not reversible.");
		Dialog.addChoice("Fast or Slow Calculation?", fastslowchoice, fastslowchoicedefault);
		Dialog.addNumber("Estimated Image Temperature Minimum:", imagetemperaturemin, 0, 5, "C");
		Dialog.addNumber("Estimated Image Temperature Maximum:", imagetemperaturemax, 0, 5, "C");

		Dialog.addMessage("Object Parameters:");
		Dialog.addNumber("Object Emissivity:", NfcE, 3, 6, "unitless");
		Dialog.addToSameRow();
		Dialog.addNumber("Object Distance:", NfcOD, 1, 6, "m");
		Dialog.addNumber("Reflected Temperature (C):", NfcRTemp, 2, 6, "C");
		Dialog.addToSameRow();
		Dialog.addNumber("Atmospheric Temperature (C):", NfcATemp, 2, 6, "C");
		Dialog.addNumber("Window Temperature (C):", NfcIRWTemp, 2, 6, "C");
		Dialog.addToSameRow();
		Dialog.addNumber("Window Transmittance:", NfcIRT, 3, 6, "unitless");
		Dialog.addNumber("Relative Humidity:", NfcRH, 2, 6, "%");
		Dialog.addToSameRow();
		Dialog.addChoice("Palette", palettetypes, defaultpalette);

		Dialog.addMessage("Camera Calibration Constants (NicevilleFactoryCal):");
		Dialog.addNumber("Nfc B:", NfcB, 4, 12, "unitless");
		Dialog.addToSameRow();
		Dialog.addNumber("Nfc R:", NfcR, 6, 12, "unitless");
		Dialog.addNumber("Nfc F:", NfcF, 4, 6, "unitless");
		Dialog.addNumber("Nfc C0:", NfcC0, 20, 20, "unitless");
		Dialog.addToSameRow();
		Dialog.addNumber("Nfc C1:", NfcC1, 20, 20, "unitless");
		Dialog.addNumber("Nfc C2:", NfcC2, 20, 20, "unitless");
		Dialog.addNumber("Atmospheric Trans Alpha 1:", NfcATA1, 8, 12, "unitless");
		Dialog.addToSameRow();
		Dialog.addNumber("Atmospheric Trans Alpha 2:", NfcATA2, 8, 12, "unitless");
		Dialog.addNumber("Atmospheric Trans Beta 1:", NfcATB1, 8, 12, "unitless");
		Dialog.addToSameRow();
		Dialog.addNumber("Atmospheric Trans Beta 2:", NfcATB2, 8, 12, "unitless");
		Dialog.addNumber("Atmospheric Trans X:", NfcATX, 8, 12, "unitless");
		Dialog.addMessage("Counts range (used to construct fast-mode polynomial within scene temp range):");
		Dialog.addNumber("Nfc Min Counts:", NfcMinCounts, 0, 8, "16-bit integer");
		Dialog.addToSameRow();
		Dialog.addNumber("Nfc Max Counts:", NfcMaxCounts, 0, 8, "16-bit integer");

		Dialog.show();

		FastSlow          = Dialog.getChoice();
		imagetemperaturemin = Dialog.getNumber();
		imagetemperaturemax = Dialog.getNumber();
		NfcE              = Dialog.getNumber();
		NfcOD             = Dialog.getNumber();
		NfcRTemp          = Dialog.getNumber();
		NfcATemp          = Dialog.getNumber();
		NfcIRWTemp        = Dialog.getNumber();
		NfcIRT            = Dialog.getNumber();
		NfcRH             = Dialog.getNumber();
		palettetype       = Dialog.getChoice();
		NfcB              = Dialog.getNumber();
		NfcR              = Dialog.getNumber();
		NfcF              = Dialog.getNumber();
		NfcC0             = Dialog.getNumber();
		NfcC1             = Dialog.getNumber();
		NfcC2             = Dialog.getNumber();
		NfcATA1           = Dialog.getNumber();
		NfcATA2           = Dialog.getNumber();
		NfcATB1           = Dialog.getNumber();
		NfcATB2           = Dialog.getNumber();
		NfcATX            = Dialog.getNumber();
		NfcMinCounts      = Dialog.getNumber();
		NfcMaxCounts      = Dialog.getNumber();
	}

	// ---- Persist values ----
	call("ij.Prefs.set", "imagetemperaturemin.persistent", toString(imagetemperaturemin));
	call("ij.Prefs.set", "imagetemperaturemax.persistent", toString(imagetemperaturemax));
	call("ij.Prefs.set", "NfcB.persistent",   toString(NfcB));
	call("ij.Prefs.set", "NfcR.persistent",   toString(NfcR));
	call("ij.Prefs.set", "NfcF.persistent",   toString(NfcF));
	call("ij.Prefs.set", "NfcC0.persistent",  toString(NfcC0));
	call("ij.Prefs.set", "NfcC1.persistent",  toString(NfcC1));
	call("ij.Prefs.set", "NfcC2.persistent",  toString(NfcC2));
	call("ij.Prefs.set", "NfcATA1.persistent",toString(NfcATA1));
	call("ij.Prefs.set", "NfcATA2.persistent",toString(NfcATA2));
	call("ij.Prefs.set", "NfcATB1.persistent",toString(NfcATB1));
	call("ij.Prefs.set", "NfcATB2.persistent",toString(NfcATB2));
	call("ij.Prefs.set", "NfcATX.persistent", toString(NfcATX));
	call("ij.Prefs.set", "NfcE.persistent",   toString(NfcE));
	call("ij.Prefs.set", "NfcOD.persistent",  toString(NfcOD));
	call("ij.Prefs.set", "NfcRTemp.persistent",  toString(NfcRTemp));
	call("ij.Prefs.set", "NfcATemp.persistent",  toString(NfcATemp));
	call("ij.Prefs.set", "NfcIRWTemp.persistent",toString(NfcIRWTemp));
	call("ij.Prefs.set", "NfcIRT.persistent", toString(NfcIRT));
	call("ij.Prefs.set", "NfcRH.persistent",  toString(NfcRH));
	call("ij.Prefs.set", "NfcMinCounts.persistent", toString(NfcMinCounts));
	call("ij.Prefs.set", "NfcMaxCounts.persistent", toString(NfcMaxCounts));

	// ---- Convert to temperature ----
	Counts2Temp(
		NfcCvals(NfcC0, NfcC1, NfcC2),
		NfcPlanckVals(NfcB, NfcR, NfcF),
		AtmosphericTransVals(NfcATA1, NfcATA2, NfcATB1, NfcATB2, NfcATX),
		NfcE, NfcOD, NfcRTemp, NfcATemp, NfcIRWTemp, NfcIRT, NfcRH,
		NfcMinCounts, NfcMaxCounts,
		palettetype, "No", FastSlow,
		imagetemperaturemin, imagetemperaturemax
	);
	
	//ATSObjectCameraParameterPersist();
	print("Done");
	print("\n");
}



function ConvertFLIRJPGs() {
	
	print("\n------ Running ConvertFLIRJPGs function ------");
	
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
	
	convertfolder = dirpath + File.separator + "converted";
	File.makeDirectory(convertfolder);
	
	print(dirpath);
	
	for (i = 0; i < filelist.length; i++){
		
		showProgress(i/filelist.length);

		// because filelist is different for my folder option vs. the single file option, need to set
		// filepath formally here
		
		if(whichtype=="Folder"){
			filepath=dirpath + filelist[i];
		}

		if(whichtype=="File"){
			filepath=filelist[i];
		}

		if (endsWith(toLowerCase(filepath), ".jpg") || endsWith(toLowerCase(filepath), ".jpeg")) {
			
		filename=File.getName(filepath);
		dotIndex = lastIndexOf(filename, "." );
		filename = substring(filename, 0, dotIndex ); // substring based on dot location.  hopefully only 1 dot.
		
		//filename=substring(filename, 0, lengthOf(filename)-4);
	
		// run Exiftool to return the meta tags with the word "RawThermalImageType".  It should be either TIFF or PNG.	

		if(OS=="Mac OS X"){		
			flirimageraw = exec(exiftoolpath + exiftoolOSX, "-RawThermalImageType", filepath);
			}

		if(OS=="Linux"){
			flirimageraw = exec(exiftoolpath + exiftoolLinux, "-RawThermalImageType", filepath);
			}
	
		if(substring(OS, 0, 5)=="Windo"){
			flirimageraw = exec("cmd", "/c", exiftoolpath + exiftoolWindows, "-RawThermalImageType", filepath);
			}
			
		//flirimageraw = exec(exiftoolpath + exiftool, "-RawThermalImageType", filepath);
		
		RawThermalType = substring(flirimageraw, indexOf(flirimageraw, ":")+1 );
		
		// determine the data storage format of the flir jpg.  Either tiff or png	
		RawThermalType=replace(RawThermalType, "\n", "");
		RawThermalType=replace(RawThermalType, " ", "");

		if(RawThermalType=="  " || RawThermalType==" " || RawThermalType==""){
			print("-- Warning -- Raw Thermal Type Unknown. This file might not be a radiometric JPG.");
			print("Setting Raw Thermal Type to tiff and attempting conversion. If resulting file is 0 bytes, the jpg cannot be converted.");
			print("Examine the settings on your camera to ensure radiometric jpgs are being saved.");					
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

// generic function to call the import/convert function but for SEQ:

function ImportConvertFLIRSEQ(){
	
	//var converttotemperature = 1;
	//var usevirtual = 1;
	//var addtimestamp=0;
	
	Dialog.create("Select a FLIR SEQ File");
	Dialog.addMessage("-- Warning: Before selecting your file, please remove spaces in the file or folder name --");
	Dialog.addMessage("Define parameters for Video Import");
	Dialog.addMessage("If you choose output file type 'Video', a single .avi file\nwill be created and imported using Import-MOVIE (FFMPEG)");
	Dialog.addMessage("If you choose output file type 'PNG', a separate PNG file\nwill be created for each SEQ frame");
	Dialog.addMessage("If you choose output file type 'TIFF', a separate TIFF file\nwill be created for each SEQ frame");
	Dialog.addChoice("Output file type (avi, png, tiff)", newArray("avi", "png", "tiff"), "avi");
	Dialog.addChoice("Video image encoding (ignored if choosing image above)", newArray("jpegls", "png"), "jpegls");
	Dialog.addNumber("Number of frames to skip. Use 1 to import without skipping, 2 to skip every other frame,...", 1);
	Dialog.addMessage("The choices below should be remembered the next time you run this function.");
	Dialog.addCheckbox("Convert to Temperature on Import", converttotemperature);
	Dialog.addMessage("Unselect Convert to Temperature for faster loading.\nThe imported file will be a 16-bit grayscale.");
	Dialog.addCheckbox("Add video frame time stamp to slice labels (choice is remembered on relaunch).", addtimestamp);
	Dialog.addCheckbox("Use virtual stack for avi import (choice is remembered on relaunch).", usevirtual);
	Dialog.addMessage("Select virtualstack for faster loading, but cannot add time stamps to image stack.\n");
	Dialog.addCheckbox("Delete the temporary files generated during conversion.", deletetempfiles);
	Dialog.show();
	
	var outtypechoice=Dialog.getChoice();
	var encodetypechoice = Dialog.getChoice();
	var framestep = Dialog.getNumber();
	var converttotemperature = Dialog.getCheckbox();
	var addtimestamp = Dialog.getCheckbox();
	var usevirtual = Dialog.getCheckbox();	
	var deletetempfiles = Dialog.getCheckbox();
	var copycodec="no";

	call("ij.Prefs.set", "usevirtual.persistent",toString(usevirtual)); 
	call("ij.Prefs.set", "addtimestamp.persistent",toString(addtimestamp)); 
	call("ij.Prefs.set", "converttotemperature.persistent",toString(converttotemperature)); 
	call("ij.Prefs.set", "deletetempfiles.persistent",toString(converttotemperature)); 
	
	// ffmpeg copy codec with tiff file creates a corrupted avi, so best to simply use ffmpeg to re-encode
	if(encodetypechoice=="tiff"){
		copycodec="no";
	}
	
	if(outtypechoice=="avi"){
		var outtype="avi";
		var outcodec=encodetypechoice;
			if(encodetypechoice=="tiff"){
				var copycodec="copy";
		}
	}

	if(outtypechoice=="png"){
		var outtype="png";
		var outcodec="png";
	}

	if(outtypechoice=="tiff"){
		var outtype="tiff";
		var outcodec="tiff";
	}
	
	ObjectParameters=ConvertFLIRVideo("seq", outtype, outcodec, converttotemperature, usevirtual, copycodec, addtimestamp, deletetempfiles);
	
	// Commit object parameters to memory
    // ObjectCameraParameterPersist(ObjectParameters);
		
}


function ImportConvertFLIRCSQ(){

	//var converttotemperature = 1;
	//var usevirtual = 1;
	//var addtimestamp=0;
	
	Dialog.create("Select a FLIR CSQ File");
	Dialog.addMessage("-- Warning: Before selecting your file, please remove spaces in the file or folder name --");
	Dialog.addMessage("Define parameters for Video Import");
	Dialog.addMessage("If you choose output file type 'Video', a single .avi file\nwill be created and imported using Import-MOVIE (FFMPEG)");
	Dialog.addMessage("If you choose output file type 'PNG', a separate PNG file\nwill be created for each CSQ frame");
	Dialog.addMessage("If you choose output file type 'TIFF', a separate TIFF file\nwill be created for each CSQ frame");
	Dialog.addChoice("Output File Type (avi, png, tiff)", newArray("avi", "png", "tiff"), "avi");
	Dialog.addChoice("Video Image Encoding (ignored if choosing file)", newArray("jpegls", "png"), "jpegls");
	Dialog.addNumber("Number of frames to skip. Use 1 to import without skipping, 2 to skip every other frame,...", 1);
	Dialog.addMessage("The choices below should be remembered the next time you run this function.");
	Dialog.addCheckbox("Convert to Temperature on Import", converttotemperature);
	Dialog.addMessage("Unselect Convert to Temperature for faster loading.\nThe imported file will be a 16-bit grayscale.\n");
	Dialog.addCheckbox("Add video frame time stamp to slice labels (choice is remembered on relaunch).", addtimestamp);
	Dialog.addCheckbox("Use virtual stack for avi import (choice is remembered on relaunch).", usevirtual);
	Dialog.addMessage("Select Virtualstack for faster loading, but cannot add time stamps to image stack.\n");
	Dialog.addCheckbox("Delete the temporary files generated during conversion.", deletetempfiles);
	Dialog.show();
	
	var outtypechoice=Dialog.getChoice();
	var encodetypechoice = Dialog.getChoice();
	var framestep = Dialog.getNumber();
	var converttotemperature = Dialog.getCheckbox();
	var addtimestamp = Dialog.getCheckbox();
	var usevirtual = Dialog.getCheckbox();
	var deletetempfiles = Dialog.getCheckbox();
	var copycodec="no";
	
	
	call("ij.Prefs.set", "usevirtual.persistent",toString(usevirtual)); 
	call("ij.Prefs.set", "addtimestamp.persistent",toString(addtimestamp)); 
	call("ij.Prefs.set", "converttotemperature.persistent",toString(converttotemperature)); 
	call("ij.Prefs.set", "deletetempfiles.persistent",toString(converttotemperature)); 
	
	if(outtypechoice=="avi"){
		var outtype="avi";
		var outcodec=encodetypechoice;
			if(encodetypechoice=="jpegls"){
				var copycodec="copy";
		}
	}

	if(outtypechoice=="png"){
		var outtype="png";
		var outcodec="png";
	}

	if(outtypechoice=="tiff"){
		var outtype="tiff";
		var outcodec="tiff";
	}

	ObjectParameters=ConvertFLIRVideo("csq", outtype, outcodec, converttotemperature, usevirtual, copycodec, addtimestamp, deletetempfiles);
	
	// Commit object parameters to memory
    //ObjectCameraParameterPersist(ObjectParameters);
 
}

function ConvertFLIRVideo(vidtype, outtype, outcodec, converttotemperature, usevirtual, copycodec, addtimestamp, deletetempfiles) {

    getDateAndTime(startyear, startmonth, startdayOfWeek, startdayOfMonth, starthour, startminute, startsecond, startmsec);
	
	var medianframediff=1;
	
	print("\n------ Running ConvertFLIRVideo function ------");
	
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

	//filepath=replace(filepath, " ", "\ ");
	//filedir=replace(filedir, " ", "\ ");
		
	//	make a temporary folder within the directory
	tempfolder=filedir + File.separator + "temp";
	File.makeDirectory(tempfolder);
	
	// Use to troubleshoot the conversion process
	print("Removing old files that may be in the following temporary folder: " + tempfolder);
	
	// call the deletetempfolder function to remove temporary files
	deletetempfolder(tempfolder);
	
//	filesintempfolder=getFileList(tempfolder);
//	for (i = 0; i < filesintempfolder.length; i++){
//	  showProgress(i/filesintempfolder.length);
//      tempfilesdelete_success=File.delete(tempfolder + File.separator + filesintempfolder[i]);	
//	}	
	
	print("Loading: ", filepath);
	
	print("Extracting calibration and image settings");
	
	// populate an array called flirvals with 19 entries to accept the array output from the flirvalues function
	flirvals=newArray(19);

	var printvalues="No";
	
	flirvals=flirvalues(filepath, printvalues);
	
	// define the constants extracted from the flir values function
	PR1=flirvals[0];
	PB=flirvals[1];
	PF=flirvals[2];
	PO=flirvals[3];
	PR2=flirvals[4];
	ATA1=flirvals[5];
	ATA2=flirvals[6];
	ATB1=flirvals[7];
	ATB2=flirvals[8];
	ATX=flirvals[9];
	E=flirvals[10];
	OD=flirvals[11];
	RTemp=flirvals[12];
	ATemp=flirvals[13];
	IRWTemp=flirvals[14];
	IRT=flirvals[15];
	RH=flirvals[16];
	imagewidth=flirvals[17];
	imageheight=flirvals[18];
	
	print("Extracted Camera Calibration and Object Parameters:");
	Array.print(flirvals);
	print("\n");
	
	if(outtype=="avi"){
		fileout=File.nameWithoutExtension + "." + outtype; // outtype should be "avi"
	}

	var pixfmt="gray16be";
	
	if(outcodec=="tiff"){
		pixfmt="gray16le";
	}
	
	if(outcodec=="jpegls"){
		pixfmt="gray16le";
	}
	
	if(outtype=="png"){
		outputfolder=filedir + File.separator + File.nameWithoutExtension;
		//print(outputfolder);
		
		outputfolderlist = getFileList(outputfolder);
		for (i = 0; i < outputfolderlist.length; i++){
      		outputfolderfilesdelete_success=File.delete(outputfolder + File.separator + outputfolderlist[i]);	
		}	
	     //outputfolderdelete=File.delete(outputfolder);
		
		File.makeDirectory(outputfolder);
		fileout=File.nameWithoutExtension + File.separator + File.nameWithoutExtension + "_%06d" + "." + outtype; // outtype should be "png"
		pixfmt="gray16be";
	}
    
	if(outtype=="tiff"){
		outputfolder=filedir + File.separator + File.nameWithoutExtension;
		//print(outputfolder);
		
		outputfolderlist = getFileList(outputfolder);
		for (i = 0; i < outputfolderlist.length; i++){
      		outputfolderfilesdelete_success=File.delete(outputfolder + File.separator + outputfolderlist[i]);	
		}	
	     //outputfolderdelete=File.delete(outputfolder);
		File.makeDirectory(outputfolder);
		fileout=File.nameWithoutExtension + File.separator + File.nameWithoutExtension + "_%06d" + "." + outtype; // outtype should be "tiff"
		pixfmt="gray16le";
	}

	//fileout=replace(fileout, " ", "\ ");
	
	// Define the syntax for the exec command to split the sequence file into .fff files
	if(vidtype=="csq"){
		splitfffexeccmd = perlpath + "perl " + perlsplit + " -i " + filepath + " -o " + tempfolder + " -b frame -p csq -x fff";
	}
	
	if(vidtype=="seq"){
		splitfffexeccmd = perlpath + "perl " + perlsplit + " -i " + filepath + " -o " + tempfolder + " -b frame -p fff -x fff";
	}
	
	print("Splitting the video file into its .fff files with: ");
	print(splitfffexeccmd);

	// Execute the split.pl script on the SEQ file to create fff files
	if(vidtype=="csq"){
		exec(perl, perlsplit, "-i", filepath, "-o", tempfolder, "-b", "frame", "-p", "csq", "-x", "fff");
	}
	
	if(vidtype=="seq"){
			exec(perl, perlsplit, "-i", filepath, "-o", tempfolder, "-b", "frame", "-p", "fff", "-x", "fff");
	}

	ffffilesintempfolder=CountFilesByExtension(tempfolder, ".fff");
	print("The number of .FFF files in the temporary folder is: ", ffffilesintempfolder);
	print("Use this number to troubleshoot if each command line step is working. The number of files should relate to the number of video frames.");
	
	// According to the framestep value, we will examing the number of fff files in the temporary folder and remove every nth frame.  
	// If framestep = 1, we skip this step
	// If framestep = 2, it should delete every other .fff file, keeping frame000001.fff, frame000003.fff, etc..
	
	if(framestep > 1){
		RemoveEveryNthFFF(tempfolder, framestep);		
	}
	

	////////////////////// Split fff -> jpegls and remove extra files approach //////////////////////

	///// After creating the fff files, an alternative to using exiftool combining to thermalvid.raw is to re-split the fff files and then filter
	///// out the extra generated files as shown in the next ~20 lines
	//// The reason for this is with large CSQ files (>5000 frames) - exiftool can't handle the stream for some reason, so the perl split.pl script is the
	//// only viable solution.
	//// The split.pl script simply splits a file whereever the magic byte sequence occurs, which for an FFF file means that a short file is created that is
	//// mostly header info about the image, and the second file split off is the jpegls image data
	
	//// Note: this section subsequently caused issues with csq files that had errors in them, so the current code by-passes this section and uses the 
	//// Thermalvid.raw approach until further notice.


	if(vidtype=="csq"){
		
		fff_files = getFileList(tempfolder);
		
		if(fff_files[0]=="datetime.txt"){
			fff_files=Array.slice(fff_files,1);
		}
		
		print("Splitting fff files into jpegls files by looping through all files using:");
		fff_file = replace(fff_files[0], "\.fff", "");
		print(perl + " " + perlsplit + " -i " + tempfolder + File.separator + fff_files[0] + " -o " + filedir + File.separator + "temp " +  "-b " + fff_file + " -p " + "jpegls " + "-x " + "jpegls " + "-s " + "y");
				
		for(i=0; i<fff_files.length; i++){
			showProgress(i/fff_files.length);
			fff_file = replace(fff_files[i], "\.fff", "");
			exec(perl, perlsplit, "-i", tempfolder + File.separator + fff_files[i], "-o", filedir + File.separator + "temp", "-b", fff_file, "-p", "jpegls", "-x", "jpegls", "-s", "y");
		}

		// Use to troubleshoot the conversion process
		jpeglsfilesintempfolder=CountFilesByExtension(tempfolder, ".jpegls");
		print("The number of .JPEGLS files in the temporary folder is: ", jpeglsfilesintempfolder);
		print("Use this number to troubleshoot if each command line step is working. The number of files should relate to the number of video frames.");

		// I added an option to the perl script so that it skips exporting data before the magicbyte, allowing for only jpegls images to be split off, so these fff checks are unnecessary now:
		//fileswithfff=GetFileListFilter(tempfolder, 3, "FFF");
		
		//print("Deleting fff files");
		
		// delete any files that are simply fff header files derived from the split function
		//for(i=0; i<fileswithfff.length; i++){
		//	x=File.delete(fileswithfff[i]);
		//}

		//jpeglsfilelist=getFileList(tempfolder);  // assumes this list of jpegls files is automatically sorted.
		// what the loop below will do is to examine the array of jpegls file names and rename them to frame000001.jpegls.
		// to speed up code, I have to assume these files are properly sorted.
		jpeglsfilelist=GetFileListByExtension(tempfolder, "jpegls");  // assumes this list of jpegls files is automatically sorted.
		for(i=0; i<jpeglsfilelist.length; i++){
			//print(jpeglsfilelist[i]);
			showProgress(i/jpeglsfilelist.length);
			filepath=tempfolder + File.separator + jpeglsfilelist[i];
			stringcounter = "" + i + 1;
			framename = "frame" + leadzero(stringcounter, 6) + ".jpegls"; 
			//newpath=replace(filepath, "000001\.jpegls", "\.jpegls");
			newpath=tempfolder + File.separator + framename;
			//print(newpath);
			x=File.rename(filepath, newpath);
		}
	}
	
	////////////////// ^ Split fff -> jpegls or tiff and remove extra files approach ^ //////////////////////

 
 	// Create an argument file that contains the full list of fff files, since the exiftool command cannot handle large numbers of files via the shell.
	ffffilelist=GetFileListByExtension(tempfolder, "fff");
	file=File.open(tempfolder + File.separator + "argfile.txt");
	for(i=0; i<ffffilelist.length; i++){
			showProgress(i/ffffilelist.length);
			File.append(tempfolder + File.separator + ffffilelist[i], tempfolder + File.separator + "argfile.txt");
		}
 
	////////////////// Thermalvid.raw approach //////////////////////

	// SEQ files may be oddly formatted, so we'll use Exiftool to generate the thermalvid.raw file.

	if(vidtype=="seq"){
				
	// Combine fff files into thermalvid.raw using exiftool raw binary extraction function
	// Difficulty getting the piping (> or |) to work with the default exec command. 
	// See: http://imagej.1557.x6.nabble.com/macro-Redirection-in-exec-UNIX-binary-td3687463.html
	
	//rawcombinecmd = exiftoolpath + exiftool +  " -b -r -fast -P -sort -RawThermalImage " + tempfolder + File.separator + "*.fff > " + tempfolder + File.separator + "thermalvid.raw";
	// previously, the code below would not work with large number of fff files.  I had to remove the "*.fff" part and force exiftool to operate only on the folder recursively:
	
	rawcombinecmd = exiftoolpath + exiftool +  " -b -RawThermalImage " + tempfolder + File.separator +  "*.fff > " + tempfolder + File.separator + "thermalvid.raw";
	rawcombinecmd = exiftoolpath + exiftool +  " -b -RawThermalImage -@ " + tempfolder + File.separator +  "argfile.txt > " + tempfolder + File.separator + "thermalvid.raw";
	//rawcombinecmd = exiftoolpath + exiftool +  " -b -RawThermalImage " + tempfolder + File.separator +  " > " + tempfolder + File.separator + "thermalvid.raw";
	//rawcombinecmd = exiftoolpath + exiftool +  " -b -r -fast -P -RawThermalImage " + tempfolder + " > " + tempfolder + File.separator + "thermalvid.raw";
	
	print("Combining the fff files into a thermalvid.raw file with: ");
	print(rawcombinecmd);
	print("Please note that this step can be slow for large files, and there is no way to indicate progress");
	
	if(OS=="Mac OS X"){
		exec("/bin/sh", "-c", rawcombinecmd);	
	}

	if(OS=="Linux"){
		exec("/bin/sh", "-c", rawcombinecmd);		
	}

	if(substring(OS, 0, 5)=="Windo"){
		exec("cmd", "/c", exiftoolpath + exiftoolWindows, "-b", "-RawThermalImage", tempfolder + File.separator + "*.fff", ">", tempfolder + File.separator + "thermalvid.raw");
	}

	// Use to troubleshoot the conversion process
	thermalvidrawfilesintempfolder=CountFilesByExtension(tempfolder, ".raw");
	print("The number of .RAW files in the temporary folder is: ", thermalvidrawfilesintempfolder);
	print("Use this number to troubleshoot if each command line step is working. There should be 1 thermalvid.raw file if conversion was successful.");
	
	// Execute the split.pl script on thermalvid.raw to create tiff (or jpegls) files
	splittiffexeccmd = perlpath + "perl " + perlsplit + " -i " + tempfolder + File.separator + "thermalvid.raw" + " -o " + filedir + "/temp -b frame -p " + RawThermalType + " -x " + RawThermalType;
	print("Splitting the thermalvid.raw file into " + RawThermalType + " files with: ");
	print(splittiffexeccmd);
	
	if(vidtype=="seq"){
		exec(perl, perlsplit, "-i", tempfolder + File.separator + "thermalvid.raw", "-o", filedir + File.separator + "temp", "-b", "frame", "-p", "tiff", "-x", "tiff");
		
		// Use to troubleshoot the conversion process
		tifffilesintempfolder=CountFilesByExtension(tempfolder, ".tiff");
		print("The number of .TIFF files in the temporary folder is: ", tifffilesintempfolder);
		print("Use this number to troubleshoot if each command line step is working. The number of files should relate to the number of video frames.");
		
		if(ffffilesintempfolder - tifffilesintempfolder>0){
			print(" ------- WARNING -------");
			print("The number of extracted / converted frames is fewer than the number of detected FLIR FFF headers");
			print("This likely means that there are some frames in the video that contain an error");
			print("These frames have been skipped");
		}
	}
	
	if(vidtype=="csq"){
		exec(perl, perlsplit, "-i", tempfolder + File.separator + "thermalvid.raw", "-o", filedir + File.separator + "temp", "-b", "frame", "-p", "jpegls", "-x", "jpegls");
		
		// Use to troubleshoot the conversion process
		jpeglsfilesintempfolder=CountFilesByExtension(tempfolder, ".jpegls");
		print("The number of JPEGLS files in the temporary folder is: ", jpeglsfilesintempfolder);
		print("Use this number to troubleshoot if each command line step is working. The number of files should relate to the number of video frames.");
		
		if(ffffilesintempfolder - jpeglsfilesintempfolder>0){
			print(" ------- WARNING -------");
			print("The number of extracted / converted frames is fewer than the number of detected FLIR FFF headers");
			print("This likely means that there are some frames in the video that contain an error");
			print("These frames have been skipped");
		}

	}

}
	
	////////////////// ^ Thermalvid.raw approach ^ //////////////////////


	// Check that the newly encoded files are all robust
	// in some cases a jpegls or a tiff file may be created with zero bytes, and this will cause failure in the 
	// subsequent conversion steps, so we need to remove these files until a better way to detect when these 
	// errors will crop up.  Usually this happens with the first frame of some files when it appears that the
	// file has been corrupted.	

		if(vidtype=="seq"){
			tifffilelist=GetFileListByExtension(tempfolder, "tiff");
			for(i=0; i<tifffilelist.length; i++){
				filenametocheck=tempfolder + File.separator + tifffilelist[i];
				checkzeroresult=CheckFileSizeZero(filenametocheck);
				
				if(checkzeroresult==1){
					filenameroot=replace(tifffilelist[i], "tiff", "");
					print(filenameroot);
					tifffiledelete=File.delete(tempfolder + File.separator + tifffilelist[i]);
					ffffiledelete=File.delete(tempfolder + File.separator + filenameroot + "fff");
					//print("Deleting tiff and fff file");
				}
			}
		}

		if(vidtype=="csq"){
			jpeglsfilelist=GetFileListByExtension(tempfolder, "jpegls");
			for(i=0; i<jpeglsfilelist.length; i++){
				filenametocheck=tempfolder + File.separator + jpeglsfilelist[i];
				checkzeroresult=CheckFileSizeZero(filenametocheck);
				
				if(checkzeroresult==1){
					filenameroot=replace(jpeglsfilelist[i], "jpegls", "");
					print(filenameroot);
					jpeglsfiledelete=File.delete(tempfolder + File.separator + jpeglsfilelist[i]);
					ffffiledelete=File.delete(tempfolder + File.separator + filenameroot + "fff");
					//print("Deleting jpegls and fff file");
				}
			}
		}



// Extract Date/Time Original from the .fff files    
	if(addtimestamp==1){
		// The following does not work from inside fiji
		//timefind = exiftoolpath + exiftool + " -DateTimeOriginal -s -r -T -f -fast " + tempfolder + " > " + tempfolder + File.separator + "datetime.txt";  
		// the following does work, but exiftool cannot handle large numbers of files this way.
		timefind = exiftoolpath + exiftool + " -DateTimeOriginal -s -r -T -f -fast " + tempfolder + File.separator + "*.fff" + " > " + tempfolder + File.separator + "datetime.txt"; // 
		timefind = exiftoolpath + exiftool + " -DateTimeOriginal -s -r -T -f -fast -@ " + tempfolder + File.separator + "argfile.txt" + " > " + tempfolder + File.separator + "datetime.txt"; // 
		print("Extracting frame times with: ");
		print(timefind);
	
		//exiftool -*DateTimeOriginal -s -T *.fff > datetime.txt

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

		// Load in Text file that contains time stamps for each frame from a SEQ or CSQ file
		// Store these time stamps into an Array to return to the ConvertImportFLIRVideo function
		// Then use these time stamps to re-name each layer in the stack

		datetimefilePath=tempfolder + File.separator + "datetime.txt";
		test=Table.open(datetimefilePath);
		Heading=Table.headings();
		NumFrames=Table.size()+1;
		Times1=Table.getColumn(Heading);
		HeadingArray=newArray(Heading);
		Times=Array.concat(HeadingArray, Times1);
	
		dateoriginal=newArray(NumFrames);
		timeoriginal=newArray(NumFrames);
		tz=newArray(NumFrames);
		sec=newArray(NumFrames);
	
		i=0;
		while (i<dateoriginal.length) { 
			dateoriginal[i]=Times[i];
			timeoriginal[i]=Times[i];
			tz[i]=Times[i];
			showProgress(i/dateoriginal.length);
			 
			if(Times[i] == "-") {
				i++;
			} else {
				dateoriginal[i]=replace(substring(dateoriginal[i], 0, 10), ":", "-");
				tz[i]=substring(tz[i], 23, 29);
				timeoriginal[i]=substring(timeoriginal[i], 11, 23);	
				sec[i]=parseFloat(substring(timeoriginal[i], 6, 12));
				i++;
			}
		}

		framediff=newArray(NumFrames-1);
		for(i=0; i<NumFrames-1; i++){
			framediff[i]=sec[i+1] - sec[i];
			if(framediff[i]<0){
				rem=60*abs(round(framediff[i]/60));
				framediff[i]=framediff[i]+rem;
			}
		}
	
		//Array.print(framediff);
		Array.getStatistics(framediff, mean);
		medianframediff=Median(framediff);
		
		var frameinterval=medianframediff;
		
		print("Video frame time difference is: " + medianframediff + " seconds");
	
	}


// Execute the ffmpeg command to assimilate all the image (TIFF or JPEGLS or PNG?) files into one avi file
	
	// determine play back rate, playbackrate
	// print(1/1/frameinterval*framestep);
	playbackrate=parseFloat("" + 1/frameinterval*framestep);
    //print(playbackrate);
	
	if(copycodec=="copy"){
		outcodec="copy";
	}
	
	print("Combining the " + RawThermalType + " files into " + outcodec + " files ready for import with: ");
	tiffcombinecmd = ffmpeg + " -f" + " image2" + " -vcodec" + " " + RawThermalType + " -r" + " " + playbackrate + " -i " + tempfolder + File.separator + "frame%06d." + RawThermalType + " -pix_fmt " + pixfmt + " -vcodec " + outcodec + " " + filedir + File.separator + fileout + " -y";   
    print(tiffcombinecmd); 

	if(outcodec=="jpegls"){
		// for recoding to jpegls, setting pred to 2 usually yields the smallest file size
		// but no saving is generated from a CSQ file where the jpegls compression is already optimal, so it is better simply to set -vodec to copy
		exec(ffmpeg, "-f", "image2", "-vcodec", RawThermalType, "-r", playbackrate, "-i", tempfolder + File.separator + "frame%06d." + RawThermalType, "-pix_fmt", pixfmt, "-vcodec", outcodec, "-pred", "2",  filedir + File.separator + fileout, "-y");
	}
	else{
 		exec(ffmpeg, "-f", "image2", "-vcodec", RawThermalType, "-r", playbackrate, "-i", tempfolder + File.separator + "frame%06d." + RawThermalType, "-pix_fmt", pixfmt, "-vcodec", outcodec, filedir + File.separator + fileout, "-y");
	}

	// Use to troubleshoot the conversion process
	filesintempfolder=getFileList(tempfolder);
	print("The number of files in the temporary folder is: ", filesintempfolder.length);
	print("Use this number to troubleshoot if each command line step is working.");
	print("The number of files should be the sum of the number of .FFF, .RAW, plus the .TIFF or .JPEGLS files generated from the extraction process.");
	
	if(deletetempfiles==1){
		deletetempfolder(tempfolder);	
	}


	if(outtype=="png"){
		print("Your converted file(s) should be located in the following folder: ", outputfolder);
		//print(outputfolder + File.Separator + File.nameWithoutExtension + "000001.png");
			
		if(File.exists(outputfolder + File.separator + File.nameWithoutExtension + "_000001.png")==0){
			exit("No .PNG files exist at that location. Please check steps above to see where conversion is failing. ");	
		}
		
		print("\nImporting Image Sequence of PNG files");
		pngsequenceimportarguments="open=[" + outputfolder + "] sort";
		print(pngsequenceimportarguments);
		run("Image Sequence...", pngsequenceimportarguments);
	}

	if(outtype=="tiff"){
		print("Your converted file(s) should be located here in the following folder: ", outputfolder);
		
		print("\nImporting Image Sequence of TIFF files");
		tiffsequenceimportarguments="open=[" + outputfolder + "] sort";
		print(tiffsequenceimportarguments);
		run("Image Sequence...", tiffsequenceimportarguments);
	}

	if(outtype=="avi"){
		print("Your converted file(s) should be located here: ", filedir + File.separator +  fileout);
		
		if(File.exists(filedir + File.separator +  fileout)==0){
			exit("No .AVI file exists at that location. Please check steps above to see where conversion is failing. ");	
		}
		
		print("\nImporting 16-bit grayscale AVI file");
		ffmpegimportarguments = "choose=[" + filedir + File.separator + fileout + "]" + " first_frame=0 last_frame=-1";
		
		if(usevirtual==1  && addtimestamp==0){
		   ffmpegimportarguments = "choose=[" + filedir + File.separator + fileout + "]" + " use_virtual_stack first_frame=0 last_frame=-1";
		}

		if(usevirtual==1  && addtimestamp==1){
			print("Warning: Time stamps cannot be added to virtual stacks. Your video has been imported as a normal stack to add time stamps");
		}

		print(ffmpegimportarguments);
		
		run("Movie (FFMPEG)...", ffmpegimportarguments);
		
	}

	if(addtimestamp==1){
		print("Adding date/time origin as slice label.");
		setBatchMode(true);
		for (i=1; i<=nSlices; i++) { 
			setSlice(i);
   			showProgress(i/nSlices);
			//slicelabel= dateoriginal + "_" + timeoriginal[i] + tz;
			slicelabel=dateoriginal[i-1] + " " + timeoriginal[i-1] + " " + tz[i-1];
			setMetadata("Label", slicelabel);
			//Property.setSliceLabel(string, slice)
		}
		setBatchMode(false);
	
		// Set frame interval to stack
		frameinterval=medianframediff; 	
		call("ij.Prefs.set", "frameinterval.persistent", toString(frameinterval)); 
		//imageproperties="channels=1 frames=1 pixel_width=1.0000 pixel_height=1.0000 voxel_depth=1.0000 frame=[" + frameinterval + " sec\] global";
		//run("Properties...", imageproperties);
	}
	
	getDateAndTime(endyear, endmonth, enddayOfWeek, enddayOfMonth, endhour, endminute, endsecond, endmsec);
	elapsedminutes = (endhour-starthour)*60 + (endminute-startminute) + (endsecond-startsecond)/60 + (endmsec-startmsec)/(60*1000);
	print("The number of minutes to process your video:", elapsedminutes);	
	print("Done Importing Video");
	
	// set frame interval
	var frameinterval=medianframediff;
	//Stack.setFrameInterval(frameinterval + " sec");
	call("ij.Prefs.set", "frameinterval.persistent", toString(frameinterval)); 
	//imageproperties="channels=1 frames=1 pixel_width=1.0000 pixel_height=1.0000 voxel_depth=1.0000 frame=[" + frameinterval + " sec\] global";
	//run("Properties...", imageproperties);
	
	if(converttotemperature==1){
		print("Converting file to temperature");
		ObjectParameters=Raw2Temp(PR1, PR2, PB, PF, PO, AtmosphericTransVals(ATA1, ATA2, ATB1, ATB2, ATX), E, OD, RTemp, ATemp, IRWTemp, IRT, RH, defaultpalette, "Yes", "Fast", imagetemperaturemin, imagetemperaturemax);	
	}
	
	run("Animation Options...", "speed=30");
	print("\n");
	//	Stack.getFrameInterval();
	return ObjectParameters;
}



// after having converted a SEQ or CSQ file into a 16-but AVI, import it as a virtualstack     
function ImportFFmpegAVI(){
	AVIfile=File.openDialog("FFmpeg AVI File");
	ffmpegchoose="choose=[" + AVIfile + "]" + " use_virtual_stack first_frame=0 last_frame=-1";
	print(ffmpegchoose);
	run("Movie (FFMPEG)...", ffmpegchoose);
	run("Animation Options...", "speed=30");
	doCommand("Start Animation [\\]");
}

function Raw2Temp(PR1, PR2, PB, PF, PO, ATvals, E, OD, RTemp, ATemp, IRWTemp, IRT, RH, palettetype, dialogprompt, FastSlow, imagetemperaturemin, imagetemperaturemax) {

	ATA1=ATvals[0];
	ATA2=ATvals[1];
	ATB1=ATvals[2];
	ATB2=ATvals[3];
	ATX=ATvals[4];
	
	//start=getTime();
	
	print("\n------ Running Raw2Temp function ------");

	// Apparently, no need to convert virtual stack if you use the Calibrate function and fast calculation
	if(is("Virtual Stack")==1 && FastSlow=="Slow"){
		print("Cannot perform conversions on a virtual stack.  Duplicating stack first.\nThis is slow and it is recommended that you crop and edit first before using the slow calculation");
		run("Duplicate...", "duplicate");
	}
		
	if(dialogprompt=="Yes"){
		
	byteorder=newArray("Default", "Swap");
	defaultbyteorder="Default";
	fastslowchoice=newArray("Fast", "Slow");
	fastslowchoicedefault=FastSlow;
	
	// Create a prompt dialog to ask user to verify the values to be used in the calculations below
	
	Dialog.create("Verify Camera and Object Parameters Function");
	Dialog.addMessage("If Calibration constants are unknown, run the FLIR Calibration Values Tool first!");
	Dialog.addMessage("TIFF file pixel byte are usually little endian, PNG file pixel bytes are usually big endian");
	Dialog.addChoice("Keep Default or Swap Byte Order?", byteorder, defaultbyteorder);
	Dialog.addMessage("Fast calculation is approximate but repeatable, Slow is accurate but not reversible");
	Dialog.addChoice("Fast or Slow Calculation?", fastslowchoice, fastslowchoicedefault); 	Dialog.addNumber("Estimated Image Temperature  Minimum:", imagetemperaturemin, 0, 5, "C");
 	Dialog.addNumber("Estimated Image Temperature  Maximum:", imagetemperaturemax, 0, 5, "C");
	
	Dialog.addMessage("Object Parameters:");
    Dialog.addNumber("Object Emissivity:", E, 3, 6, "unitless");
    Dialog.addToSameRow();
    Dialog.addNumber("Object Distance:", OD, 1, 6, "m");
    Dialog.addNumber("Reflected Temperature (C):", RTemp, 2, 6, "C");
    Dialog.addToSameRow();
    Dialog.addNumber("Atmospheric Temperature (C):", ATemp, 2, 6, "C");
    Dialog.addNumber("Window Temperature (C):", IRWTemp, 2, 6, "C");
    Dialog.addToSameRow();
    Dialog.addNumber("Window Transmittance:", IRT, 3, 6, "unitless");
    Dialog.addNumber("Relative Humidity:", RH, 2, 6, "%");
    Dialog.addChoice("Palette", palettetypes, defaultpalette);
	
	Dialog.addMessage("Camera Calibration Constants:");
	Dialog.addNumber("Planck R1:", PR1, 8, 15, "unitless"); //21106.77 //21546.203
	Dialog.addToSameRow();
	Dialog.addNumber("Planck R2:", PR2, 8, 15, "unitless"); //0.012545258 //0.016229488 
	Dialog.addNumber("Planck B:", PB, 8, 15, "unitless"); //1501 //1507.2
	Dialog.addToSameRow();
	Dialog.addNumber("Planck F:", PF, 8, 15, "unitless");//1
    Dialog.addNumber("Planck O:", PO, 8, 15, "unitless"); //-7340 //-6331
    Dialog.addNumber("Atmospheric Trans Alpha 1:", ATA1, 8, 12, "unitless");
    Dialog.addToSameRow();
    Dialog.addNumber("Atmospheric Trans Alpha 2:", ATA2, 8, 12, "unitless");
    Dialog.addNumber("Atmospheric Trans Beta 1:", ATB1, 8, 12, "unitless");
    Dialog.addToSameRow();
    Dialog.addNumber("Atmospheric Trans Beta 2:", ATB2, 8, 12, "unitless");
    Dialog.addNumber("Atmospheric Trans X:", ATX, 8, 12, "unitless");
 
	Dialog.show();

	ByteOrder=Dialog.getChoice();
	FastSlow=Dialog.getChoice();
	imagetemperaturemin = Dialog.getNumber();
	imagetemperaturemax = Dialog.getNumber();
	
	E = Dialog.getNumber();
	OD = Dialog.getNumber();
	RTemp = Dialog.getNumber();
	ATemp = Dialog.getNumber();
	IRWTemp = Dialog.getNumber();
	IRT = Dialog.getNumber();
	RH = Dialog.getNumber();
	palettetype = Dialog.getChoice();

	PR1 = Dialog.getNumber();
	PR2 = Dialog.getNumber();
	PB = Dialog.getNumber();
	PF = Dialog.getNumber();
	PO = Dialog.getNumber();
	ATA1 = Dialog.getNumber();
	ATA2 = Dialog.getNumber();
	ATB1 = Dialog.getNumber();
	ATB2 = Dialog.getNumber();
	ATX = Dialog.getNumber();
	
	
	call("ij.Prefs.set", "imagetemperaturemin.persistent",toString(imagetemperaturemin)); 
	call("ij.Prefs.set", "imagetemperaturemax.persistent",toString(imagetemperaturemax)); 
	call("ij.Prefs.set", "PR1.persistent",toString(PR1)); 
	call("ij.Prefs.set", "PB.persistent",toString(PB)); 
	call("ij.Prefs.set", "PF.persistent",toString(PF)); 
	call("ij.Prefs.set", "PR2.persistent",toString(PR2)); 
	call("ij.Prefs.set", "PO.persistent",toString(PO));
	call("ij.Prefs.set", "ATA1.persistent",toString(ATA1));
	call("ij.Prefs.set", "ATA2.persistent",toString(ATA2));
	call("ij.Prefs.set", "ATB1.persistent",toString(ATB1));
	call("ij.Prefs.set", "ATB2.persistent",toString(ATB2));
	call("ij.Prefs.set", "ATX.persistent",toString(ATX));
	call("ij.Prefs.set", "E.persistent",toString(E)); 
	call("ij.Prefs.set", "OD.persistent",toString(OD)); 
	call("ij.Prefs.set", "RTemp.persistent",toString(RTemp)); 
	call("ij.Prefs.set", "ATemp.persistent",toString(ATemp)); 
	call("ij.Prefs.set", "IRWTemp.persistent",toString(IRWTemp)); 
	call("ij.Prefs.set", "IRT.persistent",toString(IRT)); 
	call("ij.Prefs.set", "RH.persistent",toString(RH)); 
	call("ij.Prefs.set", "imagewidth.persistent",toString(imagewidth)); 
	call("ij.Prefs.set", "imageheight.persistent",toString(imageheight)); 
	
	if(ByteOrder == "Swap"){
		run("Byte Swapper");
	}
	
	}

	if(is("Virtual Stack")==1 && FastSlow=="Slow"){
		print("Cannot perform conversions on a virtual stack.  Duplicating stack first.\nThis is slow and it is recommended that you crop and edit first before using the slow calculation");
		run("Duplicate...", "duplicate");
	}
	
	//setBatchMode(true);
	// Nov 3, 2019, removed these constants and added the ability to search a particular jpg for 
	// default atmospheric transmittance constants.
	
	//ATA1 = 0.006569; //Atmospheric Trans Alpha 1
	//ATA2 = 0.012620; //Atmospheric Trans Alpha 2 
	//ATB1 = -0.002276; //Atmospheric Trans Beta 1
	//ATB2 = -0.006670; //Atmospheric Trans Beta 2 
	//ATX =  1.900000; //Atmospheric Trans X

	emisswind = 1- IRT; 
  	reflwind = 0; // anti-reflective coating on window
 	h2o = (RH/100)*exp(1.5587+0.06939*(ATemp)-0.00027816*(ATemp*ATemp)+0.00000068455*(ATemp*ATemp*ATemp)); // converts relative humidity into water vapour pressure (I think in units mmHg)
  	tau1 = ATX*exp(-sqrt(OD)*(ATA1+ATB1*sqrt(h2o)))+(1-ATX)*exp(-sqrt(OD)*(ATA2+ATB2*sqrt(h2o))); // atmos transmittance from object to window
  	//tau2 = ATX*exp(-sqrt(OD)*(ATA1+ATB1*sqrt(h2o)))+(1-ATX)*exp(-sqrt(OD)*(ATA2+ATB2*sqrt(h2o))); // atmos transmittance from window to camera
	tau2=1;
	
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

	// Fast method is good if you restrict the imagetemperaturemin and imagetemperaturemax ranges to limits that realistically span
	// the scene you are analysing.

	// empirically, we fit a curve bewteen r and temperature for a regression containing 655 data points.  
	// using higher number of data points slows down computation and added little benefit to the fits.
	
	if(FastSlow=="Fast"){
		
		r = newArray(655); 
		templookup=newArray(655);
		nai=0;
		
		for (i=0; i<655; i++) {
			
			showProgress(i/655);
			r[i]=i*100; 
			templookup[i] = PB/log(PR1/(PR2*(r[i]/rawdivisor-rawsubtract+PO))+PF)-273.15;
			//templookup[i] = 1507.2/log(21546.203/(0.016229488*(r[i]/0.9-100-6331))+1)-273.15;
			
			if(templookup[i]<imagetemperaturemin){
				templookup[i]=NaN;
			}
			
			nai=nai + isNaN(templookup[i]);
			
			if(templookup[i]>imagetemperaturemax){
				templookup[i]=NaN;
			}
			
   		}
   		
		//Fit.plot;
		//initialGuesses = newArray(1507.2, 21546.203, 0.016229488, 0.9, (-6331-100), 1);
		//print(Fit.nParams);
	
		
		s=""; // s = string to print to file for calibration
		
		text1="text1=[";
		text2="text2=[";
		x=newArray(655);
		y=newArray(655);
		
		for(i=nai; i<655; i++){
			showProgress(i/655);
			
			if(isNaN(templookup[i])){
				i=100000000; // break out of the loop
			}
			
			else{
			
			x[i]=r[i];
			y[i]=templookup[i];
			
			text1=text1 + d2s(r[i], 0) + " ";
			text2=text2 + d2s(templookup[i], 12) + " ";
			s = s + d2s(r[i], 0) + " \t" + d2s(templookup[i], 12) + "\n";
			}
		}
	
		Fit.doFit("4th Degree Polynomial", x, y);
		Fit.logResults;
		predicted=newArray(655);
		resid=newArray(655);
		for(i=0; i<655; i++){
			predicted[i]=Fit.f(x[i]);
			resid[i]=predicted[i]-y[i];
		}
 		//print(resid.length);
 		
		Array.getStatistics(resid, min, max, mean);
		
		rms_resid=RMS(resid);
		
		Fit.getEquation(3, name, formula);
		//Fit.plot();

		print("To reduce computational time, temperature was estimated using a 4th order polynomial on a restricted range of the data");
		print("Nominally, 655 data points evenly spanning a possible range of 65535 data points were used to contruct the following curve:");
		print(formula);
		print("where y = Temperature, x = Raw 16 bit value, and a,b,c,d,e are the coefficients:");
		print("a = " + Fit.p(0));
		print("b = " + Fit.p(1));
		print("c = " + Fit.p(2));
		print("d = " + Fit.p(3));
		print("e = " + Fit.p(4));
		print("r squared = " + Fit.rSquared);
		print("This approximates the Sakuma-Hattori equation (used for estimating Planck's law for instruments with non-finite bandwidth) across a limited temperature range");
		print("The root mean square of the error from polynomial predicted temperature using the fast calculation is:", rms_resid, "degrees C");
		print("The maximum mathematical error detected using the polynomial fit is:", max, "degrees C");
		print("Errors will be highest at the extreme ends of the temperature ranges.");
		print("If this error is too high, re-run the Raw2Temp Macro Tool (R->T icon) with the fast calculation, setting more stringent image minimum and maximum, or select the Slow calculation");
		print("For example, if the max residual error or the root mean square is greater than 0.1 degrees C, you probably should use the Slow calculation.");


		//File.saveString(s, "/Users/GlennTattersall/Desktop/calibration.txt");
	
		text1=text1 + "] ";
		text2=text2 + "] ";

		calibrateargument = "function=[4th Degree Polynomial] unit=°C " + text1 + text2 + "global";
		
		run("Calibrate...", calibrateargument);

		getStatistics(count, mean, min, max);

		toohigh=0; toolow=0;
		if(max > imagetemperaturemax){
			toohigh=1;
		}
		
		if(min  < imagetemperaturemin){
			toolow=1;
		}
		outofrange=toohigh+toolow;

		if(outofrange>0){
			print(" ------- WARNING -------");
			print("Minimum estimated temperature = ", min);
			print("Maximum estimated temperature = ", max);
			print("Temperatures calculated fall outside your expected image min and max values and are likely subject to extrapolation errors.");
			print("Please recalculate using the fast option with wider min or max ranges.");
		}
	}

	if(FastSlow=="Slow"){
		// remove any latent calibration on the raw 16-bit data
		run("Calibrate...", "function=[Straight Line] unit=C text1=[0 1] text2=[0 1] global");

		if(nSlices()>1){
		run("32-bit", "stack");
		run("Macro...", "code=v=" +PB+ "/log(" +PR1+ "/(" +PR2+ "*(v/" +rawdivisor+ "-" +rawsubtract+ "+" +PO+ "))+" +PF+ ")-273.15 stack");
		Stack.getStatistics(count, mean, min, max);
		mintemp=min;
		maxtemp=max;
		setMinAndMax(mintemp, maxtemp);
		}

	if(nSlices()==1){
		run("32-bit");	
		run("Macro...", "code=v=" +PB+ "/log(" +PR1+ "/(" +PR2+ "*(v/" +rawdivisor+ "-" +rawsubtract+ "+" +PO+ "))+" +PF+ ")-273.15");
		getStatistics(count, mean, min, max);
		mintemp=min;
		maxtemp=max;	
		setMinAndMax(mintemp, maxtemp);
		}
		
	}
	
	//setBatchMode(false);
	//mintemp=PB/log(PR1/(PR2*(minpix/rawdivisor-rawsubtract+PO))+PF)-273.15;
	//maxtemp=PB/log(PR1/(PR2*(maxpix/rawdivisor-rawsubtract+PO))+PF)-273.15;

	
	run(palettetype);
	//end=getTime();
	//timediff=end-start;
	//print(timediff);

	output=newArray(19);
	output=newArray(PR1, PR2, PB, PF, PO, ATA1, ATA2, ATB1, ATB2, ATX, E, OD, RTemp, ATemp, IRWTemp, IRT, RH, imagewidth, imageheight);
	
	return output;	

}


// ============================================================
// ImportConvertFLIRATS()
// Dialog + parameter collection, then calls ConvertFLIRATS()
// Mirrors ImportConvertFLIRSEQ() structure as closely as possible.
// ============================================================


function ImportConvertFLIRATS(){

	Dialog.create("Select a FLIR ATS File");
	Dialog.addMessage("-- Warning: Before selecting your file, please remove spaces in the file or folder name --");
	Dialog.addMessage("Define parameters for ATS Video Import");
	Dialog.addMessage("Note: ATS files do not contain absolute timestamps.\nOnly FrameCounter-based relative timing is available.");
	Dialog.addMessage("If you choose 'Raw Stack', the flat .raw file will be imported\ndirectly (fastest option, no intermediate conversion)");
	Dialog.addMessage("If you choose output file type 'Video', a single .avi file\nwill be created and imported using Import-MOVIE (FFMPEG)");
	Dialog.addMessage("If you choose output file type 'PNG' or 'TIFF', a separate file\nwill be created for each ATS frame");
	Dialog.addChoice("Output file type", newArray("Raw Stack", "avi", "png", "tiff"), "Raw Stack");
	Dialog.addChoice("Video image encoding (ignored if choosing Raw Stack or image above)", newArray("jpegls", "png"), "jpegls");
	Dialog.addNumber("Number of frames to skip. Use 1 to import without skipping, 2 to skip every other frame,...", 1);
	Dialog.addMessage("The choices below should be remembered the next time you run this function.");
	Dialog.addCheckbox("Convert to Temperature on Import", converttotemperature);
	Dialog.addMessage("Unselect Convert to Temperature for faster loading.\nThe imported file will be a 16-bit grayscale stack.");
	Dialog.addCheckbox("Use virtual stack for import (choice is remembered on relaunch).", usevirtual);
	Dialog.addMessage("Select virtual stack for faster loading.");
	Dialog.addCheckbox("Add relative elapsed time as slice label (FrameCounter-based; no absolute date available for ATS files).", addtimestamp);
	Dialog.addCheckbox("Delete the temporary files generated during conversion.", deletetempfiles);
	Dialog.show();

	var outtypechoice        = Dialog.getChoice();
	var encodetypechoice     = Dialog.getChoice();
	var framestep            = Dialog.getNumber();
	var converttotemperature = Dialog.getCheckbox();
	var usevirtual           = Dialog.getCheckbox();
	var addtimestamp         = Dialog.getCheckbox();
	var deletetempfiles      = Dialog.getCheckbox();

	call("ij.Prefs.set", "usevirtual.persistent",           toString(usevirtual));
	call("ij.Prefs.set", "converttotemperature.persistent", toString(converttotemperature));
	call("ij.Prefs.set", "addtimestamp.persistent",         toString(addtimestamp));
	call("ij.Prefs.set", "deletetempfiles.persistent",      toString(deletetempfiles));

	var outtype  = outtypechoice;
	var outcodec = encodetypechoice;

	if(outtypechoice == "avi"){   outtype = "avi";  outcodec = encodetypechoice; }
	if(outtypechoice == "png"){   outtype = "png";  outcodec = "png"; }
	if(outtypechoice == "tiff"){  outtype = "tiff"; outcodec = "tiff"; }
	if(outtypechoice == "Raw Stack"){ outtype = "raw"; outcodec = "raw"; }

	ObjectParameters = ConvertFLIRATS(outtype, outcodec, converttotemperature, usevirtual, framestep, addtimestamp, deletetempfiles);

	//ATSObjectCameraParameterPersist(ObjectParameters);
}

// ============================================================
// ConvertFLIRATS()
// Core pipeline: run ats-split.pl via shell -> import .raw stack
// -> optionally convert to temperature
// ============================================================
function ConvertFLIRATS(outtype, outcodec, converttotemperature, usevirtual, framestep, addtimestamp, deletetempfiles){

	getDateAndTime(startyear, startmonth, startdayOfWeek, startdayOfMonth, starthour, startminute, startsecond, startmsec);

	print("\n------ Running ConvertFLIRATS function (MWIR/ATS video import) ------");

	// ---- OS-specific paths ----
	if(OS == "Mac OS X"){
		var perlpath   = perlpathOSX;
		var ffmpegpath = ffmpegpathOSX;
	}
	if(OS == "Linux"){
		var perlpath   = perlpathLinux;
		var ffmpegpath = ffmpegpathLinux;
	}
	if(substring(OS, 0, 5) == "Windo"){
		var perlpath   = perlpathWindows;
		var ffmpegpath = ffmpegpathWindows;
	}

	perl   = perlpath + "perl";
	ffmpeg = ffmpegpath + "ffmpeg";

	// ---- Select file ----
	filepath = File.openDialog("Select a FLIR ATS or ATS-derived JPG File");
	filedir  = File.getParent(filepath);

	// ---- Sanity check ----
	result     = IsFLIRfile(filepath);
	pipepos    = indexOf(result, "|");
	cameratype = substring(result, pipepos+1);
	if(cameratype != "MWIR"){
		print("WARNING: selected file does not appear to be an ATS/MWIR file.");
		print("IsFLIRfile() returned: " + result);
		print("Proceeding anyway -- check results carefully.");
	}

	// ---- Create / clean temp folder ----
	tempfolder = filedir + File.separator + "temp";
	File.makeDirectory(tempfolder);
	print("Removing old files from temporary folder: " + tempfolder);
	deletetempfolder(tempfolder);
	// deletetempfolder() deletes the folder itself as well as its contents,
	// so we must recreate it before ats-split.pl tries to write output there.
	File.makeDirectory(tempfolder);

	print("Loading: " + filepath);
	print("Extracting ATS calibration and image settings via fliratsvalues()");

	// ---- Extract calibration constants ----
	var printvalues = "No";
	atsvals = fliratsvalues(filepath, printvalues);

	NfcB           = atsvals[0];
	NfcR           = atsvals[1];
	NfcF           = atsvals[2];
	NfcC0          = atsvals[3];
	NfcC1          = atsvals[4];
	NfcC2          = atsvals[5];
	NfcMinTemp     = atsvals[6];
	NfcMaxTemp     = atsvals[7];
	NfcMinCounts   = atsvals[8];
	NfcMaxCounts   = atsvals[9];
	NfcATA1        = atsvals[10];
	NfcATA2        = atsvals[11];
	NfcATB1        = atsvals[12];
	NfcATB2        = atsvals[13];
	NfcATX         = atsvals[14];
	NfcE           = atsvals[15];
	NfcOD          = atsvals[16];
	NfcRTemp       = atsvals[17];
	NfcATemp       = atsvals[18];
	NfcIRWTemp     = atsvals[19];
	NfcIRT         = atsvals[20];
	NfcRH          = atsvals[21];
	atsimagewidth  = atsvals[22];
	atsimageheight = atsvals[23];

	print("Extracted ATS Calibration and Object Parameters:");
	Array.print(atsvals);
	print("\n");

	// ---- Output paths ----
	// The .raw file lives alongside the original .ats file (NOT in temp),
	// so it persists for virtual stack access even after temp is deleted.
	rawstackpath  = filedir + File.separator + File.nameWithoutExtension + ".raw";
	timestamppath = tempfolder + File.separator + "timestamps.txt";

	// ---- Run ats-split.pl ----
	// Use exec() with separate arguments (NOT a shell command string) --
	// this is the reliable approach on Mac/Linux in ImageJ. The shell
	// redirect approach (exec("/bin/sh", "-c", cmd)) does not reliably
	// wait for completion before returning in ImageJ's Mac environment.
	// stdout is captured in splitoutput for frame count / fps parsing.
	print("Splitting ATS file into flat raw stack with ats-split.pl");
	print("Command: " + perl + " " + perlsplitats + " -i " + filepath + " -o " + rawstackpath + " -t " + timestamppath);

	splitoutput = exec(perl, perlsplitats, "-i", filepath, "-o", rawstackpath, "-t", timestamppath);
	print(splitoutput);

	// ---- Parse frame count: "Frames detected:  N" ----
	numframes = 1;
	if(indexOf(splitoutput, "Frames detected:") >= 0){
		fdpos     = indexOf(splitoutput, "Frames detected:");
		fdend     = indexOf(splitoutput, "\n", fdpos);
		fdstr     = substring(splitoutput, fdpos + lengthOf("Frames detected:"), fdend);
		numframes = parseInt(trim(fdstr));
		print("Frames detected by ats-split.pl: " + numframes);
	} else {
		print("WARNING: could not parse frame count from ats-split.pl output.");
		print("Defaulting to numframes=1. Re-import manually with the correct frame count if needed.");
	}

	// ---- Parse fps: "Self-derived camera fps (LockinPhase): N Hz" ----
	var frameinterval = 1.0/54.4528;  // default A8581 fallback
	if(indexOf(splitoutput, "Self-derived camera fps") >= 0){
		fpspos = indexOf(splitoutput, "Self-derived camera fps");
		fpsend = indexOf(splitoutput, "Hz", fpspos);
		fpsstr = substring(splitoutput, indexOf(splitoutput, ":", fpspos)+1, fpsend);
		fps    = parseFloat(trim(fpsstr));
		if(fps > 0){
			frameinterval = 1.0/fps;
			print("Frame interval derived from ats-split.pl fps: " + frameinterval + " s");
		}
	}

	// ---- Check the .raw file was created ----
	if(File.exists(rawstackpath) == 0){
		exit("ERROR: ats-split.pl did not produce a .raw file at: " + rawstackpath
			+ "\nCheck the command printed above and verify:\n"
			+ "  1. ats-split.pl is in your Fiji/scripts folder\n"
			+ "  2. perl is accessible at: " + perl + "\n"
			+ "  3. The input file path contains no spaces");
	}

	rawfilesintempfolder = CountFilesByExtension(tempfolder, ".raw");
	print("The number of .RAW files in the temporary folder is: " + rawfilesintempfolder);

	// ---- Import the flat .raw stack ----
	if(outtype == "raw"){
		print("\nImporting flat 16-bit unsigned little-endian raw stack directly");

		if(usevirtual == 1){
			importarguments = "open=[" + rawstackpath + "] image=[16-bit Unsigned] width=" + atsimagewidth + " height=" + atsimageheight + " number=" + numframes + " little-endian use";
		} else {
			importarguments = "open=[" + rawstackpath + "] image=[16-bit Unsigned] width=" + atsimagewidth + " height=" + atsimageheight + " number=" + numframes + " little-endian";
		}
		print("Import arguments: " + importarguments);
		run("Raw...", importarguments);
	}

	if(outtype == "avi" || outtype == "png" || outtype == "tiff"){
		print("\nConverting flat .raw stack to " + outtype + " via ffmpeg");

		pixfmt       = "gray16le";
		playbackrate = parseFloat("" + (1.0/frameinterval));

		if(outtype == "avi"){
			fileout = File.nameWithoutExtension + ".avi";
		}
		if(outtype == "png"){
			outputfolder = filedir + File.separator + File.nameWithoutExtension;
			File.makeDirectory(outputfolder);
			fileout = File.nameWithoutExtension + File.separator + File.nameWithoutExtension + "_%06d.png";
			pixfmt  = "gray16be";
		}
		if(outtype == "tiff"){
			outputfolder = filedir + File.separator + File.nameWithoutExtension;
			File.makeDirectory(outputfolder);
			fileout = File.nameWithoutExtension + File.separator + File.nameWithoutExtension + "_%06d.tiff";
		}

		ffmpegcmd = ffmpeg + " -f rawvideo -pixel_format gray16le -video_size " + atsimagewidth + "x" + atsimageheight + " -framerate " + playbackrate + " -i " + rawstackpath + " -pix_fmt " + pixfmt + " -vcodec " + outcodec + " " + filedir + File.separator + fileout + " -y";
		print("ffmpeg command: " + ffmpegcmd);

		if(OS == "Mac OS X" || OS == "Linux"){
			exec("/bin/sh", "-c", ffmpegcmd);
		}
		if(substring(OS, 0, 5) == "Windo"){
			exec("cmd", "/c", ffmpegcmd);
		}

		if(outtype == "png"){
			print("Importing PNG image sequence");
			run("Image Sequence...", "open=[" + outputfolder + "] sort");
		}
		if(outtype == "tiff"){
			print("Importing TIFF image sequence");
			run("Image Sequence...", "open=[" + outputfolder + "] sort");
		}
		if(outtype == "avi"){
			print("Importing AVI");
			if(usevirtual == 1){
				run("Movie (FFMPEG)...", "choose=[" + filedir + File.separator + fileout + "] use_virtual_stack first_frame=0 last_frame=-1");
			} else {
				run("Movie (FFMPEG)...", "choose=[" + filedir + File.separator + fileout + "] first_frame=0 last_frame=-1");
			}
		}
	}

	// ---- Add relative timestamps as slice labels ----
	// The timestamps.txt file written by ats-split.pl contains one line
	// per frame in format "Frame00001: HH:MM:SS.ffffff", re-referenced
	// to frame 1 = 00:00:00.000000. These are FrameCounter-based elapsed
	// times -- NOT absolute wall-clock timestamps (those aren't stored in
	// ATS files), but accurate relative timing from the recording start.
	if(addtimestamp == 1 && File.exists(timestamppath)){
    print("Adding relative elapsed timestamps as slice labels.");
    tstext  = File.openAsString(timestamppath);
    tslines = split(tstext, "\n");
    setBatchMode(true);
    for(i = 1; i <= nSlices; i++){
        setSlice(i);
        showProgress(i/nSlices);
        if(i <= tslines.length){
            // Each line is "Frame00001: HH:MM:SS.ffffff"
            // Extract just the elapsed time after ": "
            colonpos = indexOf(tslines[i-1], ": ");
            if(colonpos >= 0){
                slicelabel = substring(tslines[i-1], colonpos+2);
            } else {
                slicelabel = tslines[i-1];
            }
        } else {
            slicelabel = "Frame" + i;
        }
        setMetadata("Label", slicelabel);
    }
    	setBatchMode(false);
	}

	// ---- Apply framestep post-import ----
	if(framestep > 1 && nSlices > 1){
		print("Removing frames to apply framestep=" + framestep);
		setBatchMode(true);
		for(s = nSlices; s >= 1; s--){
			if((s-1) % framestep != 0){
				setSlice(s);
				run("Delete Slice", "delete=frame");
			}
		}
		setBatchMode(false);
		print("Frames remaining after framestep: " + nSlices);
	}

	// ---- Set frame interval ----
	call("ij.Prefs.set", "frameinterval.persistent", toString(frameinterval));

	// ---- Clean up temp files ----
	if(deletetempfiles == 1){
		deletetempfolder(tempfolder);
	}

	// ---- Convert to temperature ----
	if(converttotemperature == 1){
		print("Converting stack to temperature using Counts2Temp (MWIR/NFC calibration)");
		ObjectParameters = Counts2Temp(
			NfcCvals(NfcC0, NfcC1, NfcC2),
			NfcPlanckVals(NfcB, NfcR, NfcF),
			AtmosphericTransVals(NfcATA1, NfcATA2, NfcATB1, NfcATB2, NfcATX),
			NfcE, NfcOD, NfcRTemp, NfcATemp, NfcIRWTemp, NfcIRT, NfcRH,
			NfcMinCounts, NfcMaxCounts,
			defaultpalette, "Yes", "Fast",
			imagetemperaturemin, imagetemperaturemax
		);
	}

	run("Animation Options...", "speed=30");

	getDateAndTime(endyear, endmonth, enddayOfWeek, enddayOfMonth, endhour, endminute, endsecond, endmsec);
	elapsedminutes = (endhour-starthour)*60 + (endminute-startminute) + (endsecond-startsecond)/60 + (endmsec-startmsec)/(60*1000);
	print("The number of minutes to process your ATS video: " + elapsedminutes);
	print("Done Importing ATS Video");
	print("\n");

	return ObjectParameters;
}

// ============================================================
// MWIR / ATS (NicevilleFactoryCal-derived "nfc" model) temperature
// conversion functions.
//
// These are DELIBERATELY SEPARATE from Raw2Temp / Raw2TempCalc /
// Temp2RawCalc, which implement the LWIR/exiftool-style 5-constant
// Planck-on-radiance-with-offset formula:
//
//     temp = PB / log( PR1/(PR2*(raw+PO)) + PF ) - 273.15
//
// The nfc/MWIR model is structurally different in two ways:
//   1. The stored 16-bit pixel "counts" are NOT directly radiance --
//      they must first be converted to radiance via a quadratic
//      polynomial (NfcC0, NfcC1, NfcC2), confirmed against real
//      ATSFileUtil .inc exports (see ats-jpg-and-xml-notes.md).
//   2. The radiance-to-temperature step has NO offset term (no PO
//      equivalent) -- confirmed via direct comparison against real
//      TIFF pixel values (RMSE ~0.0001 C) to be what FLIR Research
//      Studio actually uses for these files:
//
//     temp = NfcB / log( NfcR/radiance + NfcF ) - 273.15
//
// Object-parameter / atmospheric-attenuation correction (reflected
// temperature, atmosphere, window, humidity, distance) uses the SAME
// physical model and tau-formula as Raw2TempCalc/Raw2Temp -- only the
// underlying "raw <-> radiance" relationship at each correction step
// changes, replaced by NfcB/NfcR/NfcF (no PO) instead of
// PR1/PR2/PB/PF/PO.
// ============================================================


// Bundles the 3 counts->radiance polynomial constants into one array,
// mirroring AtmosphericTransVals()'s existing bundling convention.

function NfcCvals(NfcC0, NfcC1, NfcC2){
	Cvals=newArray(NfcC0, NfcC1, NfcC2);
	return Cvals;
}

// Bundles the 3 radiance->temperature constants into one array, same
// convention.
function NfcPlanckVals(NfcB, NfcR, NfcF){
	Pvals=newArray(NfcB, NfcR, NfcF);
	return Pvals;
}


// ============================================================
// Counts2Radiance()
//
// Step 1 of the nfc model: converts a raw 16-bit pixel "counts" value
// into radiance, via the quadratic polynomial confirmed against real
// ATSFileUtil .inc exports.
// ============================================================
function Counts2Radiance(counts, Cvals){

	NfcC0=Cvals[0];
	NfcC1=Cvals[1];
	NfcC2=Cvals[2];

	radiance = NfcC0 + NfcC1*counts + NfcC2*counts*counts;

	return radiance;
}


// ============================================================
// Counts2TempCalc()
//
// Single-value MWIR/nfc equivalent of Raw2TempCalc(). Converts one
// raw counts value into temperature (C), applying the same object-
// parameter / atmospheric-attenuation correction model as
// Raw2TempCalc, but via the two-step counts->radiance->temperature
// nfc chain instead of the single-step LWIR Planck-with-offset
// formula.
// ============================================================
function Counts2TempCalc(counts, Cvals, Pvals, ATvals, NfcE, NfcOD, NfcRTemp, NfcATemp, NfcIRWTemp, NfcIRT, NfcRH){

	NfcB=Pvals[0];
	NfcR=Pvals[1];
	NfcF=Pvals[2];

	NfcATA1=ATvals[0];
	NfcATA2=ATvals[1];
	NfcATB1=ATvals[2];
	NfcATB2=ATvals[3];
	NfcATX=ATvals[4];

	emisswind = 1- NfcIRT;
	reflwind = 0; // anti-reflective coating on window
	h2o = (NfcRH/100)*exp(1.5587+0.06939*(NfcATemp)-0.00027816*(NfcATemp*NfcATemp)+0.00000068455*(NfcATemp*NfcATemp*NfcATemp)); // converts relative humidity into water vapour pressure (I think in units mmHg)
	tau1 = NfcATX*exp(-sqrt(NfcOD)*(NfcATA1+NfcATB1*sqrt(h2o)))+(1-NfcATX)*exp(-sqrt(NfcOD)*(NfcATA2+NfcATB2*sqrt(h2o))); // atmos transmittance from object to window
	tau2=1; 
	// after checking with FLIR Research Studio and Minkina's book, setting tau2=1 is when window is closest to the sensor
	
	// Each correction term below needs the RADIANCE corresponding to
	// a reference temperature -- this is the INVERSE of the
	// radiance->temperature step (solve NfcB/log(NfcR/L+NfcF)-273.15=T
	// for L), i.e. L = NfcR/(exp(NfcB/(T+273.15))-NfcF).

	radrefl1 = NfcR/(exp(NfcB/(NfcRTemp+273.15))-NfcF);   // radiance reflecting off the object before the window
	radrefl1attn = (1-NfcE)/NfcE*radrefl1;   // attn = the attenuated radiance

	radatm1 = NfcR/(exp(NfcB/(NfcATemp+273.15))-NfcF); // radiance from the atmosphere (before the window)
	radatm1attn = (1-tau1)/NfcE/tau1*radatm1;

	radwind = NfcR/(exp(NfcB/(NfcIRWTemp+273.15))-NfcF);
	radwindattn = emisswind/NfcE/tau1/NfcIRT*radwind;

	radrefl2 = NfcR/(exp(NfcB/(NfcRTemp+273.15))-NfcF);
	radrefl2attn = reflwind/NfcE/tau1/NfcIRT*radrefl2;

	radatm2 = NfcR/(exp(NfcB/(NfcATemp+273.15))-NfcF);
	radatm2attn = (1-tau2)/NfcE/tau1/NfcIRT/tau2*radatm2;

	radsubtract = (radatm1attn + radatm2attn + radwindattn + radrefl1attn + radrefl2attn);
	raddivisor = NfcE*tau1*NfcIRT*tau2;

	radiance = Counts2Radiance(counts, Cvals);

	radobj = (radiance/raddivisor - radsubtract);

	tempC = NfcB/log(NfcR/radobj+NfcF)-273.15;

	return tempC;
}


// ============================================================
// Counts2Temp()
//
// MWIR/nfc equivalent of Raw2Temp(). Bulk image/stack converter,
// mirroring Raw2Temp's structure closely (same dialog layout style,
// same Fast/Slow modes, same ij.Prefs.persistent saving), but built
// on the two-step nfc counts->radiance->temperature chain instead of
// the single-step LWIR Planck-with-offset formula, and WITHOUT a
// Planck O term (the nfc model has none).
//
// FAST MODE SAMPLING RANGE: unlike Raw2Temp's fast mode (which always
// samples 655 points evenly across the full 0-65535 16-bit range),
// this function samples across [NfcMinCounts, NfcMaxCounts] -- the
// camera's own confirmed valid calibration range (e.g. roughly
// 1559-12092 for the reference A8581 camera) -- since the nfc model's
// validity is only confirmed within that narrower window anyway, and
// sampling the full 16-bit range would waste most of the 655 points
// on counts values the camera never actually produces.
// ============================================================
function Counts2Temp(Cvals, Pvals, ATvals, E, OD, RTemp, ATemp, IRWTemp, IRT, RH, NfcMinCounts, NfcMaxCounts, palettetype, dialogprompt, FastSlow, imagetemperaturemin, imagetemperaturemax){

	NfcB=Pvals[0];
	NfcR=Pvals[1];
	NfcF=Pvals[2];

	NfcATA1=ATvals[0];
	NfcATA2=ATvals[1];
	NfcATB1=ATvals[2];
	NfcATB2=ATvals[3];
	NfcATX=ATvals[4];

	print("\n------ Running Counts2Temp function (MWIR / ATS-style nfc calibration) ------");

	if(is("Virtual Stack")==1 && FastSlow=="Slow"){
		print("Cannot perform conversions on a virtual stack.  Duplicating stack first.\nThis is slow and it is recommended that you crop and edit first before using the slow calculation");
		run("Duplicate...", "duplicate");
	}

	if(dialogprompt=="Yes"){
		fastslowchoicedefault="Fast";
		fastslowchoice=newArray("Slow", "Fast");
		
		Dialog.create("Verify ATS Camera and Object Parameters");
		Dialog.addMessage("If Calibration constants are unknown, run the FLIR Calibration Values Tool first!");
		Dialog.addMessage("Fast calculation is approximate but repeatable. Slow is accurate but not reversible.");
		Dialog.addChoice("Fast or Slow Calculation?", fastslowchoice, fastslowchoicedefault);
		Dialog.addNumber("Estimated Image Temperature Minimum:", imagetemperaturemin, 0, 5, "C");
		Dialog.addNumber("Estimated Image Temperature Maximum:", imagetemperaturemax, 0, 5, "C");

		Dialog.addMessage("Object Parameters:");
		Dialog.addNumber("Object Emissivity:", NfcE, 3, 6, "unitless");
		Dialog.addToSameRow();
		Dialog.addNumber("Object Distance:", NfcOD, 1, 6, "m");
		Dialog.addNumber("Reflected Temperature (C):", NfcRTemp, 2, 6, "C");
		Dialog.addToSameRow();
		Dialog.addNumber("Atmospheric Temperature (C):", NfcATemp, 2, 6, "C");
		Dialog.addNumber("Window Temperature (C):", NfcIRWTemp, 2, 6, "C");
		Dialog.addToSameRow();
		Dialog.addNumber("Window Transmittance:", NfcIRT, 3, 6, "unitless");
		Dialog.addNumber("Relative Humidity:", NfcRH, 2, 6, "%");
		Dialog.addToSameRow();
		Dialog.addChoice("Palette", palettetypes, defaultpalette);

		Dialog.addMessage("Camera Calibration Constants (NicevilleFactoryCal):");
		Dialog.addNumber("Nfc B:", NfcB, 4, 12, "unitless");
		Dialog.addToSameRow();
		Dialog.addNumber("Nfc R:", NfcR, 6, 12, "unitless");
		Dialog.addNumber("Nfc F:", NfcF, 4, 6, "unitless");
		Dialog.addNumber("Nfc C0:", NfcC0, 20, 20, "unitless");
		Dialog.addToSameRow();
		Dialog.addNumber("Nfc C1:", NfcC1, 20, 20, "unitless");
		Dialog.addNumber("Nfc C2:", NfcC2, 20, 20, "unitless");
		Dialog.addNumber("Atmospheric Trans Alpha 1:", NfcATA1, 8, 12, "unitless");
		Dialog.addToSameRow();
		Dialog.addNumber("Atmospheric Trans Alpha 2:", NfcATA2, 8, 12, "unitless");
		Dialog.addNumber("Atmospheric Trans Beta 1:", NfcATB1, 8, 12, "unitless");
		Dialog.addToSameRow();
		Dialog.addNumber("Atmospheric Trans Beta 2:", NfcATB2, 8, 12, "unitless");
		Dialog.addNumber("Atmospheric Trans X:", NfcATX, 8, 12, "unitless");
		Dialog.addMessage("Counts range (used to construct fast-mode polynomial within scene temp range):");
		Dialog.addNumber("Nfc Min Counts:", NfcMinCounts, 0, 8, "16-bit integer");
		Dialog.addToSameRow();
		Dialog.addNumber("Nfc Max Counts:", NfcMaxCounts, 0, 8, "16-bit integer");

		Dialog.show();

		FastSlow          = Dialog.getChoice();
		imagetemperaturemin = Dialog.getNumber();
		imagetemperaturemax = Dialog.getNumber();
		NfcE              = Dialog.getNumber();
		NfcOD             = Dialog.getNumber();
		NfcRTemp          = Dialog.getNumber();
		NfcATemp          = Dialog.getNumber();
		NfcIRWTemp        = Dialog.getNumber();
		NfcIRT            = Dialog.getNumber();
		NfcRH             = Dialog.getNumber();
		palettetype       = Dialog.getChoice();
		NfcB              = Dialog.getNumber();
		NfcR              = Dialog.getNumber();
		NfcF              = Dialog.getNumber();
		NfcC0             = Dialog.getNumber();
		NfcC1             = Dialog.getNumber();
		NfcC2             = Dialog.getNumber();
		NfcATA1           = Dialog.getNumber();
		NfcATA2           = Dialog.getNumber();
		NfcATB1           = Dialog.getNumber();
		NfcATB2           = Dialog.getNumber();
		NfcATX            = Dialog.getNumber();
		NfcMinCounts      = Dialog.getNumber();
		NfcMaxCounts      = Dialog.getNumber();


	// ---- Persist values ----
	call("ij.Prefs.set", "imagetemperaturemin.persistent", toString(imagetemperaturemin));
	call("ij.Prefs.set", "imagetemperaturemax.persistent", toString(imagetemperaturemax));
	call("ij.Prefs.set", "NfcB.persistent",   toString(NfcB));
	call("ij.Prefs.set", "NfcR.persistent",   toString(NfcR));
	call("ij.Prefs.set", "NfcF.persistent",   toString(NfcF));
	call("ij.Prefs.set", "NfcC0.persistent",  toString(NfcC0));
	call("ij.Prefs.set", "NfcC1.persistent",  toString(NfcC1));
	call("ij.Prefs.set", "NfcC2.persistent",  toString(NfcC2));
	call("ij.Prefs.set", "NfcATA1.persistent",toString(NfcATA1));
	call("ij.Prefs.set", "NfcATA2.persistent",toString(NfcATA2));
	call("ij.Prefs.set", "NfcATB1.persistent",toString(NfcATB1));
	call("ij.Prefs.set", "NfcATB2.persistent",toString(NfcATB2));
	call("ij.Prefs.set", "NfcATX.persistent", toString(NfcATX));
	call("ij.Prefs.set", "NfcE.persistent",   toString(NfcE));
	call("ij.Prefs.set", "NfcOD.persistent",  toString(NfcOD));
	call("ij.Prefs.set", "NfcRTemp.persistent",  toString(NfcRTemp));
	call("ij.Prefs.set", "NfcATemp.persistent",  toString(NfcATemp));
	call("ij.Prefs.set", "NfcIRWTemp.persistent",toString(NfcIRWTemp));
	call("ij.Prefs.set", "NfcIRT.persistent", toString(NfcIRT));
	call("ij.Prefs.set", "NfcRH.persistent",  toString(NfcRH));
	call("ij.Prefs.set", "NfcMinCounts.persistent", toString(NfcMinCounts));
	call("ij.Prefs.set", "NfcMaxCounts.persistent", toString(NfcMaxCounts));

	}

	if(is("Virtual Stack")==1 && FastSlow=="Slow"){
		print("Cannot perform conversions on a virtual stack.  Duplicating stack first.\nThis is slow and it is recommended that you crop and edit first before using the slow calculation");
		run("Duplicate...", "duplicate");
	}

	Pvals=NfcPlanckVals(NfcB, NfcR, NfcF);
	ATvals=AtmosphericTransVals(NfcATA1, NfcATA2, NfcATB1, NfcATB2, NfcATX);

	emisswind = 1- NfcIRT;
	reflwind = 0;
	h2o = (NfcRH/100)*exp(1.5587+0.06939*(NfcATemp)-0.00027816*(NfcATemp*NfcATemp)+0.00000068455*(NfcATemp*NfcATemp*NfcATemp));
	tau1 = NfcATX*exp(-sqrt(NfcOD)*(NfcATA1+NfcATB1*sqrt(h2o)))+(1-NfcATX)*exp(-sqrt(NfcOD)*(NfcATA2+NfcATB2*sqrt(h2o)));
	tau2=1;
	
	radrefl1 = NfcR/(exp(NfcB/(NfcRTemp+273.15))-NfcF);
	radrefl1attn = (1-NfcE)/NfcE*radrefl1;

	radatm1 = NfcR/(exp(NfcB/(NfcATemp+273.15))-NfcF);
	radatm1attn = (1-tau1)/NfcE/tau1*radatm1;

	radwind = NfcR/(exp(NfcB/(NfcIRWTemp+273.15))-NfcF);
	radwindattn = emisswind/NfcE/tau1/IRT*radwind;

	radrefl2 = NfcR/(exp(NfcB/(NfcRTemp+273.15))-NfcF);
	radrefl2attn = reflwind/NfcE/tau1/NfcIRT*radrefl2;

	radatm2 = NfcR/(exp(NfcB/(NfcATemp+273.15))-NfcF);
	radatm2attn = (1-tau2)/NfcE/tau1/NfcIRT/tau2*radatm2;

	radsubtract = (radatm1attn + radatm2attn + radwindattn + radrefl1attn + radrefl2attn);
	raddivisor = NfcE*tau1*NfcIRT*tau2;

if(FastSlow=="Fast"){

		// Find counts values corresponding to imagetemperaturemin and
		// imagetemperaturemax via binary search on Counts2TempCalc.
		// This concentrates all 655 sample points within the scene's
		// actual temperature range, giving a much tighter polynomial
		// fit than sampling the full camera calibration range would.
		// Results are clamped to [NfcMinCounts, NfcMaxCounts] so the
		// NfcC0/C1/C2 quadratic is never used outside its valid range,
		// even if the user enters temperatures beyond the camera's limits.
		npoints=655;

		// Binary search for counts at imagetemperaturemin
		lo=NfcMinCounts; hi=NfcMaxCounts;
		for(iter=0; iter<60; iter++){
			mid=(lo+hi)/2;
			t_mid=Counts2TempCalc(mid, Cvals, Pvals, ATvals, NfcE, NfcOD, NfcRTemp, NfcATemp, NfcIRWTemp, NfcIRT, NfcRH);
			if(t_mid < imagetemperaturemin){ lo=mid; } else { hi=mid; }
		}
		counts_at_tempmin = maxOf(NfcMinCounts, minOf(NfcMaxCounts, (lo+hi)/2));

		// Binary search for counts at imagetemperaturemax
		lo=NfcMinCounts; hi=NfcMaxCounts;
		for(iter=0; iter<60; iter++){
			mid=(lo+hi)/2;
			t_mid=Counts2TempCalc(mid, Cvals, Pvals, ATvals, NfcE, NfcOD, NfcRTemp, NfcATemp, NfcIRWTemp, NfcIRT, NfcRH);
			if(t_mid < imagetemperaturemax){ lo=mid; } else { hi=mid; }
		}
		counts_at_tempmax = maxOf(NfcMinCounts, minOf(NfcMaxCounts, (lo+hi)/2));

		step = (counts_at_tempmax - counts_at_tempmin) / (npoints-1);

		c = newArray(npoints);
		templookup=newArray(npoints);

		for (i=0; i<npoints; i++) {
			showProgress(i/npoints);
			c[i] = counts_at_tempmin + i*step;
			templookup[i] = Counts2TempCalc(c[i], Cvals, Pvals, ATvals, NfcE, NfcOD, NfcRTemp, NfcATemp, NfcIRWTemp, NfcIRT, NfcRH);
		}

		x=newArray(npoints);
		y=newArray(npoints);

		text1="text1=[";
		text2="text2=[";

		for(i=0; i<npoints; i++){
			showProgress(i/npoints);
			x[i]=c[i];
			y[i]=templookup[i];
			text1=text1 + d2s(c[i], 0) + " ";
			text2=text2 + d2s(templookup[i], 12) + " ";
		}

		Fit.doFit("4th Degree Polynomial", x, y);
		Fit.logResults;
		predicted=newArray(npoints);
		resid=newArray(npoints);
		for(i=0; i<npoints; i++){
			predicted[i]=Fit.f(x[i]);
			resid[i]=predicted[i]-y[i];
		}

		Array.getStatistics(resid, min, max, mean);

		rms_resid=RMS(resid);

		Fit.getEquation(3, name, formula);

		print("To reduce computational time, temperature was estimated using a 4th order polynomial");
		print("655 data points evenly spanning the scene counts range");
		print("(counts at imagetemperaturemin=" + imagetemperaturemin + "C = " + d2s(counts_at_tempmin,0) + " to counts at imagetemperaturemax=" + imagetemperaturemax + "C = " + d2s(counts_at_tempmax,0) + ")");
		print("were used to construct the following curve (clamped to NfcMinCounts=" + NfcMinCounts + " / NfcMaxCounts=" + NfcMaxCounts + "):");
		print(formula);
		print("where y = Temperature, x = 16-bit counts value, and a,b,c,d,e are the coefficients:");
		print("a = " + Fit.p(0));
		print("b = " + Fit.p(1));
		print("c = " + Fit.p(2));
		print("d = " + Fit.p(3));
		print("e = " + Fit.p(4));
		print("r squared = " + Fit.rSquared);
		print("The root mean square of the error from polynomial predicted temperature using the fast calculation is:", rms_resid, "degrees C");
		print("The maximum mathematical error detected using the polynomial fit is:", max, "degrees C");
		print("Errors will be highest if counts values in the image fall outside the sampled range.");
		print("If this error is too high, re-run with more stringent image minimum and maximum, or select the Slow calculation.");

		text1=text1 + "] ";
		text2=text2 + "] ";

		calibrateargument = "function=[4th Degree Polynomial] unit=°C " + text1 + text2 + "global";

		run("Calibrate...", calibrateargument);

		getStatistics(count, mean, min, max);

		toohigh=0; toolow=0;
		if(max > imagetemperaturemax){
			toohigh=1;
		}

		if(min  < imagetemperaturemin){
			toolow=1;
		}
		outofrange=toohigh+toolow;

		if(outofrange>0){
			print(" ------- WARNING -------");
			print("Minimum estimated temperature = ", min);
			print("Maximum estimated temperature = ", max);
			print("Temperatures calculated fall outside your expected image min and max values and are likely subject to extrapolation errors.");
			print("Please recalculate using the fast option with wider min or max ranges.");
		}
	}

	if(FastSlow=="Slow"){
		// remove any latent calibration on the raw 16-bit data
		run("Calibrate...", "function=[Straight Line] unit=C text1=[0 1] text2=[0 1] global");

		// The slow path needs to apply: counts -> radiance (quadratic)
		// -> temperature (nfc Planck, no offset), all pixel-by-pixel,
		// via ImageJ's "Macro..." code= mechanism (same approach as
		// Raw2Temp's slow path, just substituting the nfc formula and
		// inserting the counts->radiance polynomial step inline since
		// "Macro..." code= cannot call a separate user-defined macro
		// function on each pixel -- it must be a single expression).
		//
		// radiance = NfcC0 + NfcC1*v + NfcC2*v*v
		// radobj = (radiance/raddivisor - radsubtract)
		// tempC = NfcB/log(NfcR/radobj+NfcF)-273.15

		nfcCstr = "(" +Cvals[0]+ "+" +Cvals[1]+ "*v+" +Cvals[2]+ "*v*v)";
		radobjstr = "(" + nfcCstr + "/" +raddivisor+ "-" +radsubtract+ ")";
		codestr = "v=" +NfcB+ "/log(" +NfcR+ "/" + radobjstr + "+" +NfcF+ ")-273.15";
		
		//print(codestr);
		
		if(nSlices()>1){
		run("32-bit", "stack");
		run("Macro...", "code=" + codestr + " stack");
		Stack.getStatistics(count, mean, min, max);
		mintemp=min;
		maxtemp=max;
		setMinAndMax(mintemp, maxtemp);
		}

		if(nSlices()==1){
		run("32-bit");
		run("Macro...", "code=" + codestr);
		getStatistics(count, mean, min, max);
		mintemp=min;
		maxtemp=max;
		setMinAndMax(mintemp, maxtemp);
		}

	}

	run(palettetype);

	output=newArray(NfcB, NfcR, NfcF, Cvals[0], Cvals[1], Cvals[2], NfcATA1, NfcATA2, NfcATB1, NfcATB2, NfcATX, NfcE, NfcOD, NfcRTemp, NfcATemp, NfcIRWTemp, NfcIRT, NfcRH, NfcMinCounts, NfcMaxCounts);

	return output;

}



// Added CalculateTransmittance and CalculateEmissivity May 2020

function CalculateTransmittance() {
	
	// Create a prompt dialog to ask user to verify the values to be used in the calculations below
    print("\n------ Running CalculateTransmittance function ------");
    print("Not fully tested.  Please confirm these calculations using FLIR software");
    print("This macro will estimate the transmittance of a window that is placed in front of an object.");
	print("The true object temperature must first be known, usually measured without the window in place.");
	print("User provides the raw 16 bit value of the object but measured with the window in place");
	//print("Predicted temperature from the provided raw value, if IRT were truly equal to 1 is: " + raw2temppred);
	//print("Use this to verify the raw value selected is approximately close to the known temperature");
	
	//ApparentRaw=Temp2RawCalc(KnownT, PR1, PR2, PB, PF, PO, AtmosphericTransVals(ATA1, ATA2, ATB1, ATB2, ATX), E, OD, RTemp, ATemp, IRWTemp, 1, RH);

	print("Next, this function will use the raw2temp function, but only changing transmittance");
	print("from 0 to 1, in 0.001 increments, and return the transmittance value that best results in the true temperature");
	print("Default parameters are for a hypothetical object of 40 degrees C and apparent raw 16-bit value of 21000");
	
	KnownT = 40;
	ApparentRaw=21000;
	
	Dialog.create("Estimate Window Transmittance");
	Dialog.addMessage("This macro will estimate IR Window Transmittance (IRT)\nassuming you have accurate information on true temperature");
	Dialog.addMessage("Provide the Object Parameters:");
    Dialog.addNumber("Object Emissivity:", E, 3, 6, "unitless");
    Dialog.addNumber("Object Distance:", OD, 1, 6, "m");
    Dialog.addNumber("Reflected Temperature (C):", RTemp, 2, 6, "C");
    Dialog.addNumber("Atmospheric Temperature (C):", ATemp, 2, 6, "C");
    Dialog.addNumber("Window Temperature (C):", IRWTemp, 2, 6, "C");
    Dialog.addNumber("Relative Humidity:", RH, 2, 6, "%");
    
    Dialog.addMessage("Provide Object Thermal Information:\n");
  	Dialog.addNumber("Object temperature (i.e. known temperature):", KnownT, 2, 6, "C");
	Dialog.addNumber("Raw 16 bit value of this object with window:", ApparentRaw, 0, 6, "16-bit integer");
	
	Dialog.addMessage("Provide Camera Calibration Constants:");
	Dialog.addNumber("Planck R1:", PR1, 2, 12, "unitless"); //21106.77 //21546.203
	Dialog.addNumber("Planck R2:", PR2, 8, 12, "unitless"); //0.012545258 //0.016229488 
	Dialog.addNumber("Planck B:", PB, 0, 5, "unitless"); //1501 //1507.2
	Dialog.addNumber("Planck F:", PF, 0, 2, "unitless");//1
    Dialog.addNumber("Planck O:", PO, 0, 5, "unitless"); //-7340 //-6331
    Dialog.addNumber("Atmospheric Trans Alpha 1:", ATA1, 8, 12, "unitless");
    Dialog.addNumber("Atmospheric Trans Alpha 2:", ATA2, 8, 12, "unitless");
    Dialog.addNumber("Atmospheric Trans Beta 1:", ATB1, 8, 12, "unitless");
    Dialog.addNumber("Atmospheric Trans Beta 2:", ATB2, 8, 12, "unitless");
    Dialog.addNumber("Atmospheric Trans X:", ATX, 8, 12, "unitless");

	Dialog.addCheckbox("Store calculated transmittance (IRT) in memory for future use?", 0);
	
	Dialog.show();
	
	var E = Dialog.getNumber();
	var OD = Dialog.getNumber();
	var RTemp = Dialog.getNumber();
	var ATemp = Dialog.getNumber();
	var IRWTemp = Dialog.getNumber();
    //	var IRT = Dialog.getNumber();
	var RH = Dialog.getNumber();
	var KnownT = Dialog.getNumber();
	var ApparentRaw = Dialog.getNumber();
	
	var PR1 = Dialog.getNumber();
	var PR2 = Dialog.getNumber();
	var PB = Dialog.getNumber();
	var PF = Dialog.getNumber();
	var PO = Dialog.getNumber();
	var ATA1 = Dialog.getNumber();
	var ATA2 = Dialog.getNumber();
	var ATB1 = Dialog.getNumber();
	var ATB2 = Dialog.getNumber();
	var ATX = Dialog.getNumber();

	storeIRT=Dialog.getCheckbox();
	
	TempArray=newArray(1001);
	IRTArray=newArray(1001);
	IRTArray=Array.getSequence(1001);
	
	for (i = 0; i < 1001; i++) {
		IRTArray[i]=IRTArray[i]/1000;	
	}

	raw2temppred=Raw2TempCalc(ApparentRaw, PR1, PR2, PB, PF, PO, AtmosphericTransVals(ATA1, ATA2, ATB1, ATB2, ATX), E, OD, RTemp, ATemp, IRWTemp, 1, RH);
	
	
	
	for (i = 0; i < 1001; i++) {
		TempArray[i]=Raw2TempCalc(ApparentRaw, PR1, PR2, PB, PF, PO, AtmosphericTransVals(ATA1, ATA2, ATB1, ATB2, ATX), E, OD, RTemp, ATemp, IRWTemp, IRTArray[i], RH);
	}

	// need to add a match function that searched through the temp array to find which temperature is closest to KnownT to 
	// find the effective transmittance.
	tempdiff=newArray(1001);

	print("The IRT yielding a closest match to the known temperature is the estimated IRT:");
	
	// tempdiff will calculate the difference between KnownT and estimated T.  
	for (i = 0; i < 1001; i++) {
		tempdiff[i]=abs(TempArray[i]-KnownT);
	}
	
	ranklocation=doSort(tempdiff);
	// the position of the minimum temp diff should correspond to the appropriate IRT that provides the KnownT
	// the 0th ranklocation should provide the location within the tempdiff array that corresponds to the minimum


	// Do a sanity check.  If the minimum temperature difference isn't within a tolerable range (i.e. 0.5 = 0.5 Celsius),
	// then flag the calculation as suspect.
		

	IRT=IRTArray[ranklocation[0]];
	print(IRT);
	print("\n");

	if(tempdiff[ranklocation[0]]>0.5){
		IRT=1;
		Dialog.create("Window Transmittance");
		Dialog.addMessage("Warning: Results out of range!");
		Dialog.addMessage("The default window transmittance estimate is:");
		Dialog.addMessage("     " + IRT);
		Dialog.addMessage("Please check the raw 16 bit value, object parameters,\n or calibration constants and try again.");
		Dialog.show();
		print("Warning: Results out of range!");
		print("The algorithm cannot find a suitable transmittance, defaults to 1");
	}

	if(tempdiff[ranklocation[0]]<=0.5){
		Dialog.create("Window Transmittance");
		Dialog.addMessage("The window transmittance is estimated as:");
		Dialog.addMessage("     " + IRT);
		Dialog.addMessage("Compare this transmittance to your expected values");
		Dialog.addMessage("e.g. Germanium windows are ~0.94-0.95 with IR anti-reflective coating");
		Dialog.show();
	}

	if(storeIRT==1) {
		call("ij.Prefs.set", "IRT.persistent",toString(IRT)); 
	}
	
}


function CalculateEmissivity() {
	
	// Create a prompt dialog to ask user to verify the values to be used in the calculations below
	
    print("\n------ Running CalculateEmissivity function ------");
    print("Not fully tested.  Confirm these calculations using FLIR software");
    print("This macro will estimate the emissivity of a novel surface.");
	print("The object temperature must first be known, usually measured with black electrical tape, assuming thermal equilibration.");
	print("Alternatively, user may paint onto the surface a small patch, provided the emissivity of that paint is known. This also assumes thermal equilibration");
	print("User provides the estimated temperature of the object of interest, measured assuming same E as the reference E.");
	print("If the unknown Emissivity is the same as the Known Emissivity, then the 2 temperatures should equal one another");
	//print("Predicted raw from the provided temperature estimate, if E were truly equal to the reference E is: " + ApparentRaw);
	//print("Use this to verify the raw value selected is approximately close to the known temperature");
	
	//ApparentRaw=Temp2RawCalc(KnownT, PR1, PR2, PB, PF, PO, AtmosphericTransVals(ATA1, ATA2, ATB1, ATB2, ATX), E, OD, RTemp, ATemp, IRWTemp, 1, RH);

	print("This macro creates an array of predicted temperatures, by only changing new object Emissivity");
	print("from 0 to 1, in 0.001 increments.  The Emissivity that results in a calculated temperature that matches the known temperature");
	print("allows for the unknown emissivity to be estimated.");
	print("The principle follows that outlined in FLIR Documentation for Research and Professional Thermographers.");
	
	KnownE = E;
	KnownT = 52;
	ApparentTemp=50;
		
	Dialog.create("Estimate Window Transmittance");
	Dialog.addMessage("This macro will estimate Emissivity assuming you have\naccurate information on true temperature usually provided\nby using a reference surface of known Emissivity (i.e. black electrical tape E = 0.95)");
	Dialog.addMessage("Provide the Object Parameters:");
    Dialog.addNumber("Reference Emissivity:", KnownE, 3, 6, "unitless");
    Dialog.addNumber("Object Distance:", OD, 1, 6, "m");
    Dialog.addNumber("Reflected Temperature (C):", RTemp, 2, 6, "C");
    Dialog.addNumber("Atmospheric Temperature (C):", ATemp, 2, 6, "C");
    Dialog.addNumber("Window Temperature (C):", IRWTemp, 2, 6, "C");
    Dialog.addNumber("Window Transmittance:", IRT, 3, 6, "unitless");
    Dialog.addNumber("Relative Humidity:", RH, 2, 6, "%");
    
    Dialog.addMessage("Provide Object Thermal Information:\n");
  	Dialog.addNumber("Reference Object temperature (i.e. known temperature):", KnownT, 2, 6, "C");
	Dialog.addNumber("New Object Apparent temperature, assuming reference Emissivity:", ApparentTemp, 2, 6, "C");
	
	Dialog.addMessage("Provide Camera Calibration Constants:");
	Dialog.addNumber("Planck R1:", PR1, 2, 12, "unitless"); //21106.77 //21546.203
	Dialog.addNumber("Planck R2:", PR2, 8, 12, "unitless"); //0.012545258 //0.016229488 
	Dialog.addNumber("Planck B:", PB, 0, 5, "unitless"); //1501 //1507.2
	Dialog.addNumber("Planck F:", PF, 0, 2, "unitless");//1
    Dialog.addNumber("Planck O:", PO, 0, 5, "unitless"); //-7340 //-6331
    Dialog.addNumber("Atmospheric Trans Alpha 1:", ATA1, 8, 12, "unitless");
    Dialog.addNumber("Atmospheric Trans Alpha 2:", ATA2, 8, 12, "unitless");
    Dialog.addNumber("Atmospheric Trans Beta 1:", ATB1, 8, 12, "unitless");
    Dialog.addNumber("Atmospheric Trans Beta 2:", ATB2, 8, 12, "unitless");
    Dialog.addNumber("Atmospheric Trans X:", ATX, 8, 12, "unitless");

	Dialog.addCheckbox("Store calculated Emissivity (E) in memory for future use?", 0);
	
	Dialog.show();
	
	var KnownE = Dialog.getNumber();
	var OD = Dialog.getNumber();
	var RTemp = Dialog.getNumber();
	var ATemp = Dialog.getNumber();
	var IRWTemp = Dialog.getNumber();
   	var IRT = Dialog.getNumber();
	var RH = Dialog.getNumber();
	
	var KnownT = Dialog.getNumber();
	var ApparentTemp = Dialog.getNumber();
	
	var PR1 = Dialog.getNumber();
	var PR2 = Dialog.getNumber();
	var PB = Dialog.getNumber();
	var PF = Dialog.getNumber();
	var PO = Dialog.getNumber();
	var ATA1 = Dialog.getNumber();
	var ATA2 = Dialog.getNumber();
	var ATB1 = Dialog.getNumber();
	var ATB2 = Dialog.getNumber();
	var ATX = Dialog.getNumber();

	storeE = Dialog.getCheckbox();
	
	TempArray=newArray(1001);
	EArray=newArray(1001);
	EArray=Array.getSequence(1001);
	
	for (i = 0; i < 1001; i++) {
		EArray[i]=EArray[i]/1000;	
	}
		
	ApparentRaw=Temp2RawCalc(ApparentTemp, PR1, PR2, PB, PF, PO, AtmosphericTransVals(ATA1, ATA2, ATB1, ATB2, ATX), KnownE, OD, RTemp, ATemp, IRWTemp, IRT, RH);
	
	
	for (i = 0; i < 1001; i++) {
		TempArray[i]=Raw2TempCalc(ApparentRaw, PR1, PR2, PB, PF, PO, AtmosphericTransVals(ATA1, ATA2, ATB1, ATB2, ATX), EArray[i], OD, RTemp, ATemp, IRWTemp, IRT, RH);
	}

	// need to add a match function that searched through the temp array to find which temperature is closest to KnownT to 
	// find the effective transmittance.
	tempdiff=newArray(1001);

	print("The Emissivity yielding a closest match to the known temperature is the estimated Emissivity:");
	
	// tempdiff will calculate the difference between KnownT and estimated T.  
	for (i = 0; i < 1001; i++) {
		tempdiff[i]=abs(TempArray[i]-KnownT);
	}
	
	ranklocation=doSort(tempdiff);
	// the position of the minimum temp diff should correspond to the appropriate E that provides the KnownT
	// the 0th ranklocation should provide the location within the tempdiff array that corresponds to the minimum
	
	ApparentE=EArray[ranklocation[0]];
	print(ApparentE);
	print("\n");
	
	if(tempdiff[ranklocation[0]]>0.5){
		ApparentE=KnownE;
		Dialog.create("Object Emissivity");
		Dialog.addMessage("Warning: Results out of range!");
		Dialog.addMessage("The default estimate for emissivity will remain:");
		Dialog.addMessage("     " + KnownE);
		Dialog.addMessage("Please check the estimated object temperature, object parameters,\n or calibration constants and try again.");
		Dialog.show();
		print("Warning: Results out of range!");
		print("The algorithm cannot find a suitable emissivity, defaults to the reference value.");
	}

	if(tempdiff[ranklocation[0]]<=0.5){
		Dialog.create("Object Emissivity");
		Dialog.addMessage("The Object Emissivity is estimated as:");
		Dialog.addMessage("     " + ApparentE);
		Dialog.addMessage("Compare this transmittance to your expected values.");
		Dialog.addMessage("e.g. many biological surfaces have E values above 0.9.");
		Dialog.show();
	}
	
	
	if(storeE==0) {
		call("ij.Prefs.set", "E.persistent",toString(KnownE)); 
	}
	
	if(storeE==1) {
		call("ij.Prefs.set", "E.persistent",toString(ApparentE)); 
	}

}


function CalculateSpotsize() {

	OD = 1;
	HFOV = 0.47445;
	//IHFOV=0.47222;
	ph = 1024;
	
	// Create a prompt dialog to ask user to verify the values to be used in the calculations below
    print("\n------ Running CalculateSpotsize function ------");
    print("Not fully tested.  Please confirm these calculations with your camera manufacturer.");
    print("Default values are for a FLIR T1K with a 36mm lens.");
    print("For calculations, see http://www.flirmedia.com/MMC/THG/Brochures/RND_048/RND_048_EN.pdf");
   	
	Dialog.create("Estimate Minimum Spot Size");
	Dialog.addMessage("This macro will estimate minimum spot size for your camera\nat a specific object viewing distance.");
	Dialog.addMessage("Provide the Following Parameters:");
    Dialog.addNumber("Object Distance:", OD, 1, 6, "m");
    Dialog.addNumber("Horizontal Field of View (HFOV):", HFOV, 4, 6, "radians");
    Dialog.addNumber("Sensor Horizontal Pixel Resolution:", ph, 0, 4, "pixels");
 	//   Dialog.addMessage("Alternatively, if you lack HFOV and Sensor Pixel Resolution\nprovide the IFOV");
 	//Dialog.addNumber("Instantaneous Horizontal Field of View (IHFOV)", IHFOV, 4,6, "mradians");
	Dialog.show();
	
	var OD = Dialog.getNumber();
	var HFOV = Dialog.getNumber();
	var ph = Dialog.getNumber();
	//var IFOV = Dialog.getNumber();
	
	SS=1000*2*OD*tan(HFOV/2)/ph;
	//SS2=(IHFOV)*OD;
	EffectiveSS=3*SS;

	Dialog.create("Spot Size Estimate");
	Dialog.addMessage("Estimated Spot Size (i.e., 1 pixel at " + OD + "metre working distance) is: " + SS + " mm");
	//Dialog.addMessage("Estimated Spot Size (i.e., 1 pixel at " + OD + "metre working distance) is: " + SS2 + " mm");

	Dialog.addMessage("Effective Spot Size (i.e., 3 pixels at " + OD + "metre working distance) is: " + 3*SS + " mm");
	Dialog.addMessage("See Log output for further details");
	Dialog.show();
	
	print("\nEstimated Spot Size (i.e., size of 1 pixel at", OD, "metre working distance) is:", SS, "mm");
	print("\nDue to uncertainty regarding alignment of object to the digital sensor 'pixel', it is");
	print("recommended to multiply the minimum spot size by 3 to obtain a working minimum spot size");
	print("Therefore, the advised, effective minimum spot size is:", EffectiveSS, "mm");
	print("which means that you cannot accurately report temperature of an object smaller than", EffectiveSS, "mm.");
	print("\nNote that even if you take this as the minimum spot size of your camera, if the actual size of");
	print("the object on your image is only 3 pixels x 3 pixels, that is a small representation of the object");
	print("of interest, and your estimate of temperature may be inaccurate due to any number of reasons, such as:");
	print("1) pixel sensor noise");
	print("2) sampling error");
	print("3) lack of focus");
	print("4) uncertainty regarding the true environmental parameters");
	print("5) algorithm approximation");
	print("6) uncertainty in object emissivity");
	print("7) angle of incidence to object");
	print("8) camera calibration - or lack thereof");
	print("8) etc...etc...");
}



// added function June 2024

function SetAutoAdvance() {
	
	// Create a prompt dialog to ask user to verify the values to be used in the calculations below
    sliceadvancechoices=newArray("no", "yes");
	Dialog.create("Automatically Advance Frame After ROI Use");
	Dialog.addMessage("This tool will allow you to toggle the ROI tools to automatically\nadvance frame/slice after depressing one of the ROI byttons: 1,2,3,.....0.");
	Dialog.addMessage("Setting this to 'yes' means that you can hold the ROI key down\nand capture data from multiple frames in a row, useful for time lapse stacks.");
	Dialog.addMessage("Setting this to 'no' will prevent automatically advancing forward,\nuseful for stacks of different images.");
	
	Dialog.addMessage("This setting will retained until you reboot ImageJ.");
    Dialog.addChoice("Do you wish to automatically advance frame after using ROI:", sliceadvancechoices, autoadvanceslice);
 	Dialog.show();
	
	var autoadvanceslice=Dialog.getChoice();
	var autoadvanceslice=call("ij.Prefs.get", "autoadvanceslice", autoadvanceslice);
	
	if(autoadvanceslice=="yes"){
		print("ImageJ will automatically advance forward after using one of the ROI buttons");	
	}
	if(autoadvanceslice=="no"){
		print("ImageJ will not advance forward after using one of the ROI buttons");	
	}
}


// ============================================================
// SetThermalCameraType()
// Added June 2026
// Toggle that determines whether the existing Raw2Temp macros (icon
// shortcut and dropdown menu item) call the original LWIR/Planck
// conversion (Raw2Temp/Raw2TempCalc) or the new MWIR/ATS-style nfc
// conversion (Counts2Temp/Counts2TempCalc). Modeled directly on
// SetAutoAdvance() / "Set Frame Advance Default for ROI Use", using
// the same Dialog.addChoice + persisted ij.Prefs.get/set idiom.
//
// DEFAULT IS "LWIR" -- this is deliberate. The vast majority of
// ThermImageJ users (and the existing code itself) are built around
// LWIR data; nothing should change for them unless they explicitly
// toggle this. Only users working with FLIR ATS/MWIR files (expected
// to be a small number, primarily the developer) need to ever touch
// this setting.
//
// The persisted value is read back via a top-of-file
// "var thermalcameratype = call('ij.Prefs.get', 'thermalcameratype', 'LWIR');"
// declaration (alongside the other persistent variables at the start
// of ThermImageJ.ijm), so it's available globally without needing to
// re-read it inside every macro that checks it.
// ============================================================

function SetThermalCameraType() {

	cameratypechoices=newArray("LWIR", "MWIR");
	Dialog.create("Set Default Thermal Camera Type");
	Dialog.addMessage("This tool sets whether the Raw2Temp macros (icon shortcut and\ndropdown menu item) use the standard LWIR/Planck conversion,\nor the MWIR/ATS-style conversion built for FLIR ATS files.");
	Dialog.addMessage("LWIR is the correct setting for essentially all FLIR thermal\nimages/video (the vast majority of ThermImageJ users).");
	Dialog.addMessage("MWIR should only be set if you are working with FLIR ATS or\nATS-JPG (R-JPG) files from a midwave infrared camera.");
	Dialog.addMessage("This setting will be retained until you reboot ImageJ, or until you change it again.");
	Dialog.addChoice("Default thermal camera type for Raw2Temp:", cameratypechoices, thermalcameratype);
	Dialog.show();

	var thermalcameratype=Dialog.getChoice();
	call("ij.Prefs.set", "thermalcameratype.persistent", thermalcameratype);

	if(thermalcameratype=="LWIR"){
		print("Raw2Temp macros will use the standard LWIR/Planck conversion (Raw2Temp/Raw2TempCalc).");
	}
	if(thermalcameratype=="MWIR"){
		print("Raw2Temp macros will use the MWIR/ATS-style nfc conversion (Counts2Temp/Counts2TempCalc).");
		print("Make sure you have run fliratsvalues() on your current file first, so Nfc* calibration constants are populated.");
	}
}




// Create a function that just calculates the Temperature for a given Raw Value - not for use on images, just
// for calculating the conversion from raw to temperature


function Raw2TempCalc(raw, PR1, PR2, PB, PF, PO, ATvals, E, OD, RTemp, ATemp, IRWTemp, IRT, RH) {

	ATA1=ATvals[0];
	ATA2=ATvals[1];
	ATB1=ATvals[2];
	ATB2=ATvals[3];
	ATX=ATvals[4];
	
	emisswind = 1- IRT; 
  	reflwind = 0; // anti-reflective coating on window
 	h2o = (RH/100)*exp(1.5587+0.06939*(ATemp)-0.00027816*(ATemp*ATemp)+0.00000068455*(ATemp*ATemp*ATemp)); // converts relative humidity into water vapour pressure (I think in units mmHg)
  	tau1 = ATX*exp(-sqrt(OD)*(ATA1+ATB1*sqrt(h2o)))+(1-ATX)*exp(-sqrt(OD)*(ATA2+ATB2*sqrt(h2o))); // atmos transmittance from object to window
  	//tau2 = ATX*exp(-sqrt(OD)*(ATA1+ATB1*sqrt(h2o)))+(1-ATX)*exp(-sqrt(OD)*(ATA2+ATB2*sqrt(h2o))); // atmos transmittance from window to camera
	tau2=1;
	
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

	rawobj = (raw/E/tau1/IRT/tau2-rawatm1attn-rawatm2attn-rawwindattn-rawrefl1attn-rawrefl2attn);
  
  	tempC = PB/log(PR1/(PR2*(rawobj+PO))+PF)-273.15;
  
	//print(tempC);
	
	return tempC;
		
}


function Temp2RawCalc(temp, PR1, PR2, PB, PF, PO, ATvals, E, OD, RTemp, ATemp, IRWTemp, IRT, RH) {

	ATA1=ATvals[0];
	ATA2=ATvals[1];
	ATB1=ATvals[2];
	ATB2=ATvals[3];
	ATX=ATvals[4];
	
	emisswind = 1- IRT; 
  	reflwind = 0; // anti-reflective coating on window
 	h2o = (RH/100)*exp(1.5587+0.06939*(ATemp)-0.00027816*(ATemp*ATemp)+0.00000068455*(ATemp*ATemp*ATemp)); // converts relative humidity into water vapour pressure (I think in units mmHg)
  	tau1 = ATX*exp(-sqrt(OD)*(ATA1+ATB1*sqrt(h2o)))+(1-ATX)*exp(-sqrt(OD)*(ATA2+ATB2*sqrt(h2o))); // atmos transmittance from object to window
  	//tau2 = ATX*exp(-sqrt(OD)*(ATA1+ATB1*sqrt(h2o)))+(1-ATX)*exp(-sqrt(OD)*(ATA2+ATB2*sqrt(h2o))); // atmos transmittance from window to camera
	tau2=1;
	
	rawobj=PR1/(PR2*(exp(PB/(temp+273.15))-PF))-PO;

	rawrefl1=PR1/(PR2*(exp(PB/(RTemp+273.15))-PF))-PO;   // radiance reflecting off the object before the window
	rawrefl1attn=(1-E)/E*rawrefl1;   // attn = the attenuated radiance (in raw units) 

	rawatm1=PR1/(PR2*(exp(PB/(ATemp+273.15))-PF))-PO; // radiance from the atmosphere (before the window)
	rawatm1attn=(1-tau1)/E/tau1*rawatm1; // attn = the attenuated radiance (in raw units) 

	rawwind=PR1/(PR2*(exp(PB/(IRWTemp+273.15))-PF))-PO;
	rawwindattn=emisswind/E/tau1/IRT*rawwind;

	rawrefl2=PR1/(PR2*(exp(PB/(RTemp+273.15))-PF))-PO;   
	rawrefl2attn=reflwind/E/tau1/IRT*rawrefl2;

	rawatm2=PR1/(PR2*(exp(PB/(ATemp+273.15))-PF))-PO;
	rawatm2attn=(1-tau2)/E/tau1/IRT/tau2*rawatm2;

	raw=(rawobj+rawatm1attn+rawatm2attn+rawwindattn+rawrefl1attn+rawrefl2attn)*E*tau1*IRT*tau2;

	raw;
	
	return raw;
		
}



function flirvalues(filepath, printvalues){
	
	print("\n------ Running flirvalues function ------");
	
	if(OS=="Mac OS X"){
		var perlpath=perlpathOSX;
		var exiftoolpath=exiftoolpathOSX;
		var exiftool=exiftoolOSX;
		var ffmpegpath=ffmpegpathOSX;
		flirvaltext=exiftoolpath + exiftool + " " + "'-Planck*'" + " " + "'-*AtmosphericTrans*'" + " " + "'-*Emissivity'" + " " + "'-*Distance'" + " " + "'-*Temperature'" + " " + "'-*Transmission'" + " " +  "'-*Humidity'" + " " + "'-*Height'" + " " + "'-*Width'" + " " + "'-*Original'" + " " + "'-*Date'" + " " + filepath;
		print("Command line code being executed (copy/paste into terminal window to test):");
		print(flirvaltext);
		flirvals=exec(exiftoolpath + exiftool,  "-Planck*", "-*AtmosphericTrans*", "-*Emissivity", "-*Distance", "-*Temperature", "-*Transmission",  "-*Humidity", "-*Height", "-*Width", "-*Original", "-*Date",  filepath);
	}

	if(OS=="Linux"){
		var perlpath=perlpathLinux;
		var exiftoolpath=exiftoolpathLinux;
		var exiftool=exiftoolOSX;
		var ffmpegpath=ffmpegpathLinux;	
		flirvaltext=exiftoolpath + exiftool + " " + "'-Planck*'" + " " + "'-*AtmosphericTrans*'" + " " + "'-*Emissivity'" + " " + "'-*Distance'" + " " + "'-*Temperature'" + " " + "'-*Transmission'" + " " +  "'-*Humidity'" + " " + "'-*Height'" + " " + "'-*Width'" + " " + "'-*Original'" + " " + "'-*Date'" + " " + filepath;
		print("Command line code being executed (copy/paste into terminal window to test):");
		print(flirvaltext);
		flirvals=exec(exiftoolpath + exiftool,  "-Planck*", "-*AtmosphericTrans*", "-*Emissivity", "-*Distance", "-*Temperature", "-*Transmission",  "-*Humidity", "-*Height", "-*Width", "-*Original", "-*Date",  filepath);
	}
	
	if(substring(OS, 0, 5)=="Windo"){
		var perlpath=perlpathWindows;
		var exiftoolpath=exiftoolpathWindows;
		var exiftool=exiftoolWindows;
		var ffmpegpath=ffmpegpathWindows;
		flirvaltext=exiftoolpath + exiftool + " " + "'-Planck*'" + " " + "'-*AtmosphericTrans*'" + " " + "'-*Emissivity'" + " " + "'-*Distance'" + " " + "'-*Temperature'" + " " + "'-*Transmission'" + " " +  "'-*Humidity'" + " " + "'-*Height'" + " " + "'-*Width'" + " " + "'-*Original'" + " " + "'-*Date'" + " " + filepath;
		print("Command line code being executed (copy/paste into command window to test):");
		print(flirvaltext);
		// might need to explicitly call "c:/Windows/exiftool.exe" below instead of the variables
		flirvals=exec("cmd", "/c", exiftoolpath + exiftool,  "-Planck*", "-*AtmosphericTrans*", "-*Emissivity", "-*Distance", "-*Temperature", "-*Transmission",  "-*Humidity", "-*Height", "-*Width", "-*Original", "-*Date",  filepath);
	}
	
         PR1 = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Planck R1"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Planck R1")) ));
		 PB = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Planck B"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Planck B")) ));
		 PF = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Planck F"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Planck F")) ));
		 PO = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Planck O"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Planck O")) ));
		 PR2 = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Planck R2"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Planck R2")) ));
		 ATA1 = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Atmospheric Trans Alpha 1"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Atmospheric Trans Alpha 1")) ));
		 ATA2 = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Atmospheric Trans Alpha 2"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Atmospheric Trans Alpha 2")) ));
		 ATB1 = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Atmospheric Trans Beta 1"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Atmospheric Trans Beta 1")) ));
		 ATB2 = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Atmospheric Trans Beta 2"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Atmospheric Trans Beta 2")) ));
		 ATX = parseFloat(substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Atmospheric Trans X"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Atmospheric Trans X")) ));
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
			Dialog.addMessage("      Planck R1: " + PR1 + "     Planck R2: " + PR2);
			Dialog.addMessage("      Planck B: " + PB + "            Planck F:" + PF);
			Dialog.addMessage("      Planck O: " + PO);
			Dialog.addMessage("      Atmospheric Trans Alpha 1: " + ATA1 + "     Atmospheric Trans Alpha 2: " + ATA2);
			Dialog.addMessage("      Atmospheric Trans Beta 1: " + ATB1 + "      Atmospheric Trans Beta 2: " + ATB2);

			Dialog.addMessage("      Atmospheric Trans X: " + ATX);
			Dialog.addMessage("- Default Object Parameters -");
			Dialog.addMessage("      Emissivity: " + d2s(E,2) + "     Object Distance: " + d2s(OD,2));
			Dialog.addMessage("      Reflected Apparent Temperature: " + d2s(RTemp,2) + "     Atmospheric Temperature: " + d2s(ATemp,2));
			Dialog.addMessage("      IR Window Temperature: " + d2s(IRWTemp,2) + "     IR Window Transmission: " + d2s(IRT,3));			
			Dialog.addMessage("      Relative Humidity: " + d2s(RH,2));
			Dialog.addMessage("      Thermal Image Width: " + imagewidth);
			Dialog.addMessage("      Thermal Image Height: " + imageheight);
			//Dialog.addMessage("Press OK to export results to log window and store parameters for future Raw2Temp call");
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
			print("Atmospheric Trans Alpha 1: ", d2s(ATA1,12));
			print("Atmospheric Trans Alpha 2: ", d2s(ATA2,12));
			print("Atmospheric Trans Beta 1: ", d2s(ATB1,12));
			print("Atmospheric Trans Beta 2: ", d2s(ATB2,12));
			print("Atmospheric Trans X: ", d2s(ATX,12));									
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

		output=newArray(19);
		output=newArray(PR1, PB, PF, PO, PR2, ATA1, ATA2, ATB1, ATB2, ATX, E, OD, RTemp, ATemp, IRWTemp, IRT, RH, imagewidth, imageheight);
 
        call("ij.Prefs.set", "PR1.persistent",toString(PR1)); 
		call("ij.Prefs.set", "PB.persistent",toString(PB)); 
		call("ij.Prefs.set", "PF.persistent",toString(PF)); 
		call("ij.Prefs.set", "PO.persistent",toString(PO));
		call("ij.Prefs.set", "PR2.persistent",toString(PR2)); 
		call("ij.Prefs.set", "ATA1.persistent",toString(ATA1));
		call("ij.Prefs.set", "ATA2.persistent",toString(ATA2));
		call("ij.Prefs.set", "ATB1.persistent",toString(ATB1));
		call("ij.Prefs.set", "ATB2.persistent",toString(ATB2));
		call("ij.Prefs.set", "ATX.persistent",toString(ATX));
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


// ============================================================
// fliratsvalues()
//
// Companion to flirvalues(), for FLIR ATS / ATS-JPG (R-JPG) files.
// Where flirvalues() calls exiftool and parses its "Planck*" /
// "*AtmosphericTrans*" / object-parameter tags, this function calls
// the companion ats-xml.pl Perl script and parses ITS tag output
// instead.
//
// IMPORTANT -- these are NOT the same calibration model as exiftool's
// Planck R1/R2/B/F/O tags, even though they play a similar role:
//   - exiftool's RJPEG tags (Planck R1, R2, B, F, O) describe a
//     5-constant Planck-on-radiance formula with an offset term (O).
//   - ats-xml.pl's NicevilleFactoryCal-derived tags (NfcB, NfcR, NfcF)
//     describe a DIFFERENT, 3-constant Planck-on-radiance formula with
//     NO offset term, confirmed (via direct comparison against real
//     TIFF pixel values, RMSE ~0.0001 C) to be what FLIR Research
//     Studio actually uses for these particular ATS files.
// Variable names below are deliberately DIFFERENT from flirvalues()'s
// PR1/PR2/PB/PF/PO/etc (Nfc-prefixed instead) so the two calibration
// models are never silently conflated. Bridging Nfc-style values into
// the existing Raw2Temp() function (which expects the 5-constant
// Planck signature) is a separate task, not handled here.
//
// ats-xml.pl's default (non-verbose) output is already a flat
// "Tag : Value" list (no section headers), parsed the same
// indexOf/substring way flirvalues() parses exiftool's output.
// ============================================================

function fliratsvalues(filepath, printvalues){

	print("\n------ Running fliratsvalues function ------");

	if(OS=="Mac OS X"){
		var perlpath=perlpathOSX;
		var perlats=perlscriptpath + "ats-xml.pl";
		atsvaltext=perlpath + "perl " + perlats + " -i " + filepath;
		print("Command line code being executed (copy/paste into terminal window to test):");
		print(atsvaltext);
		atsvals=exec(perlpath + "perl", perlats, "-i", filepath);
	}

	if(OS=="Linux"){
		var perlpath=perlpathLinux;
		var perlats=perlscriptpath + "ats-xml.pl";
		atsvaltext=perlpath + "perl " + perlats + " -i " + filepath;
		print("Command line code being executed (copy/paste into terminal window to test):");
		print(atsvaltext);
		atsvals=exec(perlpath + "perl", perlats, "-i", filepath);
	}

	if(substring(OS, 0, 5)=="Windo"){
		var perlpath=perlpathWindows;
		var perlats=perlscriptpath + "ats-xml.pl";
		atsvaltext=perlpath + "perl " + perlats + " -i " + filepath;
		print("Command line code being executed (copy/paste into command window to test):");
		print(atsvaltext);
		atsvals=exec("cmd", "/c", perlpath + "perl", perlats, "-i", filepath);
	}
	// Remove the SourceFile line (first line) to prevent false tag matches
	// if the filename contains a substring that matches a tag name
	// e.g. a file called "EmissivityTest.jpg" would cause indexOf("Emissivity")
	// to find the filename rather than the actual Emissivity tag value.
	atsvals = substring(atsvals, indexOf(atsvals, "\n") + 1);
	
	//print("DEBUG: atsvals length = " + lengthOf(atsvals));
	//print("DEBUG: Emissivity pos = " + indexOf(atsvals, "Emissivity"));
	// --- Camera / calibration constants (NicevilleFactoryCal-derived) ---
	NfcB    = parseFloat(substring(atsvals, indexOf(atsvals, ":", indexOf(atsvals, "NfcB"))+1,    indexOf(atsvals, "\n", indexOf(atsvals, "NfcB")) ));
	NfcR    = parseFloat(substring(atsvals, indexOf(atsvals, ":", indexOf(atsvals, "NfcR"))+1,    indexOf(atsvals, "\n", indexOf(atsvals, "NfcR")) ));
	NfcF    = parseFloat(substring(atsvals, indexOf(atsvals, ":", indexOf(atsvals, "NfcF"))+1,    indexOf(atsvals, "\n", indexOf(atsvals, "NfcF")) ));
	NfcC0   = parseFloat(substring(atsvals, indexOf(atsvals, ":", indexOf(atsvals, "NfcC0"))+1,   indexOf(atsvals, "\n", indexOf(atsvals, "NfcC0")) ));
	NfcC1   = parseFloat(substring(atsvals, indexOf(atsvals, ":", indexOf(atsvals, "NfcC1"))+1,   indexOf(atsvals, "\n", indexOf(atsvals, "NfcC1")) ));
	NfcC2   = parseFloat(substring(atsvals, indexOf(atsvals, ":", indexOf(atsvals, "NfcC2"))+1,   indexOf(atsvals, "\n", indexOf(atsvals, "NfcC2")) ));
	NfcMinTemp = parseFloat(substring(atsvals, indexOf(atsvals, ":", indexOf(atsvals, "NfcMinTemp"))+1, indexOf(atsvals, "C\n", indexOf(atsvals, "NfcMinTemp")) ));
	NfcMaxTemp = parseFloat(substring(atsvals, indexOf(atsvals, ":", indexOf(atsvals, "NfcMaxTemp"))+1, indexOf(atsvals, "C\n", indexOf(atsvals, "NfcMaxTemp")) ));
	NfcMinCounts = parseFloat(substring(atsvals, indexOf(atsvals, ":", indexOf(atsvals, "NfcMinCounts"))+1, indexOf(atsvals, "\n", indexOf(atsvals, "NfcMinCounts")) ));
	NfcMaxCounts = parseFloat(substring(atsvals, indexOf(atsvals, ":", indexOf(atsvals, "NfcMaxCounts"))+1, indexOf(atsvals, "\n", indexOf(atsvals, "NfcMaxCounts")) ));

	// --- Atmospheric transmission constants (ExifTool-convention names,
	//     same underlying tau formula as flirvalues() uses) ---
	NfcATA1 = parseFloat(substring(atsvals, indexOf(atsvals, ":", indexOf(atsvals, "AtmosphericTransAlpha1"))+1, indexOf(atsvals, "\n", indexOf(atsvals, "AtmosphericTransAlpha1")) ));
	NfcATA2 = parseFloat(substring(atsvals, indexOf(atsvals, ":", indexOf(atsvals, "AtmosphericTransAlpha2"))+1, indexOf(atsvals, "\n", indexOf(atsvals, "AtmosphericTransAlpha2")) ));
	NfcATB1 = parseFloat(substring(atsvals, indexOf(atsvals, ":", indexOf(atsvals, "AtmosphericTransBeta1"))+1,  indexOf(atsvals, "\n", indexOf(atsvals, "AtmosphericTransBeta1")) ));
	NfcATB2 = parseFloat(substring(atsvals, indexOf(atsvals, ":", indexOf(atsvals, "AtmosphericTransBeta2"))+1,  indexOf(atsvals, "\n", indexOf(atsvals, "AtmosphericTransBeta2")) ));
	NfcATX  = parseFloat(substring(atsvals, indexOf(atsvals, ":", indexOf(atsvals, "AtmosphericTransX"))+1,      indexOf(atsvals, "\n", indexOf(atsvals, "AtmosphericTransX")) ));

	// --- Object parameters (ExifTool-convention names; these come from
	//     EITHER Workspace XML or the binary ObjectParameters fallback,
	//     ats-xml.pl already resolves which one and reports
	//     ObjectParametersSource accordingly -- not re-checked here) ---
	NfcE      = parseFloat(substring(atsvals, indexOf(atsvals, ":", indexOf(atsvals, "Emissivity"))+1, indexOf(atsvals, "\n", indexOf(atsvals, "Emissivity")) ));
	NfcOD     = parseFloat(substring(atsvals, indexOf(atsvals, ":", indexOf(atsvals, "ObjectDistance"))+1, indexOf(atsvals, " m\n", indexOf(atsvals, "ObjectDistance")) ));
	NfcRTemp  = parseFloat(substring(atsvals, indexOf(atsvals, ":", indexOf(atsvals, "ReflectedApparentTemperature"))+1, indexOf(atsvals, "C\n", indexOf(atsvals, "ReflectedApparentTemperature")) ));
	NfcATemp  = parseFloat(substring(atsvals, indexOf(atsvals, ":", indexOf(atsvals, "AtmosphericTemperature"))+1, indexOf(atsvals, "C\n", indexOf(atsvals, "AtmosphericTemperature")) ));
	NfcIRWTemp= parseFloat(substring(atsvals, indexOf(atsvals, ":", indexOf(atsvals, "IRWindowTemperature"))+1, indexOf(atsvals, "C\n", indexOf(atsvals, "IRWindowTemperature")) ));
	NfcIRT    = parseFloat(substring(atsvals, indexOf(atsvals, ":", indexOf(atsvals, "IRWindowTransmission"))+1, indexOf(atsvals, "\n", indexOf(atsvals, "IRWindowTransmission")) ));
	NfcRH     = parseFloat(substring(atsvals, indexOf(atsvals, ":", indexOf(atsvals, "RelativeHumidity"))+1, indexOf(atsvals, " %\n", indexOf(atsvals, "RelativeHumidity")) ));

	// --- Image dimensions (binary fallback already resolved by
	//     ats-xml.pl when Workspace XML is absent) ---
	atsimagewidth  = parseFloat(substring(atsvals, indexOf(atsvals, ":", indexOf(atsvals, "ImageWidth"))+1,  indexOf(atsvals, "\n", indexOf(atsvals, "ImageWidth")) ));
	atsimageheight = parseFloat(substring(atsvals, indexOf(atsvals, ":", indexOf(atsvals, "ImageHeight"))+1, indexOf(atsvals, "\n", indexOf(atsvals, "ImageHeight")) ));

	if(printvalues == "Yes"){
		Dialog.create("FLIR ATS Values Extracted from: " + File.getName(filepath));
		Dialog.addMessage("- Camera Calibration Constants (NicevilleFactoryCal) -");
		Dialog.addMessage("      Nfc B: " + NfcB + "     Nfc R: " + NfcR + "     Nfc F: " + NfcF);
		Dialog.addMessage("      Nfc C0: " + NfcC0 + "     Nfc C1: " + NfcC1 + "     Nfc C2: " + NfcC2);
		Dialog.addMessage("      Calibrated range: " + d2s(NfcMinTemp,1) + " C to " + d2s(NfcMaxTemp,1) + " C");
		Dialog.addMessage("      Counts range: " + NfcMinCounts + " to " + NfcMaxCounts);
		Dialog.addMessage("      Atmospheric Trans Alpha 1: " + NfcATA1 + "     Atmospheric Trans Alpha 2: " + NfcATA2);
		Dialog.addMessage("      Atmospheric Trans Beta 1: " + NfcATB1 + "      Atmospheric Trans Beta 2: " + NfcATB2);
		Dialog.addMessage("      Atmospheric Trans X: " + NfcATX);
		Dialog.addMessage("- Default Object Parameters -");
		Dialog.addMessage("      Emissivity: " + d2s(NfcE,2) + "     Object Distance: " + d2s(NfcOD,2));
		Dialog.addMessage("      Reflected Apparent Temperature: " + d2s(NfcRTemp,2) + "     Atmospheric Temperature: " + d2s(NfcATemp,2));
		Dialog.addMessage("      IR Window Temperature: " + d2s(NfcIRWTemp,2) + "     IR Window Transmission: " + d2s(NfcIRT,3));
		Dialog.addMessage("      Relative Humidity: " + d2s(NfcRH,2));
		Dialog.addMessage("      Thermal Image Width: " + atsimagewidth);
		Dialog.addMessage("      Thermal Image Height: " + atsimageheight);
		Dialog.show()

		print("\n");
		print("FLIR ATS Values Extracted from: " + filepath + "\n");
		print("Camera Calibration Constants (NicevilleFactoryCal):");
		setFont("SansSerif", 12);
		print("Nfc B: ", d2s(NfcB,6));
		print("Nfc R: ", d2s(NfcR,6));
		print("Nfc F: ", d2s(NfcF,6));
		print("Nfc C0: ", d2s(NfcC0,15));
		print("Nfc C1: ", d2s(NfcC1,15));
		print("Nfc C2: ", d2s(NfcC2,15));
		print("Calibrated range: ", d2s(NfcMinTemp,1) + " C to " + d2s(NfcMaxTemp,1) + " C");
		print("Counts range: ", NfcMinCounts + " to " + NfcMaxCounts);
		print("Atmospheric Trans Alpha 1: ", d2s(NfcATA1,12));
		print("Atmospheric Trans Alpha 2: ", d2s(NfcATA2,12));
		print("Atmospheric Trans Beta 1: ", d2s(NfcATB1,12));
		print("Atmospheric Trans Beta 2: ", d2s(NfcATB2,12));
		print("Atmospheric Trans X: ", d2s(NfcATX,12));
		print("Thermal Image Width: ", atsimagewidth);
		print("Thermal Image Height: ", atsimageheight + "\n");
		print("Default Object Parameters:");
		print("Emissivity: ", d2s(NfcE,2));
		print("Object Distance: ", d2s(NfcOD,2));
		print("Reflected Apparent Temperature: ", d2s(NfcRTemp,2));
		print("Atmospheric Temperature: ", d2s(NfcATemp,2));
		print("IR Window Temperature: ", d2s(NfcIRWTemp,2));
		print("IR Window Transmission: ", d2s(NfcIRT,3));
		print("Relative Humidity: ", d2s(NfcRH,2));
		print("\n");
	}

	output=newArray(24);
	output=newArray(NfcB, NfcR, NfcF, NfcC0, NfcC1, NfcC2, NfcMinTemp, NfcMaxTemp, NfcMinCounts, NfcMaxCounts, NfcATA1, NfcATA2, NfcATB1, NfcATB2, NfcATX, NfcE, NfcOD, NfcRTemp, NfcATemp, NfcIRWTemp, NfcIRT, NfcRH, atsimagewidth, atsimageheight);

	call("ij.Prefs.set", "NfcB.persistent",toString(NfcB));
	call("ij.Prefs.set", "NfcR.persistent",toString(NfcR));
	call("ij.Prefs.set", "NfcF.persistent",toString(NfcF));
	call("ij.Prefs.set", "NfcC0.persistent",toString(NfcC0));
	call("ij.Prefs.set", "NfcC1.persistent",toString(NfcC1));
	call("ij.Prefs.set", "NfcC2.persistent",toString(NfcC2));
	call("ij.Prefs.set", "NfcMinTemp.persistent",toString(NfcMinTemp));
	call("ij.Prefs.set", "NfcMaxTemp.persistent",toString(NfcMaxTemp));
	call("ij.Prefs.set", "NfcMinCounts.persistent",toString(NfcMinCounts));
	call("ij.Prefs.set", "NfcMaxCounts.persistent",toString(NfcMaxCounts));
	call("ij.Prefs.set", "NfcATA1.persistent",toString(NfcATA1));
	call("ij.Prefs.set", "NfcATA2.persistent",toString(NfcATA2));
	call("ij.Prefs.set", "NfcATB1.persistent",toString(NfcATB1));
	call("ij.Prefs.set", "NfcATB2.persistent",toString(NfcATB2));
	call("ij.Prefs.set", "NfcATX.persistent",toString(NfcATX));
	call("ij.Prefs.set", "NfcE.persistent",toString(NfcE));
	call("ij.Prefs.set", "NfcOD.persistent",toString(NfcOD));
	call("ij.Prefs.set", "NfcRTemp.persistent",toString(NfcRTemp));
	call("ij.Prefs.set", "NfcATemp.persistent",toString(NfcATemp));
	call("ij.Prefs.set", "NfcIRWTemp.persistent",toString(NfcIRWTemp));
	call("ij.Prefs.set", "NfcIRT.persistent",toString(NfcIRT));
	call("ij.Prefs.set", "NfcRH.persistent",toString(NfcRH));
	call("ij.Prefs.set", "atsimagewidth.persistent",toString(atsimagewidth));
	call("ij.Prefs.set", "atsimageheight.persistent",toString(atsimageheight));

	return output;
}


function flirdate(filepath, printvalues){

	print("\n------ Running flirdate function ------");
	
	if(OS=="Mac OS X"){
		var perlpath=perlpathOSX;
		var exiftoolpath=exiftoolpathOSX;
		var exiftool=exiftoolOSX;
		var ffmpegpath=ffmpegpathOSX;
		flirvaltext=exiftoolpath + exiftool + " " + "'-*Original'" + " " + filepath;
		print("Command line code being executed (copy/paste into terminal window to test):");
		print(flirvaltext);
		flirvals=exec(exiftoolpath + exiftool, "-*Original*",  filepath);
	}

	if(OS=="Linux"){
		var perlpath=perlpathLinux;
		var exiftoolpath=exiftoolpathLinux;
		var exiftool=exiftoolOSX;
		var ffmpegpath=ffmpegpathLinux;
		flirvaltext=exiftoolpath + exiftool + " " + "'-*Original'" + " " + filepath;
		print("Command line code being executed (copy/paste into terminal window to test):");
		print(flirvaltext);
		flirvals=exec(exiftoolpath + exiftool, "-*Original*",  filepath);
	}
	
	if(substring(OS, 0, 5)=="Windo"){
		var perlpath=perlpathWindows;
		var exiftoolpath=exiftoolpathWindows;
		var exiftool=exiftoolWindows;
		var ffmpegpath=ffmpegpathWindows;
		flirvaltext=exiftoolpath + exiftool + " " + "'-*Original'" + " " + filepath;
		print("Command line code being executed (copy/paste into command window to test):");
		print(flirvaltext);
		flirvals=exec("cmd", "/c", exiftoolpath + exiftool, "-*Original*",  filepath);
	}

   //	flirvals=exec(exiftoolpath + exiftool, "-*Original*",  filepath);
	
    datetimeoriginal=substring(flirvals, indexOf(flirvals, ":", indexOf(flirvals, "Original"))+1, indexOf(flirvals, "\n", indexOf(flirvals, "Original")) );
    dateoriginal=substring(datetimeoriginal, 1, 11);
    dateoriginal=replace(dateoriginal, ":", "-");
    timeoriginal=substring(datetimeoriginal, 12,30);
  
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


function flirdistance(filepath, printvalues){

	print("\n------ Running flirdistance function ------");
	
	if(OS=="Mac OS X"){
		var perlpath=perlpathOSX;
		var exiftoolpath=exiftoolpathOSX;
		var exiftool=exiftoolOSX;
		var ffmpegpath=ffmpegpathOSX;
		flirdisttext=exiftoolpath + exiftool + " " + "'-FocusDistance'" + " " + filepath;
		print("Command line code being executed (copy/paste into terminal window to test):");
		print(flirdisttext);
		flirdist=exec(exiftoolpath + exiftool, "-FocusDistance",  filepath);
	}

	if(OS=="Linux"){
		var perlpath=perlpathLinux;
		var exiftoolpath=exiftoolpathLinux;
		var exiftool=exiftoolOSX;
		var ffmpegpath=ffmpegpathLinux;
		flirdisttext=exiftoolpath + exiftool + " " + "'-FocusDistance'" + " " + filepath;
		print("Command line code being executed (copy/paste into terminal window to test):");
		print(flirdisttext);
		flirdist=exec(exiftoolpath + exiftool, "-FocusDistance",  filepath);
	}
	
	if(substring(OS, 0, 5)=="Windo"){
		var perlpath=perlpathWindows;
		var exiftoolpath=exiftoolpathWindows;
		var exiftool=exiftoolWindows;
		var ffmpegpath=ffmpegpathWindows;
		flirdisttext=exiftoolpath + exiftool + " " + "'-FocusDistance'" + " " + filepath;
		print("Command line code being executed (copy/paste into terminal window to test):");
		print(flirdisttext);
		flirdist=exec("cmd", "/c", exiftoolpath + exiftool, "-FocusDistance",  filepath);
	}

   //	flirvals=exec(exiftoolpath + exiftool, "-*Original*",  filepath);

    focusdistanceoriginal=substring(flirdist, indexOf(flirdist, ":")+1 );
    
		if(printvalues == "Yes"){
			Dialog.create("Focus Distance Information:");
			Dialog.addMessage("Focus Distance: " + focusdistanceoriginal);
			Dialog.addMessage("Press OK to export results to Log window");
			Dialog.show()

			print("\n");
			print("Focus Distance Information:");
			setFont("SansSerif", 12);
			print("Focus Distance: ", focusdistanceoriginal);
			print("\n");
		}

		return focusdistanceoriginal;	
}


function addMeasurementLabel(type, units, decimals, colour, fontsize, addROI, drawx, drawy) {

	print("\n------ Running addMeasurementLabel function ------");
	
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
  			setFont("SansSerif", fontsize);
         	drawString(label, drawx, drawy);
         
     	 }
     	 
	if(addROI==1){
		 Roi.setStrokeColor(colour, colour, colour);
     	 Overlay.addSelection;     	 
	}
     	
}



function addvaluelocation(type, label, colour, fontsize) {
	
	//type="Max";
	//fontsize=12;
	//print(type);
	print("\n------ Running addvaluelocation function ------");

	// type should be one of: Min or Max
	// but will be converted to: mean min standard modal median skewness kurtosis

	n = nSlices;
	getSelectionBounds(x, y, width, height);

     	 for (slice=1; slice<=n; slice++) {
     	 	//run("Clear Results");
        	showProgress(slice, n);
        	//print("Slice", slice);
         	setSlice(slice);
		 	rownum=getSliceNumber()-1;
		 	
				Roi.getBounds(rx, ry, width, height); 
				row = 0; 
				X=newArray(width*height);
				Y=newArray(width*height);
				Value=newArray(width*height);
				for(y=ry; y<ry+height; y++) { 
  				  	for(x=rx; x<rx+width; x++) { 
  				      	//if(Roi.contains(x, y)==1) { 
    			        	//setResult("X", row, x); 
    			        	//setResult("Y", row, y); 
    			        	//setResult("Value", row, getPixel(x, y)); 
  				          	X[row]=x;
  				          	Y[row]=y;
  				          	Value[row]=getPixel(x,y);
  				          	//print(Value[row]);
  				          	row++; 
  				          //	} 
			    	} 
				} 
				
        	// Get the columns from the active Results table
			//X=Table.getColumn("X");
			//Y=Table.getColumn("Y");
			//Value=Table.getColumn("Value");
			
			// locate maxima in the array, returns an array
			indices_max = Array.findMaxima(Value, 1);
			indices_min = Array.findMinima(Value, 1);
			
			imax = indices_max[0]; // just keep the largest
			imin = indices_min[0];
			
			if(type=="Max"){
				Xcoord=X[imax];
				Ycoord=Y[imax];
			}

 			  if(type=="Min"){
				Xcoord=X[imin];
				Ycoord=Y[imin];
			}
			
        	setColor(colour, colour, colour);
        	setFont("SansSerif", fontsize);
         	drawString(label, Xcoord, Ycoord);
         	      	
     	 }
     
}



function StackDifference(){

	activewindow=getInfo("window.title");
	//print(activewindow);
	activeID=getImageID();
	//print(activeID);
	close("\\Others");
	
	//selectWindow(activewindow);
	selectImage(activeID);
	
	ns=nSlices();

	n2stacktext="  slices=2-" + ns;
	n1stacktext="  slices=1-" + ns-1;
	
	run("Make Substack...", n2stacktext);
	selectImage(activeID);
	run("Make Substack...", n1stacktext);

	totalOpenImages=nImages;                //get total number of open images 
	imageIDs=newArray(nImages);          	//create array to hold all image IDs 
	imagetitles=newArray(nImages);
	for(i=0;i<nImages;i++){                  //and populate array with image IDs 
     	selectImage(i+1); 
	     imageIDs[i]=getImageID();
		 imagetitles[i]=getTitle();	
		 print(imagetitles[i]); 
		// print(imageIDs[i]);     
	}

	// use the imagetitles to calculate difference
	// choosing 1st and second imageID should yield the two generated substacks
	//imageCalculator("Difference create 32-bit stack", "Substack (2-2346)","Substack (1-2345)");
	imageCalculator("Difference create 32-bit stack", imagetitles[2], imagetitles[1]);
	//differencetitle="Result of " + imagetitles[2];

	//selectWindow(differencetitle);
	close(imagetitles[2]);
	close(imagetitles[1]);
	
}



function StackCumulativeDiffSummation(interval, dataType, windowType, detrend, removemean, isdifference){

	//run("Duplicate...", "duplicate");
	if(isdifference=="No"){
		StackDifference();	
	}
	
	dt=interval;
	
	//run("8-bit");
	//run("Stack Difference", "gap=1"); // default provides absolute difference, no negative numbers
	run("Enhance Contrast", "saturated=0.35"); //   
	
	ns=nSlices();
	
	// create arrays for mean and standard deviations
	mn=newArray(ns);
	sd=newArray(ns);
	cv=newArray(ns);
	rms_data=newArray(ns);
	w = getWidth();
	h = getHeight();
	
	// obtain the mean and sd of the difference image.  each frame's values are summarised
	for(i=0; i<ns; i++){
		setSlice(i+1);
		getRawStatistics(area, mean, min, max, std, histogram);
		mn[i]=mean;
		sd[i]=std;
		cv[i]=sd[i]/mn[i];	
		
		binwidth=(max-min)/256;
		pixelsumsquares=0;
		value=min;
		
		for (j = 0; j < histogram.length; j++) {
			pixelsumsquares += pow(value, 2)*histogram[j];
			value += binwidth;
		}
		
		rms_data[i]=sqrt(pixelsumsquares/histogram.length);
	}

	
	// rms_data=removeoutliers(rms_data);

          
	// create cumulative summation of the mn and sd arrays.
	cummn=cumsum(mn);
	cumsd=cumsum(sd);
	cumcv=cumsum(cv);

	// calculate smoothing slopes (derivatives) over 3 frame intervals
	cummnslp=newArray(ns);
	cumsdslp=newArray(ns);
	cumcvslp=newArray(ns);
	cummnslp[0]=0;
	cummnslp[1]=0;
	cumsdslp[0]=0;
	cumsdslp[1]=0;
	cumcvslp[0]=0;
	cumcvslp[1]=0;
	
	for(i=2; i<ns; i++){
		y=newArray(cummn[i-2], cummn[i-1], cummn[i]);
		x=newArray(0,1,2); 
		cummnslp[i]=Slope(x,y);
		y=newArray(cumsd[i-2], cumsd[i-1], cumsd[i]);
		cumsdslp[i]=Slope(x,y);
		y=newArray(cumcv[i-2], cumcv[i-1], cumcv[i]);
		cumcvslp[i]=Slope(x,y);
	}

	//Array.print(cummnslp);
	
	t=Array.getSequence(ns); 
	Plot.create("Inter Frame Difference", "Slice", "Slope of Cumulative\nMean, Median, or SD of |Frame Difference|");
	Plot.setColor("black");
	Plot.add("lines", t, cummnslp);
	Plot.setColor("blue");
	Plot.add("lines", t, cumsdslp);
	Plot.setColor("red");
	Plot.add("lines", t, cumcvslp);
	Plot.setLimitsToFit();
	Plot.setLegend("Mean\tSD\tCV", "top-left");
	Plot.show();

	// Put values into the Results Window
	run("Clear Results");

	// Define a time variable
	Time=Array.getSequence(ns);
	for (i = 0; i < ns; i++) {
		Time[i]=Time[i]*interval;
		setResult("Elapsed Time", i, Time[i]);
	}
	
	    for (i=0; i<ns; i++) {
	    	setResult("Slice", i, i+1);
	    	setResult("RMS", i, rms_data[i]);  // removed from above since this is far too slow to calculate
            setResult("Mean", i, mn[i]);
            setResult("Cumulative Mean", i, cummn[i]);
            setResult("Slope Cumul Mean", i, cummnslp[i]);
            setResult("SD", i, sd[i]);
            setResult("Cumulative SD", i, cumsd[i]);
            setResult("Slope Cumul SD", i, cumsdslp[i]);   
            setResult("CV", i, cv[i]);
            setResult("Cumulative CV", i, cumcv[i]);
            setResult("Slope Cumul CV", i, cumcvslp[i]);           
          }
          
    if(dataType=="sd"){
    	data=cumsd; 
    	dataname="Cumulative SD";   
    }
    
    if(dataType=="mean"){
    	data=cummn; 
    	dataname="Cumulative Mean"; 
    }
    
	if(dataType=="cv"){
    	data=cumcv; 
    	dataname="Cumulative CV"; 
    }

	// because the first two values of data are 0, remove these before running spectral analysis
	//data=Array.slice(data,2,data.length);
	
	spectralanalysis(data, dataname, windowType, dt, detrend, removemean);
}



function spectralanalysis(data, dataname, windowType, dt, detrend, removemean){

	// data is the array of data sampled at interval, dt
	// dt is the sample interval typically in seconds: 0.033333 seconds
	// windowType can be:  None, Hamming, Hann or Flattop
	
	len=data.length;
	//print("Data is : " + len);
	t=Array.getSequence(len);
	frame=Array.getSequence(len);
	datasquared=newArray(len);
	sum=0;
	for(i=0; i<len; i++){
		t[i]=t[i]*dt; 
		datasquared[i]=data[i]*data[i];
		sum += datasquared[i];
		frame[i]=frame[i]+1;
	}
	rms_data=sqrt(sum/len);
 	frequ=dt*len; // cycles per array length   
	
	X=newArray(t[0], t[t.length-1]);
	Y=newArray(data[0], data[data.length-1]);
	m=Slope(X,Y);
	b=Intercept(X,Y);

	// remove linear trend
	if(detrend==1){
		//Array.getStatistics(data, min, max, mean);
		//meandata=mean;
		for(i=0; i<data.length; i++){
			data[i]=data[i]-(m*t[i]+b);
		}
	}
	
	// remove mean
	if(removemean==1){
		Array.getStatistics(data, min, max, mean);
		meandata=mean;
		for(i=0; i<data.length; i++){
			data[i]=data[i]-meandata;
		}
	}
	
	sum_detrend=0;
	dd2=newArray(len);
	for(i=0; i<len; i++){
		dd2[i]=data[i]*data[i];
		sum_detrend += dd2[i];
	}
	rms_detrend=sqrt(sum_detrend/len);
		
	y = Array.fourier(data, windowType);
	//logy=newArray(lengthOf(y));
	f = newArray(lengthOf(y));
  	
 		 for (i=0; i<lengthOf(y); i++){
 		 	f[i] = i/(2*lengthOf(y)*dt);
 		 	//logy[i] = log(y[i])/log(10);
 		 }


	fhtSize = 2*lengthOf(y);
  	peakF = frequ/len*fhtSize; // i.e., frequ/len = peakF/fhtSize
  	
	Plot.create(dataname, "Time (s)", dataname, t, data);
    Plot.show();
  	Plot.create("Fourier amplitudes of " + dataname + " with window: " + windowType, "Frequency (Hz)", "Amplitude (RMS)", f, y);
  	Plot.addText("RMS of Raw Data: " + rms_data + "  RMS of Detrended Data: " + rms_detrend, 0, 0)
  	Plot.show();
   
}

// returns hex byte readout from a file, where the reading frame 
// is equal to the imagewidth * imageheight * 4, to ensure that at least 
function ReadBytesFromFile(filepath, searchlength, offsetread){
	
	// create a search byte length that is at least 2 frames in length
	// searchlength=imagewidth*imageheight*2*2;
	
	// command="xxd -p -l " + searchlength + " " + filepath + " | grep -aob " + magicbyte + " | head -n10";
	command="xxd -g 1 -s " + offsetread + " -ps -l " + searchlength + " -aob " + "'" + filepath + "'";
	// use the bash xxd to hexdump "searchlength" amount of the begining of file and store this as a string variable
	
	if(OS=="Mac OS X"){
		//print("Detected Operating System: " + OS);
		//print("Using the following bash command: ");
		//print(command);
		res=exec("/bin/sh", "-c", command);
		//print("Cleaning up hex output");
		res=replace(res, "\n", "");
	}

	if(OS=="Linux"){
		//print("Detected Operating System: " + OS);
		//print("Using the following bash command: ");
		//print(command);
		res=exec("/bin/sh", "-c", command);
		//print("Cleaning up hex output");
		res=replace(res, "\n", "");
	}

	// Windows does not have xxd installed, so need an alternative - 
	// Need to install powershell open source frmo github:
	// https://github.com/powershell/powershell 
	
	if(substring(OS, 0, 5)=="Windo"){
		
		// check if xxd is installed, if it is then run similar code as OSX and Linux
		checkxxd=exec("where xxd.exe");
		
		if(lengthOf(checkxxd)>0){
			//print("Detected Operating System: " + OS);
			//print("Using the following bash command: ");
			//print(command);
			res=exec("cmd", "/c", command);
			//print("Cleaning up hex output");
			res=replace(res, "\n", "");
		}
	
		if(lengthOf(checkxxd)==0){
			
			checkpwsh=exec("where pwsh.exe");
		
			if(lengthOf(checkpwsh)==0){
				exit("Neither xxd.exe nor Powershell Core 6 (pwsh.exe) can be found.\nPlease install from github.com/powershell and try again.\nA version of xxd for windows can be found at: https://sourceforge.net/projects/xxd-for-windows/");
			}
	
			command="Format-Hex -Path " + filepath + " " + "-Count " + searchlength;
		
			//print("Detected Operating System: " + OS);
			//print("Using the following powershell command: ");
			//print(command);
		
			res=exec("pwsh", "-c", command);
			//print(res);
			resarray=split(res, "\n");
			resarray=Array.deleteIndex(resarray, 0); resarray=Array.deleteIndex(resarray, 0);		
			resarray=Array.deleteIndex(resarray, 0); resarray=Array.deleteIndex(resarray, 0);		
			resarray=Array.deleteIndex(resarray, 0);
		
			//print("Cleaning up hex output");
			res="";
			start=20; // removes the first 20 char of the byte line
			end=70;   // removes the unicode conversion at the end of each line
			String.resetBuffer;
			for(i=0; i<resarray.length; i++){
				showProgress(i/resarray.length);
				len=lengthOf(resarray[i]);
			
				if(len<end){
					resarray=Array.deleteIndex(resarray, i);
					i=resarray.length+1;
				}
				else {
					resarray[i]=toLowerCase(substring(resarray[i], start, end));
					String.append(resarray[i]); // working with string buffer much faster than concatenating text
					//res = res + resarray[i];
				}
			}
			res=String.buffer;
			res=replace(res, " ", ""); 
			print(res);
		
			//command="Get-Content " + filepath + " " + "-ReadCount " + "200000 " + "-Encoding " + "byte " + "-TotalCount " + imagewidth*imageheight*2*2;
		}
	}
		return res;
}

// ============================================================
// IsFLIRATS()
//
// Quick file-type check: reads the first 5000 bytes of a file and
// reports whether it looks like a FLIR ATS file (raw .ats) or a FLIR
// RJPEG / ATS-JPG. Intended for a quick sanity check when a user
// selects a .jpg and you want to know -- before doing anything
// heavier like calling ats-xml.pl or ats-repair.pl -- whether it's
// actually a FLIR radiometric file at all.
//
// Uses ONLY the built-in File.openAsRawString() macro function -- no
// xxd, no PowerShell, no OS branching, no external dependency at all.
//
// CHECK ORDER MATTERS: RJPEG is checked FIRST. The literal ASCII text
// "FLIR ATS-US File" was found (empirically, by testing a real RJPEG
// file) to ALSO appear somewhere inside RJPEG files' embedded FLIR
// metadata stream -- not just at the start of raw .ats files as
// originally assumed. An unanchored search for that string alone
// therefore misreports real RJPEG files as "ATS". ats-xml.pl avoids
// this same trap by checking for the JPEG SOI marker (FF D8) first
// and only falling through to the ATS string check if that didn't
// match; the same order is mirrored here, using the FF E1 + "FLIR"
// APP1 signature instead of a bare FF D8 check (see below).
//
// Both checks are simple "is this byte sequence present anywhere in
// the first 5000 bytes" searches, NOT anchored to the start of the
// file:
//   - RJPEG/ATS-JPG: FLIR stores its data inside one or more JPEG
//     APP1 segments (marker FF E1), each beginning with a "FLIR"
//     text header 4 bytes after the FF E1 marker (2 bytes for the
//     marker itself + 2 bytes for the segment's length field) -- see
//     ats-repair.pl's own APP1-parsing logic for the same structure.
//     This FF E1 + "FLIR" segment is NOT necessarily near the start
//     of the file (a standard JFIF APP0 header, EXIF data, etc. can
//     come first), so this check scans the whole 5000-byte window
//     rather than checking only the first few bytes.
//   - raw .ats file: the literal ASCII text "FLIR ATS-US File".
//     Checked only if the RJPEG check above did NOT match.
//
// Returns one of: "ATS", "RJPEG", "unknown"
// ============================================================

function IsFLIRATS(filepath){

    searchbytes = File.openAsRawString(filepath, 5000);

    // ---- ATS check FIRST for jpg files ----
    // "FLIR ATS-US File" appears inside the APP1 payload of
    // ATS-derived JPGs -- check for it before the generic RJPEG
    // APP1 scan, which would otherwise match both ATS-JPGs and
    // standard LWIR RJPEGs equally and never reach this check.
    if(indexOf(searchbytes, "FLIR ATS-US File") >= 0){
        return "ATS";
    }

    // ---- RJPEG/ATS-JPG check ----
    app1marker = fromCharCode(0xFF, 0xE1);
    app1pos = indexOf(searchbytes, app1marker);

    while(app1pos >= 0){
        flirsigpos = app1pos + 4;
        flirsig = substring(searchbytes, flirsigpos, flirsigpos+4);
        if(flirsig == "FLIR"){
            return "RJPEG";
        }
        app1pos = indexOf(searchbytes, app1marker, app1pos+1);
    }

    return "unknown";
}

// ============================================================
// IsFLIRfile() -- revised
//
// Returns a pipe-delimited string: "FILETYPE|CAMERATYPE"
//
// FILETYPE is one of:
//   "ATS"     -- raw MWIR ATS video file (.ats)
//   "RJPEG"   -- FLIR radiometric JPEG (both LWIR and MWIR JPG variants)
//   "JPEGLS"  -- JPEG-LS lossless (FF D8 FF F7)
//   "FCF"     -- older FLIR video format (FFF\0 + "CAP")
//   "SEQ"     -- FLIR camera-recorded video (FFF\0 + "CAM")
//   "CSQ"     -- FLIR compressed video (FFF\0 + "RTP")
//   "FFF"     -- generic FFF-style single frame
//   "TIFF"    -- TIFF (little-endian magic "II*\0"); may or may not
//                be a FLIR-specific TIFF -- treat as "possibly FLIR"
//   "unknown" -- no recognised signature found
//
// CAMERATYPE is one of:
//   "MWIR"    -- confirmed mid-wave IR (ATS-style file or ATS-derived JPG)
//   "LWIR"    -- confirmed long-wave IR (standard RJPEG, SEQ, CSQ, FFF, FCF, TIFF)
//   "unknown" -- file type was recognised but camera waveband cannot be
//                determined from the file alone
//
// HOW THE EXTENSION GUIDES THE CHECK:
//   Extension is extracted first and used to restrict which byte-pattern
//   checks are performed -- faster and more informative than scanning
//   5000 bytes for every possible signature regardless of extension.
//
//   For ambiguous extensions (.jpg / .jpeg), IsFLIRATS() is called
//   internally to distinguish MWIR (ATS-derived) from LWIR (standard
//   RJPEG) -- both start with FF D8 FF E1 but differ inside.
//
// USAGE AT CALL SITE:
//   result     = IsFLIRfile(filepath);
//   parts      = split(result, "|");
//   filetype   = parts[0];  // e.g. "RJPEG"
//   cameratype = parts[1];  // e.g. "MWIR"
//
// DEPENDENCY: IsFLIRATS() must be defined (used for .jpg/.jpeg only).
// ============================================================

function IsFLIRfile(filepath){

	// ---- Extract file extension (lowercase, with leading dot) ----
	filename = File.getName(filepath);
	dotpos   = lastIndexOf(filename, ".");
	if(dotpos >= 0){
		ext = toLowerCase(substring(filename, dotpos));
	} else {
		ext = "";
	}

	// ---- Route by extension ----

	// .ats -- unambiguous: always MWIR ATS, confirm with signature
	if(ext == ".ats"){
		header = File.openAsRawString(filepath, 20);
		if(startsWith(header, "FLIR ATS-US File")){
			return "ATS|MWIR";
		}
		return "unknown|unknown";
	}

	if(ext == ".jpg" || ext == ".jpeg"){
    searchbytes = File.openAsRawString(filepath, 5000);

    // MWIR ATS-derived JPG: contains this specific marker string
    if(indexOf(searchbytes, "FLIR ATS-US File") >= 0){
        return "RJPEG|MWIR";
    }

    // LWIR RJPEG: has both an APP1 segment (FF E1) AND "FLIR" text
    // somewhere in the first 5000 bytes (inside Exif metadata).
    // These are checked independently since the FLIR thermal APP1
    // segments may be beyond the 5000-byte window, but the Exif
    // block with "FLIR Systems" text is always within it.
    app1marker = fromCharCode(0xFF, 0xE1);
    if(indexOf(searchbytes, app1marker) >= 0 && indexOf(searchbytes, "FLIR") >= 0){
        return "RJPEG|LWIR";
    }

    return "unknown|unknown";
	}
	
	// .fff -- generic FLIR frame, always LWIR
	if(ext == ".fff"){
		header  = File.openAsRawString(filepath, 8);
		fffbase = "FFF" + fromCharCode(0x00);
		if(indexOf(header, fffbase) >= 0){ return "FFF|LWIR"; }
		return "unknown|unknown";
	}

	// .seq -- FLIR camera-recorded video, always LWIR
	if(ext == ".seq"){
    	header = File.openAsRawString(filepath, 8);
    	seqpat = "FFF" + fromCharCode(0x00) + "CAM";
   	 	affpat = "AFF" + fromCharCode(0x00);
   	 	if(indexOf(header, seqpat) >= 0){ return "SEQ|LWIR"; }
    	if(indexOf(header, affpat) >= 0){ return "SEQ|LWIR"; }
   		 // Some .seq files use bare FFF header without CAM suffix
    	fffbase = "FFF" + fromCharCode(0x00);
    	if(indexOf(header, fffbase) >= 0){ return "SEQ|LWIR"; }
    	return "unknown|unknown";
	}

	// .csq -- FLIR compressed video, always LWIR
	if(ext == ".csq"){
		header = File.openAsRawString(filepath, 8);
		csqpat = "FFF" + fromCharCode(0x00) + "RTP";
		if(indexOf(header, csqpat) >= 0){ return "CSQ|LWIR"; }
		fffbase = "FFF" + fromCharCode(0x00);
		if(indexOf(header, fffbase) >= 0){ return "CSQ|LWIR"; }
		return "unknown|unknown";
	}

	// .fcf -- older FLIR video format, always LWIR
	if(ext == ".fcf"){
		header = File.openAsRawString(filepath, 8);
		fcfpat = "FFF" + fromCharCode(0x00) + "CAP";
		if(indexOf(header, fcfpat) >= 0){ return "FCF|LWIR"; }
		fffbase = "FFF" + fromCharCode(0x00);
		if(indexOf(header, fffbase) >= 0){ return "FCF|LWIR"; }
		return "unknown|unknown";
	}

	// .tif / .tiff -- TIFF (little-endian); FLIR LWIR cameras export
	// 32-bit TIFFs, but this matches any LE TIFF so treat as "possibly LWIR"
	if(ext == ".tif" || ext == ".tiff"){
		header  = File.openAsRawString(filepath, 6);
		tiffpat = "II" + fromCharCode(0x2A, 0x00);
		if(indexOf(header, tiffpat) >= 0){ return "TIFF|LWIR"; }
		return "unknown|unknown";
	}

	// ---- Unknown or missing extension ----
	// Fall back to the original broad scan across all signatures.
	// This handles files with no extension, wrong extension, or
	// extensions not listed above (e.g. .aff, .raw, etc.).
	searchbytes = File.openAsRawString(filepath, 5000);

	rjpegpat  = fromCharCode(0xFF, 0xD8, 0xFF, 0xE1);
	jpeglspat = fromCharCode(0xFF, 0xD8, 0xFF, 0xF7);
	tiffpat   = "II" + fromCharCode(0x2A, 0x00);
	fffbase   = "FFF" + fromCharCode(0x00);
	fcfpat    = fffbase + "CAP";
	seqpat    = fffbase + "CAM";
	csqpat    = fffbase + "RTP";

	if(startsWith(searchbytes, "FLIR ATS-US File")){ return "ATS|MWIR"; }
	if(indexOf(searchbytes, jpeglspat) >= 0){         return "JPEGLS|LWIR"; }
	if(indexOf(searchbytes, rjpegpat)  >= 0){
		atsresult = IsFLIRATS(filepath);
		if(atsresult == "ATS"){   return "RJPEG|MWIR"; }
		if(atsresult == "RJPEG"){ return "RJPEG|LWIR"; }
		return "RJPEG|unknown";
	}
	if(indexOf(searchbytes, fcfpat) >= 0){ return "FCF|LWIR"; }
	if(indexOf(searchbytes, seqpat) >= 0){ return "SEQ|LWIR"; }
	if(indexOf(searchbytes, csqpat) >= 0){ return "CSQ|LWIR"; }
	if(indexOf(searchbytes, fffbase) >= 0){ return "FFF|LWIR"; }
	if(indexOf(searchbytes, tiffpat) >= 0){ return "TIFF|LWIR"; }

	return "unknown|unknown";
}


// Call an R script: requires that you install Rserve http://www.rforge.net/Rserve/doc.html
function callRScriptviaJavaScript(script) {
	// Use javascript ability to call direct java commands to load R engine and send command to R
	// Note that anything because this is an ImageJ macro calling a javascript calling R...
	//	pretty much anything with quotes in it is likely to fail.
	jscode = "importClass(javax.script.ScriptEngineManager); ";
	jscode = jscode + "sEM = new ScriptEngineManager();";
	jscode = jscode + "engine = sEM.getEngineByName(\"Renjin\");"
	jscode = jscode + "engine.eval(\""+script+"\")";
	ret = eval("script",jscode);
	return ret;
}



// The next Six Functions are used in converting a 32 bit integer from FLIR files into a Date/Time Stamp:
// function to determine if the year provided is a leap year or not
function isLeapYear(year) {
    // Adjusted leap year check without ternary operator
    if ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0) {
        return true;
    } else {
        return false;
    }
}

// Helper function to ensure two-digit formatting of date/time values
// will return a leading zero for numbers less than 10
function d2(n) {
    n = Math.floor(n); // Ensure n is an integer
    if (n < 10) {
        return "0" + n;
    } else {
        return "" + n;
    }
}

// function to convert unix epoch seconds into formatted Date and Time
// in YYYY-MM-DD hh:mm:ss format
// Usage: 
//timestamphex=exec("/bin/sh", "-c", "xxd -s 1284 -g 1 -ps -l 4 ~/Desktop/DavidStoneFiles/temp/frame000007.fff");
//timestampstring=replace(timestamphex, "\n", "");
//timestampinteger=parseInt(timestampstring, 16);
//timestamp=swapEndian(timestampinteger, 4);
//ConvertEpochTimetoFullDateTime(timestamp);
//ConvertEpochTimetoFullDateTime(947815708);

function ConvertEpochTimetoFullDateTime(epochSeconds) {
    // Epoch time in seconds (example)
    // epochSeconds = 949630898;
    // Usage: ConvertEpochTimetoFullDateTime(1709429135);
    // Constants
    secondsInMinute = 60;
    minutesInHour = 60;
    hoursInDay = 24;
    startYear = 1970;
    
    // Month lengths in days
    monthLengths = newArray(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
    
    // Calculate days
    totalDays = epochSeconds / (hoursInDay * minutesInHour * secondsInMinute);
    
    // Calculate remaining seconds after extracting days
    remainingSeconds = epochSeconds % (hoursInDay * minutesInHour * secondsInMinute);
    
    // Calculate hours from remaining seconds
    hours = remainingSeconds / (minutesInHour * secondsInMinute);
    
    // Calculate remaining seconds after extracting hours
    remainingSeconds = remainingSeconds % (minutesInHour * secondsInMinute);
    
    // Calculate minutes from remaining seconds
    minutes = remainingSeconds / secondsInMinute;
    
    // Calculate remaining seconds
    seconds = remainingSeconds % secondsInMinute;
    
    year = startYear;
    month = 0;
    
    // Adjust for leap years and find the correct year
    while (true) {
        if (isLeapYear(year)) {
            daysThisYear = 366;
        } else {
            daysThisYear = 365;
        }
        if (totalDays < daysThisYear) break;
        totalDays = totalDays - daysThisYear;
        year++;
    }
    
    // Adjust February for leap year
    if (isLeapYear(year)) {
        monthLengths[1] = 29;
    }
    
    // Find the correct month
    for (i = 0; i < monthLengths.length; i++) {
        if (totalDays < monthLengths[i]) {
            month = i;
            break;
        }
        totalDays = totalDays - monthLengths[i];
    }
    
    // Remaining totalDays + 1 is the day of the month
    day = totalDays + 1;
    
    // Format and print the date and time
    datetimeString = "" + year + "-" + d2(month + 1) + "-" + d2(day) + " " + d2(hours) + ":" + d2(minutes) + ":" + d2(seconds);
   // print("Date/Time: " + datetimeString);
    
    return datetimeString;
}


// Function to convert hours to HH:MM format
// Example usage
// number = -5.75;
// result = hoursToHHMM(number);
function hoursToHHMM(hours) {
    // Determine sign
    if (hours >= 0)
        sign = "+";
    else
        sign = "-";

    // Convert hours to absolute value
    hours = abs(hours);

    // Calculate hours and minutes
    hh = floor(hours);
    mm = round((hours - hh) * 60);

    // Format HH:MM string
    formattedTime = sign + IJ.pad(hh, 2) + ":" + IJ.pad(mm, 2);
    
    return formattedTime;
}

// for a 4 byte/32 bit integer, swap it so that it is the reverse endian order
// intValue is an integer
function swapEndian(intValue, numBytes) {
    // Perform byte swapping based on the number of bytes
    if (numBytes == 2) {
        byte0 = (intValue >> 8) & 0xFF;
        byte1 = intValue & 0xFF;
        
        // Reassemble in reversed order
        return (byte1 << 8) | byte0;
    } else if (numBytes == 4) {
        byte0 = (intValue >> 24) & 0xFF;
        byte1 = (intValue >> 16) & 0xFF;
        byte2 = (intValue >> 8) & 0xFF;
        byte3 = intValue & 0xFF;
        
        // Reassemble in reversed order
        return (byte3 << 24) | (byte2 << 16) | (byte1 << 8) | byte0;
    } else {
        // Unsupported number of bytes
        return NaN;
    }
}

function swaphex(hexstring, numBytes){
	if (numBytes==2){
		byte0 = substring(hexstring, 0, 2);
		byte1 = substring(hexstring, 2, 4);
		reversebyte = byte1 + byte0;
		return reversebyte;
	} else if(numBytes==4){
		byte0 = substring(hexstring, 0, 2);
		byte1 = substring(hexstring, 2, 4);
		byte2 = substring(hexstring, 4, 6);
		byte3 = substring(hexstring, 6, 8);
		reversebyte = byte3 + byte2 + byte1 + byte0;
		return reversebyte;
		
	} else {
		return NaN;
	}
}

// Date Time Original Conversion code, as described in Exiftool
function ExtractDateTimeInfoFromHex(timestamphex) {
	
	timestamphex=replace(timestamphex, "\n", "");
	
	datetimehex=substring(timestamphex, 0, 8);
	datetimehex=swaphex(timestamphex, 4);
	datetimeint=parseInt(datetimehex, 16);
	//datetimeInt=swapEndian(datetimeint,4);
	
	millisechex=substring(timestamphex, 8, 12);
	millisechex=swaphex(millisechex, 2);
	millisecint=parseInt(millisechex,16);
	millisecstr=toString(millisecint);
	millisecstr=leadzero(millisecstr, 3);
	//millisecint=swapEndian(millisecint,2);
	
	timezonehex=substring(timestamphex, 16, 20);
	timezonehex=swaphex(timezonehex,2);
	timezoneint=parseInt(timezonehex, 16);
	//print(timezoneint);
	//timezoneint=swapEndian(timezoneint, 2);

	// Convert the decimal integer to a signed 16-bit integer
	if (timezoneint > 32767) {
    	// If the value is greater than the maximum positive signed 16-bit integer value (32767),
    	// it means it's a negative value in two's complement representation
    	timezoneint = timezoneint - 65536;
	} 

	timezoneint=-1*timezoneint/60; // convert timezone to hour
	timezonestr=hoursToHHMM(timezoneint);
	
	datetimeString=ConvertEpochTimetoFullDateTime(datetimeint+timezoneint*3600);
	datetimeString=datetimeString + "." + millisecstr + timezonestr;
	
	return datetimeString;
}


// using three detect byte positions describing potential offsets in 
// FLIR video files, generate a complete sequence of possible byte offsets
// for the length of the entire file
// set returnindex to all, even, or odd
function GenerateBytePatternSequence(FirstThree, l, returnIndex) {
 		
 	smalldiff = FirstThree[1] - FirstThree[0];  // small difference
    largediff = FirstThree[2] - FirstThree[1];  // Large difference
    
    // Initialize counter and result array
    result = newArray(3);
    result[0] = FirstThree[0];
    result[1] = FirstThree[1];
    result[2] = FirstThree[2];
    
    // Generate next numbers until the largest number exceeds the limit
    nextNumber = result[2];
    n = 3;
    while (nextNumber <= l) {
        if (n % 2 == 0) {
            nextNumber = nextNumber + largediff;
        } else {
            nextNumber = nextNumber + smalldiff;
        }
        if (nextNumber <= l) {
            result[n] = nextNumber;
            n++;
        } else {
            break;
        }
    }
    
    // Return every other value from the sequence based on the specified option
    if (returnIndex=="even") {
        newResult = newArray(result.length/2);
        for (i = 0; i < result.length; i = i + 2) {
            newResult[i/2] = result[i];
        }
    } else if(returnIndex=="odd") {
        newResult = newArray(result.length/2);
        for (i = 1; i < result.length; i = i + 2) {
            newResult[(i-1)/2] = result[i];
        }
    } else if(returnIndex=="all"){
    	newResult=result;
    }
    return newResult;
}


// detects the number of FFF headers in a FLIR video file and thus the number of frames in the video
function FrameCountFLIRVideo(filepath) {
		
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
	
	var perl=perlpath+"perl";
	
	//command=" -0777 -ne 'print scalar(() = /\\x{46}\\x{46}\\x{46}\\x{00}\\x{52}\\x{54}/g)'";
	//command=" -0777 " + "-ne " + "'$c = () = /\\x46\\x46\\x46\\x00\\x52\\x54/g; print $c'"; 
	//perl -0777 -ne '$c = () = /\x46\x46\x46\x00\x52\x54/g; print $c' /Users/GlennTattersall/IRconvert/CSQfiles/IR_2019-06-23_0689.csq
	//res=exec("/usr/bin/perl", "-0777 -ne 'my $c = () = /\x46\x46\x46\x00\x52\x54/g; printf $c' /Users/GlennTattersall/IRconvert/CSQfiles/IR_2019-06-23_0689.csq");
	
	// Making use of split.pl to count the # of FFF headers in a file, without splitting it
	// use "perl split.pl filename -c y" to return an integer number that corresponds to the number of FFF headers 

	if(OS=="Mac OS X"){
		res=exec(perl, perlsplit, "-i", filepath, "-c", "yes");
	}

	if(OS=="Linux"){
		res=exec(perl, perlsplit, "-i", filepath, "-c", "yes");
	}

	if(substring(OS, 0, 5)=="Windo"){
		
		// check if xxd is installed, if it is then run similar code as OSX and Linux
		checkxxd=exec("where xxd.exe");
		
		if(lengthOf(checkxxd)>0){
			res=exec(perl, perlsplit, "-i", filepath, "-c", "yes");
		}
	}
	
	res=replace(res, "The number of FFF headers is: ", "");
	res=replace(res, "\n", "");
	res=parseInt(res);
	//print(res);
	return res;
	
}




/////////////////////////////////////////////// Macros //////////////////////////////////////////////////////

macro "Import Menu Tool - C037T0b11FT6b09IT9b09LTeb09E" {
       cmd = getArgument();
       if (cmd=="Raw Import Mikron RTV")
           RawImportMikronRTV();
	   else if (cmd=="Raw Import Mikron SIT")
           RawImportMikronSIT();
       else if (cmd=="Raw Import FLIR SEQ"){
       		thermalcameratype="LWIR";
        	RawImportFLIRSEQ();	
       }
       else if (cmd=="Convert FLIR JPG(s)"){
 	      	thermalcameratype="LWIR";
          	ConvertFLIRJPGs();
       }
       else if (cmd=="Import FLIR JPG"){
 		   	thermalcameratype="LWIR";
     		ConvertImportFLIRJPG("no");
       }
       else if (cmd=="Import FLIR JPG with defaults"){
            thermalcameratype="LWIR";
           	ConvertImportFLIRJPG("yes");
       }
       else if (cmd=="Import FLIR ATS JPG"){
           	thermalcameratype="MWIR";
           ConvertImportFLIRATSJPG("no");
       }
       else if (cmd=="Import FLIR ATS JPG with defaults"){
           	thermalcameratype="MWIR";
           	ConvertImportFLIRATSJPG("yes");
       }
       else if (cmd=="Import Image Sequence"){
           ImportImageSequence();    
       }
       else if (cmd=="Import CSV Image Sequence"){
           ImportCSVImageSequence();        
       }
       else if (cmd=="Import FLIR SEQ"){
           thermalcameratype="LWIR";
           ImportConvertFLIRSEQ();
       }
       else if (cmd=="Import FLIR CSQ"){
           thermalcameratype="LWIR";
           ImportConvertFLIRCSQ();
       }
       else if (cmd=="Import FLIR ATS"){
           thermalcameratype="MWIR";
           ImportConvertFLIRATS();
       }
       else if (cmd=="Import 16-bit AVI"){
           ImportFFmpegAVI();
       }
	   else if (cmd!="-")
            run(cmd);
}


//macro "Raw Import Mikron RTV Action Tool - C000D00D01D02D03D04D05D06D09D0aD0bD0cD0dD0eD0fD10D13D19D1cD20D23D24D25D29D2cD2dD2eD30D31D32D33D35D36D39D3aD3bD3cD3eD3fD54D55D56D59D61D62D63D64D69D70D71D74D76D77D79D7aD7bD7cD7dD7eD7fD81D82D83D84D89D94D95D96D99Db0Db1Db2Db3Db9DbaDbbDc3Dc4Dc5Dc6DcbDccDcdDd1Dd2Dd3Dd4DddDdeDdfDe3De4De5De6DebDecDedDf0Df1Df2Df3Df9DfaDfbC000C111C222C333C444C555C666C777C888C999D67D78D87C999CaaaCbbbCcccCdddCeeeCfff" {
//	RawImportMikronRTV();
//}

macro "Search Install Location"{
	WhereProgram();
}

macro "Check Installations" {
	InstallChecks();
}

macro "-" {} //menu divider

macro "Raw Import Mikron RTV" {
	RawImportMikronRTV();
}

macro "Raw Import Mikron SIT" {
	RawImportMikronSIT();
}

//macro "Raw Import FLIR SEQ Action Tool - C000D00D01D02D03D04D05D06D0aD0bD0fD10D13D19D1cD1fD20D23D24D25D29D2cD2fD30D31D32D33D35D36D39D3dD3eD3fD54D55D56D59D5aD5bD5cD5dD5eD5fD61D62D63D64D69D6cD6fD70D71D74D76D77D79D7cD7fD81D82D83D84D89D8cD8fD94D95D96D99D9fDb0Db1Db2Db3DbaDbbDbcDbdDbeDc3Dc4Dc5Dc6Dc9DcfDd1Dd2Dd3Dd4Dd9DdeDdfDe3De4De5De6DeaDebDecDedDeeDefDf0Df1Df2Df3DffC000C111C222C333C444C555C666C777C888C999D67D78D87C999CaaaCbbbCcccCdddCeeeCfff" {
//	RawImportFLIRSEQ();
//}

macro "-" {} //menu divider

macro "Convert FLIR JPG(s)" {
	thermalcameratype="LWIR";
	ConvertFLIRJPGs();
}

macro "Import FLIR JPG" {
	var ConvertWithDefault="no";
	thermalcameratype="LWIR";
	ConvertImportFLIRJPG(ConvertWithDefault);
}

macro "Import FLIR JPG with defaults" {
	var ConvertWithDefault="yes";
	thermalcameratype="LWIR";
	ConvertImportFLIRJPG(ConvertWithDefault);
}

macro "-" {} //menu divider

macro "Import FLIR ATS-JPG" {
    var ConvertWithDefault = "no";
    thermalcameratype="MWIR";
    ConvertImportFLIRATSJPG(ConvertWithDefault);
}

macro "Import FLIR ATS-JPG with defaults" {
    var ConvertWithDefault = "yes";
    thermalcameratype="MWIR";
    ConvertImportFLIRATSJPG(ConvertWithDefault);
}

macro "-" {} //menu divider

macro "Import Image Sequence" {
	ImportImageSequence();    
}

macro "-" {} //menu divider

macro "Raw Import FLIR SEQ" {
	thermalcameratype="LWIR";
	RawImportFLIRSEQ();
}

macro "Import FLIR SEQ" {
	thermalcameratype="LWIR";
	ImportConvertFLIRSEQ();
}

macro "Import FLIR CSQ" {
	thermalcameratype="LWIR";
	ImportConvertFLIRCSQ();
}

macro "-" {} //menu divider


macro "Import 16-bit AVI [i]" {
	ImportFFmpegAVI();
}

macro "-" {} //menu divider

macro "Import FLIR ATS" {
	thermalcameratype="MWIR";
	ImportConvertFLIRATS();
}


macro "-" {} //menu divider


macro "Frame Start Byte [j]"{
	Dialog.create("Magicbyte scan for pixel byte offset in FLIR SEQ Videos"); 
	Dialog.addMessage("This macro will scan a FLIR video file (SEQ) for the offset byte\nposition '0200wwwwhhhh'\nwhere wwww and hhhh are the image width and height\nin 16-bit little endian hexadecimal.");
	Dialog.addMessage("For example, magicbyte for a 640x480 camera: 02008002e001");
	Dialog.addMessage("Last magicbyte used: " + magicbyte);
	Dialog.addString("Custom magicbyte (leave blank if unknown):", "");
	Dialog.addMessage("The function returns estimates for the offset and gap bytes\nnecessary for use with the Raw Import FLIR SEQ macro");
	Dialog.addNumber("Image Width:", imagewidth, 0, 6, "pixels");
	Dialog.addNumber("Image Height:", imageheight, 0, 6, "pixels");
	Dialog.addMessage("Note: If running Windows you may need to install xxd.exe in c:/windows, available from github.com/gtatters/ThermimageJ");
	Dialog.addMessage("Alternatively, please install Powershell Core 6 from github:");
	Dialog.addMessage("https://github.com/powershell/powershell"); 
    Dialog.show();

	custommagicbyte=Dialog.getString();
	imagewidth=Dialog.getNumber();
	imageheight=Dialog.getNumber();
	width=leadzero(toString(toHex(imagewidth)), 4);
	height=leadzero(toString(toHex(imageheight)), 4);
	
	if(lengthOf(custommagicbyte)>0){
		magicbyte=custommagicbyte;
	}
	
	if(lengthOf(custommagicbyte)==0){
		magicbyte = "0200" + swapHex(width) + swapHex(height);	
	}

	call("ij.Prefs.set", "magicbyte.persistent", toString(magicbyte));
	
	filepath=File.openDialog("Select a File"); 
	print("Magicbyte search");
	print("Scanning: ", filepath, "for: ", magicbyte);

	// call ReadBytesFromFile function to return the first imagewidth*imageheight*2*2 bytes of data as a string
	searchlength=imagewidth*imageheight*2*2;
	offsetread=0;
	res=ReadBytesFromFile(filepath, searchlength, offsetread);

	// now examine the bytes for the location of the magicbyte position
	ind=newArray(100); // ind will be the index of byte positions where magicbyte is found
	newres=res;
	j=0; // counter index for use in next loop. each j refers to index of magic byte detection
	
	for(i=0; i<10; i++){
		position=indexOf(newres, magicbyte);
		//print(position);
		l=lengthOf(newres);
		
		if(position==-1) {
			i=1000; // break out of loop if position does not exist
		}
		
		else {
			
		  ind[j] = position/2;
		  
		  if(j>0){
		  	ind[j]=ind[j] + ind[j-1] + lengthOf(magicbyte)/2;
		  	// add the previous index value so that ind reflects position in string
		  }
		  
		  j++;  
		  newres=substring(newres, position + lengthOf(magicbyte), l);
		}
	}
	
	//Array.print(ind);
	ind=Array.deleteValue(ind, 0); // remove 0s from the array
	
	if(ind.length<2){
		Array.print(ind);
		print("Number of magicbyte positions detected: " + ind.length);
		print("\n");
		exit("Too few magicbyte positions detected. Please try a different magicbyte or use a Hex editor to search manually.");
	}
	
	for(j=0; j<ind.length; j++){
		ind[j]=ind[j]+32; 
		// add 32 bytes to each ind entry, since the first pixel in tiff style video files
		// starts 32 bytes after the beginning of the magicbyte start		
	}
	
	startbyte=ind[1];
	gapbyte=ind[3]-(startbyte+imagewidth*imageheight*2);
	
	print("Image data usually begins 32 bytes after magicbyte offsets.");
	print("Possible pixel start byte positions detected at the following magicbyte (+32) byte offsets: ");
	Array.print(ind);
	print("Usually the second startbyte position reflects the start of the first frame's image pixel data"); 
	print("Suggested offset start to use in the Import-Raw function is: ",  startbyte);
	print("Suggested gap byte to use in the Import-Raw function is:", gapbyte);
	print("\n");
	
	if(startbyte<0 || gapbyte<0){
		exit("Magicbyte position unsuccessful.  Possibly too many magicbyte positions detected.  Please try a different magicbyte or use a Hex editor to search manually.");
	}
}


macro "Find Time Stamps in FLIR Videos [f]"{
	
	print("\n");
	print("-------------- Running Find Time Stamps in FLIR Videos Macro -------------");
	Dialog.create("Time stamp extraction from FLIR SEQ Videos"); 
	Dialog.addMessage("This macro will scan a FLIR video file (SEQ) for the offset byte\nposition '464646'.");
	Dialog.addMessage("Last header search used: " + magicbyte);
	Dialog.addString("Custom header search (leave blank if unknown):", "");
	Dialog.addMessage("The function returns estimates for the offsets\n for use with certain FLIR Video files.");
	Dialog.addNumber("Image Width:", imagewidth, 0, 6, "pixels");
	Dialog.addNumber("Image Height:", imageheight, 0, 6, "pixels");
	Dialog.addMessage("Note: If running Windows you may need to install xxd.exe in c:/windows, available from github.com/gtatters/ThermimageJ");
	Dialog.addMessage("Alternatively, please install Powershell Core 6 from github:");
	Dialog.addMessage("https://github.com/powershell/powershell"); 
    Dialog.show();

	custommagicbyte=Dialog.getString();
	imagewidth=Dialog.getNumber();
	imageheight=Dialog.getNumber();
	width=leadzero(toString(toHex(imagewidth)), 4);
	height=leadzero(toString(toHex(imageheight)), 4);
	
	if(lengthOf(custommagicbyte)>0){
		magicbyte=custommagicbyte;
	}
	
	if(lengthOf(custommagicbyte)==0){
		magicbyte = "0200" + swapHex(width) + swapHex(height);	
	}

	call("ij.Prefs.set", "magicbyte.persistent", toString(magicbyte));
	
	filepath=File.openDialog("Select a File"); 
	
	Frames=FrameCountFLIRVideo(filepath);
	
	print("Magicbyte search");
	print("Scanning: ", filepath, "for: ", magicbyte);
	
	// call ReadBytesFromFile function to return the first imagewidth*imageheight*2*2 bytes of data as a string
	searchlength=imagewidth*imageheight*2*10;
	offsetread=0;
	res=ReadBytesFromFile(filepath, searchlength, offsetread);

	// now examine the bytes for the location of the magicbyte position
	ind=newArray(100); // ind will be the index of byte positions where magicbyte is found
	newres=res;
	j=0; // counter index for use in next loop. each j refers to index of magic byte detection
		
	for(i=0; i<10; i++){
		position=indexOf(newres, magicbyte);
		//print(position);
		l=lengthOf(newres);
		
		if(position==-1) {
			i=1000; // break out of loop if position does not exist
		}
		else {	
		  ind[j] = position/2;
		  if(j>0){
		  	ind[j]=ind[j] + ind[j-1] + lengthOf(magicbyte)/2;
		  	// add the previous index value so that ind reflects position in string
		  }
		  
		  j++;  
		  newres=substring(newres, position + lengthOf(magicbyte), l);
		}
	}
		
	ind=Array.deleteValue(ind, 0); // remove 0s from the array
	
	if(ind.length<2){
		Array.print(ind);
		print("Number of magicbyte positions detected: " + ind.length);
		print("\n");
		exit("Too few magicbyte positions detected. Please try a different magicbyte or use a Hex editor to search manually.");
	}
	
	for(j=0; j<ind.length; j++){
		ind[j]=ind[j]+900; 
		// add 900 bytes to each ind entry, since the Date/Time Original Occurs 
		// 900 bytes after the beginning of the magicbyte start		
	}
	
	//Array.print(ind);
	
	startbyte=ind[0];
	filelength=File.length(filepath);
	FirstThree=Array.slice(ind,0,3);
	//Array.print(FirstThree);
	
	DateTimeOffsets=GenerateBytePatternSequence(FirstThree, filelength, "even");
	
	print("Date/Time stamp data usually begins 900 bytes after Magicbyte in FFF header offsets.");
	Array.print(DateTimeOffsets);
	
	print("Suggested offset start find first Date/Time Stamp is: ", startbyte);
	FirstTimeStampHex=ReadBytesFromFile(filepath, 10, startbyte);
	
	AllTimeStampsHex=newArray(DateTimeOffsets.length);
	DateTimeString=newArray(DateTimeOffsets.length);
	
	for(i=0; i<DateTimeOffsets.length; i++){
		ind[j]=ind[j]+900; 
		AllTimeStampsHex[i]=ReadBytesFromFile(filepath, 10, DateTimeOffsets[i]);		
		DateTimeString[i]=ExtractDateTimeInfoFromHex(AllTimeStampsHex[i]);
		print(DateTimeString[i]);
	}
	
	//FirstTimeStampString=replace(FirstTimeStampHex, "\n", "");
	//DateTimeString=ExtractDateTimeInfoFromHex(FirstTimeStampString);
	
	
	//print("\n");
	print("First frame time stamp: " + DateTimeString[0]); 	
	
	if(startbyte<0){
		exit("Magicbyte position unsuccessful.  Possibly too many magicbyte positions detected.  Please try a different magicbyte or use a Hex editor to search manually.");
	}
}



macro "Count FFF Headers in FLIR Video [c]" {
	
	print("\n");
	print("-------------- Running Macro to Estimate Number of Frames in FLIR Video File -------------");
	//Dialog.create("Count the number of Frames in a FLIR Videos"); 
	//Dialog.addMessage("This macro will scan a FLIR video file (SEQ or CSQ) for the number of magicbytes: '46464600'.");
	//Dialog.addMessage("Recommended header search: " + custommagicbyte);
	//Dialog.addString("Custom header search (leave blank if unknown):", custommagicbyte);
    //Dialog.show();
    //custommagicbyte=Dialog.getString();
    
	filepath=File.openDialog("Select a SEQ or CSQ File to Scan"); 
	print("Scanning: ", filepath, "for: \\x46\\x46\\x46\\x00");
	
	ext = substring(filepath, lengthOf(filepath) - 3, lengthOf(filepath));
	
	Frames=FrameCountFLIRVideo(filepath);
	
	print("The number of FFF headers in the file is: " + Frames);
}



//macro "Import FLIR JPG Action Tool - C000D1eD2eD38D3eD43D48D49D4aD4bD4cD4dD54D65D68D69D6aD6bD6cD6dD6eD70D71D72D73D74D75D76D78D7bD80D81D82D83D84D85D86D88D8bD95D98D99D9aDa4Db3Db9DbaDbbDbcDbdDc8DceDd8DdcDdeDecDedDeeC000C111C222C333C444C555C666C777C888C999CaaaCbbbCcccCdddCeeeCfff"{
//	ConvertImportFLIRJPG();
//}


// "Import/Convert FLIR SEQ Action Tool - C000D19D1aD1eD28D2bD2eD38D3bD3eD43D48D4cD4dD4eD54D65D68D69D6aD6bD6cD6dD6eD70D71D72D73D74D75D76D78D7bD7eD80D81D82D83D84D85D86D88D8bD8eD95D98D9eDa4Db3Db9DbaDbbDbcDbdDc8DceDd8DdeDe9DeaDebDecDedDeeDefDfeDffC000C111C222C333C444C555C666C777C888C999CaaaCbbbCcccCdddCeeeCfff" {

// "Import/Convert FLIR CSQ Action Tool - C000D19D1aD1bD1cD1dD28D2eD38D3eD43D48D4eD54D65D69D6aD6eD70D71D72D73D74D75D76D78D7bD7eD80D81D82D83D84D85D86D88D8bD8eD95D98D9cD9dD9eDa4Db3Db9DbaDbbDbcDbdDc8DceDd8DdeDe9DeaDebDecDedDeeDefDfeDffC000C111C222C333C444C555C666C777C888C999CaaaCbbbCcccCdddCeeeCfff" {
	


macro "-" {} //menu divider

// This will call a subset of LUTs that are more appropriate for thermal imaging.
macro "Thermal LUT Menu Tool - C037T0b11LT6b09UTcb09T" {
      cmd = getArgument();
          run(cmd);
}


macro "Previous LUT Action Tool - C037T4d14<" {
        cycleLUTs(-1);
}

macro "Previous LUT [<]" {
        cycleLUTs(-1);
}

macro "Next LUT Action Tool - C037T4d14>" {
        cycleLUTs(1);
}

macro "Next LUT [>]" {
        cycleLUTs(1);
}

macro "Invert LUT Action Tool - C037R12ccL12cc" {
        run("Invert LUT");
}

macro "Invert LUT" {
        run("Invert LUT");
}


macro "Adjust Brightness and Contrast Action Tool - C037D04D05D06D07D08D09D0aD0bD0cD14D18D1cD24D28D2cD34D38D3cD45D46D47D49D4aD4bD6bD6cD76D77D78D79D7aD84D85Da6Da7Da8Da9DaaDb5DbbDc4DccDd4DdcDe5DebDf6Dfa" {
        //run("Enhance Contrast", "saturated=0.35");
        run("Brightness/Contrast...");
}


macro "-" {} //menu divider

macro "Image Byte Swap Action Tool - C000D12D13D1cD1dD21D24D25D26D27D28D29D2aD2bD2eD31D34D35D36D37D38D39D3aD3bD3eD42D43D4cD4dD82D83D91D92D93D94Da0Da1Da2Da3Da4Da5Db2Db3Dc2Dc3DccDcdDd2Dd3Dd4Dd5Dd6Dd7Dd8Dd9DdaDdbDdeDe2De3De4De5De6De7De8De9DeaDebDeeDfcDfdC000C111C222C333C444C555C666C777C888C999CaaaD1bD4bCaaaD11D14DcbDceDfbDfeCaaaD1eD4eCaaaD41D44CbbbCcccD2dD3dCcccD22DddDedCcccD32CcccD72D73CcccDc4CcccCdddD23D2cD3cDdcDecCdddDb1CdddD33CeeeDb0CeeeD8cD8dDb4DbcDbdCeeeCfffD20D30Df5CfffDc7CfffD17D18D47D48Dc6Dc8Df6Df7Df8CfffD16D19D46D49Dc9Df9CfffDf4CfffDb5CfffDc1"{
	ByteSwapperFileLocation=getDirectory("plugins") + "Byte_Swapper.class";
	if(File.exists(ByteSwapperFileLocation)==0){
		exit("Please install Byte Swapper to your plugins folder\nSee: https://imagej.nih.gov/ij/plugins/swapper.html");
	}
	run("Byte Swapper");
}

macro "Image Byte Swap"{
	ByteSwapperFileLocation=getDirectory("plugins") + "Byte_Swapper.class";
	if(File.exists(ByteSwapperFileLocation)==0){
		exit("Please install Byte Swapper to your plugins folder\nSee: https://imagej.nih.gov/ij/plugins/swapper.html");
	}
	run("Byte Swapper");
}


macro "-" {} //menu divider

macro "Add Calibration Bar Action Tool - C000D10D11D12D13D14D15D16D17D18D19D1aD1bD1cD1dD1eD1fD20D2dD2eD2fD30D3dD3eD3fD40D4dD4eD4fD50D5dD5eD5fD60D61D62D63D64D65D66D67D68D69D6aD6bD6cD6dD6eD6fD70D72D74D76D78D7aD7cD7eD80D82D84D86D88D8aD8cD8eDa4Da5Da6Da9DaaDabDacDadDb3Db7Db9DbbDc3Dc7Dc9DcbDd4Dd6Dd9C001C002C003C004C005C006C007C107C108C208C308C309C409D2bD2cD3bD3cD4bD4cD5bD5cC409C509C609C709C809C909Ca09D29D2aD39D3aD49D4aD59D5aCa09Cb09Cc09Cc08Cc18Cc17Cd17Cd26D27D28D37D38D47D48D57D58Cd26Cd25Cd34Cd33Ce33Ce32Ce41Ce40Ce50Ce60D25D26D35D36D45D46D55D56Ce60Cf60Cf70Cf80Cf90Cfa0D23D24D33D34D43D44D53D54Cfa0Cfb0Cfc0Cfd0Cfd1D21D22D31D32D41D42D51D52Cfd1Cfe2Cfe3Cfe4Cfe5Cfe6Cff6Cff7Cff8Cff9CffaCffbCffcCffdCffeCfff"{
	w=getWidth();
	h=getHeight();
	barheight=148; // at zoom level 1 this is the height of the box that defines the calibration bar (with background bounding box)
	zoomlevel=0.5*h/barheight;
	calbaroptions="location=[At Selection] fill=None label=White number=5 decimal=1 font=10 zoom=" + zoomlevel + " overlay";
	run("Calibration Bar...", calbaroptions);

}

macro "Add Calibration Bar"{
	w=getWidth();
	h=getHeight();
	barheight=148; // at zoom level 1 this is the height of the box that defines the calibration bar (with background bounding box)
	zoomlevel=0.5*h/barheight;
	calbaroptions="location=[Upper Right] fill=None label=White number=5 decimal=1 font=10 zoom=" + zoomlevel + " overlay";
	
	//getMinAndMax(min, max);
	//range=max-min;
	
	//   	newImage("LUT", "16-bit ramp", 480, 32, 1);
	//newwidth=w+69;
	//run("Canvas Size...", "width=" + newwidth + " height=" + h + " position=Center-Left");
	//run("32-bit");
	//	run("Calibrate...", "function=None");

	
	run("Calibration Bar...", calbaroptions);
}




macro "-" {} //menu divider


macro "FLIR Date Stamps Action Tool - C000D08D09D0aD0bD0cD17D1dD26D2eD35D3eD45D4fD55D57D58D59D5aD5fD65D6aD6fD72D73D75D7aD7eD82D86D8aD8eD90D91D92D94D97D9dDa2Da8Da9DaaDabDacDb2Db4Db6Dc2Dc8Dd0Dd1Dd2Dd4Dd6Dd8De2De8Df2Df3Df4Df5Df6Df7Df8C000C111C222C333C444C555C666C777C888C999CaaaCbbbCcccDc1CcccDd7CcccD83CcccD81CcccDe1CcccCdddD56CdddDe7CdddDa1CdddDb3CdddDc7CdddD16CdddD2dCdddD1eD48D4eDb7CdddD69CdddD49D7bCdddCeeeD46Dc4CeeeD6bDc6CeeeD6eCeeeD93Dc3CeeeDe3CeeeDe9CeeeDa3CeeeDd9CeeeDd3CeeeD99Db5CeeeD74CeeeD1bD2fD54D8fCeeeD19D85Dd5CeeeD25D96Db1De4CeeeDa4Db8CeeeDe6CfffD9bDbaCfffD5eD79CfffDe5CfffD8bCfffD68DadCfffD0dCfffD07D64CfffD1aD63D89Da7Dc5CfffD9aCfffD44D5bDb9De0CfffD84Da0DbbCfffD4aD80Da5Dc0Dc9Df1CfffD62D71Df9CfffD47" {
	filepath=File.openDialog("Select a FLIR Image or Video File");
	printvalues="Yes";
	if(File.exists(filepath)){
		result     = IsFLIRfile(filepath);
		pipepos    = indexOf(result, "|");
		cameratype = substring(result, pipepos+1);

		if(cameratype == "MWIR"){
			print("FLIR Date Stamps: date/time information cannot be");
			print("extracted from ATS/MWIR files. Absolute timestamps");
			print("are not stored inside ATS files -- only relative");
			print("frame timing via FrameCounter is available.");
			print("File: " + File.getName(filepath));
		} else {
			flirdate(filepath, printvalues);
		}
	}
}

macro "FLIR Date Stamps [D]" {
	filepath=File.openDialog("Select a FLIR Image or Video File");
	printvalues="Yes";
	if(File.exists(filepath)){
		result     = IsFLIRfile(filepath);
		pipepos    = indexOf(result, "|");
		cameratype = substring(result, pipepos+1);

		if(cameratype == "MWIR"){
			print("FLIR Date Stamps: date/time information cannot be");
			print("extracted from ATS/MWIR files. Absolute timestamps");
			print("are not stored inside ATS files -- only relative");
			print("frame timing via FrameCounter is available.");
			print("File: " + File.getName(filepath));
		} else {
			flirdate(filepath, printvalues);
		}
	}
}


//macro "FLIR Calibration Values [C]" {
//	filepath=File.openDialog("Select a FLIR Image or Video File"); 
//	printvalues="Yes";
//	if(File.exists(filepath)){
//		flirvalues(filepath, printvalues);
//	}
//}

// ============================================================
// Uses IsFLIRfile() to detect both file type AND camera type in one
// call, then dispatches to:
//   fliratsvalues()  -- MWIR/ATS files (cameratype == "MWIR")
//   flirvalues()     -- everything else (LWIR, unknown, TIFF, etc.)
//
// IsFLIRfile() returns "FILETYPE|CAMERATYPE" as a pipe-delimited
// string -- split on "|" to get both parts.
// ============================================================

macro "FLIR Calibration Values Action Tool - C000D00D01D02D03D04D05D10D16D20D22D23D24D27D2dD2eD30D32D34D36D37D38D39D3aD3bD3cD3fD40D42D44D47D4fD50D52D54D56D57D58D59D5aD5bD5cD5fD60D62D63D64D67D6dD6eD70D76D80D81D82D83D84D85DbbDbcDbdDbeDc1Dc2Dc3Dc4Dc5Dc6Dc7Dc8Dc9DcaDcbDcfDd0DdfDe1De2De3De4De5De6De7De8De9DeaDebDefDf3Df5Df7Df9DfbDfcDfdDfeCc10DccDcdDceDd5Dd6Dd7Dd8Dd9DdaDdbDdcDddDdeDecDedDee" {
	filepath=File.openDialog("Select a FLIR Image or Video File");
	printvalues="Yes";
	if(File.exists(filepath)){
		result = IsFLIRfile(filepath);

		// Parse "FILETYPE|CAMERATYPE" without relying on split()
		pipepos    = indexOf(result, "|");
		if(pipepos >= 0){
			filetype   = substring(result, 0, pipepos);
			cameratype = substring(result, pipepos+1);
		} else {
			// IsFLIRfile() returned old single-value format (no pipe)
			// -- treat the whole return value as the filetype and
			// infer cameratype from it for backwards compatibility
			filetype = result;
			if(filetype == "ATS" || filetype == "RJPEG"){
				cameratype = "MWIR";
			} else if(filetype == "unknown"){
				cameratype = "unknown";
			} else {
				cameratype = "LWIR";
			}
		}

		print("File Type: " + filetype);
		print("Thermal Camera Type: " + cameratype);

		if(cameratype == "MWIR"){
			thermalcameratype = "MWIR";
			fliratsvalues(filepath, printvalues);
		} else if(filetype == "unknown"){
			print("File type unknown -- could not identify as a FLIR file.");
		} else {
			thermalcameratype = "LWIR";
			flirvalues(filepath, printvalues);
		}

		call("ij.Prefs.set", "thermalcameratype.persistent", thermalcameratype);
	}
}

	
// ============================================================
// REPLACEMENT for the "FLIR Calibration Values [C]" macro.
//
// Uses IsFLIRfile() which returns "FILETYPE|CAMERATYPE".
// Parses the return value using indexOf/substring rather than
// split(), since ImageJ's split() uses StringTokenizer which
// can behave unexpectedly with non-whitespace delimiters.
// ============================================================

macro "FLIR Calibration Values [C]" {
	filepath=File.openDialog("Select a FLIR Image or Video File");
	printvalues="Yes";
	if(File.exists(filepath)){
		result = IsFLIRfile(filepath);

		// Parse "FILETYPE|CAMERATYPE" without relying on split()
		pipepos    = indexOf(result, "|");
		if(pipepos >= 0){
			filetype   = substring(result, 0, pipepos);
			cameratype = substring(result, pipepos+1);
		} else {
			// IsFLIRfile() returned old single-value format (no pipe)
			// -- treat the whole return value as the filetype and
			// infer cameratype from it for backwards compatibility
			filetype = result;
			if(filetype == "ATS" || filetype == "RJPEG"){
				cameratype = "MWIR";
			} else if(filetype == "unknown"){
				cameratype = "unknown";
			} else {
				cameratype = "LWIR";
			}
		}

		print("File Type: " + filetype);
		print("Thermal Camera Type: " + cameratype);

		if(cameratype == "MWIR"){
			thermalcameratype = "MWIR";
			fliratsvalues(filepath, printvalues);
		} else if(filetype == "unknown"){
			print("File type unknown -- could not identify as a FLIR file.");
		} else {
			thermalcameratype = "LWIR";
			flirvalues(filepath, printvalues);
		}

		call("ij.Prefs.set", "thermalcameratype.persistent", thermalcameratype);
	}
}


	
	
macro "FLIR Focus Distance [F]" {
	filepath=File.openDialog("Select a FLIR Image or Video File"); 
	printvalues="Yes";
	if(File.exists(filepath)){
		flirdistance(filepath, printvalues);
	}
}

macro "-" {} //menu divider

// ============================================================
// REPLACEMENT for the "Raw2Temp Action Tool" macro
// (the icon-toolbar shortcut version)
//
// The ENTIRE body of the original macro is preserved verbatim,
// unchanged, inside the "if(thermalcameratype=='LWIR')" block below
// -- this is a pure copy-paste of what already exists, with no edits
// of any kind to its internals. Only the outer if/else wrapper and
// the new MWIR sibling block are new.
//
// Default thermalcameratype is "LWIR" (see SetThermalCameraType()),
// so for every existing user who never touches the new toggle,
// behavior is 100% unchanged.
// ============================================================

macro "Raw2Temp Action Tool - C000D00D01D02D03D04D05D06D07D10D13D14D20D23D24D25D30D33D35D36D40D41D42D43D46D47D57D75D7dD85D8dD93D94D95D9bD9cD9dDa8Db8Dc8Dd8De8Df8C666D62D6aD73D7bD84D8cCf80DcbDdbCe50DcaDdaCfe2DceDdeCfc0DcdDddCd17Dc9Dd9Cff7DcfDdfCfb0DccDdc"{

	if(thermalcameratype=="LWIR"){

		// ---- UNCHANGED original macro body, verbatim ----

		byteorder=newArray("Default", "Swap");
		defaultbyteorder="Default";
		fastslowchoice=newArray("Fast", "Slow");
		fastslowchoicedefault="Fast";
		
		// Create a prompt dialog to ask user to verify the values to be used in the calculations below
		Dialog.create("Verify Camera and Object Parameters");
		Dialog.addMessage("If Calibration constants are unknown, run the FLIR Calibration Values Tool first!");
		Dialog.addMessage("TIFF files are usually little endian, PNG files are usually big endian");
		Dialog.addChoice("Keep Default or Swap Byte Order (Usually default is fine)", byteorder, defaultbyteorder);
		Dialog.addMessage("Fast calculation is approximate but repeatable, Slow is accurate but not reversible");
		Dialog.addChoice("Fast or Slow Calculation?", fastslowchoice, fastslowchoicedefault); 
		Dialog.addNumber("Estimated Image Temperature  Minimum:", imagetemperaturemin, 0, 5, "C");
	 	Dialog.addNumber("Estimated Image Temperature  Maximum:", imagetemperaturemax, 0, 5, "C");
	 	
		Dialog.addMessage("Object Parameters:");
	    Dialog.addNumber("Object Emissivity:", E, 3, 6, "unitless");
	    Dialog.addToSameRow();
	    Dialog.addNumber("Object Distance:", OD, 1, 6, "m");
	    Dialog.addNumber("Reflected Temperature (C):", RTemp, 2, 6, "C");
	    Dialog.addToSameRow();
	    Dialog.addNumber("Atmospheric Temperature (C):", ATemp, 2, 6, "C");
	    Dialog.addNumber("Window Temperature (C):", IRWTemp, 2, 6, "C");
	    Dialog.addToSameRow();
	    Dialog.addNumber("Window Transmittance:", IRT, 3, 6, "unitless");
	    Dialog.addNumber("Relative Humidity:", RH, 2, 6, "%");
	    Dialog.addToSameRow();
	    Dialog.addChoice("Palette", palettetypes, defaultpalette);
	    
		Dialog.addMessage("Camera Calibration Constants:");
		Dialog.addNumber("Planck R1:", PR1, 2, 12, "unitless"); //21106.77 //21546.203
		Dialog.addToSameRow();
		Dialog.addNumber("Planck R2:", PR2, 8, 12, "unitless"); //0.012545258 //0.016229488 
		Dialog.addNumber("Planck B:", PB, 0, 5, "unitless"); //1501 //1507.2
		Dialog.addToSameRow();
		Dialog.addNumber("Planck F:", PF, 0, 2, "unitless");//1
	    Dialog.addNumber("Planck O:", PO, 0, 5, "unitless"); //-7340 //-6331
	    Dialog.addNumber("Atmospheric Trans Alpha 1:", ATA1, 8, 12, "unitless");
		Dialog.addToSameRow();
	    Dialog.addNumber("Atmospheric Trans Alpha 2:", ATA2, 8, 12, "unitless");
	    Dialog.addNumber("Atmospheric Trans Beta 1:", ATB1, 8, 12, "unitless");
		Dialog.addToSameRow();
	    Dialog.addNumber("Atmospheric Trans Beta 2:", ATB2, 8, 12, "unitless");
	    Dialog.addNumber("Atmospheric Trans X:", ATX, 8, 12, "unitless");     
		Dialog.show();

		 ByteOrder=Dialog.getChoice();
		 FastSlow=Dialog.getChoice();
		 imagetemperaturemin = Dialog.getNumber();
		 imagetemperaturemax = Dialog.getNumber();
		 E = Dialog.getNumber();
		 OD = Dialog.getNumber();
		 RTemp = Dialog.getNumber();
		 ATemp = Dialog.getNumber();
		 IRWTemp = Dialog.getNumber();
		 IRT = Dialog.getNumber();
		 RH = Dialog.getNumber();
		 palettetype = Dialog.getChoice();
		 PR1 = Dialog.getNumber();
		 PR2 = Dialog.getNumber();
		 PB = Dialog.getNumber();
		 PF = Dialog.getNumber();
		 PO = Dialog.getNumber();
		 ATA1 = Dialog.getNumber();
		 ATA2 = Dialog.getNumber();
		 ATB1 = Dialog.getNumber();
		 ATB2 = Dialog.getNumber();
		 ATX = Dialog.getNumber();
		
		call("ij.Prefs.set", "imagetemperaturemin.persistent",toString(imagetemperaturemin)); 
		call("ij.Prefs.set", "imagetemperaturemax.persistent",toString(imagetemperaturemax)); 
		call("ij.Prefs.set", "PR1.persistent",toString(PR1)); 
		call("ij.Prefs.set", "PB.persistent",toString(PB)); 
		call("ij.Prefs.set", "PF.persistent",toString(PF)); 
		call("ij.Prefs.set", "PR2.persistent",toString(PR2)); 
		call("ij.Prefs.set", "PO.persistent",toString(PO));
		call("ij.Prefs.set", "ATA1.persistent",toString(ATA1));
		call("ij.Prefs.set", "ATA2.persistent",toString(ATA2));
		call("ij.Prefs.set", "ATB1.persistent",toString(ATB1));
		call("ij.Prefs.set", "ATB2.persistent",toString(ATB2));
		call("ij.Prefs.set", "ATX.persistent",toString(ATX));
		call("ij.Prefs.set", "E.persistent",toString(E)); 
		call("ij.Prefs.set", "OD.persistent",toString(OD)); 
		call("ij.Prefs.set", "RTemp.persistent",toString(RTemp)); 
		call("ij.Prefs.set", "ATemp.persistent",toString(ATemp)); 
		call("ij.Prefs.set", "IRWTemp.persistent",toString(IRWTemp)); 
		call("ij.Prefs.set", "IRT.persistent",toString(IRT)); 
		call("ij.Prefs.set", "RH.persistent",toString(RH)); 
		call("ij.Prefs.set", "imagewidth.persistent",toString(imagewidth)); 
		call("ij.Prefs.set", "imageheight.persistent",toString(imageheight)); 
		
		if(ByteOrder == "Swap"){
			run("Byte Swapper");
		}

		Raw2Temp(PR1, PR2, PB, PF, PO, AtmosphericTransVals(ATA1, ATA2, ATB1, ATB2, ATX), E, OD, RTemp, ATemp, IRWTemp, IRT, RH, palettetype, "No", FastSlow, imagetemperaturemin, imagetemperaturemax);

		// ---- end of unchanged original macro body ----

	}

	if(thermalcameratype=="MWIR"){

		// ---- NEW: MWIR/ATS-style nfc conversion ----
		// Mirrors the structure of the LWIR block above as closely as
		// possible, substituting Nfc* calibration constants (no Planck
		// O / no byte-order step -- ATS files don't need byte swapping)
		// and calling Counts2Temp() instead of Raw2Temp().

		fastslowchoice=newArray("Fast", "Slow");
		fastslowchoicedefault="Fast";

		Dialog.create("Verify ATS Camera and Object Parameters");
		Dialog.addMessage("If Calibration constants are unknown, run the FLIR Calibration Values Tool first!");
		Dialog.addMessage("Fast calculation is approximate but repeatable. Slow is accurate but not reversible.");
		Dialog.addChoice("Fast or Slow Calculation?", fastslowchoice, fastslowchoicedefault);
		Dialog.addNumber("Estimated Image Temperature Minimum:", imagetemperaturemin, 0, 5, "C");
		Dialog.addNumber("Estimated Image Temperature Maximum:", imagetemperaturemax, 0, 5, "C");

		Dialog.addMessage("Object Parameters:");
		Dialog.addNumber("Object Emissivity:", NfcE, 3, 6, "unitless");
		Dialog.addToSameRow();
		Dialog.addNumber("Object Distance:", NfcOD, 1, 6, "m");
		Dialog.addNumber("Reflected Temperature (C):", NfcRTemp, 2, 6, "C");
		Dialog.addToSameRow();
		Dialog.addNumber("Atmospheric Temperature (C):", NfcATemp, 2, 6, "C");
		Dialog.addNumber("Window Temperature (C):", NfcIRWTemp, 2, 6, "C");
		Dialog.addToSameRow();
		Dialog.addNumber("Window Transmittance:", NfcIRT, 3, 6, "unitless");
		Dialog.addNumber("Relative Humidity:", NfcRH, 2, 6, "%");
		Dialog.addToSameRow();
		Dialog.addChoice("Palette", palettetypes, defaultpalette);
		
		Dialog.addMessage("Camera Calibration Constants (NicevilleFactoryCal):");
		Dialog.addNumber("Nfc B:", NfcB, 4, 12, "unitless");
		Dialog.addToSameRow();
		Dialog.addNumber("Nfc R:", NfcR, 6, 12, "unitless");
		Dialog.addNumber("Nfc F:", NfcF, 4, 6, "unitless");
		Dialog.addNumber("Nfc C0:", NfcC0, 20, 20, "unitless");
		Dialog.addToSameRow();
		Dialog.addNumber("Nfc C1:", NfcC1, 20, 20, "unitless");
		Dialog.addNumber("Nfc C2:", NfcC2, 20, 20, "unitless");
		Dialog.addNumber("Atmospheric Trans Alpha 1:", NfcATA1, 8, 12, "unitless");
		Dialog.addToSameRow();
		Dialog.addNumber("Atmospheric Trans Alpha 2:", NfcATA2, 8, 12, "unitless");
		Dialog.addNumber("Atmospheric Trans Beta 1:", NfcATB1, 8, 12, "unitless");
		Dialog.addToSameRow();
		Dialog.addNumber("Atmospheric Trans Beta 2:", NfcATB2, 8, 12, "unitless");
		Dialog.addNumber("Atmospheric Trans X:", NfcATX, 8, 12, "unitless");
		Dialog.addMessage("Counts range (used to construct fast-mode polynomial within scene temp range):");
		Dialog.addNumber("Nfc Min Counts:", NfcMinCounts, 0, 8, "16-bit integer");
		Dialog.addToSameRow();
		Dialog.addNumber("Nfc Max Counts:", NfcMaxCounts, 0, 8, "16-bit integer");

		Dialog.show();

		FastSlow          = Dialog.getChoice();
		imagetemperaturemin = Dialog.getNumber();
		imagetemperaturemax = Dialog.getNumber();
		NfcE              = Dialog.getNumber();
		NfcOD             = Dialog.getNumber();
		NfcRTemp          = Dialog.getNumber();
		NfcATemp          = Dialog.getNumber();
		NfcIRWTemp        = Dialog.getNumber();
		NfcIRT            = Dialog.getNumber();
		NfcRH             = Dialog.getNumber();
		palettetype       = Dialog.getChoice();
		NfcB              = Dialog.getNumber();
		NfcR              = Dialog.getNumber();
		NfcF              = Dialog.getNumber();
		NfcC0             = Dialog.getNumber();
		NfcC1             = Dialog.getNumber();
		NfcC2             = Dialog.getNumber();
		NfcATA1           = Dialog.getNumber();
		NfcATA2           = Dialog.getNumber();
		NfcATB1           = Dialog.getNumber();
		NfcATB2           = Dialog.getNumber();
		NfcATX            = Dialog.getNumber();
		NfcMinCounts      = Dialog.getNumber();
		NfcMaxCounts      = Dialog.getNumber();


	// ---- Persist values ----
	call("ij.Prefs.set", "imagetemperaturemin.persistent", toString(imagetemperaturemin));
	call("ij.Prefs.set", "imagetemperaturemax.persistent", toString(imagetemperaturemax));
	call("ij.Prefs.set", "NfcB.persistent",   toString(NfcB));
	call("ij.Prefs.set", "NfcR.persistent",   toString(NfcR));
	call("ij.Prefs.set", "NfcF.persistent",   toString(NfcF));
	call("ij.Prefs.set", "NfcC0.persistent",  toString(NfcC0));
	call("ij.Prefs.set", "NfcC1.persistent",  toString(NfcC1));
	call("ij.Prefs.set", "NfcC2.persistent",  toString(NfcC2));
	call("ij.Prefs.set", "NfcATA1.persistent",toString(NfcATA1));
	call("ij.Prefs.set", "NfcATA2.persistent",toString(NfcATA2));
	call("ij.Prefs.set", "NfcATB1.persistent",toString(NfcATB1));
	call("ij.Prefs.set", "NfcATB2.persistent",toString(NfcATB2));
	call("ij.Prefs.set", "NfcATX.persistent", toString(NfcATX));
	call("ij.Prefs.set", "NfcE.persistent",   toString(NfcE));
	call("ij.Prefs.set", "NfcOD.persistent",  toString(NfcOD));
	call("ij.Prefs.set", "NfcRTemp.persistent",  toString(NfcRTemp));
	call("ij.Prefs.set", "NfcATemp.persistent",  toString(NfcATemp));
	call("ij.Prefs.set", "NfcIRWTemp.persistent",toString(NfcIRWTemp));
	call("ij.Prefs.set", "NfcIRT.persistent", toString(NfcIRT));
	call("ij.Prefs.set", "NfcRH.persistent",  toString(NfcRH));
	call("ij.Prefs.set", "NfcMinCounts.persistent", toString(NfcMinCounts));
	call("ij.Prefs.set", "NfcMaxCounts.persistent", toString(NfcMaxCounts));

	Counts2Temp(NfcCvals(NfcC0, NfcC1, NfcC2), NfcPlanckVals(NfcB, NfcR, NfcF), AtmosphericTransVals(NfcATA1, NfcATA2, NfcATB1, NfcATB2, NfcATX), NfcE, NfcOD, NfcRTemp, NfcATemp, NfcIRWTemp, NfcIRT, NfcRH, NfcMinCounts, NfcMaxCounts, palettetype, "No", FastSlow, imagetemperaturemin, imagetemperaturemax);

	}

}

// ============================================================
// REPLACEMENT for the "Raw2Temp Tool [r]" macro
// (the dropdown menu item version -- functionally identical to the
// icon-toolbar version above, just a different macro header)
//
// Same approach: ENTIRE original body preserved verbatim inside the
// "if(thermalcameratype=='LWIR')" block. Only the outer wrapper and
// the new MWIR sibling block are new.
// ============================================================

macro "Raw2Temp Tool [r]"{

	if(thermalcameratype=="LWIR"){

		// ---- UNCHANGED original macro body, verbatim ----

		byteorder=newArray("Default", "Swap");
		defaultbyteorder="Default";
		fastslowchoice=newArray("Fast", "Slow");
		fastslowchoicedefault="Fast";
		
		// Create a prompt dialog to ask user to verify the values to be used in the calculations below
		
		Dialog.create("Verify ATS Camera and Object Parameters");
		Dialog.addMessage("If Calibration constants are unknown, run the FLIR Calibration Values Tool first!");
		Dialog.addMessage("Fast calculation is approximate but repeatable. Slow is accurate but not reversible.");
		Dialog.addChoice("Fast or Slow Calculation?", fastslowchoice, fastslowchoicedefault);
		Dialog.addNumber("Estimated Image Temperature Minimum:", imagetemperaturemin, 0, 5, "C");
		Dialog.addNumber("Estimated Image Temperature Maximum:", imagetemperaturemax, 0, 5, "C");

		Dialog.addMessage("Object Parameters:");
		Dialog.addNumber("Object Emissivity:", NfcE, 3, 6, "unitless");
		Dialog.addToSameRow();
		Dialog.addNumber("Object Distance:", NfcOD, 1, 6, "m");
		Dialog.addNumber("Reflected Temperature (C):", NfcRTemp, 2, 6, "C");
		Dialog.addToSameRow();
		Dialog.addNumber("Atmospheric Temperature (C):", NfcATemp, 2, 6, "C");
		Dialog.addNumber("Window Temperature (C):", NfcIRWTemp, 2, 6, "C");
		Dialog.addToSameRow();
		Dialog.addNumber("Window Transmittance:", NfcIRT, 3, 6, "unitless");
		Dialog.addNumber("Relative Humidity:", NfcRH, 2, 6, "%");
		Dialog.addToSameRow();
		Dialog.addChoice("Palette", palettetypes, defaultpalette);

		Dialog.addMessage("Camera Calibration Constants (NicevilleFactoryCal):");
		Dialog.addNumber("Nfc B:", NfcB, 4, 12, "unitless");
		Dialog.addToSameRow();
		Dialog.addNumber("Nfc R:", NfcR, 6, 12, "unitless");
		Dialog.addNumber("Nfc F:", NfcF, 4, 6, "unitless");
		Dialog.addNumber("Nfc C0:", NfcC0, 20, 20, "unitless");
		Dialog.addToSameRow();
		Dialog.addNumber("Nfc C1:", NfcC1, 20, 20, "unitless");
		Dialog.addNumber("Nfc C2:", NfcC2, 20, 20, "unitless");
		Dialog.addNumber("Atmospheric Trans Alpha 1:", NfcATA1, 8, 12, "unitless");
		Dialog.addToSameRow();
		Dialog.addNumber("Atmospheric Trans Alpha 2:", NfcATA2, 8, 12, "unitless");
		Dialog.addNumber("Atmospheric Trans Beta 1:", NfcATB1, 8, 12, "unitless");
		Dialog.addToSameRow();
		Dialog.addNumber("Atmospheric Trans Beta 2:", NfcATB2, 8, 12, "unitless");
		Dialog.addNumber("Atmospheric Trans X:", NfcATX, 8, 12, "unitless");
		Dialog.addMessage("Counts range (used to construct fast-mode polynomial within scene temp range):");
		Dialog.addNumber("Nfc Min Counts:", NfcMinCounts, 0, 8, "16-bit integer");
		Dialog.addToSameRow();
		Dialog.addNumber("Nfc Max Counts:", NfcMaxCounts, 0, 8, "16-bit integer");

		Dialog.show();

		FastSlow          = Dialog.getChoice();
		imagetemperaturemin = Dialog.getNumber();
		imagetemperaturemax = Dialog.getNumber();
		NfcE              = Dialog.getNumber();
		NfcOD             = Dialog.getNumber();
		NfcRTemp          = Dialog.getNumber();
		NfcATemp          = Dialog.getNumber();
		NfcIRWTemp        = Dialog.getNumber();
		NfcIRT            = Dialog.getNumber();
		NfcRH             = Dialog.getNumber();
		palettetype       = Dialog.getChoice();
		NfcB              = Dialog.getNumber();
		NfcR              = Dialog.getNumber();
		NfcF              = Dialog.getNumber();
		NfcC0             = Dialog.getNumber();
		NfcC1             = Dialog.getNumber();
		NfcC2             = Dialog.getNumber();
		NfcATA1           = Dialog.getNumber();
		NfcATA2           = Dialog.getNumber();
		NfcATB1           = Dialog.getNumber();
		NfcATB2           = Dialog.getNumber();
		NfcATX            = Dialog.getNumber();
		NfcMinCounts      = Dialog.getNumber();
		NfcMaxCounts      = Dialog.getNumber();


	// ---- Persist values ----
	call("ij.Prefs.set", "imagetemperaturemin.persistent", toString(imagetemperaturemin));
	call("ij.Prefs.set", "imagetemperaturemax.persistent", toString(imagetemperaturemax));
	call("ij.Prefs.set", "NfcB.persistent",   toString(NfcB));
	call("ij.Prefs.set", "NfcR.persistent",   toString(NfcR));
	call("ij.Prefs.set", "NfcF.persistent",   toString(NfcF));
	call("ij.Prefs.set", "NfcC0.persistent",  toString(NfcC0));
	call("ij.Prefs.set", "NfcC1.persistent",  toString(NfcC1));
	call("ij.Prefs.set", "NfcC2.persistent",  toString(NfcC2));
	call("ij.Prefs.set", "NfcATA1.persistent",toString(NfcATA1));
	call("ij.Prefs.set", "NfcATA2.persistent",toString(NfcATA2));
	call("ij.Prefs.set", "NfcATB1.persistent",toString(NfcATB1));
	call("ij.Prefs.set", "NfcATB2.persistent",toString(NfcATB2));
	call("ij.Prefs.set", "NfcATX.persistent", toString(NfcATX));
	call("ij.Prefs.set", "NfcE.persistent",   toString(NfcE));
	call("ij.Prefs.set", "NfcOD.persistent",  toString(NfcOD));
	call("ij.Prefs.set", "NfcRTemp.persistent",  toString(NfcRTemp));
	call("ij.Prefs.set", "NfcATemp.persistent",  toString(NfcATemp));
	call("ij.Prefs.set", "NfcIRWTemp.persistent",toString(NfcIRWTemp));
	call("ij.Prefs.set", "NfcIRT.persistent", toString(NfcIRT));
	call("ij.Prefs.set", "NfcRH.persistent",  toString(NfcRH));
	call("ij.Prefs.set", "NfcMinCounts.persistent", toString(NfcMinCounts));
	call("ij.Prefs.set", "NfcMaxCounts.persistent", toString(NfcMaxCounts));
	
		if(ByteOrder == "Swap"){
			run("Byte Swapper");
		}

		Raw2Temp(PR1, PR2, PB, PF, PO, AtmosphericTransVals(ATA1, ATA2, ATB1, ATB2, ATX), E, OD, RTemp, ATemp, IRWTemp, IRT, RH, palettetype, "No", FastSlow, imagetemperaturemin, imagetemperaturemax);

		// ---- end of unchanged original macro body ----

	}

	if(thermalcameratype=="MWIR"){

		// ---- NEW: MWIR/ATS-style nfc conversion ----
		// Mirrors the structure of the LWIR block above as closely as
		// possible, substituting Nfc* calibration constants (no Planck
		// O / no byte-order step -- ATS files don't need byte swapping)
		// and calling Counts2Temp() instead of Raw2Temp().

		fastslowchoice=newArray("Fast", "Slow");
		fastslowchoicedefault="Fast";

		Dialog.create("Verify ATS Camera and Object Parameters");
		Dialog.addMessage("If Calibration constants are unknown, run fliratsvalues() first!");
		Dialog.addMessage("Fast calculation is approximate but repeatable, Slow is accurate but not reversible");
		Dialog.addChoice("Fast or Slow Calculation?", fastslowchoice, fastslowchoicedefault);
		Dialog.addNumber("Estimated Image Temperature  Minimum:", imagetemperaturemin, 0, 5, "C");
		Dialog.addNumber("Estimated Image Temperature  Maximum:", imagetemperaturemax, 0, 5, "C");

		Dialog.addMessage("Object Parameters:");
		Dialog.addNumber("Object Emissivity:", NfcE, 3, 6, "unitless");
		Dialog.addToSameRow();
		Dialog.addNumber("Object Distance:", NfcOD, 1, 6, "m");
		Dialog.addNumber("Reflected Temperature (C):", NfcRTemp, 2, 6, "C");
		Dialog.addToSameRow();
		Dialog.addNumber("Atmospheric Temperature (C):", NfcATemp, 2, 6, "C");
		Dialog.addNumber("Window Temperature (C):", NfcIRWTemp, 2, 6, "C");
		Dialog.addToSameRow();
		Dialog.addNumber("Window Transmittance:", NfcIRT, 3, 6, "unitless");
		Dialog.addNumber("Relative Humidity:", NfcRH, 2, 6, "%");
		Dialog.addToSameRow();
		Dialog.addChoice("Palette", palettetypes, defaultpalette);

		Dialog.addMessage("Camera Calibration Constants (NicevilleFactoryCal-derived):");
		Dialog.addNumber("Nfc B:", NfcB, 4, 12, "unitless");
		Dialog.addToSameRow();
		Dialog.addNumber("Nfc R:", NfcR, 6, 12, "unitless");
		Dialog.addNumber("Nfc F:", NfcF, 4, 6, "unitless");
		Dialog.addNumber("Atmospheric Trans Alpha 1:", NfcATA1, 8, 12, "unitless");
		Dialog.addToSameRow();
		Dialog.addNumber("Atmospheric Trans Alpha 2:", NfcATA2, 8, 12, "unitless");
		Dialog.addNumber("Atmospheric Trans Beta 1:", NfcATB1, 8, 12, "unitless");
		Dialog.addToSameRow();
		Dialog.addNumber("Atmospheric Trans Beta 2:", NfcATB2, 8, 12, "unitless");
		Dialog.addNumber("Atmospheric Trans X:", NfcATX, 8, 12, "unitless");
		Dialog.addNumber("Nfc Min Counts:", NfcMinCounts, 0, 8, "16-bit integer");
		Dialog.addToSameRow();
		Dialog.addNumber("Nfc Max Counts:", NfcMaxCounts, 0, 8, "16-bit integer");

		Dialog.show();

		FastSlow=Dialog.getChoice();
		imagetemperaturemin = Dialog.getNumber();
		imagetemperaturemax = Dialog.getNumber();
		NfcE = Dialog.getNumber();
		NfcOD = Dialog.getNumber();
		NfcRTemp = Dialog.getNumber();
		NfcATemp = Dialog.getNumber();
		NfcIRWTemp = Dialog.getNumber();
		NfcIRT = Dialog.getNumber();
		NfcRH = Dialog.getNumber();
		palettetype = Dialog.getChoice();
		NfcB = Dialog.getNumber();
		NfcR = Dialog.getNumber();
		NfcF = Dialog.getNumber();
		NfcATA1 = Dialog.getNumber();
		NfcATA2 = Dialog.getNumber();
		NfcATB1 = Dialog.getNumber();
		NfcATB2 = Dialog.getNumber();
		NfcATX = Dialog.getNumber();
		NfcMinCounts = Dialog.getNumber();
		NfcMaxCounts = Dialog.getNumber();

		call("ij.Prefs.set", "imagetemperaturemin.persistent",toString(imagetemperaturemin));
		call("ij.Prefs.set", "imagetemperaturemax.persistent",toString(imagetemperaturemax));
		call("ij.Prefs.set", "NfcB.persistent",toString(NfcB));
		call("ij.Prefs.set", "NfcR.persistent",toString(NfcR));
		call("ij.Prefs.set", "NfcF.persistent",toString(NfcF));
		call("ij.Prefs.set", "NfcATA1.persistent",toString(NfcATA1));
		call("ij.Prefs.set", "NfcATA2.persistent",toString(NfcATA2));
		call("ij.Prefs.set", "NfcATB1.persistent",toString(NfcATB1));
		call("ij.Prefs.set", "NfcATB2.persistent",toString(NfcATB2));
		call("ij.Prefs.set", "NfcATX.persistent",toString(NfcATX));
		call("ij.Prefs.set", "NfcE.persistent",toString(NfcE));
		call("ij.Prefs.set", "NfcOD.persistent",toString(NfcOD));
		call("ij.Prefs.set", "NfcRTemp.persistent",toString(NfcRTemp));
		call("ij.Prefs.set", "NfcATemp.persistent",toString(NfcATemp));
		call("ij.Prefs.set", "NfcIRWTemp.persistent",toString(NfcIRWTemp));
		call("ij.Prefs.set", "NfcIRT.persistent",toString(NfcIRT));
		call("ij.Prefs.set", "NfcRH.persistent",toString(NfcRH));
		call("ij.Prefs.set", "NfcMinCounts.persistent",toString(NfcMinCounts));
		call("ij.Prefs.set", "NfcMaxCounts.persistent",toString(NfcMaxCounts));
		call("ij.Prefs.set", "atsimagewidth.persistent",toString(atsimagewidth));
		call("ij.Prefs.set", "atsimageheight.persistent",toString(atsimageheight));

		Counts2Temp(NfcCvals(NfcC0, NfcC1, NfcC2), NfcPlanckVals(NfcB, NfcR, NfcF), AtmosphericTransVals(NfcATA1, NfcATA2, NfcATB1, NfcATB2, NfcATX), NfcE, NfcOD, NfcRTemp, NfcATemp, NfcIRWTemp, NfcIRT, NfcRH, NfcMinCounts, NfcMaxCounts, palettetype, "No", FastSlow, imagetemperaturemin, imagetemperaturemax);

	}

}


macro "-" {} //menu divider

macro "Estimate Window Transmittance [t]" {
	CalculateTransmittance();
}


macro "Estimate Object Emissivity [e]" {
	CalculateEmissivity();
}

macro "Estimate Camera Spot Size [s]" {
	CalculateSpotsize();
}

macro "-" {} //menu divider

macro "Set Frame Advance Default for ROI Use [a]"{
	SetAutoAdvance();
}

macro "Set Thermal Camera Type (LWIR or MWIR) [m]"{
	SetThermalCameraType();
}

macro "-" {} //menu divider

// ROI Macros and Journalling Macros Start Here

macro "Denote Image as Upright [u]" { // 

	if(defaultroifilename=="") {
		roifilename=getTitle() + "_roi_results.csv";
	}
	
	columnlabel="Posture";
	outcome="Upright";
	filename=getTitle; 

	updateResults();

	rownum=getSliceNumber()-1;
	
	// this will allow you to skip aheaad to a new slice, do the analysis, then scroll back
	for (i=0; i<getSliceNumber(); i++) { 	
		setResult("Filename", i, "");
	}

	setResult("Filename", rownum, filename);
	setResult("SliceLabel", rownum, getMetadata("label"));
	setResult("Slice", rownum, getSliceNumber());
	setResult(columnlabel, rownum, outcome);	
	
	updateResults();
	saveAs("Results", desktopdir + File.separator + File.getName(roifilename));
}


macro "Denote Image as Prone [p]" { // 

	if(defaultroifilename=="") {
		roifilename=getTitle() + "_roi_results.csv";
	}
	
	columnlabel="Posture";
	outcome="Prone";
	filename=getTitle; 
	updateResults();

	rownum=getSliceNumber()-1;
	
	// this will allow you to skip aheaad to a new slice, do the analysis, then scroll back
	for (i=0; i<getSliceNumber(); i++) { 	
		setResult("Filename", i, "");
	}

	setResult("Filename", rownum, filename);
	setResult("SliceLabel", rownum, getMetadata("label"));
	setResult("Slice", rownum, getSliceNumber());
	setResult(columnlabel, rownum, outcome);	
	
	updateResults();
	saveAs("Results", desktopdir + File.separator + File.getName(roifilename));
}


macro "Denote Image Quality as Good [g]" { // 

	if(defaultroifilename=="") {
		roifilename=getTitle() + "_roi_results.csv";
	}
	
	columnlabel="ImageQuality";
	outcome="Good";
	filename=getTitle; 
	updateResults();

	rownum=getSliceNumber()-1;
	
	// this will allow you to skip aheaad to a new slice, do the analysis, then scroll back
	for (i=0; i<getSliceNumber(); i++) { 	
		setResult("Filename", i, "");
	}

	setResult("Filename", rownum, filename);
	setResult("SliceLabel", rownum, getMetadata("label"));
	setResult("Slice", rownum, getSliceNumber());
	setResult(columnlabel, rownum, outcome);	
	
	updateResults();
	saveAs("Results", desktopdir + File.separator + File.getName(roifilename));
}


macro "Denote Image Quality as Bad [b]" { // 

	if(defaultroifilename=="") {
		roifilename=getTitle() + "_roi_results.csv";
	}
	
	roilabel="ImageQuality";
	outcome="Bad";
	filename=getTitle; 
	updateResults();

	rownum=getSliceNumber()-1;
	
	// this will allow you to skip aheaad to a new slice, do the analysis, then scroll back
	for (i=0; i<getSliceNumber(); i++) { 	
		setResult("Filename", i, "");
	}

	setResult("Filename", rownum, filename);
	setResult("SliceLabel", rownum, getMetadata("label"));
	setResult("Slice", rownum, getSliceNumber());
	setResult(roilabel, rownum, outcome);	
	
	updateResults();
	saveAs("Results", desktopdir + File.separator + File.getName(roifilename));
}


macro "ROI d Results [d]" { // 

	if(defaultroifilename=="") {
		roifilename=getTitle() + "_roi_results.csv";
	}
	
	roilabel="BillDepth";
	
	roitype=Roi.getType();
	
	getSelectionBounds(xleft, yupper, wd, ht); // provides the upper left most cursor position
	getSelectionCoordinates(xCoordinates, yCoordinates);
	len=xCoordinates.length;
		
	getCursorLoc(x2, y2, z2, flags); // obtains the final cursor postion

	x1=xCoordinates[0];
	y1=yCoordinates[0];
	x2=xCoordinates[len-1];
	y2=yCoordinates[len-1];
	

	//theta=180/PI*atan2((y2-y1), (x2-x1));
	hypotenuse=sqrt((wd*wd + ht*ht));

	getStatistics(area, mean, min, max, std, histogram);

	filename=getTitle; 

	type = selectionType(); 
	if(type==-1) exit("No ROI selection specified");
	
	updateResults();

	rownum=getSliceNumber()-1;
	
	// this will allow you to skip aheaad to a new slice, do the analysis, then scroll back
	for (i=0; i<getSliceNumber(); i++) { 	
		setResult("Filename", i, "");
	}

	setResult("Filename", rownum, filename);
	setResult("SliceLabel", rownum, getMetadata("label"));
	setResult("Slice", rownum, getSliceNumber());
	//setResult("ROI 1 X1", rownum, x1);
	//setResult("ROI 1 Y1", rownum, y1);
	//setResult("ROI 1 X2", rownum, x2);
	//setResult("ROI 1 Y2", rownum, y2);
	setResult(roilabel, rownum, hypotenuse);	
	
	updateResults();
	saveAs("Results", desktopdir + File.separator + File.getName(roifilename));
}

macro "ROI l Results [l]" { // 
	
	if(defaultroifilename=="") {
		roifilename=getTitle() + "_roi_results.csv";
	}
	
	roilabel="BillLength";
	
	roitype=Roi.getType();
	
	getSelectionBounds(xleft, yupper, wd, ht); // provides the upper left most cursor position
	getSelectionCoordinates(xCoordinates, yCoordinates);
	len=xCoordinates.length;
		
	getCursorLoc(x2, y2, z2, flags); // obtains the final cursor postion

	x1=xCoordinates[0];
	y1=yCoordinates[0];
	x2=xCoordinates[len-1];
	y2=yCoordinates[len-1];
	

	//theta=180/PI*atan2((y2-y1), (x2-x1));
	hypotenuse=sqrt((wd*wd + ht*ht));

	getStatistics(area, mean, min, max, std, histogram);

	filename=getTitle; 
	
	type = selectionType(); 
	if(type==-1) exit("No ROI selection specified");
	
	updateResults();

	rownum=getSliceNumber()-1;
	
	// this will allow you to skip aheaad to a new slice, do the analysis, then scroll back
	for (i=0; i<getSliceNumber(); i++) { 	
		setResult("Filename", i, "");
	}

	setResult("Filename", rownum, filename);
	setResult("SliceLabel", rownum, getMetadata("label"));
	setResult("Slice", rownum, getSliceNumber());
	//setResult("ROI 1 X1", rownum, x1);
	//setResult("ROI 1 Y1", rownum, y1);
	//setResult("ROI 1 X2", rownum, x2);
	//setResult("ROI 1 Y2", rownum, y2);
	setResult(roilabel, rownum, hypotenuse);	
	
	updateResults();
	saveAs("Results", desktopdir + File.separator + File.getName(roifilename));

}

macro "ROI 1 Results [1]" {
	RegionOfInterest(ROI1);
}
macro "ROI 2 Results [2]" {
	RegionOfInterest(ROI2);
}
macro "ROI 3 Results [3]" {
	RegionOfInterest(ROI3);
}
macro "ROI 4 Results [4]" {
	RegionOfInterest(ROI4);
}
macro "ROI 5 Results [5]" {
	RegionOfInterest(ROI5);
}
macro "ROI 6 Results [6]" {
	RegionOfInterest(ROI6);
}
macro "ROI 7 Results [7]" {
	RegionOfInterest(ROI7);
}
macro "ROI 8 Results [8]" {
	RegionOfInterest(ROI8);
}
macro "ROI 9 Results [9]" {
	RegionOfInterest(ROI9);
}
macro "ROI 10 Results [0]" {
	RegionOfInterest(ROI10);
}
macro "ROI 11 Results [Q]" {
	RegionOfInterest(ROI11);
}
macro "ROI 12 Results [W]" {
	RegionOfInterest(ROI12);
}
macro "ROI 13 Results [E]" {
	RegionOfInterest(ROI13);
}
macro "ROI 14 Results [R]" {
	RegionOfInterest(ROI14);
}
macro "ROI 15 Results [T]" {
	RegionOfInterest(ROI15);
}
macro "ROI 16 Results [Y]" {
	RegionOfInterest(ROI16);
}
macro "ROI 17 Results [U]" {
	RegionOfInterest(ROI17);
}
macro "ROI 18 Results [I]" {
	RegionOfInterest(ROI18);
}
macro "ROI 19 Results [O]" {
	RegionOfInterest(ROI19);
}
macro "ROI 20 Results [P]" {
	RegionOfInterest(ROI20);
}

macro "-" {} //menu divider

macro "Extract ROI Pixel Values [x]"{
	
// http://imagej.1557.x6.nabble.com/Extracts-individual-pixel-values-from-a-selection-or-RIO-td5020121.html
	
	Roi.getBounds(rx, ry, width, height); 
	row = 0; 

	for(y=ry; y<ry+height; y++) { 
    	for(x=rx; x<rx+width; x++) { 
        	if(Roi.contains(x, y)==1) { 
            	setResult("X", row, x); 
            	setResult("Y", row, y); 
            	setResult("Value", row, getPixel(x, y)); 
            	row++; 
        	} 
    	} 
	} 
}


macro "Add ROI Measurement to Image" {
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
	Dialog.addNumber("Font Size", 14);
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
	var fontsize=Dialog.getNumber();
	var addROI=Dialog.getCheckbox();
	var drawx=Dialog.getNumber();
	var drawy=Dialog.getNumber();
	
	addMeasurementLabel(type, units, decimals, colour, fontsize, addROI, drawx, drawy);
	
}


macro "Add Location of Min or Max to Image" {
	w=getWidth();
	h=getHeight();
	leftx=0;
	rightx=w;
	topy=0;
	bottomy=h;
		
	items=newArray("Max", "Min");
	Dialog.create("Choose Measurement Type");
	Dialog.addChoice("Measure Type", items);
	Dialog.addString("Label", "+");
	Dialog.addNumber("Text Colour 0-255: Black-White", 255);
	Dialog.addNumber("Font Size", 14);
	Dialog.show();
	
	var type=Dialog.getChoice();
	var label=Dialog.getString();
	var colour=Dialog.getNumber();
	var fontsize=Dialog.getNumber();
	
	addvaluelocation(type, label,  colour, fontsize);
	
}


macro "-" {} //menu divider

macro "ROI on Entire Stack [z]" {

	close("Results");
 	close("ROI*");
 	close("Fourier amplitudes of*");
 	close("Histo*");
	close("Raw data*");

	dt=Stack.getFrameInterval();
	if(dt==0){
		dt=frameinterval;
	}
	
	items=newArray("Mean", "StdDev", "Min", "Max", "Mode", "Median", "CenterMassX", "CenterMassY", "CenterMassXY", "Skewness", "Kurtosis");
	Dialog.create("ROI Analysis on Stack");
	Dialog.addMessage("This function works on stacks.  Provide an ROI and preferred summary statistic.");
	Dialog.addMessage("This ROI value is then detrended and normalised\nto remove mean value prior to a discrete fourier analysis to return freuquency components.");
	Dialog.addMessage("The user should provide time interval in seconds for the image stack if the value below is blank or incorrect.");
	Dialog.addNumber("Seconds between video frames: ", dt);
	Dialog.addChoice("Perform spectral analysis on: ", items);
	Dialog.addChoice("Window Type for Spectral Analysis: ", newArray("None", "Hamming", "Hann", "Flattop"), "Hann");
	Dialog.addNumber("Lowpass Filter: set number of samples for moving average (set to 0 to ignore): ", 0);
	Dialog.addNumber("Highpass filter: set number of samples for moving average (set to 0 to ignore): ", 0);
	Dialog.addCheckbox("Linear Detrend data before Spectral Analysis: ", 1);
	Dialog.addCheckbox("Remove mean from data before Spectral Analysis: ", 1);
	Dialog.show();
	
	//x=getValue("Mean");
	//print(x);
	//roiManager("select", 0);
	
	dt=Dialog.getNumber();
	dataType=Dialog.getChoice();
	windowType=Dialog.getChoice();
	lowpasssamples=Dialog.getNumber();
	highpasssamples=Dialog.getNumber();
	detrend=Dialog.getCheckbox();
	removemean=Dialog.getCheckbox();
	
	frameinterval=dt;

	Stack.setFrameInterval(frameinterval + " sec");
	call("ij.Prefs.set", "frameinterval.persistent", toString(frameinterval)); 
	imageproperties="channels=1 frames=1 pixel_width=1.0000 pixel_height=1.0000 voxel_depth=1.0000 frame=[" + frameinterval + " sec\] global";
	run("Properties...", imageproperties);
	
	run("Clear Results");
	run("Set Measurements...", "stack mean standard modal min median center skewness kurtosis stack display redirect=None decimal=9");
	run("ROI Manager...");
	roiManager("reset");
	roiManager("Add");
	roiManager("Show All");
	roiManager("Multi Measure");
	
	data=newArray(nSlices);
	x=newArray(nSlices);
	Time=Array.getSequence(nSlices);
	databackground=newArray(nSlices);
	XM1=newArray(nSlices);
	YM1=newArray(nSlices);
	
	// Define a time variable
	for (i = 0; i < nSlices; i++) {
		Time[i]=Time[i]*frameinterval;
		XM1[i]=getResult("XM1", i);
		YM1[i]=getResult("XM1", i);
		ZM1=(XM1[i]+YM1[i])/2;
		setResult("Elapsed Time", i, Time[i]);
		setResult("ZM1", i, ZM1);
	}
	
	// rename Label values to be the Slice Labels
	for (i=1; i<=nSlices; i++) { 
		setSlice(i);
		setResult("Label", i-1, getMetadata("Label"));
	}
	
	for(n=0; n<nSlices; n++){
		if(dataType=="Mean"){
			data[n]=getResult("Mean1", n);
			databackground[n]=getResult("Mean1", n);
			//databackground[n]=getResult("XM2", n) + getResult("YM2", n);
			//databackground[n]=(getResult("XM2", n) + getResult("YM2", n) +  getResult("StdDev2", n) + getResult("Skew2", n) + getResult("Kurt2", n))/5;
			dataname="ROI Mean";
		}
		if(dataType=="StdDev"){
			data[n]=getResult("StdDev1", n);
			databackground[n]=getResult("Mean1", n);
			dataname="ROI StdDev";
		}
		if(dataType=="Min"){
			data[n]=getResult("Min1", n);
			databackground[n]=getResult("Mean1", n);
			dataname="ROI Min";
		}
		if(dataType=="Max"){
			data[n]=getResult("Max1", n);
			databackground[n]=getResult("Mean1", n);
			dataname="ROI Max";
		}
		if(dataType=="CenterMassX"){
			data[n]=getResult("XM1", n);
			databackground[n]=getResult("Mean1", n);
			dataname="ROI CenterMassX";
		}
		if(dataType=="CenterMassY"){
			data[n]=getResult("YM1", n);
			databackground[n]=getResult("Mean1", n);
			dataname="ROI CenterMassY";
		}
		if(dataType=="CenterMassXY"){
			data[n]=getResult("ZM1", n);
			databackground[n]=getResult("Mean1", n);
			dataname="ROI CenterMassXY";
		}
		if(dataType=="Mode"){
			data[n]=getResult("Mode1", n);
			databackground[n]=getResult("Mean1", n);
			dataname="ROI Mode";
		}
		if(dataType=="Median"){
			data[n]=getResult("Median1", n);
			databackground[n]=getResult("Mean1", n);
			dataname="ROI Median";
		}
		if(dataType=="Skewness"){
			data[n]=getResult("Skew1", n);
			databackground[n]=getResult("Mean1", n);
			dataname="ROI Skewness";
		}
		if(dataType=="Kurtosis"){
			data[n]=getResult("Kurt1", n);
			databackground[n]=getResult("Mean1", n);
			dataname="ROI Kurtosis";
		}
		
	}

	originaldata=newArray(nSlices);
	for (i = 0; i < nSlices; i++) {
		//Time[i]=Time[i]*frameinterval; 
		originaldata[i]=data[i];
	}

	Array.getStatistics(originaldata, mean);
	mean=mean;

		// Having decided on the background reference data, fit a curve through it to represent the slow changing movement
		// artifact
	
		//Fit.doFit("8th Degree Polynomial", x, databackground);
		//Fit.logResults;

		if(lowpasssamples==0 || highpasssamples==0){
			predictedlowpass=data;
			predictedhighpass=data;
		}
		
		// if user sets low pass sample >0, then resample the data as a moving average over these # of samples
		if(lowpasssamples>0){
			predictedlowpass=movavg(data,lowpasssamples);
			for(i=0; i<nSlices; i++){
				data[i]=predictedlowpass[i];
			}
		}
		
		shifteddata=newArray(nSlices);
		
		// if highpasssamples>0 then subtract the slow moving average from the data
		if(highpasssamples >0 ){
			predictedhighpass=movavg(databackground, highpasssamples);
			for(i=0; i<nSlices; i++){
				//predicted[i]=Fit.f(x[i]);
				data[i]=data[i]-predictedhighpass[i];
				shifteddata[i]=data[i]+mean;
			}
		}

	
	if(lowpasssamples>=0 || highpasssamples>=0){
		Plot.create("Original Data", "Time (s)", dataname, Time, originaldata);
		Plot.show();
		Plot.setColor("red");
		run("Line Width...", "line=5");
		Plot.add("line", Time, predictedhighpass);
		Plot.setColor("blue");
		Plot.add("line", Time, predictedlowpass);
		Plot.setColor("orange");
		Plot.add("line", Time, shifteddata);
		run("Line Width...", "line=1"); // return to default
	}
	
	spectralanalysis(data, dataname, windowType, dt, detrend, removemean);
	
	saveAs("Results", desktopdir + File.separator + "ROI_Stack_Results.csv");
}


macro "Cumulative Difference Sum on Stack [Z]"{
	
	run("Clear Results");
	close("Results");
 	
 	close("ROI*");
 	close("Cumulative*");
 	close("Inter Frame Differenc*");
 	close("Difference Image");
 	close("Fourier amplitudes of*");
 	close("Histo*");
	close("Raw data*");
	
	dt=Stack.getFrameInterval();
	if(dt==0){
		dt=frameinterval;
	}
	
	Dialog.create("Cumulative Difference Sum Analysis");
	Dialog.addMessage("This function works on stacks first by subtracting the difference in pixel values between frames,\ncreating an absolute value difference stack n-1 frames in length.");
	Dialog.addMessage("Then all pixels from each frame are examined for the mean and standard deviation per frame,\nstored to the results window, after which a cumulative value is calculated.");
	Dialog.addMessage("This cumulative absolute difference value is then detrended and normalised\nto remove mean value prior to a discrete fourier analysis to return freuquency components.");
	Dialog.addChoice("Is your image stack already a difference image? (If no, a difference stack will be calculated", newArray("No", "Yes"));
	Dialog.addMessage("The user should provide time interval in seconds for the image stack if value below is blank or incorrect.");
	Dialog.addNumber("Seconds between video frames: ", dt);
	Dialog.addChoice("Perform spectral analysis on mean or sd: ", newArray("sd", "mean", "cv"));
	Dialog.addChoice("Window Type for Spectral Analysis: ", newArray("None", "Hamming", "Hann", "Flattop"));
	Dialog.addCheckbox("Detrend data before Spectral Analysis: ", 1);
	Dialog.addCheckbox("Remove mean from data before Spectral Analysis: ", 1);
	Dialog.show();

	isdifference=Dialog.getChoice();
	dt=Dialog.getNumber();
	dataType=Dialog.getChoice();
	windowType=Dialog.getChoice();
	detrend=Dialog.getCheckbox();
	removemean=Dialog.getCheckbox();

	frameinterval=dt;
	Stack.setFrameInterval(frameinterval + " sec");
	call("ij.Prefs.set", "frameinterval.persistent", toString(frameinterval)); 
	imageproperties="channels=1 frames=1 pixel_width=1.0000 pixel_height=1.0000 voxel_depth=1.0000 frame=[" + frameinterval + " sec\] global";
	run("Properties...", imageproperties);
	
	StackCumulativeDiffSummation(dt, dataType, windowType, detrend, removemean, isdifference);
	
	saveAs("Results", desktopdir + File.separator + "C_Diff_Stack_Results.csv");
}


macro "-" {} //menu divider


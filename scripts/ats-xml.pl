#!/usr/bin/perl

# ats-xml.pl  v4.0
# Author: Glenn J. Tattersall / Claude, 2026
#
# Extracts metadata and calibration constants from a FLIR ATS video file
# (.ats) or RJPEG (.jpg). Default output is ExifTool-style: a flat list
# of "Tag : Value" lines with NO section headers, intended to be parsed
# programmatically (e.g. by ThermImageJ in FIJI via colon-splitting).
# Verbose mode (-v) adds section headers, all-4-presets detail, detection
# diagnostics, and explanatory notes -- intended for humans, not parsing.
#
# USAGE:
#   perl ats-xml.pl -i <file.ats>
#   perl ats-xml.pl -i <file.jpg>           (RJPEG / ATS-JPG snapshot)
#   perl ats-xml.pl -i <file.ats> -v        (verbose: full diagnostic output)
#   perl ats-xml.pl -i <file.ats> -o <output.txt>   (save to file)
#   perl ats-xml.pl -i <file.ats> -p 2      (override active-preset detection)
#
# ============================================================
# v3.0 CHANGES FROM v2.0 -- WHY THIS REWRITE HAPPENED
# ============================================================
# v2.0 derived "Planck" calibration constants (PlanckB/PlanckR1/PlanckO)
# from two (Counts, TemperatureK) "CalPair" values found in the Workspace
# XML's <segmentationValue> tags. This turned out to be WRONG in a
# fundamental way: those XML values are SEGMENTATION THRESHOLDS (a
# ResearchIR/Research Studio display/highlighting feature -- pixels
# outside the range show as blue/red), not a calibration reference.
# See ats-jpg-and-xml-notes.md, Addendum 4, for FLIR's own documentation
# confirming this. The v2.0 2-point Planck fit reproduced those two
# points exactly (by construction) but was off by ~1-3C across the rest
# of any given recording's actual scene -- because it was never fitting
# real calibration data in the first place.
#
# The REAL calibration data lives in 4 binary "NicevilleFactoryCal"
# blocks per file (one per NUC temperature preset), which we cracked by
# cross-referencing FLIR's own ATSFileUtil tool's ".inc" export against
# raw file bytes. The real conversion is a TWO-STEP chain:
#   1. Radiance = nfcC0 + nfcC1*Counts + nfcC2*Counts^2   (quadratic)
#   2. TempK    = nfcB / ln(nfcR/Radiance + nfcF)          (Planck, radiance domain)
# This was validated against REAL Research Studio TIFF output (not just
# self-consistency): RMSE 0.0001C across a full scene's pixels, vs
# 0.62C RMSE for FLIR's own exported 6th-order polynomial approximation
# of the same curve (see ats-jpg-and-xml-notes.md, Addendum 3).
#
# The v2.0 CalPair/Lambda/PlanckO logic is preserved below, commented
# out, for reference -- DO NOT re-enable without re-reading Addendum 1
# and Addendum 4 in the notes file first.
# ============================================================

use strict;
use warnings;
use Getopt::Std;
use POSIX qw();

my $C2 = 14387.752;  # um*K  (second radiation constant -- universal physics
                      # constant, NOT in question; used only to derive an
                      # informational "effective wavelength" display value)

# ============================================================
# Arguments
#
# v3.4 ADDITION: ExifTool-style "-TagName" filtering. ExifTool lets you
# run `exiftool -Emissivity file.jpg` to print only that one tag. We
# support the same syntax here: any -argument that isn't one of our
# known single-letter flags (-h -i -o -v -p) is treated as a requested
# tag name. Multiple such flags can be given to request multiple tags,
# same as ExifTool. When any tag filters are given, the script builds
# its full output internally as usual, then prints ONLY the matching
# lines (case-sensitive exact tag-name match) instead of everything.
# ============================================================
my @tag_filters;
{
    my @remaining;
    for my $arg (@ARGV) {
        if ($arg =~ /^-([A-Za-z][A-Za-z0-9_]*)$/ && $1 !~ /^[hiovp]$/) {
            push @tag_filters, $1;
        } else {
            push @remaining, $arg;
        }
    }
    @ARGV = @remaining;
}

my %opt;
getopts("hi:o:vp:", \%opt);
my $infile      = $opt{i};
my $verbose     = $opt{v} || 0;
my $force_preset = defined $opt{p} ? $opt{p} : undef;

if ($opt{h} || !$infile) {
    print "Usage: perl ats-xml.pl -i <input.ats or .jpg> [-v] [-o output.txt] [-p 0-3] [-TagName ...]\n";
    print "  -v          verbose mode: section headers, all 4 presets, diagnostics\n";
    print "  -o FILE     save output to FILE (in addition to printing it)\n";
    print "  -p N        override active-preset detection, force preset N (0-3)\n";
    print "  -TagName    print only this tag (ExifTool-style; repeatable, e.g. -Emissivity -NfcB)\n";
    exit;
}

# ============================================================
# Read file and extract FLIR data stream
# ============================================================
open(my $fh, '<:raw', $infile) or die "Cannot open '$infile': $!\n";
my $file = do { local $/; <$fh> };
close $fh;

my $stream;
my $filetype;

if ($file =~ /^\xFF\xD8/) {
    $filetype = "RJPEG";
    my @App = split /(?=\xFF\xE1)/, $file;
    $stream  = "";
    for my $i (1 .. $#App) {
        my $seglen = unpack("n", substr($App[$i], 2, 2));
        $stream .= substr($App[$i], 12, $seglen - 10);
    }
} elsif ($file =~ /^FLIR ATS-US File/) {
    $filetype = "ATS";
    $stream   = $file;
} else {
    die "ERROR: Not a recognised FLIR ATS or RJPEG file.\n";
}

# ============================================================
# Extract Workspace XML block (segmentation thresholds, object
# parameters, source/display settings -- all still useful, just
# not for calibration; see Addendum 4 in the notes file)
# ============================================================
# ============================================================
# Extract Workspace XML block (segmentation thresholds, object
# parameters, source/display settings -- all still useful, just
# not for calibration; see Addendum 4 in the notes file)
#
# v3.1 CHANGE: XML is now OPTIONAL, not required. Some .ats files
# (e.g. files shared by FLIR from cameras calibrated outside the
# "Niceville" facility, observed with "FranceFactoryCal" blocks
# instead of "NicevilleFactoryCal") do not contain a Workspace XML
# at all, but DO contain SourceInfo, ObjectParameters, and FactoryCal
# binary blocks. Previously this script died immediately if the XML
# was missing, before ever attempting to read those other blocks --
# that was the actual bug, not anything wrong with the other parsers.
# ============================================================
my $xml_open  = '<workspaceFileSettings';
my $xml_close = '</workspaceFileSettings>';
my $xs = index($stream, $xml_open);
my $xe = index($stream, $xml_close);
my $has_xml = ($xs >= 0 && $xe >= 0);
my $xml = $has_xml ? substr($stream, $xs, $xe + length($xml_close) - $xs) : '';

if (!$has_xml) {
    print STDERR "NOTE: No Workspace XML found in this file. Segmentation "
               . "thresholds, scene range, and XML-derived object parameters "
               . "will be unavailable. Camera info, per-frame metadata, and "
               . "FactoryCal binary blocks will still be attempted.\n";
}

sub tag_attrs {
    my ($xml, $tag) = @_;
    my %by_unit;
    while ($xml =~ /<${tag}(\b[^>\/]*)[\/>]/g) {
        my $attrs_str = $1;
        my %h;
        while ($attrs_str =~ /(\w+)="([^"]*)"/g) { $h{$1} = $2; }
        next unless %h;
        my $key = $h{unit} // '_';
        $by_unit{$key} = \%h unless exists $by_unit{$key};
    }
    return %by_unit;
}

sub get_attr {
    my ($xml, $tag, $attr) = @_;
    return $1 if $xml =~ /<${tag}\b[^>]*\b${attr}="([^"]*)"/;
    return undef;
}

# ============================================================
# Parse Workspace XML fields
#
# v3.1 NOTE: object parameters (emissivity, distance, etc.) currently
# ONLY come from the Workspace XML. When XML is absent (e.g. the
# FranceFactoryCal-style files), these all silently fall back to
# hardcoded defaults below -- which is misleading if presented as if
# they were read from the file. $objparams_from_xml tracks this so the
# output can flag defaulted values honestly instead of implying they
# were extracted. A binary ObjectParameters block HAS been observed in
# at least one XML-less file (visually, via hex editor) but we do not
# yet have a verified byte layout for it -- this is a known gap, not
# yet fixed. See ats-jpg-and-xml-notes.md for status.
# ============================================================
my $objparams_from_xml = $has_xml;

my %seg   = tag_attrs($xml, 'segmentationValue');
my %level = tag_attrs($xml, 'levelAndSpanValue');

# v3.4 ADDITION: ImageWidth/ImageHeight binary fallback. Previously
# these came ONLY from the XML's <roiList> tag, so files without
# Workspace XML always reported "unknown" -- even though the Width/
# Height values were ALREADY being read from the binary "Pixels" block
# elsewhere in this script (for internal frame-size math) and simply
# never surfaced. Confirmed correct via direct verification against a
# known answer (faceRecognitionA8300sc-000003.ats, true size 1280x720):
# Pixels+107 (u16 LE) = 1280, Pixels+109 (u16 LE) = 720, exact match.
my $pixels_tag_early = index($stream, "Pixels");
my ($img_w_bin, $img_h_bin);
if ($pixels_tag_early >= 0
    && $pixels_tag_early + 111 <= length($stream)) {
    $img_w_bin = unpack("v", substr($stream, $pixels_tag_early + 107, 2));
    $img_h_bin = unpack("v", substr($stream, $pixels_tag_early + 109, 2));
}

my $img_w = get_attr($xml, 'roiList', 'imageWidth')  // $img_w_bin;
my $img_h = get_attr($xml, 'roiList', 'imageHeight') // $img_h_bin;
my $src_unit   = get_attr($xml, 'source',            'unit');
my $temp_type  = get_attr($xml, 'source',            'temperatureType');
my $apply_nuc  = get_attr($xml, 'source',            'applyNUC');
my $apply_bp   = get_attr($xml, 'source',            'applyBP');
my $emissivity = get_attr($xml, 'objectParameters',  'emissivity')            // '1.0';
my $distance   = get_attr($xml, 'objectParameters',  'distance')              // '1';
my $ext_trans  = get_attr($xml, 'objectParameters',  'extOpticsTransmission') // '1';
my $palette    = get_attr($xml, 'palette',           'name')                  // '';

my $refl_temp_K  = get_attr($xml, 'objectParameters', 'reflectedTemp')     // '293.15';
my $atm_temp_K   = get_attr($xml, 'objectParameters', 'atmosphereTemp')    // '293.15';
my $ext_temp_K   = get_attr($xml, 'objectParameters', 'extOpticsTemp')     // '293.15';
my $rel_hum_frac = get_attr($xml, 'objectParameters', 'relativeHumidity')  // '0.5';

# v3.2 ADDITION, renamed v3.3: the XML attribute "estAtmosphericTransmission"
# was present in the schema all along (confirmed via direct string dump of
# a real file's <objectParameters> tag) but never extracted in v2.0-v3.1.
# Renamed here to TransmissionOverrideFlag to match the binary
# ObjectParameters field at offset 110, which was CONFIRMED (via a direct
# hex-edit test in Research Studio -- see notes Addendum 5) to be a
# boolean override toggle for the "Transmission" UI field, not a
# continuous physical estimate. A literal transmission value of 0 (seen
# in this XML attribute for a real file) would be physically nonsensical
# for a working camera, which independently supports the same
# boolean-flag interpretation. NOTE ON CONFIDENCE: the hex-edit test was
# performed on the BINARY-ObjectParameters path (a different file, no
# XML); this XML attribute's identical name and 0/1-only values strongly
# suggest it's the same flag, but that has NOT been independently
# hex-edit-confirmed on an XML-bearing file. Treat as "very likely, by
# analogy" rather than "directly confirmed" for this specific code path.
my $trans_override_flag = get_attr($xml, 'objectParameters', 'estAtmosphericTransmission') // '0';

my $refl_temp_C = $refl_temp_K - 273.15;
my $atm_temp_C  = $atm_temp_K  - 273.15;
my $ext_temp_C  = $ext_temp_K  - 273.15;
my $rel_hum_pct = $rel_hum_frac * 100;

# ============================================================
# Extract camera info from SourceInfo binary block
# ============================================================
my $si_pos = index($stream, "SourceInfo");
my ($camera_model, $camera_serial, $lens_focal) = ('', '', '');

if ($si_pos >= 0) {
    my $si_region = substr($stream, $si_pos, 512);
    my @strings;
    while ($si_region =~ /([A-Za-z0-9][A-Za-z0-9_ \-\.]{3,})/g) {
        push @strings, $1 unless $1 =~ /^(SourceInfo|FLIR|Workspace)/;
    }
    ($camera_model)  = grep { /^[A-Z]\d{4}/ } @strings;
    ($camera_serial) = grep { /^\d{5}$/ }      @strings;
    ($lens_focal)    = grep { /^\d+ mm$/ }     @strings;
}

# ============================================================
# Binary ObjectParameters parser (v3.2 -- fallback for files without
# Workspace XML)
#
# Some .ats files (observed: a France-calibrated file with no XML, and
# an A8300sc file with no XML) carry object parameters in a binary
# "ObjectParameters" block instead of XML. Field layout was reverse-
# engineered from real bytes in TWO such files and CONFIRMED against
# the user's own Research Studio readings for both -- not guessed.
#
# Layout (offsets relative to the 'O' of "ObjectParameters\x00"):
#   86  : f32 LE  Emissivity                  -- CONFIRMED exact, both files
#   90  : f32 LE  ObjectDistance (m)           -- CONFIRMED exact, both files
#   94  : f32 LE  ReflectedTemp (K)            -- value confirmed; order vs
#   98  : f32 LE  AtmosphereTemp (K)              98/102 inferred from XML
#  102  : f32 LE  ExtOpticsTemp/IRWindowTemp(K)   attribute order, NOT yet
#                                                  independently verified
#                                                  (both test files had all
#                                                  three at the same default
#                                                  293.15K)
#  106  : f32 LE  ExternalOpticsTransmission  -- CONFIRMED exact, both files
#  110  : f32 LE  TransmissionOverrideFlag -- CONFIRMED via direct hex-edit
#                  experiment: changing this from 0.0 to 1.0 in a real file
#                  flipped Research Studio's "Transmission" override toggle
#                  from OFF to ON, and the displayed Transmission value
#                  changed from the stored 0.975 (greyed out/read-only) to
#                  a reset default of 1.000 (editable). This is a BOOLEAN
#                  override flag controlling whether offset 114's
#                  Transmission value is taken from the file/computed
#                  value (0.0) or manually overridden (1.0) -- NOT a
#                  continuous physical measurement. Originally guessed to
#                  be ExifTool's "EstimatedAtmosphericTrans" tag (matched
#                  by position only) -- that guess is now known to be
#                  WRONG given this toggle behavior; left here as a record
#                  of the dead end. Exact relationship (if any) to the
#                  Workspace XML's separate "estAtmosphericTransmission"
#                  attribute is still unclear and not assumed.

#  114  : f32 LE  Transmission / IRWindowTransmission -- CONFIRMED exact,
#                  both files (0.975 in the A8300sc file nails this one)
#  118  : f32 LE  RelativeHumidity (fraction) -- CONFIRMED exact, both files
#
# See ats-jpg-and-xml-notes.md for the full cross-referencing history.
# ============================================================
my $op_pos = index($stream, "ObjectParameters\x00");
my $objparams_from_binary = 0;
my %binop;  # binary-decoded object parameters, if found

use constant {
    OP_OFF_EMISSIVITY  =>  86,
    OP_OFF_DISTANCE    =>  90,
    OP_OFF_REFLTEMP    =>  94,
    OP_OFF_ATMTEMP     =>  98,
    OP_OFF_EXTOPTTEMP  => 102,
    OP_OFF_EXTOPTTRANS => 106,
    OP_OFF_TRANSOVERRIDE  => 110,
    OP_OFF_TRANS       => 114,
    OP_OFF_RELHUM      => 118,
};

if ($op_pos >= 0 && $op_pos + 122 <= length($stream)) {
    $binop{Emissivity}        = read_f32($stream, $op_pos + OP_OFF_EMISSIVITY);
    $binop{ObjectDistance}    = read_f32($stream, $op_pos + OP_OFF_DISTANCE);
    $binop{ReflectedTemp_K}   = read_f32($stream, $op_pos + OP_OFF_REFLTEMP);
    $binop{AtmosphereTemp_K}  = read_f32($stream, $op_pos + OP_OFF_ATMTEMP);
    $binop{ExtOpticsTemp_K}   = read_f32($stream, $op_pos + OP_OFF_EXTOPTTEMP);
    $binop{ExtOpticsTrans}    = read_f32($stream, $op_pos + OP_OFF_EXTOPTTRANS);
    $binop{TransmissionOverrideFlag}        = read_f32($stream, $op_pos + OP_OFF_TRANSOVERRIDE);
    $binop{Transmission}      = read_f32($stream, $op_pos + OP_OFF_TRANS);
    $binop{RelativeHumidity}  = read_f32($stream, $op_pos + OP_OFF_RELHUM);
    $objparams_from_binary = 1;
}

# ============================================================
# Extract per-frame metadata from the first inter-frame block
#
# CLOCK_HZ CORRECTED in v3.0 (again): v3.0's first draft used
# ticks/CLOCK_HZ*1000 assuming CLOCK_HZ was ticks-per-SECOND, giving
# IntegrationTime=1699.68ms instead of the correct 1.699680ms (confirmed
# directly against FLIR Research Studio's own metadata display, and
# against ATSFileUtil's presetInfo[0].intTime=1.699680ms).
# The fix: ticks/CLOCK_HZ alone (no *1000) already yields milliseconds.
# So CLOCK_HZ=6250 is really "ticks per millisecond", not "ticks per
# second" -- the _HZ naming was misleading; corrected the formula below
# (not the constant name, to avoid disturbing anything else that may
# reference it) and added this note so the mistake isn't repeated.
my $CLOCK_HZ          = 6250;   # ticks per MILLISECOND (despite the _HZ name)
# FRAME_META_BYTES is now derived from image width after Width is known.
# Placeholder here; actual value set after Width/Height are read.
my $FRAME_META_BYTES  = 2560;  # overridden below with Width*2
my $META_RECORD_BYTES = 256;

# v3.5 FIX: pixel_start was previously found by BACKWARD ARITHMETIC --
# assuming the entire file from just after the Pixels header to EOF is
# exactly N identical (frame_bytes + FRAME_META_BYTES) blocks, and
# solving for N. This broke badly on CricketCooling-319_18_49_58_963-
# 0008.ats (a file the user noted was the only one saved with a
# different/larger palette, taking up extra space before the XML
# data) -- the loop found a mathematically-valid-looking N=35 that
# happened to satisfy the loose bounds check, but did NOT actually
# point at real per-frame metadata (confirmed: decoded to nonsense --
# CameraSN_int=1417119095 instead of 49, MainBoardTemp=-273C, etc).
# The user correctly flagged that ANY backward/file-size-dependent
# assumption is inherently fragile, since FLIR files can include
# variable-sized blocks (palettes, ROIs, etc) that silently break a
# "uniform N blocks" assumption.
#
# Root cause investigation (see ats-jpg-and-xml-notes.md Addendum 6
# for the full story) initially chased the alphabet-marker pattern
# (B,C,D...Z,[,\,],^,_) as a forward-search anchor, but this turned
# out to be unreliable on its own -- it appears at a FIXED 256-byte
# period for 9-10 consecutive repeats near the start of every file
# we checked (including the two REFERENCE files that decode
# correctly), and naively reading metadata from inside that region
# gives a nonsensical, IDENTICAL FrameCounter across all repeats.
# However: it was determined empirically (and confirmed three
# independent ways: direct value-correctness check against known
# CameraSN/FilterID/SaturationThreshold, a check that this position
# does NOT show 256-byte self-repetition the way true padding would,
# and consistency across THREE different files including the
# previously-broken CricketCooling) that a SIMPLE FIXED GAP from the
# Pixels tag reliably locates real pixel data:
#
#   pixel_start = pixels_tag + 3149   (constant across all 3 files
#                                       tested: Rec-0018, CricketCooling,
#                                       Morio -- despite their differing
#                                       file sizes, frame counts, and in
#                                       CricketCooling's case, a
#                                       different palette)
#
# We do NOT yet have a confirmed explanation for WHY this exact
# constant works, or whether it's truly universal vs specific to this
# camera/header format -- the user specifically asked whether the
# Pixels header itself might contain an EXPLICIT stored offset field
# (which would be more robust than a bare constant), and that
# possibility is still being checked as of this writing (see
# scan_for_offset_field.py in outputs). If/when a real stored offset
# field is confirmed, it should REPLACE this constant. Until then,
# this constant is the best validated approach we have, and is a
# major improvement over the old backward-arithmetic method since it
# no longer depends on file size or assumed frame count at all.
my $PIXEL_DATA_GAP = 3149;   # fallback constant; dynamic detection preferred

my %frame_meta;
my $pixels_tag = $pixels_tag_early;  # already found above (for ImageWidth/Height)

if ($filetype eq 'ATS' && $pixels_tag >= 0) {
    my $file_size = length($stream);
    my $Width  = unpack("v", substr($stream, $pixels_tag + 107, 2));
    my $Height = unpack("v", substr($stream, $pixels_tag + 109, 2));
    my $frame_bytes = $Width * $Height * 2;

    # v4.0: dynamic pixel_start detection (mirrors ats-split.pl v4.0).
    # Step 1: find zero->pixel boundary (4 zero bytes then 6 valid counts)
    $FRAME_META_BYTES = $Width * 2;  # width-derived (not fixed 2560)
    my $pixel_start = undef;
    my ($PIX_LO, $PIX_HI, $ZERO_PREFIX) = (1000, 15000, 4);
    my $s_start = $pixels_tag + 1800;
    my $s_end   = $pixels_tag + 3500;
    PIXSCAN: for my $pos ($s_start .. $s_end) {
        last if $pos + 12 > $file_size;
        my $zeros_ok = 1;
        for my $i (0..$ZERO_PREFIX-1) {
            $zeros_ok=0,last
                if unpack("C",substr($stream,$pos-$ZERO_PREFIX+$i,1))!=0;
        }
        next unless $zeros_ok;
        my $pix_ok = 1;
        for my $i (0..5) {
            my $v = unpack("v", substr($stream, $pos+$i*2, 2));
            $pix_ok=0,last if $v<$PIX_LO || $v>$PIX_HI;
        }
        next unless $pix_ok;
        # Step 2: nudge to HeaderID=20
        for my $nudge (0..15) {
            my $mo = $pos + $nudge + $frame_bytes;
            if ($mo < $file_size &&
                unpack("C",substr($stream,$mo,1))==20) {
                $pixel_start = $pos + $nudge;
                last PIXSCAN;
            }
        }
    }
    $pixel_start //= $pixels_tag + $PIXEL_DATA_GAP;  # fallback

    # ---- OLD METHOD (v3.0-v3.4), preserved per user request as a
    # documented dead end / fallback for posterity. This back-solved
    # for how many (frame+meta) blocks must fit between pixel_start
    # and EOF, assuming perfect uniformity -- works for SOME files
    # (e.g. correctly found pixel_start=10431 for Rec-0018, matching
    # the new method's result exactly: 7282+3149=10431) but produced
    # a wrong, nonsensical result for CricketCooling. Left here
    # commented out in case a future file breaks the new fixed-gap
    # assumption and this old approach needs to be revisited or
    # combined with it.
    #
    # my $pixel_start = -1;
    # for my $N (1..5000) {
    #     my $candidate = $file_size - $N*$frame_bytes - ($N-1)*$FRAME_META_BYTES;
    #     next unless $candidate > $pixels_tag + 100;
    #     next unless $candidate < $pixels_tag + 10000;
    #     $pixel_start = $candidate;
    #     last;
    # }

    if ($pixel_start >= 0) {
        my $meta_offset = $pixel_start + $frame_bytes;
        if ($meta_offset + $META_RECORD_BYTES <= $file_size) {
            my $meta = substr($stream, $meta_offset, $META_RECORD_BYTES);

            $frame_meta{SavedFrameCounter}     = unpack("C", substr($meta,  4, 1));
            $frame_meta{FrontPanelTemp_K100}   = unpack("v", substr($meta, 12, 2));
            $frame_meta{AirGapTemp_K100}       = unpack("v", substr($meta, 14, 2));
            $frame_meta{InternalTemp_K100}     = unpack("v", substr($meta, 16, 2));
            $frame_meta{FPATemp_K100}          = unpack("v", substr($meta, 18, 2));
            $frame_meta{FrameCounter}          = unpack("V", substr($meta, 20, 4));
            $frame_meta{IntegrationTime_ticks} = unpack("V", substr($meta, 24, 4));
            $frame_meta{FilterID}              = unpack("C", substr($meta, 30, 1));
            $frame_meta{SaturationThreshold}   = unpack("v", substr($meta, 44, 2));
            $frame_meta{SaturatedPixels}       = unpack("v", substr($meta, 46, 2));
            $frame_meta{AnalogOffset_mV}       = unpack("v", substr($meta, 62, 2));
            $frame_meta{MainBoardTemp_K100}    = unpack("v", substr($meta, 64, 2));
            $frame_meta{PowerBoardTemp_K100}   = unpack("v", substr($meta, 66, 2));
            $frame_meta{DigitizerTemp_K100}    = unpack("v", substr($meta, 68, 2));
            $frame_meta{NUCFlagTemp_K100}      = unpack("v", substr($meta, 70, 2));
            $frame_meta{LockinValue}           = unpack("v", substr($meta, 86, 2));
            $frame_meta{ADResolution}          = unpack("v", substr($meta, 90, 2));
            $frame_meta{CameraSN_int}          = unpack("V", substr($meta, 92, 4));

            $frame_meta{IntegrationTime_ms} =
                $frame_meta{IntegrationTime_ticks} / $CLOCK_HZ;
        }
    }
}

# ============================================================
# NicevilleFactoryCal binary parser (v3.0 -- the real calibration)
#
# Locates and decodes all 4 NicevilleFactoryCal preset blocks.
# Byte offsets confirmed against ATSFileUtil's .inc export to full
# float precision, cross-validated on two files (25mm and 100mm
# lenses, serial 00049). See ats-jpg-and-xml-notes.md Addendum 2.
#
# v3.1 CHANGE: the block NAME is no longer hardcoded to
# "NicevilleFactoryCal". A file shared by FLIR (not from our own
# camera) was found to contain "FranceFactoryCal" blocks instead --
# evidently the calibration facility name varies by camera/region.
# We now search generically for the pattern "*FactoryCal\x00" and
# read whichever name actually matched.
#
# The "FranceFactoryCal" blocks found so far are only 133 bytes
# (vs our camera's 589 bytes) and do NOT appear to share the same
# internal payload layout beyond the common header (name, type GUID,
# version+preset-index+flags). We do NOT have a verified field map
# for this shorter format yet (no .inc cross-reference available for
# that camera), so rather than guess at offsets and risk silently
# reporting wrong numbers, we detect the block, confirm the preset
# index, and report "unknown calibration payload format" for any
# block whose size doesn't match our one confirmed-good layout
# (589 bytes, "NicevilleFactoryCal"-style). This can be extended once
# we have ground truth for the shorter format.
# ============================================================
my $NFC_NAME_PATTERN = qr/([A-Za-z]+FactoryCal)\x00/;
my $NFC_MIN_KNOWN_BLOCKSIZE = 589;  # the layout we've fully verified; this
                                     # is a MINIMUM, not an exact match --
                                     # see v3.4 note below
my $NFC_HEADER_PRESET_OFFSET = 52;  # confirmed same absolute offset
                                     # regardless of name length (tested
                                     # with both 19-char and 16-char names)

# v3.4 NOTE: a third file (A8300sc, serial 00018) was found with
# "NicevilleFactoryCal"-named blocks of 2109 bytes -- much larger than
# our reference camera's 589 bytes. Rather than guessing, every single
# field offset from 52 through 312 (preset index through
# nfcMaxCounts) was directly verified byte-for-byte against that
# camera's own ATSFileUtil .inc export and found to match EXACTLY --
# same struct, same offsets, just with ~1500 extra bytes of additional
# data/padding appended after byte 312 that we don't decode (and don't
# currently need to). So block size is now treated as a MINIMUM
# (>=589) rather than an exact match: any block at least 589 bytes
# uses our known decode logic on its first 589 bytes; anything
# SMALLER (like FranceFactoryCal's 132-133 bytes) is correctly still
# treated as a genuinely different, undecoded format.

use constant {
    OFF_PRESET_IDX   =>  52,
    OFF_NFC_C0       =>  89,
    OFF_NFC_C1       =>  97,
    OFF_NFC_C2       => 105,
    OFF_NFC_TEMPC0   => 157,
    OFF_NFC_TEMPC1   => 165,
    OFF_NFC_TEMPC2   => 173,
    OFF_NFC_TEMPC3   => 181,
    OFF_NFC_TEMPC4   => 189,
    OFF_NFC_TEMPC5   => 197,
    OFF_NFC_TEMPC6   => 205,
    OFF_NFC_BANDHIGH => 213,
    OFF_NFC_BANDLOW  => 221,
    OFF_NFC_R        => 229,
    OFF_NFC_B        => 237,
    OFF_NFC_F        => 245,
    OFF_NFC_ATMX     => 253,
    OFF_NFC_ATMA1    => 261,
    OFF_NFC_ATMA2    => 269,
    OFF_NFC_ATMB1    => 277,
    OFF_NFC_ATMB2    => 285,
    OFF_NFC_MINTEMP  => 293,
    OFF_NFC_MAXTEMP  => 297,
    OFF_NFC_MINRAD   => 301,
    OFF_NFC_MAXRAD   => 305,
    OFF_NFC_MINCOUNTS=> 309,
    OFF_NFC_MAXCOUNTS=> 311,
};

sub read_f64 { return unpack("d<", substr($_[0], $_[1], 8)); }
sub read_f32 { return unpack("f<", substr($_[0], $_[1], 4)); }
sub read_u16 { return unpack("v",  substr($_[0], $_[1], 2)); }
sub read_u8  { return unpack("C",  substr($_[0], $_[1], 1)); }

my %nfc;              # keyed by preset 0..3 (only populated for KNOWN format)
my @nfc_warnings;     # collected non-fatal issues, shown in verbose mode
my $nfc_block_name;   # whichever "*FactoryCal" name actually matched
my $nfc_block_size;   # detected block size (gap between consecutive blocks)
my $nfc_format_known = 0;  # true only if size is >= our verified minimum (589 bytes)

{
    # First pass: find all "*FactoryCal" occurrences and their names,
    # so we can detect the actual block size before trying to decode
    # anything (the size varies by camera/calibration-facility format).
    my @found_offsets;
    my $search_pos = 0;
    while ($stream =~ /$NFC_NAME_PATTERN/g) {
        my $name      = $1;
        my $name_end  = pos($stream);
        my $name_start = $name_end - length($name) - 1;  # -1 for the \x00
        push @found_offsets, $name_start;
        $nfc_block_name //= $name;
    }

    if (@found_offsets >= 2) {
        $nfc_block_size = $found_offsets[1] - $found_offsets[0];
    } elsif (@found_offsets == 1) {
        # Only one block found -- can't measure a gap; assume the known
        # minimum size as a best guess so we at least attempt a decode.
        $nfc_block_size = $NFC_MIN_KNOWN_BLOCKSIZE;
    }

    $nfc_format_known = (defined $nfc_block_size
                          && $nfc_block_size >= $NFC_MIN_KNOWN_BLOCKSIZE);

    if (@found_offsets && !$nfc_format_known) {
        push @nfc_warnings, sprintf(
            "Found '%s' blocks (calibration facility name differs from "
          . "our reference camera's 'NicevilleFactoryCal') with block "
          . "size %d bytes -- this is SMALLER than the minimum size we've "
          . "verified (589 bytes), so it's a genuinely different, "
          . "undecoded layout, not just a larger version of the known one. "
          . "Reporting block locations and preset indices only; "
          . "calibration constants CANNOT be decoded for this format yet "
          . "(no .inc cross-reference available). See "
          . "ats-jpg-and-xml-notes.md for how NicevilleFactoryCal was "
          . "originally cracked -- the same approach is needed here.",
            $nfc_block_name, $nfc_block_size // 0);
    }

    for my $block_start (@found_offsets) {
        if (!$nfc_format_known) {
            # Unknown format: just confirm presence + preset index using
            # the one header field confirmed stable across both formats
            # tested so far (preset index at absolute offset 52), without
            # attempting to decode any calibration payload.
            if ($block_start + $NFC_HEADER_PRESET_OFFSET + 1 <= length($stream)) {
                my $preset_idx = read_u8($stream, $block_start + $NFC_HEADER_PRESET_OFFSET);
                push @nfc_warnings, sprintf(
                    "  %s block at offset %d: preset index byte = %d "
                  . "(payload not decoded -- unknown format)",
                    $nfc_block_name, $block_start, $preset_idx);
            }
            next;
        }

        # Known format (NicevilleFactoryCal-style layout, >= 589 bytes) --
        # full decode of the first 589 bytes; any extra trailing bytes
        # (seen on the A8300sc camera, 2109-byte blocks) are simply
        # not read, since all needed fields fit in the first 589.
        if ($block_start + $nfc_block_size > length($stream)) {
            push @nfc_warnings,
                "$nfc_block_name block at offset $block_start is truncated -- skipped";
            next;
        }

        my $block = substr($stream, $block_start, $nfc_block_size);
        my $preset_idx = read_u8($block, OFF_PRESET_IDX);

        if ($preset_idx > 3) {
            push @nfc_warnings,
                "$nfc_block_name at offset $block_start has invalid preset "
              . "index $preset_idx -- skipped (possible false match)";
            next;
        }

        my %p;
        $p{block_offset}    = $block_start;
        $p{nfcC0}           = read_f64($block, OFF_NFC_C0);
        $p{nfcC1}           = read_f64($block, OFF_NFC_C1);
        $p{nfcC2}           = read_f64($block, OFF_NFC_C2);
        $p{nfcTempC0}       = read_f64($block, OFF_NFC_TEMPC0);
        $p{nfcTempC1}       = read_f64($block, OFF_NFC_TEMPC1);
        $p{nfcTempC2}       = read_f64($block, OFF_NFC_TEMPC2);
        $p{nfcTempC3}       = read_f64($block, OFF_NFC_TEMPC3);
        $p{nfcTempC4}       = read_f64($block, OFF_NFC_TEMPC4);
        $p{nfcTempC5}       = read_f64($block, OFF_NFC_TEMPC5);
        $p{nfcTempC6}       = read_f64($block, OFF_NFC_TEMPC6);
        $p{nfcBandpassHigh} = read_f64($block, OFF_NFC_BANDHIGH);
        $p{nfcBandpassLow}  = read_f64($block, OFF_NFC_BANDLOW);
        $p{nfcR}            = read_f64($block, OFF_NFC_R);
        $p{nfcB}            = read_f64($block, OFF_NFC_B);
        $p{nfcF}            = read_f64($block, OFF_NFC_F);
        $p{nfcAtmX}         = read_f64($block, OFF_NFC_ATMX);
        $p{nfcAtmA1}        = read_f64($block, OFF_NFC_ATMA1);
        $p{nfcAtmA2}        = read_f64($block, OFF_NFC_ATMA2);
        $p{nfcAtmB1}        = read_f64($block, OFF_NFC_ATMB1);
        $p{nfcAtmB2}        = read_f64($block, OFF_NFC_ATMB2);
        $p{nfcMinTemp}      = read_f32($block, OFF_NFC_MINTEMP);
        $p{nfcMaxTemp}      = read_f32($block, OFF_NFC_MAXTEMP);
        $p{nfcMinRad}       = read_f32($block, OFF_NFC_MINRAD);
        $p{nfcMaxRad}       = read_f32($block, OFF_NFC_MAXRAD);
        $p{nfcMinCounts}    = read_u16($block, OFF_NFC_MINCOUNTS);
        $p{nfcMaxCounts}    = read_u16($block, OFF_NFC_MAXCOUNTS);
        $p{lambda_eff_um}   = $C2 / $p{nfcB};

        if (exists $nfc{$preset_idx}) {
            push @nfc_warnings,
                "duplicate $nfc_block_name block for preset $preset_idx "
              . "(offset $block_start overwrites $nfc{$preset_idx}{block_offset})";
        }
        $nfc{$preset_idx} = \%p;
    }
}

# ============================================================
# Active preset detection
#
# Uses the SourceInfo presetInfo array. Byte layout confirmed by
# direct inspection of real file bytes (NOT inferred/guessed):
#   128-byte stride between consecutive preset entries
#   relative offset 25 within each entry: minTemp (f64 LE, Kelvin)
#   relative offset  4 within each entry: available (uint8 bool)
# Anchored by searching for preset 0's minTemp value, since preset 0
# is present in every file tested so far. See Addendum 2 in the notes.
# ============================================================
my $active_preset;
my $active_preset_src = "not yet determined";
my @preset_detect_log;
my (%preset_framerates, %preset_numframes);  # v4.0: from presetInfo binary  # diagnostic lines, shown in verbose mode

my $PRESETINFO_STRIDE               = 128;
my $PRESETINFO_AVAIL_TO_MINTEMP_GAP = 20;

if (defined $force_preset) {
    $active_preset     = $force_preset;
    $active_preset_src = "FORCED via -p $force_preset command-line option";
} elsif (%nfc && exists $nfc{0}) {
    my $minTempK0     = $nfc{0}{nfcMinTemp} + 273.15;
    my $minTempBytes0 = pack("d<", $minTempK0);
    my $anchor_offset = index($stream, $minTempBytes0);

    if ($anchor_offset >= 0) {
        push @preset_detect_log,
            sprintf("presetInfo anchor found at stream offset %d (preset 0 minTemp=%.2fK)",
                    $anchor_offset, $minTempK0);

        # Read FrameRate (float32 at anchor-10) and NumFrames (uint32 at anchor-5)
        # presetInfo layout (confirmed from ATSfileutil FileBlocks + algebraic fit):
        #   +0:  available (1, bool)     +1:  intTime (8, float64, ms)
        #   +9:  intTimeValid (1, bool)  +10: frameRate (4, float32) <- anchor-10
        #   +14: frameRateValid (1)      +15: numFrames (4, uint32)  <- anchor-5
        #   +19: calibrated (1)          +20: minTemp (8, float64)   <- anchor
        my $PRESETINFO_FRAMERATE_OFFSET = -10;  # float32 relative to minTemp
        my $PRESETINFO_NUMFRAMES_OFFSET = -5;   # uint32 relative to minTemp
        for my $pn (0..3) {
            my $mt_off = $anchor_offset + $pn * $PRESETINFO_STRIDE;
            my $fr_off = $mt_off + $PRESETINFO_FRAMERATE_OFFSET;
            my $nf_off = $mt_off + $PRESETINFO_NUMFRAMES_OFFSET;
            if ($fr_off >= 0 && $fr_off + 4 <= length($stream)) {
                my $fr = unpack("f<", substr($stream, $fr_off, 4));
                $preset_framerates{$pn} = sprintf("%.4f", $fr)
                    if $fr > 0.5 && $fr < 700.0;
            }
            if ($nf_off >= 0 && $nf_off + 4 <= length($stream)) {
                my $nf = unpack("V", substr($stream, $nf_off, 4));
                $preset_numframes{$pn} = $nf if $nf < 1_000_000;
            }
        }

        for my $p (0..3) {
            next unless exists $nfc{$p};
            my $this_minTemp_off = $anchor_offset + $p * $PRESETINFO_STRIDE;
            next if $this_minTemp_off + 8 > length($stream);

            my $found_minTempK    = unpack("d<", substr($stream, $this_minTemp_off, 8));
            my $expected_minTempK = $nfc{$p}{nfcMinTemp} + 273.15;

            if (abs($found_minTempK - $expected_minTempK) < 0.01) {
                my $avail_off = $this_minTemp_off - $PRESETINFO_AVAIL_TO_MINTEMP_GAP;
                if ($avail_off >= 0) {
                    my $avail = unpack("C", substr($stream, $avail_off, 1));
                    push @preset_detect_log,
                        sprintf("preset %d: minTemp matches (%.2fK), available=%d",
                                $p, $found_minTempK, $avail);
                    if ($avail == 1 && !defined $active_preset) {
                        $active_preset     = $p;
                        $active_preset_src = sprintf(
                            "detected from SourceInfo presetInfo[%d].available=1", $p);
                    }
                }
            } else {
                push @preset_detect_log,
                    sprintf("preset %d: minTemp MISMATCH (found %.2fK, expected %.2fK)",
                            $p, $found_minTempK, $expected_minTempK);
            }
        }
    } else {
        push @preset_detect_log, "presetInfo anchor not found in stream";
    }
}

unless (defined $active_preset) {
    $active_preset     = 0;
    $active_preset_src = "ASSUMED preset 0 -- detection failed; verify manually "
                        . "or use -p to override";
}

# ============================================================
# v2.0 LEGACY CalPair/Lambda/PlanckO derivation -- SUPERSEDED, kept
# commented out for reference only. DO NOT re-enable without reading
# Addendum 1 and Addendum 4 in ats-jpg-and-xml-notes.md first: the
# CalPair values are segmentation display thresholds, not calibration
# data, and this entire derivation was based on that mistaken premise.
# ============================================================
# my %CAL_CACHE = (
#     '00049_25 mm' => {
#         Lambda   => 4.642,
#         PlanckR1 => 131769348.77,
#         PlanckO  => -921.5469,
#         source   => 'Rec-0018.ats',
#     },
#     '00049_100 mm' => {
#         Lambda   => 4.642,
#         PlanckR1 => 131769348.77,
#         PlanckO  => -921.5469,
#         source   => 'StarNosedMole-184_18_43_35_177-0067.ats',
#     },
# );
#
# my ($B, $R, $O, $PlanckO, $LAMBDA) = (undef, undef, undef, undef, undef);
# my $planck_source = 'unavailable';
# my $cnt_min = $seg{Counts}       ? $seg{Counts}{min}       : undef;
# my $cnt_max = $seg{Counts}       ? $seg{Counts}{max}       : undef;
# my $tk_min  = $seg{TemperatureK} ? $seg{TemperatureK}{min} : undef;
# my $tk_max  = $seg{TemperatureK} ? $seg{TemperatureK}{max} : undef;
# my $cache_key = ($camera_serial && $lens_focal)
#               ? "${camera_serial}_${lens_focal}" : $camera_serial || '';
# if (defined $cnt_min && defined $cnt_max && defined $tk_min && defined $tk_max) {
#     my $cached = $cache_key ? $CAL_CACHE{$cache_key} : undef;
#     $LAMBDA = ($cached && $cached->{Lambda}) ? $cached->{Lambda} : 4.642;
#     $B  = $C2 / $LAMBDA;
#     my $A1 = exp($B / $tk_min) - 1;
#     my $A2 = exp($B / $tk_max) - 1;
#     $O  = ($A2*$cnt_max - $A1*$cnt_min) / ($A2 - $A1);
#     $R  = $A1 * ($cnt_min - $O);
#     $PlanckO = -$O;
#     $planck_source = "derived from Counts+TemperatureK pairs in this file";
# }
# ============================================================

# ============================================================
# Output construction -- two modes:
#   non-verbose (default): flat ExifTool-style tag list, no headers
#   verbose (-v): section headers + all-preset detail + diagnostics
# ============================================================
my @out;
my $fmt = "%-32s: %s\n";

sub add { push @out, sprintf($fmt, $_[0], $_[1]); }
sub hdr { push @out, "\n---- $_[0] ----\n" if $verbose; }

# ---- Core file/camera/image info (both modes) ----
add("SourceFile",        $infile);
add("FileType",          $filetype);
hdr("Camera Info");
add("CameraModel",       $camera_model  || 'not found');
add("CameraSerial",      $camera_serial || 'not found');
add("LensFocalLength",   $lens_focal    || 'not found');
hdr("Image");
add("ImageWidth",        $img_w // 'unknown');
add("ImageHeight",       $img_h // 'unknown');
hdr("Source Settings");
add("SourceUnit",        $src_unit  // 'unknown');
add("TemperatureType",   $temp_type // 'unknown');
add("ApplyNUC",          $apply_nuc // 'unknown');
add("ApplyBadPixels",    $apply_bp  // 'unknown');

# ---- Per-frame metadata (both modes, if available) ----
if (%frame_meta) {
    hdr("Per-Frame Metadata (frame 0)");
    add("CameraSN_int",         $frame_meta{CameraSN_int});
    add("SavedFrameCounter",    $frame_meta{SavedFrameCounter});
    add("FrameCounter",         $frame_meta{FrameCounter});
    add("IntegrationTime",      sprintf("%.6f ms", $frame_meta{IntegrationTime_ms}));
    add("FPATemp",              sprintf("%.2f K", $frame_meta{FPATemp_K100}/100));
    add("FrontPanelTemp",       sprintf("%.2f C", $frame_meta{FrontPanelTemp_K100}/100 - 273.15));
    add("AirGapTemp",           sprintf("%.2f C", $frame_meta{AirGapTemp_K100}/100 - 273.15));
    add("InternalTemp",         sprintf("%.2f C", $frame_meta{InternalTemp_K100}/100 - 273.15));
    add("MainBoardTemp",        sprintf("%.2f C", $frame_meta{MainBoardTemp_K100}/100 - 273.15));
    add("PowerBoardTemp",       sprintf("%.2f C", $frame_meta{PowerBoardTemp_K100}/100 - 273.15));
    add("DigitizerBoardTemp",   sprintf("%.2f C", $frame_meta{DigitizerTemp_K100}/100 - 273.15));
    add("NUCFlagTemp",          sprintf("%.2f C", $frame_meta{NUCFlagTemp_K100}/100 - 273.15));
    add("SaturationThreshold",  $frame_meta{SaturationThreshold});
    add("SaturatedPixels",      $frame_meta{SaturatedPixels});
    add("AnalogOffset",         sprintf("%.3f V", $frame_meta{AnalogOffset_mV}/1000));
    add("ADResolution",         $frame_meta{ADResolution});
    add("FilterID",             $frame_meta{FilterID});
    add("LockinValue",          $frame_meta{LockinValue});
}

# ---- NicevilleFactoryCal calibration (both modes: active preset only
#      in non-verbose; all 4 presets + diagnostics in verbose) ----
hdr("NicevilleFactoryCal Calibration");
add("ActivePreset", $active_preset);
# FrameRate and NumFrames from presetInfo binary block (v4.0)
if (exists $preset_framerates{$active_preset}) {
    add("FrameRate", sprintf("%.4f Hz", $preset_framerates{$active_preset}));
}
if (exists $preset_numframes{$active_preset}) {
    add("NumFrames", $preset_numframes{$active_preset});
}

if (%nfc && exists $nfc{$active_preset}) {
    my $p = $nfc{$active_preset};
    add("NfcMinTemp",        sprintf("%.1f C", $p->{nfcMinTemp}));
    add("NfcMaxTemp",        sprintf("%.1f C", $p->{nfcMaxTemp}));
    add("NfcMinCounts",      $p->{nfcMinCounts});
    add("NfcMaxCounts",      $p->{nfcMaxCounts});
    add("NfcC0",             sprintf("%.15e", $p->{nfcC0}));
    add("NfcC1",             sprintf("%.15e", $p->{nfcC1}));
    add("NfcC2",             sprintf("%.15e", $p->{nfcC2}));
    add("NfcB",              sprintf("%.6f", $p->{nfcB}));
    add("NfcR",              sprintf("%.10f", $p->{nfcR}));
    add("NfcF",              sprintf("%.1f", $p->{nfcF}));
    add("NfcBandpassLow",    sprintf("%.2f um", $p->{nfcBandpassLow}));
    add("NfcBandpassHigh",   sprintf("%.2f um", $p->{nfcBandpassHigh}));
    add("AtmosphericTransAlpha1", sprintf("%.15e", $p->{nfcAtmA1}));
    add("AtmosphericTransAlpha2", sprintf("%.15e", $p->{nfcAtmA2}));
    add("AtmosphericTransBeta1",  sprintf("%.15e", $p->{nfcAtmB1}));
    add("AtmosphericTransBeta2",  sprintf("%.15e", $p->{nfcAtmB2}));
    add("AtmosphericTransX",      sprintf("%.15e", $p->{nfcAtmX}));
} elsif (defined $nfc_block_name && !$nfc_format_known) {
    add("NfcStatus", "Found '$nfc_block_name' calibration blocks "
                    . "($nfc_block_size bytes each) but this format is "
                    . "NOT YET DECODED -- only NicevilleFactoryCal-style "
                    . "blocks of at least 589 bytes are currently "
                    . "supported. Run with -v for details.");
} else {
    add("NfcStatus", "No FactoryCal-style calibration blocks found in this file "
                    . "(file may be a stripped RJPEG)");
}

# ---- VERBOSE-ONLY: detection diagnostics, all 4 presets, formulas,
#      self-tests, and the narrative context behind these discoveries ----
if ($verbose) {
    push @out, "\n---- Active Preset Detection Diagnostics ----\n";
    push @out, "Source: $active_preset_src\n";
    for my $line (@preset_detect_log) {
        push @out, "  $line\n";
    }
    if (@nfc_warnings) {
        push @out, "\nWarnings during NicevilleFactoryCal parsing:\n";
        push @out, "  $_\n" for @nfc_warnings;
    }

    push @out, "\n---- All 4 NicevilleFactoryCal Presets (for reference) ----\n";
    push @out, sprintf("%-20s  %14s  %14s  %14s  %14s\n",
                        "Field", "Preset 0", "Preset 1", "Preset 2", "Preset 3");
    my @rows = (
        ["nfcMinTemp",   "MinTemp (C)",  "%14.2f"],
        ["nfcMaxTemp",   "MaxTemp (C)",  "%14.2f"],
        ["nfcMinCounts", "MinCounts",    "%14d"],
        ["nfcMaxCounts", "MaxCounts",    "%14d"],
        ["nfcB",         "nfcB",         "%14.4f"],
        ["nfcR",         "nfcR",         "%14.8f"],
        ["lambda_eff_um","Lambda_eff(um)","%14.4f"],
        ["nfcC0",        "nfcC0",        "%14.6e"],
        ["nfcC1",        "nfcC1",        "%14.6e"],
        ["nfcC2",        "nfcC2",        "%14.6e"],
    );
    for my $row (@rows) {
        my ($key, $label, $f) = @$row;
        push @out, sprintf("%-20s", $label);
        for my $pn (0..3) {
            if (exists $nfc{$pn}) {
                push @out, sprintf("  $f", $nfc{$pn}{$key});
            } else {
                push @out, sprintf("  %14s", "(missing)");
            }
        }
        push @out, "\n";
    }

    if (%nfc && exists $nfc{$active_preset}) {
        my $p = $nfc{$active_preset};
        push @out, "\n---- Conversion Formulas (active preset $active_preset) ----\n";
        push @out, "Step 1, Counts -> Radiance (quadratic polynomial):\n";
        push @out, "  Radiance = nfcC0 + nfcC1*Counts + nfcC2*Counts^2\n";
        push @out, sprintf("  Radiance range: %.6e to %.6e W/sr/m2/um\n",
                            $p->{nfcMinRad}, $p->{nfcMaxRad});
        push @out, "\nStep 2, Radiance -> Temperature (Planck, radiance domain --\n";
        push @out, "CONFIRMED via real Research Studio TIFF comparison, RMSE 0.0001C,\n";
        push @out, "see ats-jpg-and-xml-notes.md Addendum 3 -- USE THIS FORMULA):\n";
        push @out, "  TempK = nfcB / ln(nfcR/Radiance + nfcF)\n";
        push @out, "  TempC = TempK - 273.15\n";
        push @out, "\nFLIR's exported 6th-order polynomial (nfcTempC0..C6) is the\n";
        push @out, "sfmov/.inc EXPORT APPROXIMATION of the above, NOT what Research\n";
        push @out, "Studio actually uses internally (confirmed: 0.62C RMSE vs the\n";
        push @out, "true TIFF, ~2-4x worse than the Planck formula). Provided here\n";
        push @out, "for reference / cross-checking only:\n";
        push @out, "  TempC = nfcTempC0 + nfcTempC1*Rad + ... + nfcTempC6*Rad^6\n";

        push @out, "\nAtmospheric transmission (tau) formula:\n";
        push @out, "  tau = AtmosphericTransX * exp(-sqrt(d) *\n";
        push @out, "        (Alpha1*exp(-Beta1*sqrt(h)) + Alpha2*exp(-Beta2*sqrt(h))))\n";
        push @out, "  where d = object distance (m), h = relative humidity (0..1)\n";

        push @out, "\n---- Self-test: formula at preset boundary counts ----\n";
        push @out, "(small errors here are EXPECTED -- nfcMinCounts/MaxCounts mark\n";
        push @out, "fit-validity bounds, not exact points where the Planck formula\n";
        push @out, "reproduces the rounded nfcMinTemp/MaxTemp label -- see Addendum 2)\n";
        for my $lc (["MinCounts", $p->{nfcMinCounts}, $p->{nfcMinTemp}],
                    ["MaxCounts", $p->{nfcMaxCounts}, $p->{nfcMaxTemp}]) {
            my ($label, $counts, $expected_c) = @$lc;
            my $rad   = $p->{nfcC0} + $p->{nfcC1}*$counts + $p->{nfcC2}*$counts**2;
            my $tempC = $p->{nfcB} / log($p->{nfcR}/$rad + $p->{nfcF}) - 273.15;
            push @out, sprintf("  %-10s %6d counts -> TempC=%7.3f (nominal %.1f, error %+.3f C)\n",
                                $label, $counts, $tempC, $expected_c, $tempC-$expected_c);
        }
    }
}

# ---- Factory calibration pairs / segmentation thresholds (both modes)
#      RELABELLED in v3.0 -- these are NOT calibration data, see Addendum 4.
#      Kept because they're a useful record of the workspace's display
#      state when the file was saved, and because we can't rule out some
#      future use for them. ----
hdr("Segmentation Thresholds (display feature, NOT calibration -- see notes Addendum 4)");
for my $unit (qw(Counts Radiance TemperatureC TemperatureK TemperatureF TemperatureR)) {
    next unless exists $seg{$unit};
    add("CalPair_${unit}_Min", $seg{$unit}{min} // 'n/a');
    add("CalPair_${unit}_Max", $seg{$unit}{max} // 'n/a');
}

# ---- Scene display range (both modes) ----
hdr("Scene Display Range (this recording)");
for my $unit (qw(TemperatureC TemperatureK TemperatureF TemperatureR)) {
    next unless exists $level{$unit};
    add("SceneRange_${unit}_Min", $level{$unit}{min} // 'n/a');
    add("SceneRange_${unit}_Max", $level{$unit}{max} // 'n/a');
}

# ---- Object parameters (both modes, ExifTool-convention names) ----
hdr("Object Parameters");

if ($objparams_from_xml) {
    add("ObjectParametersSource", "Workspace XML");
    add("Emissivity",                    $emissivity);
    add("ObjectDistance",                "$distance m");
    add("ReflectedApparentTemperature",  sprintf("%.1f C", $refl_temp_C));
    add("AtmosphericTemperature",        sprintf("%.1f C", $atm_temp_C));
    add("IRWindowTemperature",           sprintf("%.1f C", $ext_temp_C));
    add("IRWindowTransmission",          $ext_trans);
    add("TransmissionOverrideFlag", $trans_override_flag);
    add("RelativeHumidity",              sprintf("%.1f %%", $rel_hum_pct));
} elsif ($objparams_from_binary) {
    add("ObjectParametersSource", "binary ObjectParameters block "
                                 . "(no Workspace XML in this file -- field "
                                 . "layout confirmed against Research Studio "
                                 . "readings for two test files, see notes)");
    add("Emissivity",                    sprintf("%.4f", $binop{Emissivity}));
    add("ObjectDistance",                sprintf("%.5f m", $binop{ObjectDistance}));
    add("ReflectedApparentTemperature",  sprintf("%.2f C", $binop{ReflectedTemp_K} - 273.15));
    add("AtmosphericTemperature",        sprintf("%.2f C", $binop{AtmosphereTemp_K} - 273.15));
    add("IRWindowTemperature",           sprintf("%.2f C", $binop{ExtOpticsTemp_K} - 273.15));
    add("IRWindowTransmission",          sprintf("%.4f", $binop{Transmission}));
    add("ExternalOpticsTransmission",    sprintf("%.4f", $binop{ExtOpticsTrans}));
    add("RelativeHumidity",              sprintf("%.1f %%", $binop{RelativeHumidity} * 100));
    add("TransmissionOverrideFlag", sprintf("%d", $binop{TransmissionOverrideFlag})
        . " (0=use stored/computed Transmission value, 1=manually overridden -- "
        . "confirmed via hex-edit test, see notes)");
} else {
    add("ObjectParametersSource", "DEFAULTS (no Workspace XML and no binary "
                                 . "ObjectParameters block found in this file); "
                                 . "values below are NOT from this file");
    add("Emissivity",                    $emissivity);
    add("ObjectDistance",                "$distance m");
    add("ReflectedApparentTemperature",  sprintf("%.1f C", $refl_temp_C));
    add("AtmosphericTemperature",        sprintf("%.1f C", $atm_temp_C));
    add("IRWindowTemperature",           sprintf("%.1f C", $ext_temp_C));
    add("IRWindowTransmission",          $ext_trans);
    add("RelativeHumidity",              sprintf("%.1f %%", $rel_hum_pct));
}
add("Palette", $palette eq '' ? '(none)' : $palette);

if ($verbose) {
    push @out, "\n---- About this output ----\n";
    push @out, "Run with -v for this verbose mode (section headers + diagnostics).\n";
    push @out, "Run WITHOUT -v for a flat, ExifTool-style tag list with no headers,\n";
    push @out, "suitable for programmatic parsing (e.g. ThermImageJ in FIJI).\n";
    push @out, "See ats-jpg-and-xml-notes.md for the full history of how these\n";
    push @out, "calibration constants were discovered and validated.\n";
}

# ============================================================
# Output
#
# When @tag_filters is non-empty (ExifTool-style -TagName usage),
# filter @out down to only the "Tag : Value" lines whose tag name
# exactly matches one of the requested names. Header lines ("---- X
# ----") and multi-line verbose narrative are never matched (they
# don't follow the "Tag : Value" pattern), so filtering naturally
# produces a clean flat list either way, same spirit as ExifTool.
# ============================================================
my $output;
if (@tag_filters) {
    my %wanted = map { $_ => 1 } @tag_filters;
    my @matched;
    for my $line (@out) {
        if ($line =~ /^(\S+)\s*:\s/) {
            my $tag = $1;
            push @matched, $line if $wanted{$tag};
        }
    }
    if (@matched) {
        $output = join("", @matched);
    } else {
        $output = "(no matching tags found: " . join(", ", @tag_filters) . ")\n";
    }
} else {
    $output = join("", @out);
}

print $output;

if ($opt{o}) {
    open(my $fout, '>', $opt{o}) or die "Cannot write '$opt{o}': $!\n";
    print $fout $output;
    close $fout;
    print "\nOutput saved to '$opt{o}'\n";
}

#!/usr/bin/perl

# ats-repair.pl  v3.2
# Author: Glenn J. Tattersall
#
# ============================================================
# PLAIN ENGLISH GUIDE TO WHAT THIS SCRIPT DOES
# ============================================================
#
# WHAT IS A JPEG FILE?
#   A JPEG file is not just raw image pixels.  It is a structured
#   container made up of labelled chunks called SEGMENTS.  Each
#   segment starts with a 2-byte code called a MARKER that says
#   what kind of data follows.  A JPEG decoder reads the file
#   marker by marker, like chapters in a book.
#
# COMMON JPEG MARKERS (all start with FF):
#   FF D8  =  SOI  "Start Of Image"   -- the very first 2 bytes of every JPEG
#   FF D9  =  EOI  "End Of Image"     -- the very last 2 bytes of every JPEG
#   FF E0  =  APP0 "Application segment 0" -- usually holds JFIF header info
#                   (things like pixel aspect ratio, thumbnail size)
#   FF E1  =  APP1 "Application segment 1" -- general purpose storage space.
#                   Normally used by cameras to store Exif metadata (date, GPS,
#                   camera model etc).  FLIR hijacks this segment to store
#                   thermal/radiometric data instead.
#   FF DB  =  DQT  "Define Quantization Table" -- JPEG compression tables
#   FF C0  =  SOF  "Start Of Frame"   -- image dimensions, colour depth
#   FF C4  =  DHT  "Define Huffman Table" -- more JPEG compression tables
#   FF DA  =  SOS  "Start Of Scan"    -- the actual compressed visible image
#                   pixels follow immediately after this marker
#
# HOW FLIR USES THIS STRUCTURE:
#   A FLIR MWIR radiometric JPEG (also called RJPEG or ATS-JPG) is a
#   valid JPEG file that contains BOTH:
#     (a) a real compressed visible-light thumbnail (at the end), AND
#     (b) raw 16-bit thermal pixel data (hidden in APP1 segments)
#
#   The thermal data is too large to fit in a single APP1 segment
#   (JPEG limits segments to 65536 bytes).  So FLIR splits it across
#   multiple APP1 segments -- like splitting a long letter across
#   40 envelopes.  Each envelope (APP1 segment) has:
#     - a 2-byte JPEG marker:    FF E1
#     - a 2-byte length field:   FF FE  (= 65534 in decimal, big-endian)
#     - a 10-byte FLIR header:   "FLIR" + fixed bytes + chunk# + total chunks
#     - 65524 bytes of thermal data payload
#
#   The complete file structure looks like this:
#
#   [FF D8]                     SOI  (2 bytes)
#   [FF E0  APP0/JFIF]          visible thumbnail header (18 bytes)
#   [FF E1  APP1 chunk 0 ]  \
#   [FF E1  APP1 chunk 1 ]   |  40 segments x 65536 bytes = thermal pixel data
#   [FF E1  APP1 chunk 2 ]   |
#   ...                      |
#   [FF E1  APP1 chunk 39]  /
#   [FF E1  APP1 metadata]      1 final segment with FLIR XML metadata (~8496 bytes)
#   [FF DB  DQT           ]  \
#   [FF DB  DQT           ]   |
#   [FF C0  SOF0          ]   |  real JPEG compressed visible thumbnail
#   [FF C4  DHT  x4       ]   |
#   [FF DA  SOS           ]  /
#   [FF D9]                     EOI  (2 bytes)
#
# WHAT THE "NOISE" IN EXTRACTED IMAGES IS:
#   If you naively concatenate all the bytes from APP1 segments without
#   stripping those 12-byte headers, you get the thermal pixel stream
#   interrupted every 65524 bytes by a 12-byte header artifact.
#   That's the "repeating noise" visible in the extracted TIFF/raw images.
#   This script strips those headers correctly before joining the segments.
#
# WHAT THIS SCRIPT OUTPUTS:
#   A flat binary file of Width x Height x 2 bytes.
#   Each pixel is a 16-bit unsigned integer, little-endian byte order.
#   This is raw radiance/count data -- NOT a standard image format.
#   Open it in ImageJ as:  File > Import > Raw
#     Image type : 16-bit Unsigned
#     Width/Height: as reported by this script
#     Byte order : Little-endian
#     Everything else: 0 / unchecked
#
# USAGE:
#   perl ats-repair.pl -i <input.jpg>  [-o <output.raw>]
#
# ============================================================

use strict;
use warnings;
use Getopt::Std;

# --- argument handling ---
my %opt;
getopts("hi:o:", \%opt);
my $infile = $opt{i};

if ($opt{h} || !$infile) {
    print "Usage: perl ats-repair.pl -i <input_rjpeg> [-o <output.raw>]\n";
    print "  -i  input FLIR RJPEG / ATS-JPG file\n";
    print "  -o  output raw file  (default: replaces input extension with .raw)\n";
    exit;
}

# If no output filename given, replace the input file's extension with .raw
# e.g.  Snap-0007.jpg  becomes  Snap-0007.raw  in the same folder
my $outfile = $opt{o} // ($infile =~ s/\.[^.]+$/.raw/r);

# ============================================================
# STEP 1: Read the entire file into memory as raw binary bytes
# ============================================================
# ':raw' means "don't mess with line endings or character encoding,
# just give me the bytes exactly as they are on disk"

open(my $fh, '<:raw', $infile) or die "Cannot open '$infile': $!\n";
my $file = do { local $/; <$fh> };
# "local $/" temporarily undefines the line separator, so <$fh> reads
# the entire file at once into $file as one big string of bytes
close $fh;
printf "Read %d bytes from '%s'\n", length($file), $infile;

# ============================================================
# STEP 2: Split the file at every APP1 marker (FF E1)
#         to locate all the FLIR thermal segments
# ============================================================
# The Perl split with (?=pattern) is a "lookahead" split --
# it splits just BEFORE each occurrence of FF E1, keeping the
# FF E1 bytes as the start of the next element (rather than
# discarding them).
#
# After this split:
#   $App[0]  = everything before the first FF E1
#              (the SOI + APP0 header, usually 20 bytes)
#   $App[1]  = FF E1 + first segment data
#   $App[2]  = FF E1 + second segment data
#   ...etc
#
# IMPORTANT: because FF E1 is kept at the START of each element,
# the byte offsets inside each $App[$i] are:
#   0-1  : FF E1  (the marker itself)
#   2-3  : length field (big-endian, value = 65534 = FF FE)
#   4-7  : "FLIR" ASCII signature
#   8-9  : fixed bytes 00 01
#   10   : chunk counter (0x00 for first chunk, up to 0x27 for chunk 39)
#   11   : total chunk count (0x28 = 40 decimal)
#   12.. : payload data (65534 - 10 = 65524 bytes of thermal data)

my $patAPP1 = "\xFF\xE1";
my @App     = split /(?=$patAPP1)/, $file;
my $tot     = scalar @App;   # includes $App[0] which is the pre-APP1 header

# Read the total chunk count from byte 11 of the first APP1 segment
# unpack("C", ...) = unpack one unsigned byte (C = unsigned char)
my $NumChunks = unpack("C", substr($App[1], 11, 1));
my $PreAppLen = length($App[0]);   # length of the SOI+APP0 header before first APP1

printf "APP1 segments found : %d\n", $tot - 1;
printf "Thermal chunks      : %d\n", $NumChunks;
printf "Pre-APP1 header     : %d bytes\n", $PreAppLen;

# ============================================================
# STEP 3: Strip the 12-byte header from each segment and
#         join the payloads into one continuous data stream
# ============================================================
# Each APP1 segment's payload is 65524 bytes:
#   Total segment = 65536 bytes (FF E1 marker + 65534 length field value)
#   Minus 2 bytes for FF E1 marker  (already at start of $App[$i])
#   Minus 2 bytes for length field  (bytes 2-3)
#   Minus 8 bytes for FLIR header   (bytes 4-11)
#   = 65524 bytes of actual payload (bytes 12 onward)
#
# The length field value (65534) counts everything AFTER the marker,
# so payload = length_field_value - 10 header bytes = 65524 bytes.
#
# unpack("n", ...) = unpack a 16-bit big-endian unsigned integer
#   "n" = network byte order = big-endian (as used in JPEG)
#   "v" = VAX byte order     = little-endian (as used in the thermal pixel data)

my $assembled = "";

for my $i (1 .. $tot-1) {
    my $seglen  = unpack("n", substr($App[$i], 2, 2));  # big-endian length field
    my $payload = substr($App[$i], 12, $seglen - 10);   # skip 12-byte header
    $assembled .= $payload;                              # append to stream
}

printf "Assembled FLIR stream: %d bytes\n", length($assembled);

# ============================================================
# STEP 4: Find the thermal pixel data using the "Pixels" tag
# ============================================================
# Inside the assembled FLIR data stream there is a metadata header
# that contains a series of named blocks.  One block is called "Pixels"
# (hex: 50 69 78 65 6C 73) and marks where the image data block begins.
#
# Empirically discovered offsets from the "Pixels" tag:
#   +107 bytes : image width  (16-bit little-endian integer)
#   +109 bytes : image height (16-bit little-endian integer)
#   +717 bytes : first actual pixel value
#
# v3.1 NOTE (REVERTED): a session investigating a similar bug in
# ats-xml.pl (raw .ats files) found that file format needed a FIXED
# gap of 3149 bytes from the "Pixels" tag, confirmed across three .ats
# files (see ats-jpg-and-xml-notes.md Addendum 6). Since this script's
# offset was ALSO 717 (suspiciously close to a different, smaller
# number) and the user had separately observed 717 producing ~1 row of
# garbage in some .ats-derived extractions, it seemed plausible the
# SAME 3149 fix would apply here too -- this was tried as v3.1, but
# the caveat at the time was explicit: "this has NOT been independently
# confirmed against an actual RJPEG file." It was wrong: the user
# tested it against a real RJPEG/.jpg (Snap-0007) and the resulting
# image came out VISIBLY SHIFTED in ImageJ. So the RJPEG/.jpg container
# (this script) and the raw .ats container (ats-xml.pl) do NOT share
# the same gap -- confirming this is a per-CONTAINER-FORMAT constant,
# not a universal one. REVERTED back to the original, correct value
# of 717 for this script. The 3149 value remains correct for
# ats-xml.pl's raw .ats files specifically; do NOT carry it over here
# again without independent verification against a real RJPEG file.
#
# split /(?=$patPixels)/ works the same way as the APP1 split above:
# it splits just BEFORE the "Pixels" tag, so $pixsplit[0] contains
# everything before it, and $pixsplit[1] starts with "Pixels...".
# The length of $pixsplit[0] therefore tells us the byte offset of
# the "Pixels" tag within the assembled stream.

my $patPixels = "\x50\x69\x78\x65\x6C\x73";  # "Pixels" in ASCII hex
my @pixsplit  = split /(?=$patPixels)/, $assembled;

die "ERROR: Could not find 'Pixels' tag in assembled data!\n"
    unless @pixsplit >= 2;

# unpack("v", ...) = 16-bit little-endian unsigned integer
my $Width      = unpack("v", substr($pixsplit[1], 107, 2));
my $Height     = unpack("v", substr($pixsplit[1], 109, 2));
my $ImageBytes = $Width * $Height * 2;   # 2 bytes per pixel (16-bit)

my $PixTagOffset = length($pixsplit[0]);     # where "Pixels" tag is

# ============================================================
# Dynamic pixel data start detection (v3.3)
# ============================================================
# The default pixel data offset from the "Pixels" tag is +717 bytes,
# confirmed correct for normal camera-exported ATS-JPG files.
#
# Research Studio exports with a colour bar embed extra palette data
# between the Pixels tag and the actual pixel counts, pushing the real
# pixel start to a later offset. A distinctive symptom of this is a
# doubling/power-of-2 byte sequence (1, 2, 4, 8, 16... 2048, 4096)
# in the bytes just before the real pixel data -- this is a colour bar
# lookup table. The sequence always ends with 2048 then 4096 as
# consecutive LE16 values (bytes \x00\x08\x00\x10), and the real
# pixel data begins exactly 8 bytes after the start of that 4-byte
# pattern.
#
# Strategy:
#   1. Try the default offset (+717). Works for all normal files.
#   2. If the data there does not look like valid MWIR pixel counts,
#      search for the power-of-2 sequence terminator (\x00\x08\x00\x10)
#      and start 8 bytes after it.
#   3. If that also fails, fall back to a forward heuristic scan.

my $DEFAULT_GAP = 717;
my $PIX_LO      = 1000;   # minimum plausible MWIR pixel count
my $PIX_HI      = 15000;  # maximum plausible MWIR pixel count
my $MIN_RUN     = 8;      # consecutive in-range values required

sub looks_like_pixels {
    my ($data, $offset, $lo, $hi, $min_run) = @_;
    my @vals;
    for my $i (0 .. $min_run - 1) {
        my $raw = substr($data, $offset + $i * 2, 2);
        return 0 if length($raw) < 2;
        my $val = unpack("v", $raw);
        return 0 if $val < $lo || $val > $hi;
        push @vals, $val;
    }
      # All values in range -- also require they are tightly clustered.
    # Threshold of 1000 counts is empirically derived from ~20M 4-pixel
    # windows across a high-contrast MWIR scene (frozen insect ~-20C on
    # a room-temperature bench -- close to the worst-case thermal contrast
    # for this camera): p99.9 range = 756 counts, max = 2013 counts.
    # Header/palette false positives from colour-bar RS exports show a
    # minimum range of 1389 counts, giving a clean separation from real
    # pixel data even in extreme scenes. Max real scene range (2013) does
    # overlap with false positives (1389-1994), but only 0.000% of windows
    # exceed 2000 counts, so the overlap is negligible in practice.
    my @sorted = sort { $a <=> $b } @vals;
    my $val_range = $sorted[-1] - $sorted[0];
    return 0 if $val_range > 1000;
    return 1;
}

my $PixDataStart = $PixTagOffset + $DEFAULT_GAP;

unless (looks_like_pixels($assembled, $PixDataStart, $PIX_LO, $PIX_HI, $MIN_RUN)) {
    printf "NOTE: default offset (+%d) does not contain valid pixel data.\n",
           $DEFAULT_GAP;

    # Step 2: search for the power-of-2 sequence terminator
    # bytes \x00\x08\x00\x10 = LE16 values 2048, 4096 consecutively
    # Pixel data starts 8 bytes after the start of this pattern.
            my $pow2_pat = chr(0x00).chr(0x04).chr(0x00).chr(0x08).chr(0x00).chr(0x10);  # 1024,2048,4096 as LE16 bytes
    # Find the LAST occurrence of the pattern -- the colour bar lookup table
    # repeats the sequence many times; only the final occurrence marks the
    # true end of the colour bar and the start of real pixel data.
    my $pow2_pos = -1;
    my $search_from = $PixTagOffset + $DEFAULT_GAP;
    while (1) {
        my $found = index($assembled, $pow2_pat, $search_from);
        last if $found < 0;
        $pow2_pos = $found;
        $search_from = $found + 1;
    }
    if ($pow2_pos >= 0) {
        my $candidate = $pow2_pos + 10;  # start searching from here
        if (looks_like_pixels($assembled, $candidate, $PIX_LO, $PIX_HI, $MIN_RUN)) {
            $PixDataStart = $candidate;
            printf "      Found pixel data via power-of-2 sequence anchor at offset +%d\n",
                   $PixDataStart - $PixTagOffset;
        } else {
            printf "      Power-of-2 anchor found but candidate +%d failed pixel check.\n",
                   $candidate - $PixTagOffset;
            goto FALLBACK;
        }
    } else {
        FALLBACK:
        # Step 3: forward heuristic scan
        print  "      Falling back to forward heuristic scan...\n";
        my $found = 0;
        my $MAX_SCAN = $PixTagOffset + length($assembled) - $PixTagOffset;
        for (my $try = $DEFAULT_GAP; $try < 50000; $try += 2) {
            if (looks_like_pixels($assembled, $PixTagOffset + $try,
                                  $PIX_LO, $PIX_HI, $MIN_RUN)) {
                $PixDataStart = $PixTagOffset + $try;
                printf "      Found pixel data at offset +%d from Pixels tag.\n", $try;
                $found = 1;
                last;
            }
        }
        unless ($found) {
            printf "WARNING: could not locate pixel data. Using default +%d.\n",
                   $DEFAULT_GAP;
            $PixDataStart = $PixTagOffset + $DEFAULT_GAP;
        }
    }
}



printf "Image dimensions    : %d x %d\n", $Width, $Height;
printf "Expected pixel bytes: %d\n",      $ImageBytes;
printf "'Pixels' tag offset : %d\n",      $PixTagOffset;
printf "Pixel data start    : %d\n",      $PixDataStart;

# ============================================================
# STEP 5: Extract exactly Width x Height x 2 bytes of pixel data
# ============================================================
my $pixels = substr($assembled, $PixDataStart, $ImageBytes);
my $got    = length($pixels);
printf "Extracted           : %d bytes\n", $got;

if ($got != $ImageBytes) {
    printf "WARNING: Expected %d bytes but got %d -- output may be incomplete!\n",
           $ImageBytes, $got;
}

# ============================================================
# STEP 6: Write the raw pixel data to disk
# ============================================================
open(my $out, '>:raw', $outfile) or die "Cannot write '$outfile': $!\n";
print $out $pixels;
close $out;

printf "Written to '%s'\n", $outfile;
print  "Done.\n";
print  "\nTo open in ImageJ:\n";
printf "  File > Import > Raw\n";
printf "  Image type : 16-bit Unsigned\n";
printf "  Width      : %d\n", $Width;
printf "  Height     : %d\n", $Height;
printf "  Byte order : Little-endian\n";
printf "  (all other fields: 0 / unchecked)\n";

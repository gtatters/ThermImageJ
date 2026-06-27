#!/usr/bin/perl

# ats-split.pl  v4.0
# Author: Glenn J. Tattersall, 2026
#
# ============================================================
# WHAT THIS SCRIPT DOES
# ============================================================
#
# Converts a FLIR ATS video file (.ats) into a flat binary
# .raw file that ImageJ can open as an image stack (video),
# and reports per-frame metadata extracted from the inter-frame
# blocks.
#
# ATS FILE STRUCTURE (reverse-engineered from Rec-0009.ats):
#
#   [File header: ~10KB]
#     Named blocks: FLIR ATS-US File, FOV, Workspace (XML),
#                   SourceInfo, Empty (filter slot), AbateCfg,
#                   NicevilleFactoryCal x4 (one per lens),
#                   ObjectParameters, Pixels
#
#   Then repeating for each frame:
#   [Pixel data:      Width x Height x 2 bytes, 16-bit LE]
#   [Frame metadata:  Width x 2 bytes = one extra row of intra-frame data]
#     Confirmed by ATSfileutil FileBlocks: frameHeight = imageHeight + 1
#     packedSize = imageWidth * frameHeight * 2  (all camera variants)
#     For 1280-wide cameras: frame_meta = 1280*2 = 2560 bytes (10x256 records)
#     For 704-wide cameras:  frame_meta = 704*2  = 1408 bytes (differs!)
#     The first 256-byte record (HeaderID=20 at byte 0) is the primary record.
#     NOT present after the final frame.
#
# PER-FRAME METADATA (256-byte record, confirmed fields):
#   Bytes [0]     : HeaderID (= 20)
#   Bytes [4]     : SavedFrameCounter (increments each saved frame)
#   Bytes [12:14] : FrontPanelTemp  (uint16, K*100)
#   Bytes [14:16] : AirGapTemp      (uint16, K*100)
#   Bytes [16:18] : InternalTemp    (uint16, K*100)
#   Bytes [18:20] : FPATemp         (uint16, K*100) <- Stirling cooler temp
#   Bytes [20:24] : FrameCounter    (uint32, absolute camera frame)
#   Bytes [24:28] : IntegrationTime (uint32, clock ticks at 6,250,000 Hz)
#   Bytes [30]    : FilterID        (uint8)
#   Bytes [44:46] : SaturationThreshold (uint16, counts)
#   Bytes [46:48] : SaturatedPixels     (uint16, count)
#   Bytes [62:64] : AnalogOffset    (uint16, millivolts)
#   Bytes [64:66] : MainBoardTemp   (uint16, K*100)
#   Bytes [66:68] : PowerBoardTemp  (uint16, K*100)
#   Bytes [68:70] : DigitizerBoardTemp (uint16, K*100)
#   Bytes [70:72] : NUCFlagTemp     (uint16, K*100)
#   Bytes [86:88] : LockinValue     (uint16)
#   Bytes [90:92] : ADResolution    (uint16, bits)
#   Bytes [92:96] : CameraSN        (uint32, integer serial number)
#
# CLOCK FREQUENCY: 6,250,000 Hz (confirmed from Research Studio)
# IntegrationTime in seconds = ticks / 6250000
# FrameCounter can be used to compute absolute timestamps if
# the camera epoch (power-on time) is known.
#
# OUTPUT:
#   A flat binary .raw file: Width x Height x 2 x NumFrames bytes.
#   Open in ImageJ as: File > Import > Raw
#     Image type    : 16-bit Unsigned
#     Width/Height  : as reported
#     Number of images: as reported
#     Byte order    : Little-endian
#
# USAGE:
#   perl ats-split.pl -i <input.ats> [-o <output.raw>] [-m]
#   -m : print per-frame metadata to stdout

use strict;
use warnings;
use Getopt::Std;

# FRAME_META_BYTES is now derived from image width (see below).
# For 1280-wide cameras this equals 2560 (10x256 records) -- same as before.
# For other widths it differs: frame_meta = Width * 2 (one extra row).
my $META_RECORD_BYTES = 256;    # one metadata record (repeated 10x)
my $CLOCK_HZ          = 6_250_000; # camera clock frequency

# Camera frame rate. Default = 54.4528 Hz, cross-validated for camera SN=49
# (A8581) via TWO independent methods/files in session v4:
#   - Rec-0009 (countdown mode): FrameCounter/RawTimestamp_us deltas -> 54.453 Hz
#   - CricketCooling (fc_only mode, gap=552): same ratio -> 54.4528 Hz
# Override with -f for a different camera/SN. The FrameCounter increments
# once per camera frame; Time_s = FrameCounter_delta / fps.
my $CAMERA_FPS = 54.4528;  # default; override via -f

my %opt;
getopts("hi:o:mf:t:", \%opt);
my $infile = $opt{i};

if ($opt{h} || !$infile) {
    print "Usage: perl ats-split.pl -i <input.ats> [-o <output.raw>] [-m] [-f <camera_fps>] [-t <timestamps.txt>]\n";
    print "  -i  input FLIR ATS video file\n";
    print "  -o  output raw file (default: replaces input extension with .raw)\n";
    print "  -m  print per-frame metadata table\n";
    print "  -f  camera acquisition frame rate in Hz (default: self-derived from\n";
    print "      LockinPhase; fallback $CAMERA_FPS Hz, SN=49/A8581, if too few frames)\n";
    print "      Used to convert FrameCounter to timestamps for fc_only-mode files.\n";
    print "      Supply -f to override self-derivation if needed.\n";
    print "  -t  write per-frame timestamps to a text file, format:\n";
    print "        FrameNNNNN: HH:MM:SS.ffffff\n";
    print "      Frame 1 (the first saved/extracted frame) = 00:00:00.000000.\n";
    print "      Times are FrameCounter-based (Time_s_RS), re-referenced to frame 1.\n";
    exit;
}

$CAMERA_FPS = $opt{f} + 0 if defined $opt{f};
my $outfile = $opt{o} // ($infile =~ s/\.[^.]+$/.raw/r);

# ============================================================
# Read file
# ============================================================
open(my $fh, '<:raw', $infile) or die "Cannot open '$infile': $!\n";
my $file = do { local $/; <$fh> };
close $fh;

my $file_size = length($file);
printf "Read %d bytes (%.2f MB) from '%s'\n",
       $file_size, $file_size/1024/1024, $infile;

# ============================================================
# Find Pixels tag and read dimensions
# ============================================================
my $pixels_tag  = index($file, "Pixels");
die "ERROR: Could not find 'Pixels' tag\n" if $pixels_tag < 0;

my $Width       = unpack("v", substr($file, $pixels_tag + 107, 2));
my $Height      = unpack("v", substr($file, $pixels_tag + 109, 2));
my $frame_bytes = $Width * $Height * 2;
my $FRAME_META_BYTES = $Width * 2;  # intra-frame metadata row = width * 2
                                    # (1280x cameras: 2560; 704x: 1408; etc.)

printf "'Pixels' tag at:  %d\n", $pixels_tag;
printf "Image dimensions: %d x %d (%d bytes/frame)\n", $Width, $Height, $frame_bytes;

# ============================================================
# Calculate frame count and pixel start
# ============================================================
# pixel_start detection: scan for zero->pixel boundary then nudge to HeaderID=20.
# Confirmed gaps: 3149 (A8581 1280x1024/1280x720), 1997 (A8581 704x696 windowed).
# Falls back to PIXELS_SUBHEADER_BYTES=3149 if detection fails (standard files).
my $PIXELS_SUBHEADER_BYTES = 3149;  # fallback constant

my $pixel_start = undef;
{
    # Step 1: find zero->pixel boundary (4 zero bytes then 6 valid MWIR counts)
    my ($PIX_LO, $PIX_HI, $ZERO_PREFIX) = (1000, 15000, 4);
    my $search_start = $pixels_tag + 1800;
    my $search_end   = $pixels_tag + 3500;
    for my $pos ($search_start .. $search_end) {
        last if $pos + 12 > $file_size;
        # Check 4 preceding bytes are zero
        my $zeros_ok = 1;
        for my $i (0 .. $ZERO_PREFIX-1) {
            $zeros_ok = 0, last
                if unpack("C", substr($file, $pos - $ZERO_PREFIX + $i, 1)) != 0;
        }
        next unless $zeros_ok;
        # Check 6 consecutive LE uint16 are valid MWIR counts
        my $pix_ok = 1;
        for my $i (0..5) {
            my $v = unpack("v", substr($file, $pos + $i*2, 2));
            $pix_ok = 0, last if $v < $PIX_LO || $v > $PIX_HI;
        }
        next unless $pix_ok;
        $pixel_start = $pos;
        last;
    }
    # Step 2: nudge forward until HeaderID=20 at byte 0 of metadata row
    if (defined $pixel_start) {
        for my $nudge (0..15) {
            my $mo = $pixel_start + $nudge + $frame_bytes;
            if ($mo < $file_size &&
                unpack("C", substr($file, $mo, 1)) == 20) {
                $pixel_start += $nudge;
                last;
            }
        }
        my $actual_gap = $pixel_start - $pixels_tag;
        if ($actual_gap != $PIXELS_SUBHEADER_BYTES) {
            printf "Pixel data start: %d  (gap=%d, non-standard -- differs from %d)\n",
                   $pixel_start, $actual_gap, $PIXELS_SUBHEADER_BYTES;
        } else {
            printf "Pixel data start: %d  (gap=%d, standard)\n",
                   $pixel_start, $actual_gap;
        }
    } else {
        $pixel_start = $pixels_tag + $PIXELS_SUBHEADER_BYTES;
        printf "Pixel data start: %d  (gap=%d, standard -- dynamic detection not required)\n",
               $pixel_start, $PIXELS_SUBHEADER_BYTES;
    }
}
my $num_frames  = int(($file_size - $pixel_start + $FRAME_META_BYTES)
                       / ($frame_bytes + $FRAME_META_BYTES));

die "ERROR: Could not locate pixel data (file too small for one frame).\n"
    if $num_frames < 1 || $pixel_start + $frame_bytes > $file_size;

my $trailing_bytes = $file_size
                    - ($pixel_start + $num_frames*$frame_bytes + ($num_frames-1)*$FRAME_META_BYTES);

printf "Pixel data start: %d\n", $pixel_start;
printf "Frames detected:  %d\n", $num_frames;
printf "Trailing bytes:   %d\n", $trailing_bytes if $trailing_bytes > 0;

# The 10 header-copy records (pixels_tag+589 .. pixel_start-1) correspond to
# RS's "Frame 1" -- the pre-roll/pre-pixel-data reference frame, ONE interval
# before our extracted frame 0. Its FrameCounter lets us compute an
# RS-equivalent total duration: (last_extracted_FC - header_FC) / camera_fps,
# validated to <0.07% against RS ground truth on two independent files.
my $HEADER_RECORD_OFFSET = $pixels_tag + 589;
my $header_FrameCounter  = unpack("V", substr($file, $HEADER_RECORD_OFFSET + 20, 4));

# ============================================================
# Self-derive camera fps from LockinPhase (frame0 -> last metadata frame)
# ============================================================
# LockinPhase (bytes[78:82]) is a free-running 32-bit counter that increments
# at ClockFrequency/4 = 1,562,500 Hz (A8581 family). Wraps every ~45.8 minutes.
# Uses CONSECUTIVE frame pairs (up to 10) to avoid multi-wrap issues on long
# recordings (Oxalis 2-hour file wraps ~2.6 times; single-wrap fix insufficient).
# Sanity range: 1-700 Hz. Returns undef if no valid samples (e.g. A8303sc,
# which uses a different clock divisor giving ~2339 Hz -- rejected as implausible).
my $LOCKIN_RATE = 1_562_500;  # = ClockFrequency/4
my $self_derived_fps = undef;
if ($num_frames >= 3) {
    my $frame_unit = $frame_bytes + $FRAME_META_BYTES;
    my $max_pairs  = ($num_frames - 2 < 10) ? $num_frames - 2 : 10;
    my @fps_samples;
    for my $f (0 .. $max_pairs - 1) {
        my $off0 = $pixel_start + $f * $frame_unit + $frame_bytes;
        my $off1 = $pixel_start + ($f+1) * $frame_unit + $frame_bytes;
        last if $off1 + $META_RECORD_BYTES > $file_size;
        my $rec0 = substr($file, $off0, $META_RECORD_BYTES);
        my $rec1 = substr($file, $off1, $META_RECORD_BYTES);
        my $fc0  = unpack("V", substr($rec0, 20, 4));
        my $lp0  = unpack("V", substr($rec0, 78, 4));
        my $fc1  = unpack("V", substr($rec1, 20, 4));
        my $lp1  = unpack("V", substr($rec1, 78, 4));
        my $fc_delta = ($fc1 - $fc0) & 0xFFFFFFFF;
        my $lp_delta = ($lp1 - $lp0) & 0xFFFFFFFF;
        next unless $fc_delta > 0 && $lp_delta > 0 && $lp_delta < 2**31;
        my $fps = $fc_delta / ($lp_delta / $LOCKIN_RATE);
        push @fps_samples, $fps if $fps > 1.0 && $fps < 700.0;
    }
    if (@fps_samples) {
        my @sorted = sort { $a <=> $b } @fps_samples;
        $self_derived_fps = $sorted[int(@sorted/2)];  # median
    }
}

if (defined $self_derived_fps) {
    if (defined $opt{f}) {
        printf "Self-derived camera fps (LockinPhase): %.4f Hz  (overridden by -f %.4f Hz)\n",
               $self_derived_fps, $CAMERA_FPS;
    } else {
        printf "Self-derived camera fps (LockinPhase): %.4f Hz  (using this; no -f given)\n",
               $self_derived_fps;
        $CAMERA_FPS = $self_derived_fps;
    }
} else {
    printf "Could not self-derive camera fps (too few frames); using %.4f Hz%s\n",
           $CAMERA_FPS, (defined $opt{f} ? " (-f)" : " (default)");
}

# ============================================================
# Helper: decode K*100 uint16 to Celsius string
# ============================================================
sub k100_to_c {
    my $raw = shift;
    return sprintf("%.2f C (%.2f K)", $raw/100 - 273.15, $raw/100);
}

# Format a seconds value (float) as HH:MM:SS.ffffff
sub format_hhmmss {
    my $s = shift;
    my $total_us = int($s * 1_000_000 + 0.5);
    my $us       = $total_us % 1_000_000;
    my $total_s  = int($total_us / 1_000_000);
    my $ss       = $total_s % 60;
    my $total_m  = int($total_s / 60);
    my $mm       = $total_m % 60;
    my $hh       = int($total_m / 60);
    return sprintf("%02d:%02d:%02d.%06d", $hh, $mm, $ss, $us);
}

# ============================================================
# Extract and report first-frame metadata
# ============================================================
sub decode_meta {
    my ($meta, $frame_num) = @_;
    my %m;

    $m{SavedFrameCounter}   = unpack("C",  substr($meta,  4, 1));
    $m{RawTimestamp_us}     = unpack("V",  substr($meta,  8, 4));  # fractional second + per-file offset
    $m{FrontPanelTemp_K100} = unpack("v",  substr($meta, 12, 2));
    $m{AirGapTemp_K100}     = unpack("v",  substr($meta, 14, 2));
    $m{InternalTemp_K100}   = unpack("v",  substr($meta, 16, 2));
    $m{FPATemp_K100}        = unpack("v",  substr($meta, 18, 2));
    $m{FrameCounter}        = unpack("V",  substr($meta, 20, 4));
    $m{IntegrationTime_ticks}= unpack("V", substr($meta, 24, 4));
    $m{FilterID}            = unpack("C",  substr($meta, 30, 1));
    $m{SaturationThreshold} = unpack("v",  substr($meta, 44, 2));
    $m{SaturatedPixels}     = unpack("v",  substr($meta, 46, 2));
    $m{AnalogOffset_mV}     = unpack("v",  substr($meta, 62, 2));
    $m{MainBoardTemp_K100}  = unpack("v",  substr($meta, 64, 2));
    $m{PowerBoardTemp_K100} = unpack("v",  substr($meta, 66, 2));
    $m{DigitizerTemp_K100}  = unpack("v",  substr($meta, 68, 2));
    $m{NUCFlagTemp_K100}    = unpack("v",  substr($meta, 70, 2));
    $m{LockinValue}         = unpack("v",  substr($meta, 86, 2));
    $m{ADResolution}        = unpack("v",  substr($meta, 90, 2));
    $m{CameraSN_int}        = unpack("V",  substr($meta, 92, 4));

    # Derived values
    $m{IntegrationTime_ms}  = $m{IntegrationTime_ticks} / $CLOCK_HZ * 1000;
    $m{FPATemp_K}           = $m{FPATemp_K100} / 100;

    return %m;
}

# ============================================================
# Pre-scan: determine timing mode from bytes[8:12] distribution
# ============================================================
# In countdown mode (intervals ~1 second), bytes[8:12] raw_diffs
# cluster near zero (small fractional second changes) while
# FrameCounter gaps are large (>10 frames per saved frame).
# In that case elapsed = 1,000,000 - raw_diff gives accurate timing.
#
# For all other files, we rely on FrameCounter gaps + camera fps
# (supplied via -f flag) for timing.

my @prescan_raw_diffs;
my @prescan_fc_gaps;
{
    my $prev_raw = undef;
    my $prev_fc  = undef;
    for my $f (0 .. $num_frames - 2) {
        my $meta_off = $pixel_start + $f * ($frame_bytes + $FRAME_META_BYTES) + $frame_bytes;
        last if $meta_off + $META_RECORD_BYTES > length($file);
        my $meta = substr($file, $meta_off, $META_RECORD_BYTES);
        my $raw  = unpack("V", substr($meta, 8, 4));
        my $fc   = unpack("V", substr($meta, 20, 4));
        if (defined $prev_raw) {
            push @prescan_raw_diffs, $prev_raw - $raw;
            push @prescan_fc_gaps,   $fc - $prev_fc;
        }
        $prev_raw = $raw;
        $prev_fc  = $fc;
    }
}

# Countdown mode: small raw_diffs + fc_gaps consistent with ~1-second intervals.
# bytes[8:12] only stores the FRACTIONAL second, so the complement formula
# (elapsed = 1,000,000 +/- raw_diff) can only represent intervals in (0, 2)
# seconds. If fc_gap is large (e.g. 552 frames ~ 10s at 54.5Hz), countdown
# mode would silently produce wrong timing -- require fc_only + -f instead.
my $ts_mode = 'fc_only';   # default: use FrameCounter only
if (@prescan_raw_diffs) {
    my @abs_diffs  = sort { $a <=> $b } map { abs($_) } @prescan_raw_diffs;
    my @sorted_fc  = sort { $a <=> $b } @prescan_fc_gaps;
    my $median_abs = $abs_diffs[int(@abs_diffs/2)];
    my $median_fc  = $sorted_fc[int(@sorted_fc/2)];
    if ($median_abs < 50_000 && $median_fc > 10 && $median_fc <= 100) {
        $ts_mode = 'countdown';
    }
}

if ($opt{m}) {
    my @abs_diffs = sort { $a <=> $b } map { abs($_) } @prescan_raw_diffs;
    my @sorted_fc = sort { $a <=> $b } @prescan_fc_gaps;
    printf "\nTimestamp mode: %s  (median |raw_diff|=%d, median fc_gap=%.1f)\n",
           $ts_mode,
           scalar @abs_diffs ? $abs_diffs[int(@abs_diffs/2)] : 0,
           scalar @sorted_fc ? $sorted_fc[int(@sorted_fc/2)] : 0;
    if ($ts_mode eq 'countdown') {
        printf "  Timing derived from bytes[8:12] (reliable for ~1s intervals)\n";
    } elsif (defined $CAMERA_FPS) {
        printf "  Timing derived from FrameCounter + camera fps (%.4f Hz from -f)\n", $CAMERA_FPS;
    } else {
        printf "  Supply camera fps with -f <hz> for time conversion\n";
    }
}

# ============================================================
# Extract frames and write output
# ============================================================
open(my $out, '>:raw', $outfile) or die "Cannot write '$outfile': $!\n";

printf "\nExtracting frames:\n";
my $offset = $pixel_start;

# Print metadata header
if ($opt{m}) {
    if (defined $CAMERA_FPS || $ts_mode eq 'countdown') {
        printf "\n%-5s %-12s %-6s %-10s %-10s %-11s\n",
               "Frame", "FrameCounter", "Delta", "Time_Raw_s", "Time_RS_s", "Flag";
    } else {
        printf "\n%-6s  %-12s  %-8s  %-8s  %-10s  %-10s  %-10s  %-6s\n",
               "Frame", "FrameCtr", "DeltaF",
               "IntgMs", "FPATemp_K", "FrontPnl_C", "MainBrd_C", "SatPx";
    }
    print "-" x 59 . "\n";
}

my $first_frame_counter = undef;
my $prev_frame_counter  = undef;
my $first_raw_ts        = undef;
my $prev_raw_ts         = undef;
my $cumulative_us       = 0;
my @frame_counters;
my @interval_us;
my $offset_baseline     = undef;  # Time_s_RS - Time_s_Raw for frame 0
my @export_times;                 # (FrameCounter - frame0_FrameCounter) / fps, for -t export
my %frame0_meta;                  # captured for printing after the table
my $frame0_time_s_rs;

for my $f (0 .. $num_frames - 1) {
    # Write pixel data
    my $pixels = substr($file, $offset, $frame_bytes);
    print $out $pixels;

    # Read metadata (first copy of the 256-byte record)
    my $meta_offset = $offset + $frame_bytes;
    printf "  Frame %3d: pixels at %9d  |  metadata at %9d\n",
           $f, $offset, $meta_offset
        unless $opt{m};

    if ($f < $num_frames - 1) {  # metadata exists between frames only
        my $meta = substr($file, $meta_offset, $META_RECORD_BYTES);
        my %m = decode_meta($meta, $f);

        # Timestamp computation from FrameCounter
        $first_frame_counter //= $m{FrameCounter};
        $first_raw_ts        //= $m{RawTimestamp_us};
        my $elapsed_frames = $m{FrameCounter} - $first_frame_counter;
        my $elapsed_s      = defined $CAMERA_FPS
                           ? $elapsed_frames / $CAMERA_FPS
                           : undef;
        my $delta_f = defined $prev_frame_counter
                    ? $m{FrameCounter} - $prev_frame_counter : 0;

        # Timing: countdown mode uses bytes[8:12]; otherwise use FrameCounter + camera fps
        $first_raw_ts //= $m{RawTimestamp_us};
        my $raw_diff = defined $prev_raw_ts ? $prev_raw_ts - $m{RawTimestamp_us} : undef;
        my $interval_us = undef;
        if ($ts_mode eq 'countdown' && defined $raw_diff) {
            $interval_us = $raw_diff >= 0
                         ? 1_000_000 - $raw_diff
                         : 1_000_000 + abs($raw_diff);
        } elsif (defined $CAMERA_FPS && $delta_f > 0) {
            $interval_us = int($delta_f / $CAMERA_FPS * 1_000_000 + 0.5);
        }
        if (defined $interval_us) {
            $cumulative_us += $interval_us;
            push @interval_us, $interval_us;
        }
        $prev_raw_ts = $m{RawTimestamp_us};

        push @frame_counters, $m{FrameCounter};
        $prev_frame_counter = $m{FrameCounter};

        my $show_time = ($ts_mode eq 'countdown' || defined $CAMERA_FPS);
        my $time_s_raw = $cumulative_us / 1_000_000;
        my $time_s_rs  = ($m{FrameCounter} - $header_FrameCounter) / $CAMERA_FPS;

        # Anomaly flag: Time_s_RS - Time_s_Raw should be a constant offset
        # (the header->frame0 interval) for every frame. A large deviation
        # from frame 0's offset flags a RawTimestamp anomaly at this frame
        # (typically following an irregular/non-modal FrameCounter gap).
        $offset_baseline //= ($time_s_rs - $time_s_raw);
        my $deviation = ($time_s_rs - $time_s_raw) - $offset_baseline;
        my $flag = (abs($deviation) > 0.05) ? "*** ANOMALY" : "";

        # Export timestamp: FrameCounter-based, re-referenced to frame 0
        # (frame 0 = 00:00:00.000000), matches Time_s_RS minus its frame-0 value.
        push @export_times, ($m{FrameCounter} - $first_frame_counter) / $CAMERA_FPS;

        if ($opt{m}) {
            if ($show_time) {
                printf "%-5d %-12d %-6d %-10.4f %-10.4f %-11s\n",
                       $f, $m{FrameCounter}, $delta_f,
                       $time_s_raw,
                       $time_s_rs,
                       $flag;
            } else {
                printf "%-6d  %-12d  %-8d  %-8.4f  %-10.2f  %-10.2f  %-6d\n",
                       $f, $m{FrameCounter}, $delta_f,
                       $m{IntegrationTime_ms}, $m{FPATemp_K},
                       $m{FrontPanelTemp_K100}/100 - 273.15,
                       $m{SaturatedPixels};
            }
        }

        # Save frame 0 metadata to print AFTER the table (keeps the table
        # header and all rows contiguous/visible together)
        if ($f == 0) {
            %frame0_meta = %m;
            $frame0_time_s_rs = $time_s_rs;
        }
    }

    $offset += $frame_bytes + $FRAME_META_BYTES;
}

close $out;

# Print Frame 0 metadata detail block (after the table, so the table
# header and all rows stay contiguous/visible together)
if (%frame0_meta) {
    my %m = %frame0_meta;
    my $fmt = "  %-28s: %s\n";
    printf "\n--- Frame 0 metadata ---\n";
    printf $fmt, "CameraSN",            $m{CameraSN_int};
    printf $fmt, "SavedFrameCounter",   $m{SavedFrameCounter};
    printf $fmt, "FrameCounter",         $m{FrameCounter};
    printf $fmt, "RawTimestamp_us",
                 sprintf("%d  (bytes[8:12]; %s counter)",
                         $m{RawTimestamp_us},
                         $ts_mode // 'mode not yet detected');
    printf $fmt, "Time_s_Raw (RawTimestamp-based)", "0  (reference frame)";
    printf $fmt, "Time_s_RS (FrameCounter-based)",
                 sprintf("%.4f", $frame0_time_s_rs);
    printf $fmt, "IntegrationTime",
                 sprintf("%.4f ms (%d ticks)", $m{IntegrationTime_ms},
                         $m{IntegrationTime_ticks});
    printf $fmt, "FPATemp",
                 sprintf("%.2f K (Stirling cooler)", $m{FPATemp_K});
    printf $fmt, "FrontPanelTemp",
                 sprintf("%.2f C", $m{FrontPanelTemp_K100}/100 - 273.15);
    printf $fmt, "AirGapTemp",
                 sprintf("%.2f C", $m{AirGapTemp_K100}/100 - 273.15);
    printf $fmt, "InternalTemp",
                 sprintf("%.2f C", $m{InternalTemp_K100}/100 - 273.15);
    printf $fmt, "MainBoardTemp",
                 sprintf("%.2f C", $m{MainBoardTemp_K100}/100 - 273.15);
    printf $fmt, "PowerBoardTemp",
                 sprintf("%.2f C", $m{PowerBoardTemp_K100}/100 - 273.15);
    printf $fmt, "DigitizerBoardTemp",
                 sprintf("%.2f C", $m{DigitizerTemp_K100}/100 - 273.15);
    printf $fmt, "NUCFlagTemp",
                 sprintf("%.2f C", $m{NUCFlagTemp_K100}/100 - 273.15);
    printf $fmt, "SaturationThreshold",  "$m{SaturationThreshold} counts";
    printf $fmt, "SaturatedPixels",      "$m{SaturatedPixels} pixels";
    printf $fmt, "AnalogOffset",
                 sprintf("%.3f V", $m{AnalogOffset_mV}/1000);
    printf $fmt, "ADResolution",         "$m{ADResolution} bits";
    printf $fmt, "LockinValue",           $m{LockinValue};
    printf $fmt, "FilterID",              $m{FilterID};
}

# Compute and report frame rate summary if we have enough frames
if (@frame_counters >= 2) {
    my @diffs = map { $frame_counters[$_+1] - $frame_counters[$_] }
                0 .. $#frame_counters - 1;
    my $sum = 0; $sum += $_ for @diffs;
    my $mean_gap = $sum / @diffs;
    my $modal_gap = (sort { scalar(grep {$_==$b} @diffs) <=>
                            scalar(grep {$_==$a} @diffs) } @diffs)[0];

    printf "\n--- Frame counter summary ---\n";
    printf "  Header record (RS Frame 1) FrameCounter: %d\n", $header_FrameCounter;
    printf "  FrameCounter span   : %d -> %d  (delta=%d camera frames)\n",
           $frame_counters[0], $frame_counters[-1],
           $frame_counters[-1] - $frame_counters[0];
    printf "  Mean gap per save   : %.1f camera frames\n", $mean_gap;
    printf "  Modal gap           : %d camera frames\n",   $modal_gap;
    printf "  Irregular gaps      : %s\n",
           join(", ", map { "frame $_->".($_+1).": $diffs[$_]" }
                grep { $diffs[$_] != $modal_gap } 0..$#diffs) || "none";

    # --- PRIMARY: RS-equivalent total duration & saved frame rate ---
    # (last_extracted_FC - header_FC) / camera_fps matches RS's reported
    # file Duration to <0.07% (validated on Rec-0009 and CricketCooling).
    # This is more robust than summing RawTimestamp_us intervals because it
    # only depends on the NET FrameCounter span, not on individual interval
    # attribution (which can be skewed by anomalous/NUC-affected gaps).
    {
        my $rs_span_fc = $frame_counters[-1] - $header_FrameCounter;
        my $rs_duration = $rs_span_fc / $CAMERA_FPS;
        my $n_total = @frame_counters + 1;  # +1 for the header/pre-roll frame
        printf "  Total duration      : %.4f s  (RS-equivalent: (last_FC-header_FC)/%.4f Hz)\n",
               $rs_duration, $CAMERA_FPS;
        printf "  Saved frame rate    : %.4f fps  (%d frames incl. pre-roll / %.4f s)\n",
               $n_total / $rs_duration, $n_total, $rs_duration;
    }

    # Compute camera fps and acquisition fps from RawTimestamp_us
    if ($cumulative_us > 0 && @interval_us) {
        my $duration_s = $cumulative_us / 1_000_000;
        my $acq_fps    = (@frame_counters - 1) / $duration_s;

        # Camera fps: use modal-gap intervals only, and filter out anomalous
        # ones (e.g. NUC stalls) by keeping only intervals within 1.5x of
        # the minimum interval for the modal gap size.
        my @modal_pairs;
        for my $i (0 .. $#diffs) {
            next unless $diffs[$i] == $modal_gap && $i <= $#interval_us;
            push @modal_pairs, $interval_us[$i];
        }
        my $min_modal = (sort { $a <=> $b } @modal_pairs)[0] // 0;
        my @clean_modal = grep { $_ <= $min_modal * 1.5 } @modal_pairs;

        my $cam_fps = undef;
        if (@clean_modal) {
            my $sum_us = 0; $sum_us += $_ for @clean_modal;
            my $mean_us = $sum_us / @clean_modal;
            $cam_fps = $modal_gap / ($mean_us / 1_000_000);
        }

        # Recompute duration excluding anomalous intervals (replace with expected)
        my $clean_duration_us = 0;
        for my $i (0 .. $#diffs) {
            next unless $i <= $#interval_us;
            my $iv = $interval_us[$i];
            # If anomalous (> 1.5x minimum for this gap size), replace with expected
            if (defined $cam_fps && $iv > ($modal_gap / $cam_fps * 1_000_000 * 1.5)) {
                $clean_duration_us += $diffs[$i] / $cam_fps * 1_000_000;
            } else {
                $clean_duration_us += $iv;
            }
        }

        printf "  [diag] RawTS duration: %.4f s  (sum of inter-frame intervals, no pre-roll)\n",
               $clean_duration_us / 1_000_000;
        printf "  [diag] Camera fps    : %.4f Hz  (modal-gap, NUC-filtered)\n",
               $cam_fps if defined $cam_fps;
        if ($clean_duration_us > 0) {
            printf "  [diag] Acquisition fps: %.4f fps  (large divergence from 'Saved frame rate'\n",
                   (@frame_counters - 1) / ($clean_duration_us / 1_000_000);
            printf "  [diag]   above may indicate a RawTimestamp anomaly at an irregular-gap frame)\n";
        }
        printf "  SkipFrames setting  : %d  (modal_gap - 1)\n", $modal_gap - 1;
    }

    printf "  Camera fps in use   : %.4f Hz%s\n", $CAMERA_FPS,
           defined $self_derived_fps
               ? (defined $opt{f} ? "  (-f, overrides self-derived)" : "  (self-derived from LockinPhase)")
               : "  (fallback default)";

    # --- Write timestamp export file (-t) ---
    if ($opt{t}) {
        # @export_times has num_frames-1 entries (no metadata follows the
        # last frame). Extrapolate the last frame using the modal gap.
        push @export_times, $export_times[-1] + $modal_gap / $CAMERA_FPS;
        write_timestamp_file($opt{t}, \@export_times, $num_frames);
    }
} elsif ($opt{t}) {
    # Single-frame file: only one timestamp, trivially 0.
    @export_times = (0) if !@export_times;
    write_timestamp_file($opt{t}, \@export_times, $num_frames);
}

sub write_timestamp_file {
    my ($path, $times, $n) = @_;
    open(my $tf, '>', $path) or die "Cannot write '$path': $!\n";
    my $width = length($n);
    $width = 5 if $width < 5;
    for my $i (0 .. $n - 1) {
        my $t = $times->[$i] // 0;
        printf $tf "Frame%0*d: %s\n", $width, $i+1, format_hhmmss($t);
    }
    close $tf;
    printf "\nWrote %d timestamps to '%s'\n", $n, $path;
    if (@export_times == $n) {
        printf "  (Note: last frame's timestamp is extrapolated using the modal\n";
        printf "   FrameCounter gap, since no metadata record follows the final frame)\n";
    }
}

printf "\nWritten %d frames to '%s'\n", $num_frames, $outfile;
print  "Done.\n";
print  "\nTo open in ImageJ:\n";
printf "  File > Import > Raw\n";
printf "  Image type      : 16-bit Unsigned\n";
printf "  Width           : %d\n", $Width;
printf "  Height          : %d\n", $Height;
printf "  Number of images: %d\n", $num_frames;
printf "  Byte order      : Little-endian\n";

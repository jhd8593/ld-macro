// LD Macro - live/dead analysis for paired GREEN (w1) / RED (w2) images.
// Thresholds adapt to each image's own background, noise and signal level,
// so dim and bright samples are measured the same way.

// Define directory with trailing backslash and get list of files
dir = "C:\\Users\\Jon\\Desktop\\Cardiac_Hypothermia_72025\\";
list = getFileList(dir);
List.clear(); // stores per-sample values for the summary

// ---- Tunable parameters -------------------------------------------------
// GREEN (live): outline at bg + max(G_NOISE_K x noise, G_SIGNAL_FRAC x signal),
// keep objects whose peak reaches bg + G_SEED_K x noise. The signal fraction
// excludes out-of-focus glow in proportion to brightness, so live area stays
// the same whether the image is bright or dim.
G_NOISE_K = 5;  G_SIGNAL_FRAC = 0.20;  G_SEED_K = 10;  G_MIN_SIZE = 200;
// RED (dead): on the background-subtracted image, outline at
// max(R_NOISE_K x noise, R_SIGNAL_FRAC x signal), keep objects whose peak
// reaches R_SEED_K x noise (hysteresis: dim nuclei count if they have a real peak).
R_NOISE_K = 3.5;  R_SIGNAL_FRAC = 0.15;  R_SEED_K = 6;  R_MIN_SIZE = 10;
// Signal-to-noise below these values is flagged in the summary (counts unreliable).
R_SNR_MIN = 12;  G_SNR_MIN = 20;
// -------------------------------------------------------------------------

// List keys cannot contain spaces (List.setList splits on them), so sanitize.
function key(prefix, name) { return prefix + replace(name, "[ :=]", "_"); }

// Returns [median, noise, p99.9] of the current image. noise = 1.4826 x MAD,
// a background noise estimate that ignores the (minority) cell pixels.
// Note: List.setMeasurements overwrites the global List; callers stash/restore it.
function imageStats(blur) {
    run("Duplicate...", "title=_stats");
    run("32-bit");
    if (blur) run("Gaussian Blur...", "sigma=1");
    List.setMeasurements; med = List.getValue("Median");
    getRawStatistics(n, mean, mn, mx);
    nb = 4096; getHistogram(v, c, nb, mn, mx);
    cum = 0; p999 = mx;
    for (b = 0; b < nb; b++) { cum += c[b]; if (cum >= 0.999 * n) { p999 = mn + (b + 0.5) * (mx - mn) / nb; b = nb; } }
    run("Subtract...", "value=" + med); run("Abs");
    List.setMeasurements; mad = List.getValue("Median") * 1.4826;
    close();
    return newArray(med, maxOf(mad, 1e-6), p999);
}

// Removes ROIs whose peak intensity on image id is below hi.
function keepSeeded(id, hi) {
    selectImage(id);
    for (k = roiManager("count") - 1; k >= 0; k--) {
        roiManager("select", k);
        getStatistics(ar, mean, mn, mx);
        if (mx < hi) roiManager("delete");
    }
    run("Select None");
}

// Saves measurements, a binary mask of the ROI Manager contents and a QC overlay.
function saveOutputs(rawID, prefix, color, baseName) {
    selectImage(rawID);
    w = getWidth(); h = getHeight();
    run("Clear Results");
    if (roiManager("count") > 0) { roiManager("deselect"); roiManager("Measure"); }
    saveAs("Results", dir + "Results_" + prefix + "_" + baseName + ".csv");
    newImage("_mask", "8-bit black", w, h, 1);
    setForegroundColor(255, 255, 255);
    for (k = 0; k < roiManager("count"); k++) { roiManager("select", k); run("Fill", "slice"); }
    run("Select None");
    saveAs("Tiff", dir + "Mask_" + prefix + "_" + baseName + ".tif");
    close();
    selectImage(rawID);
    run("Select None");
    run("Duplicate...", "title=_qc");
    run("Enhance Contrast", "saturated=0.35"); run("8-bit"); run("RGB Color");
    if (roiManager("count") > 0) {
        roiManager("deselect"); // apply color to every ROI, not just the last selected
        roiManager("Set Color", color); roiManager("Set Line Width", 1);
        roiManager("Show All without labels"); run("Flatten");
    }
    saveAs("PNG", dir + "QC_" + prefix + "_" + baseName + ".png");
}

// Print list of files found
print("Files found in the directory:");
for (i = 0; i < lengthOf(list); i++) {
    print(list[i]);
}
print("Total files: " + lengthOf(list));
setOption("BlackBackground", false);
run("Set Measurements...", "area mean integrated redirect=None decimal=3");

// Loop through all files
for (i = 0; i < lengthOf(list); i++) {
    showProgress(i + 1, lengthOf(list));
    fileName = list[i];
    print("Processing: " + fileName);

    // Process GREEN images (w1.tif)
    if (endsWith(fileName, "w1.TIF")) {
        baseName = replace(fileName, "w1.TIF", "");
        stash = List.getList;

        open(dir + fileName);
        rawID = getImageID();
        print("Opened GREEN image: " + fileName);
        // Calcein fills the cytoplasm continuously across aggregates, so each
        // particle is a live cell aggregate, not a single cell. Use total live
        // area rather than particle count as the live readout.
        s = imageStats(true); bg = s[0]; noise = s[1]; sig = s[2] - bg;
        snr = sig / noise;
        run("Duplicate...", "title=_g"); run("32-bit"); run("Gaussian Blur...", "sigma=1");
        procID = getImageID();
        lo = bg + maxOf(G_NOISE_K * noise, G_SIGNAL_FRAC * sig);
        hi = bg + G_SEED_K * noise;
        run("Duplicate...", "title=_gmask");
        setThreshold(lo, 1e30); run("Convert to Mask");
        roiManager("reset");
        // The 200 px minimum drops faint green specks that sit on dead cells.
        run("Analyze Particles...", "size=" + G_MIN_SIZE + "-Infinity pixel include add");
        close();
        keepSeeded(procID, hi);

        saveOutputs(rawID, "GREEN", "cyan", baseName);
        liveArea = 0;
        for (r = 0; r < nResults; r++) liveArea += getResult("Area", r);
        nLive = nResults;
        List.setList(stash);
        print("Processed GREEN image: " + nLive + " live aggregates, total live area = " + liveArea + " px, SNR = " + d2s(snr, 1));
        List.set(key("G_", baseName), liveArea);
        List.set(key("GS_", baseName), d2s(snr, 1));

        roiManager("reset");
        close("Results");
        run("Close All");
    }

    // Process RED images (w2.tif)
    else if (endsWith(fileName, "w2.TIF")) {
        baseName = replace(fileName, "w2.TIF", "");
        stash = List.getList;

        open(dir + fileName);
        rawID = getImageID();
        print("Opened RED image: " + fileName);
        s = imageStats(true); noise = s[1];
        run("Duplicate...", "title=_r");
        run("Subtract Background...", "rolling=10");
        run("32-bit"); run("Gaussian Blur...", "sigma=1");
        procID = getImageID();
        s2 = imageStats(false); sig = s2[2];
        snr = sig / noise;
        lo = maxOf(R_NOISE_K * noise, R_SIGNAL_FRAC * sig);
        hi = R_SEED_K * noise;
        run("Duplicate...", "title=_rmask");
        setThreshold(lo, 1e30); run("Convert to Mask");
        // Remove long thin debris (fibers) before watershed splits them into
        // fake "cells": anything with Feret > 60 px and MinFeret < 25 px.
        run("Set Measurements...", "area feret's redirect=None decimal=3");
        roiManager("reset");
        run("Analyze Particles...", "size=0-Infinity pixel clear add");
        nFiber = 0;
        setForegroundColor(255, 255, 255);
        for (k = roiManager("count") - 1; k >= 0; k--) {
            if (getResult("Feret", k) > 60 && getResult("MinFeret", k) < 25) {
                roiManager("select", k); run("Fill", "slice"); nFiber++;
            }
        }
        run("Select None");
        if (nFiber > 0) print("Removed " + nFiber + " fiber/debris object(s) from RED");
        run("Set Measurements...", "area mean integrated redirect=None decimal=3");
        run("Watershed");
        roiManager("reset");
        run("Analyze Particles...", "size=" + R_MIN_SIZE + "-Infinity pixel circularity=0.30-1.00 clear include add");
        close();
        keepSeeded(procID, hi);

        saveOutputs(rawID, "RED", "yellow", baseName);
        deadArea = 0;
        for (r = 0; r < nResults; r++) deadArea += getResult("Area", r);
        nDead = nResults;
        List.setList(stash);
        print("Processed RED image: " + nDead + " dead cells, total dead area = " + deadArea + " px, SNR = " + d2s(snr, 1));
        List.set(key("R_", baseName), deadArea);
        List.set(key("N_", baseName), nDead);
        List.set(key("RS_", baseName), d2s(snr, 1));

        roiManager("reset");
        close("Results");
        run("Close All");
    }

    // Skip unrelated files
    else {
        print("Skipped file (not w1 or w2): " + fileName);
    }
}

// Summary per sample: Pct_Live_Area = GREEN / (GREEN + RED) * 100,
// Pct_Dead_Area = RED / (GREEN + RED) * 100 (they sum to 100);
// Dead_per_10k_Live_px = RED count / GREEN area * 10000.
// Green_SNR / Red_SNR = signal (99.9th percentile above background) / noise;
// Low_Signal names any channel below G_SNR_MIN / R_SNR_MIN - check its QC image.
csv = "Sample,Green_Area_px,Red_Area_px,Red_Count,Pct_Live_Area,Pct_Dead_Area,Dead_per_10k_Live_px,Green_SNR,Red_SNR,Low_Signal\n";
for (i = 0; i < lengthOf(list); i++) {
    if (endsWith(list[i], "w1.TIF")) {
        b = replace(list[i], "w1.TIF", "");
        g = List.get(key("G_", b)); r = List.get(key("R_", b)); n = List.get(key("N_", b));
        gs = List.get(key("GS_", b)); rs = List.get(key("RS_", b));
        if (g == "" || r == "") {
            print("Summary: missing GREEN or RED for " + b);
        } else {
            tot = parseFloat(g) + parseFloat(r);
            pLive = "NaN"; pDead = "NaN";
            if (tot > 0) {
                pLive = d2s(parseFloat(g) / tot * 100, 2);
                pDead = d2s(parseFloat(r) / tot * 100, 2);
            }
            dpl = "NaN";
            if (parseFloat(g) > 0) dpl = d2s(parseFloat(n) / parseFloat(g) * 10000, 2);
            flag = "";
            if (parseFloat(gs) < G_SNR_MIN) flag = "GREEN";
            if (parseFloat(rs) < R_SNR_MIN) { if (flag != "") flag = flag + "+"; flag = flag + "RED"; }
            csv = csv + b + "," + g + "," + r + "," + n + "," + pLive + "," + pDead + "," + dpl + "," + gs + "," + rs + "," + flag + "\n";
            print("% live area for " + b + ": " + pLive + "   % dead area: " + pDead);
            print("Dead cells per 10,000 px live area for " + b + ": " + dpl);
            if (flag != "") print("WARNING: low signal in " + flag + " for " + b + " - check QC images");
        }
    }
}
File.saveString(csv, dir + "Summary_Area_Percent.csv");
print("Saved summary: Summary_Area_Percent.csv");

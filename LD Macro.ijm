// Define directory with trailing backslash and get list of files
dir = "C:\\Users\\Jon\\Desktop\\Cardiac_Hypothermia_72025\\";
list = getFileList(dir);
List.clear(); // stores per-sample GREEN/RED areas for the summary

// Print list of files found
print("Files found in the directory:");
for (i = 0; i < lengthOf(list); i++) {
    print(list[i]);
}
print("Total files: " + lengthOf(list));

// Loop through all files
for (i = 0; i < lengthOf(list); i++) {
    showProgress(i + 1, lengthOf(list));
    fileName = list[i];
    print("Processing: " + fileName);
    wait(500); // Optional delay

    // Process GREEN images (w1.tif)
    if (endsWith(fileName, "w1.TIF")) {
        baseName = replace(fileName, "w1.TIF", "");

        open(dir + fileName);
        greenID = getImageID();
        print("Opened GREEN image: " + fileName);
        // Calcein fills the cytoplasm continuously across aggregates, so each
        // particle is a live cell aggregate, not a single cell. Use total live
        // area (logged below) rather than particle count as the live readout.
        // The 200 px minimum drops faint green specks that sit on dead cells.
        run("Sharpen");
        wait(200);
        run("Auto Threshold", "method=Li ignore_black white");
        setOption("BlackBackground", false);
        run("Convert to Mask");
        roiManager("reset");
        run("Analyze Particles...", "size=200-Infinity pixel show=[Overlay Masks] display clear include add");
        liveArea = 0;
        for (r = 0; r < nResults; r++) liveArea += getResult("Area", r);
        print("Processed GREEN image: " + nResults + " live aggregates, total live area = " + liveArea + " px");
        List.set("G_" + baseName, liveArea);

        selectImage(greenID);
        saveAs("Tiff", dir + "Mask_GREEN_" + baseName + ".tif");
        print("Saved GREEN mask: Mask_GREEN_" + baseName + ".tif");
        saveAs("Results", dir + "Results_GREEN_" + baseName + ".csv");
        print("Saved GREEN results: Results_GREEN_" + baseName + ".csv");

        // QC overlay: outlines on the contrast-stretched raw image
        open(dir + fileName);
        run("Enhance Contrast", "saturated=0.35"); run("8-bit"); run("RGB Color");
        roiManager("Set Color", "cyan"); roiManager("Set Line Width", 1);
        roiManager("Show All without labels"); run("Flatten");
        saveAs("PNG", dir + "QC_GREEN_" + baseName + ".png");
        roiManager("reset");

        close("Results");
        run("Close All");
        wait(500);
    }

    // Process RED images (w2.tif)
    else if (endsWith(fileName, "w2.TIF")) {
        baseName = replace(fileName, "w2.TIF", "");

        open(dir + fileName);
        rawTitle = getTitle();
        print("Opened RED image: " + fileName);
        // Yen on raw 16-bit sat above most dead nuclei (~472 vs ~200-320) and the
        // 20-100 px cap dropped touching nuclei. Flatten background, split clusters.
        run("Subtract Background...", "rolling=10");
        run("Gaussian Blur...", "sigma=1");
        run("Auto Threshold", "method=Otsu white");
        setOption("BlackBackground", false);
        run("Convert to Mask");
        run("Watershed");
        roiManager("reset");
        run("Analyze Particles...", "size=10-400 pixel circularity=0.30-1.00 show=Masks display clear include add");
        deadArea = 0;
        for (r = 0; r < nResults; r++) deadArea += getResult("Area", r);
        print("Processed RED image: " + nResults + " dead cells, total dead area = " + deadArea + " px");
        List.set("R_" + baseName, deadArea);
        List.set("N_" + baseName, nResults);

        saveAs("Tiff", dir + "Mask_RED_" + baseName + ".tif");
        print("Saved RED mask: Mask_RED_" + baseName + ".tif");
        saveAs("Results", dir + "Results_RED_" + baseName + ".csv");
        print("Saved RED results: Results_RED_" + baseName + ".csv");

        // QC overlay: outlines on the contrast-stretched raw image
        open(dir + fileName);
        run("Enhance Contrast", "saturated=0.35"); run("8-bit"); run("RGB Color");
        roiManager("Set Color", "yellow"); roiManager("Set Line Width", 1);
        roiManager("Show All without labels"); run("Flatten");
        saveAs("PNG", dir + "QC_RED_" + baseName + ".png");
        roiManager("reset");

        close("Results");
        run("Close All");
        wait(500);
    }

    // Skip unrelated files
    else {
        print("Skipped file (not w1 or w2): " + fileName);
    }
}

// Summary: Area % = GREEN area / RED area * 100, one row per sample
csv = "Sample,Green_Area_px,Red_Area_px,Red_Count,Green_over_Red_Area_pct\n";
for (i = 0; i < lengthOf(list); i++) {
    if (endsWith(list[i], "w1.TIF")) {
        b = replace(list[i], "w1.TIF", "");
        g = List.get("G_" + b); r = List.get("R_" + b); n = List.get("N_" + b);
        if (g == "" || r == "") {
            print("Summary: missing GREEN or RED for " + b);
        } else {
            pct = "NaN";
            if (parseFloat(r) > 0) pct = d2s(parseFloat(g) / parseFloat(r) * 100, 2);
            csv = csv + b + "," + g + "," + r + "," + n + "," + pct + "\n";
            print("Area % (green/red*100) for " + b + ": " + pct);
        }
    }
}
File.saveString(csv, dir + "Summary_Area_Percent.csv");
print("Saved summary: Summary_Area_Percent.csv");

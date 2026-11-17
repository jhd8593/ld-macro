// Define directory with trailing backslash and get list of files
dir = "C:\\Users\\Jon\\Desktop\\Cardiac_Hypothermia_72025\\";
list = getFileList(dir);

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
        print("Opened GREEN image: " + fileName);
        run("Sharpen");
        wait(200);
        run("Auto Threshold", "method=Li ignore_black white");
        setOption("BlackBackground", false);
        run("Convert to Mask");
        run("Analyze Particles...", "size=200-Infinity pixel show=[Overlay Masks] display include add");
        print("Processed GREEN image");

        selectWindow("Results");
        saveAs("Tiff", dir + "Mask_GREEN_" + baseName + ".tif");
        print("Saved GREEN mask: Mask_GREEN_" + baseName + ".tif");
        saveAs("Results", dir + "Results_GREEN_" + baseName + ".csv");
        print("Saved GREEN results: Results_GREEN_" + baseName + ".csv");

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
        print("Processed RED image: " + nResults + " dead cells");

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


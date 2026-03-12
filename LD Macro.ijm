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
        print("Opened RED image: " + fileName);
        wait(200);
        run("Auto Threshold", "method=Yen white");
        setOption("BlackBackground", false);
        run("Convert to Mask");
        run("Analyze Particles...", "size=20-100 pixel circularity=0.30-1.00 show=Outlines display include add");
        print("Processed RED image");

        run("Flatten");
        run("Make Binary");

        saveAs("Tiff", dir + "Mask_RED_" + baseName + ".tif");
        print("Saved RED mask: Mask_RED_" + baseName + ".tif");
        saveAs("Results", dir + "Results_RED_" + baseName + ".csv");
        print("Saved RED results: Results_RED_" + baseName + ".csv");

        close("Results");
        run("Close All");
        wait(500);
    }

    // Skip unrelated files
    else {
        print("Skipped file (not w1 or w2): " + fileName);
    }
}


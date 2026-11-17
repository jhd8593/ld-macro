## LD Macro – Live/Dead ImageJ Analysis

This repository contains an ImageJ/Fiji macro (`LD Macro.ijm`) for **batch live/dead cell analysis** from fluorescence microscopy images.

The macro assumes that, for each field of view, you have:
- **GREEN channel** images named with suffix `w1.TIF` (e.g. `Sample1_w1.TIF`) – typically live-cell stain.
- **RED channel** images named with suffix `w2.TIF` (e.g. `Sample1_w2.TIF`) – typically dead-cell stain.

For each file in the target directory, the macro:
- **Scans a folder** you specify in the `dir` variable.
- **Adapts to each image's brightness.** For every image the macro measures its background, its noise (1.4826 × median absolute deviation) and its signal (99.9th percentile above background), and sets cutoffs from those. Dim and bright samples are therefore measured the same way. Tested by dimming two samples to 50%, 25% and 12% signal: live area stayed constant and % dead held until the dead-cell signal approached camera noise (where the summary flags it).
- **Processes GREEN (`w1.TIF`) images**  
  - Gaussian Blur (`sigma=1`).  
  - Outline at background + max(5 × noise, 20% of signal). The signal fraction rejects out-of-focus glow in proportion to brightness, so area does not depend on how bright the sample is.  
  - Keeps objects ≥ 200 px whose peak reaches background + 10 × noise.  
  - Saves `Mask_GREEN_<basename>.tif`, `Results_GREEN_<basename>.csv`, `QC_GREEN_<basename>.png` (cyan outlines).
  - Note: calcein-type live stains fill the cytoplasm continuously across a cell aggregate, so each GREEN particle is an **aggregate, not a single cell**. Use total live area as the live readout. The 200 px minimum intentionally drops faint green specks that sit on dead cells.
  - Why not Li: on dim images Li's cutoff collapses into the background and reports the whole field as live (~500,000 px instead of ~28,000).
- **Processes RED (`w2.TIF`) images**  
  - Subtract Background (`rolling=10`), Gaussian Blur (`sigma=1`).  
  - Outline at max(3.5 × noise, 15% of signal); keep objects whose peak reaches 6 × noise (hysteresis, so dim nuclei with a real peak still count).  
  - Removes long thin debris (Feret > 60 px and MinFeret < 25 px), then Watershed to split touching nuclei.  
  - Keeps objects ≥ 10 px, circularity 0.30–1.00.  
  - Saves `Mask_RED_<basename>.tif`, `Results_RED_<basename>.csv` (one row per dead cell), `QC_RED_<basename>.png` (yellow outlines).
  - History: Yen on the raw image gave 4 cells instead of ~108; Otsu was thrown off by bright debris (6 instead of ~120); Triangle undercounted dim samples.
- **All cutoffs are tunable** in the parameter block at the top of the macro (`G_*`, `R_*`).
- **Writes a summary** `Summary_Area_Percent.csv` with one row per sample: GREEN area, RED area, RED count, and:
  - **Pct_Live_Area** = GREEN / (GREEN + RED) × 100
  - **Pct_Dead_Area** = RED / (GREEN + RED) × 100 (the two sum to 100%)
  - **Dead_per_10k_Live_px** = RED count / GREEN area × 10,000 – dead cells per 10,000 px² of live area; uses the count, so it doesn't depend on nucleus size. Lower = healthier.
  - **Green_SNR / Red_SNR** – signal-to-noise of each channel.
  - **Low_Signal** – names any channel below `G_SNR_MIN` (20) / `R_SNR_MIN` (12). Results for flagged samples are unreliable (dead cells too close to camera noise); check their QC images or re-image with longer exposure.
  - Note: RED marks only dead nuclei while GREEN fills live cytoplasm, so % dead area understates the fraction of dead cells. Use these to compare samples; a true % viability by cell count needs a total-nuclei stain (e.g. Hoechst/DAPI).
- **Skips all other files** (anything not ending in `w1.TIF` or `w2.TIF`).

### How to Use

1. **Open the macro in ImageJ/Fiji**
   - In Fiji: `Plugins` → `Macros` → `Edit…`, then open `LD Macro.ijm`,  
     or drag-and-drop the file into Fiji.

2. **Set the data directory**
   - At the top of the macro, edit the line:
     ```javascript
     dir = "C:\\Users\\Jon\\Desktop\\Cardiac_Hypothermia_72025\\";
     ```
   - Replace this path with the folder that contains your image files.  
   - Make sure the path ends with a **trailing backslash** (`\\`).

3. **Ensure file naming is correct**
   - GREEN images must end with `w1.TIF`.  
   - RED images must end with `w2.TIF`.  
   - Example pair:
     - `Sample1_w1.TIF` (GREEN / live)  
     - `Sample1_w2.TIF` (RED / dead)

4. **Run the macro**
   - In Fiji: `Run` → `Run` (or press `Ctrl+R` while the macro editor is focused).  
   - Progress and file names will be printed to the **Log** window.

5. **Review outputs**
   - In the same folder as your images, you will get:
     - `Mask_GREEN_<basename>.tif` and `Results_GREEN_<basename>.csv`  
     - `Mask_RED_<basename>.tif` and `Results_RED_<basename>.csv`
   - Use the CSV files for quantitative live/dead analysis (e.g., cell counts, area).

### Notes

- Thresholding methods and particle size/circularity cutoffs are tuned for a specific experiment (cardiac hypothermia dataset).  
  - You can adjust:
    - Threshold methods in the `Auto Threshold` calls.
    - `size` and `circularity` parameters in the `Analyze Particles...` commands.
- The macro closes result tables and images between files to keep memory usage low.
- This repository is meant as a simple, shareable reference for live/dead batch analysis using Fiji/ImageJ.


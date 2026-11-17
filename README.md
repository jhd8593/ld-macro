## LD Macro – Live/Dead ImageJ Analysis

This repository contains an ImageJ/Fiji macro (`LD Macro.ijm`) for **batch live/dead cell analysis** from fluorescence microscopy images.

The macro assumes that, for each field of view, you have:
- **GREEN channel** images named with suffix `w1.TIF` (e.g. `Sample1_w1.TIF`) – typically live-cell stain.
- **RED channel** images named with suffix `w2.TIF` (e.g. `Sample1_w2.TIF`) – typically dead-cell stain.

For each file in the target directory, the macro:
- **Scans a folder** you specify in the `dir` variable.
- **Processes GREEN (`w1.TIF`) images**  
  - Opens the image.  
  - Applies **Sharpen**.  
  - Applies **Li Auto Threshold** (`method=Li`, white foreground, `ignore_black`).  
  - Converts to a **binary mask**.  
  - Runs **Analyze Particles** with `size=200-Infinity pixel`, outputs overlay masks and results.  
  - Logs the number of live aggregates and the **total live area**.  
  - Saves:
    - `Mask_GREEN_<basename>.tif` – GREEN mask image.  
    - `Results_GREEN_<basename>.csv` – particle analysis results.  
    - `QC_GREEN_<basename>.png` – detected outlines drawn on the contrast-stretched image.
  - Note: calcein-type live stains fill the cytoplasm continuously across a cell aggregate, so each GREEN particle is an **aggregate, not a single cell**. Use total live area (sum of `Area`) as the live readout, not the row count. The 200 px minimum intentionally drops faint green specks that sit on dead cells.
- **Processes RED (`w2.TIF`) images**  
  - Opens the image.  
  - Applies **Subtract Background** (`rolling=10`) and **Gaussian Blur** (`sigma=1`).  
  - Applies **Otsu Auto Threshold** (`method=Otsu`, white foreground).  
  - Converts to a **binary mask** and runs **Watershed** to split touching nuclei.  
  - Runs **Analyze Particles** with `size=10-400 pixel`, `circularity=0.30-1.00`.  
  - Saves:
    - `Mask_RED_<basename>.tif` – RED mask image.  
    - `Results_RED_<basename>.csv` – particle analysis results (one row per dead cell).  
    - `QC_RED_<basename>.png` – detected outlines drawn on the contrast-stretched image, for visual checking.
  - Why not Yen on the raw image: on 16-bit images with a dim background, Yen can set the cutoff above most dead nuclei (e.g. 472 vs. nuclei at ~200–320), and a 20–100 px size cap discards touching nuclei. On a liver sample this gave 4 cells instead of ~108.
- **Writes a summary** `Summary_Area_Percent.csv` with one row per sample: GREEN area, RED area, RED count, and **Area % = GREEN area / RED area × 100**. (RED area is dead nuclei, GREEN is live cytoplasm, so values above 100 are expected.) It also reports **Dead_per_10k_Live_px = RED count / GREEN area × 10,000**: dead cells per 10,000 px² of live area, which uses the dead-cell count and so doesn't depend on nucleus size. Lower = healthier. Both metrics are for comparing samples imaged the same way; a true % viability needs a total-nuclei stain (e.g. Hoechst/DAPI).
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


SMITE is a toolbox for using eye trackers from SMI GmbH with MATLAB,
specifically offering integration with [PsychToolbox](http://psychtoolbox.org/). A Python version
that integrates with PsychoPy is also available from
www.github.com/marcus-nystrom/SMITE

Cite as:
Niehorster, D.C., & Nyström, M., (in revision). SMITE: A
toolbox for creating Psychtoolbox and Psychopy experiments with SMI eye
trackers.

For questions, bug reports or to check for updates, please visit
www.github.com/dcnieho/SMITE. 

SMITE is licensed under the Creative Commons Attribution 4.0 (CC BY 4.0) license.

`demos/readme.m` shows a minimal example of using the toolbox's
functionality.

To run the toolbox, it is required to install the SMI iViewX SDK version
4.4.26. An up-to-date version of PsychToolbox is recommended. Make sure
PsychToolbox's GStreamer dependency is installed.

Tested on MATLAB R2015b & R2018a. Octave is currently not supported.

## Usage
As demonstrated in the demo scripts, the toolbox is configured through
the following interface:
1. Retrieve (default) settings for eye tracker of interest: `settings =
SMITE.getDefaults('trackerName');` Supported tracker model names are `HiSpeed`,
`RED`, `RED-m`, `RED250mobile`, `REDn Scientific`, and `REDn
Professional`.
2. Change settings from their defaults if wanted (see [supported options](#supported-options) section below)
3. Create a SMITE instance using this settings struct: `EThndl = SMITE(settings);`

### API
#### Static methods
The below method can be called on a SMITE instance or on the SMITE class directly.

|Call|inputs|outputs|description|
| --- | --- | --- | --- |
|`getDefaults`|<ol><li>`tracker`: one of the supported eye tracker model names</li></ol>|<ol><li>`settings`: struct with all supported settings for a specific model of eyeTracker</li></ol>|Gets all supported settings with defaulted values for the indicated eyeTracker, can be modified and used for constructing an instance of SMITE. See the supported options section below.|

#### Construction
An instance of SMITE is constructed by calling `SMITE()` with either the name of a specific supported eye tracker model (in which case default settings for this model will be used) or with a settings struct retrieved from `SMITE.getDefaults()`, possibly with changed settings (passing the settings struct unchanged is equivalent to using the eye tracker model name as input argument).

#### Methods
The following method calls are available on a SMITE instance

|Call|inputs|outputs|description|
| --- | --- | --- | --- |
|`getOptions()`|||Get active settings, returns only those that can be changed in the current state (which is a subset of all settings once `init()` has been called)|
|`setOptions()`|||Change active settings|
|`init()`|| |Connects to the SMI eye tracker and initializes it according to the requested settings|
|`isConnected()`|| |Reports status of the connection to the eye tracker|
|`calibrate()`|| |Starts participant setup and calibration|
|`startRecording()`|| |Starts recording eye-movement data to idf file|
|`startBuffer()`|| |Starts recording data into buffer for online use|
|`sendMessage()`|| |Inserts message into idf file|
|`getLatestSample()`|| |Returns most recent data sample|
|`consumeBufferData()`|| |Returns data in the online buffer and clears it|
|`peekBufferData()`|| |Returns data in the online buffer without clearing it|
|`stopBuffer()`|| |Stop recording data into buffer|
|`stopRecording()`|| |Stop recording data into idf file|
|`saveData()`|| |Saves idf file to specified location|
|`deInit()`|| |Closes connection to the eye tracker and cleans up|
|`setBegazeTrialImage()`|| |Put specially prepared message in idf file to notify BeGaze what stimulus image/video belongs to a trial|
|`setBegazeKeyPress()`|| |Put specially prepared message in idf file that shows up as keypress in BeGaze|
|`setBegazeMouseClick()`|| |Put specially prepared message in idf file that shows up as mouse click in BeGaze|
|`startEyeImageRecording()`|| |Starts recording eye images to file|
|`stopEyeImageRecording()`|| |Stop recording eye images to file|
|`setDummyMode()`|| |Enable dummy mode, which allows running the program without an eye tracker connected|


### Supported options
Which of the below options are available depends on the eye tracker model. The `getDefaults` and `getOptions` method calls return the appropriate set of options for the indicated eye tracker.

| Option name | Explanation |
| --- | --- |
| settings.trackEye              | `'EYE_LEFT'`, `'EYE_RIGHT'`, or `'EYE_BOTH'` |
| settings.trackMode             | `'MONOCULAR'`, `'BINOCULAR'`, `'SMARTBINOCULAR'`, or `'SMARTTRACKING'` |
| settings.freq                  | sampling frequency |
| settings.cal.nPoint            | number of calibration points |
| settings.doAverageEyes         | average the gaze position of the two eyes? |
| settings.setup.viewingDist     | for all remotes: set reference view distance used during setup |
| settings.setup.geomMode        | for REDs, monitorIntegrated or standalone |
| settings.setup.monitorSize     | inch, for REDs in monitorIntegrated mode |
| settings.setup.geomProfile     | `'profileName'`, for REDs in standalone mode, and for RED-m, RED250mobile and REDn |
| settings.setup.scrWidth        | for REDs in standalone mode |
| settings.setup.scrHeight       | for REDs in standalone mode |
| settings.setup.scrDistToFloor  | for REDs in standalone mode |
| settings.setup.REDDistToFloor  | for REDs in standalone mode |
| settings.setup.REDDistToScreen | for REDs in standalone mode |
| settings.setup.REDInclAngle    | for REDs in standalone mode |
| settings.start.removeTempDataFile | when calling `iV_Start`, iView always complains with a popup if there is some unsaved recorded data in iView's temp location. The popup can really mess with visual timing of PTB, so its best to remove it. Not relevant for a two computer setup |
| settings.setup.startScreen     | 0: skip head positioning, go straight to calibration; 1: start with simple head positioning interface; 2: start with advanced head positioning interface |
| settings.setup.basicRefColor   |  basic head position visualization: color of reference circle
| settings.setup.basicHeadEdgeColor | basic head position visualization: color of egde of disk representing head
| settings.setup.basicHeadFillColor | basic head position visualization: color of fill of disk representing head
| settings.setup.basicHeadFillOpacity | basic head position visualization: opacity of disk representing head
| settings.setup.basicShowEyes | basic head position visualization: show eyes?
| settings.setup.basicEyeColor | basic head position visualization: color of eyes in head
| settings.setup.valAccuracyTextColor | color of text displaying accuracy number on validation feedback screen
| settings.cal.autoPace          | 0: manually confirm each calibration point. 1: only manually confirm the first point, the rest will be autoaccepted. 2: all calibration points will be auto-accepted |
| settings.cal.bgColor           | RGB (0-255) background color for setup/calibration |
| settings.cal.fixBackSize       | size (pixels) of large circle in fixation cross |
| settings.cal.fixFrontSize      | size (pixels) of small circle in fixation cross |
| settings.cal.fixBackColor      | color (RGB, 0-255) of large circle in fixation cross |
| settings.cal.fixFrontColor     | color (RGB, 0-255) of large circle in fixation cross |
| settings.cal.drawFunction      | function to be called to draw calibration screen. See `AnimatedCalibrationDisplay` for an example |
| settings.text.font             | font name for text in interface, e.g. `'Consolas'` |
| settings.text.style            | style for text in interface. The following can ORed together: 0=normal, 1=bold, 2=italic, 4=underline, 8=outline, 32=condense, 64=extend |
| settings.text.wrapAt           | long texts in interface will be wrapped at this many characters |
| settings.text.vSpacing         | vertical space between lines. 1 is normal |
| settings.text.size             | text size (pt) |
| settings.string.simplePositionInstruction  | text shown on simple head positioning interface |
| settings.logFileName           | filename where SMI log is stored |
| settings.debugMode             | only for SMITE developer use |

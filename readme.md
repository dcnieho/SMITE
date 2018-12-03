SMITE is a toolbox for using eye trackers from SMI GmbH with Matlab,
specifically offering integration with PsychToolbox. A python version
that integrates with PsychoPy is also available from
www.github.com/marcus-nystrom/SMITE

Cite as:
Niehorster, D.C., & Nyström, M., (in prep). SMITE: The definitive
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
1. retrieve (default) settings for eye tracker of interest: `settings =
SMITE.getDefaults('trackerName');` Supported tracker Names are `HiSpeed`,
`RED`, `RED-m`, `RED250mobile`, `REDn Scientific`, and `REDn
Professional`.
2. edit settings if wanted (see below)
3. initialize SMITE using this settings struct: `EThndl = SMITE(settings);`

Supported options (depending on eye tracker model):

| Option name | Explanation |
| --- | --- |
| settings.trackEye              | `'EYE_LEFT'`, `'EYE_RIGHT'`, or `'EYE_BOTH'` |
| settings.trackMode             | `'MONOCULAR'`, `'BINOCULAR'`, `'SMARTBINOCULAR'`, or `'SMARTTRACKING'` |
| settings.freq                  | sampling frequency |
| settings.cal.nPoint            | number of calibration points |
| settings.doAverageEyes         | average the gaze position of the two eyes? |
| settings.setup.viewingDist     | for all remotes: desider view distance indicated during setup |
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

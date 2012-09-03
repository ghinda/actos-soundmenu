import QtQuick 1.1
import org.kde.plasma.core 0.1 as PlasmaCore
import org.kde.plasma.graphicswidgets 0.1 as PlasmaWidgets

Item {
	property string controller
	property int level : 0
	property int size : Math.min(width, height)
    property bool volumeChangedByEngine : false
    property bool volumeChangedBySlider : false
	
	anchors.fill: parent
	
	// timer to change volume, to only trigger a single request on the datasource
	Timer {
		id: changeVolume
		interval: 200
        running: false
        repeat: false
        onTriggered: {
			var operation = mixerSource.serviceForSource(controller).operationDescription("setVolume");
			operation.level = level;

			mixerSource.serviceForSource(controller).startOperationCall(operation);
		}
	}
	
	// connect dataengine to controller
	function connectToDevice() {
		controller = mixerSource.data["Mixers"]["Current Master Mixer"] + "/" + mixerSource.data["Mixers"]["Current Master Control"];
		mixerSource.connectSource(controller);
		
		level = (controller) ? mixerSource.data[controller].Volume : 0;
		volumeSlider.value = level;
		volumeSlider.opacity = (controller) ? 0.01 : 0;
	}
	
	// mixer DataEngine for global volume control
	// used in compactRepresentation to change volume icon, based on volume level
	PlasmaCore.DataSource {
		id: mixerSource
		dataEngine: "mixer"
		connectedSources: [ "Mixers" ]
		
		onDataChanged: {

			// connect after kmix was started
			if(mixerSource.data["Mixers"].Running) {
				
				if(controller) {
					level = (controller) ? mixerSource.data[controller].Volume : 0;
					
					if(volumeChangedBySlider) {
						volumeChangedBySlider = false;
					} else {
						volumeChangedByEngine = true;
						volumeSlider.value = level;
					}
					
					if(level == 0) {
						volumeIcon.elementId = "audio-volume-muted";
					} else if (level < 33) {
						volumeIcon.elementId = "audio-volume-low";
					} else if (level < 66) {
						volumeIcon.elementId = "audio-volume-medium";
					} else {
						volumeIcon.elementId = "audio-volume-high";
					}
					
				} else {
					connectToDevice();
				}
			
				volumeChangedBySlider = false;
				
			} else {
				// disconnect if kmix closed
				controller = "";
				volumeSlider.value = level = 0;
				volumeSlider.opacity = 0;
				
				volumeIcon.elementId = "audio-volume-muted";
			}
			
		}
		
		Component.onCompleted: {
			if(mixerSource.data["Mixers"].Running) connectToDevice()
		}
	
	}
	
	PlasmaCore.Svg {
		id: audioSvg
		imagePath: "icons/audio"
	}
	
	// volume slider
	PlasmaWidgets.Slider {
		id: volumeSlider
		anchors.fill: parent
		orientation: Qt.Horizontal
		maximum: 100
		minimum: 0
		value: level
		
		opacity: 0.01
		
		onValueChanged: {
			if(controller) {
				if(volumeChangedByEngine) {
					volumeChangedByEngine = false;
				} else {
					volumeChangedBySlider = true;
					level = volumeSlider.value;
					
					changeVolume.restart();
				}
			}
		}
	}
	
	PlasmaCore.SvgItem {
		id: volumeIcon
		
		anchors.centerIn: parent
		width: size
		height: size
		
		svg: audioSvg
		elementId: "audio-volume-low"
	}
	
	MouseArea {
		anchors.fill: parent
		
		onClicked: plasmoid.togglePopup();
	}
	
	PlasmaCore.ToolTip {
		target: volumeIcon
		mainText: "Volume at " + level + "%"
		image: "preferences-desktop-sound"
	}
}
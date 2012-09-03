import QtQuick 1.1
import org.kde.plasma.core 0.1 as PlasmaCore
import org.kde.plasma.components 0.1 as Plasma
import org.kde.plasma.graphicswidgets 0.1 as PlasmaWidgets

import "../code/service.js" as Control

Item {
	id: root
	width: 300
    height: (playerActive) ? 340 : 120
    
    property int minimumWidth: 300
    property int minimumHeight: (playerActive) ? 340 : 120
	
	property Component compactRepresentation: VolumeIcon {}
	
    property bool playerActive : (source.identity) ? true : false
    property bool volumeChangedByEngine : false
    property bool volumeChangedBySlider : false
	property string controller
	property int level : 0
	property int previousVolume : 0
	
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
	}
	
	// mixer DataEngine for global Volume control
	PlasmaCore.DataSource {
		id: mixerSource
		dataEngine: "mixer"
		connectedSources: [ "Mixers" ]
		
		onDataChanged: {
			// connect after kmix was started
			if(mixerSource.data["Mixers"].Running) {
				if(controller) {
					if(volumeChangedBySlider) {
						volumeChangedBySlider = false;
					} else {
						volumeChangedByEngine = true;
						
						level = (controller) ? mixerSource.data[controller].Volume : 0;
						volumeSlider.value = level;
					}
				} else {
					connectToDevice();
				}
				
			} else {
				// disconnect if kmix closed
				controller = "";
				volumeSlider.value = level = 0;
			}
		}
		
		Component.onCompleted: {
			if(mixerSource.data["Mixers"].Running) connectToDevice()
		}
		
	}
	
	// MPRIS2 dataEngine
	Mpris2 { id: source }
	
	// separator line svg
	PlasmaCore.Svg {
		id: lineSvg
		imagePath: "widgets/line"
	}
	
	// main item
	Item {
		anchors {
			fill: parent
			margins: 10
		}
		
		Column {
			spacing: 10
			anchors {
				left: parent.left
				right: parent.right
			}
			
			// mute/unmute button
			Plasma.ToolButton {
				text: (volumeSlider.value == 0) ? "Unmute" : "Mute"
				iconSource: 'plasmapackage:/images/blank.png' // use blank icon to left-align text
				
				anchors {
					left: parent.left
					right: parent.right
				}
				
				onClicked: {
					
					// mute/unmute
					if(volumeSlider.value == 0) {
						volumeSlider.value = previousVolume;
					} else {
						previousVolume = volumeSlider.value; 
						volumeSlider.value = 0;
					}
					
				}
			}
			
			// volume slider
			PlasmaWidgets.Slider {
				id: volumeSlider
				anchors {
					left: parent.left
					right: parent.right
				}
				orientation: Qt.Horizontal
				maximum: 100
				minimum: 0
				value: level
				
				height: 10
				
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
			
			// separator
			PlasmaCore.SvgItem {
				anchors {
					left: parent.left
					right: parent.right
				}
				svg: lineSvg
				elementId: "horizontal-line"
				height: lineSvg.elementSize("horizontal-line").height
			}
			
			// media player button
			Plasma.ToolButton {
				id: playerButton
				text: source.identity.trim()
				visible: (source.identity)
				iconSource: 'plasmapackage:/images/blank.png' // use blank icon to left-align text
				
				anchors {
					left: parent.left
					right: parent.right
				}
				
				onClicked: {
					Control.associateItem(playerButton, 'Raise');
				}
			}
			
			// album art and metadata
			Row {
				spacing: 20
				
				visible: source.playbackStatus == 'Playing' || source.playbackStatus == 'Paused'
				
				anchors {
					left: parent.left
					leftMargin: 20
					right: parent.right
				}
				
				AlbumArt {
					id: albumArt
					artUrl: source.artUrl
					width: 100
					height: 100
				}
				
				MetadataPanel {
					id: metadataPane
					source: source
					
					anchors {
						left: albumArt.right
						leftMargin: 20
						right: parent.right
					}
				}
				
			}
			
			// controls
			Row {
				spacing: 10
				visible: (source.identity)
				anchors {
					horizontalCenter: parent.horizontalCenter
				}
				
				Plasma.ToolButton {
					id: prevButton
					height: 48
					iconSource: "plasmapackage:/images/media-skip-backward.png"
					onClicked: {
						Control.callCommand('Previous');
					}
					Component.onCompleted: {
						Control.associateItem(prevButton, 'Previous');
					}
				}
				
				Plasma.ToolButton {
					id: playPauseButton
					height: 48
					property string operation: (source.playbackStatus == 'Playing' ? 'Pause' : 'Play')
					iconSource: (source.playbackStatus == 'Playing' ? "plasmapackage:/images/media-playback-pause.png" : "plasmapackage:/images/media-playback-start.png")
					onClicked: {
						Control.callCommand(operation);
					}
					Component.onCompleted: {
						Control.associateItem(playPauseButton, operation);
					}
					onOperationChanged: {
						Control.associateItem(playPauseButton, operation);
					}
				}
				
				Plasma.ToolButton {
					id: stopButton
					height: 48
					iconSource: "plasmapackage:/images/media-playback-stop.png"
					onClicked: {
						Control.callCommand('Stop');
					}
					Component.onCompleted: {
						Control.associateItem(stopButton, 'Stop');
					}
				}
				
				Plasma.ToolButton {
					id: nextButton
					height: 48
					iconSource: "plasmapackage:/images/media-skip-forward.png"
					onClicked: {
						Control.callCommand('Next');
					}
					Component.onCompleted: {
						Control.associateItem(nextButton, 'Next');
					}
				}
			
			}
			
			// separator
			PlasmaCore.SvgItem {
				visible: (source.identity) // hide if no controls
				anchors {
					left: parent.left
					right: parent.right
				}
				svg: lineSvg
				elementId: "horizontal-line"
				height: lineSvg.elementSize("horizontal-line").height
			}
			
			// settings button - starts kmix
			Plasma.ToolButton {
				text: "Sound settings"
				iconSource: 'plasmapackage:/images/blank.png' // use blank icon to left-align text
				
				anchors {
					left: parent.left
					right: parent.right
				}
				
				onClicked: {
					
					// show kmix
					plasmoid.runCommand("qdbus", ["org.kde.kmix", "/kmix/KMixWindow", "visible", "true"]);
					
					// hide popup
					plasmoid.togglePopup();
					
				}
			}
			
		}
	}
	
	Component.onCompleted: {
		plasmoid.popupIcon = "preferences-desktop-sound";
	}

}
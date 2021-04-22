


--NOTICE: THIS IS VERSION 0.9.4c! EDITS ARE BEING MADE HERE TO BE BETA RELEASED WHEN PEOPLE NEED TO IMPORT CAMERAS INTO REPLAYS WITH BETTER TIME INTERPOLATION




try(destroyDialog CBMaxWrapper)
catch()
global frameRate = 60
--timeDisplayMode = #frameTicks

/*
TO-DO
	- IMPLEMENT EXPORT FPS SO YOU DONT HAVE TO DO MANY CULCULATIONS FOR POSITION/ROTATION






	- Receive wheel/suspension animation data

	- Add global frame/subframe offset to sync to original recording
		- This would change the timing of the animations for the ball, camera, and cars
		- Different from the camera sync offset. That is to properly line up the timestamps if a second camera is imported

	- "Ignore Camera" checkbox needs to function
	
	- Everything in camera list rollout needs to function
	
	- Fix gamma of UI banner. Maybe only in max 2016? (not bugged in 2017, 2018????, 2019)
		- https://forums.cgsociety.org/t/gamma-of-maxscript-bitmaps-in-max-2016-vs-max-2014/1702291
		- https://forums.cgsociety.org/t/imgtag-woes/1534090
	
	- Ion boost impulse should have 2 particle emission points, one at top of booster and one at bottom
		- per frame emit particle and use the two new points to create an additional polygon on a tapeworm

	- About/help dialog pops up when clicking banner
		- image should do something on hover, like add a dropshadow
		- Add a link to a short tutorial series on youtube covering the basics of the plugin's functions
		
	- Add camera to listbox
	
	- Test if you fixed stuttering at slower playback speeds in the replay viewer
	
	- Make sure replay metadata gets the full length of replay names instead of missing parts due to spaces
*/

global gameState

global ball
global car = #()
global newCamera
global numCars

global importedFile
global rawLineRead
global filteredLine
global subframeScale

global frame
global camFOV
global camPosX
global camPosY
global camPosZ
global camRotX
global camRotY
global camRotZ
global ballPosX
global ballPosY
global ballPosZ
global ballRotX
global ballRotY
global ballRotZ

global useCars = true
global useBall = true

global relativePath = getFilenamePath(getSourceFileName())




global msVersion	= "0.9.4"--0.9.4d
global versionMismatch = false





--BEGIN ROLLOUT
rollout CBMaxWrapper "" width:235 height:500
(
	GroupBox imgBox pos:[2,0] width:231 height:62.5
	local imgBM = openBitMap(relativePath + "/Assets/CinematicsBuddyMaxscriptBanner2.jpg")
	imgTag imgCinematicsBuddy bitmap:imgBM pos:[5,9] width:225 height:51.12
	hyperlink hylinkVersionNum "Version" pos:[83,62] color:[125,200,175] enabled:false
	label lblVersionNum msVersion pos:[122,62]
	subrollout allRollouts "All Rollouts" pos:[0,80] width:239 height:425
)

rollout initialize "Initialize"
(
	button btnCameraImport "Import File" pos:[3,3] width:71 height:28
	button btnConfirmImport "Confirm" pos:[77,3] width:71 height:28 enabled:false
	button btnCancelImport "Cancel" pos:[151,3] width:71 height:28 enabled:false
	spinner spnFpsChange "FPS:" range:[0,999,0] pos:[5,35] width:50 tooltip:"This reads the average FPS from the recording. It is sometimes wrong so adjust accordingly." type:#integer align:#left
	spinner spnFrameCount "Frames:" range:[0,999999,0] pos:[5,54] width:80 type:#integer align:#left
	label lblNumCars "#" pos:[89,35]
	label lblCars "CARS" pos:[101,35]
	label lblCameraNameLabel "Camera:" pos:[5,76]
	edittext textCameraName "" pos:[44,74] width:105
	label lblIgnore "Ignore:" pos:[115,50]
	groupbox gboxIngores "" pos:[155,32] width:66 height:60
	checkbox cboxCamera "Camera" pos:[160,40] width: 60
	checkbox cboxBall "Ball" pos:[160,57]
	checkbox cboxCars "Cars" pos:[160,74]
	
	
	on btnCameraImport pressed do
	(
		filePathName = getOpenFileName caption:"Select file to import"
		if filePathName != undefined do
		(
			importedFile = openFile filePathName
			rawLineRead = readline importedFile
			filteredLine = filterString rawLineRead " ,	"

			cppVersion = filteredLine[2]
			if cppVersion != msVersion do
			(			
				versionMismatch = true
				close importedFile
				messageBox ("The file version is not compatible.\nUse version: " +  cppVersion) beep:true
			)
			
			if cppVersion == msVersion do
			(
				rawLineRead = readline importedFile -- get GameState								USE LATER TO DETERMINE IF CAMERA CAN BE SENT BACK TO REPLAY
				filteredLine = filterString rawLineRead " ,	"
				gameState = filteredLine[2]
				rawLineRead = readline importedFile
				filteredLine = filterString rawLineRead " ,	"
				textCameraName.text = filteredLine[2] -- get camera name
				rawLineRead = readline importedFile
				filteredLine = filterString rawLineRead " ,	"
				spnFpsChange.value = filteredLine[2] as float -- get in game fps
				rawLineRead = readline importedFile
				filteredLine = filterString rawLineRead " ,	"
				spnFrameCount.value = filteredLine[2] as float -- get recorded frames
				rawLineRead = readline importedFile
				filteredLine = filterString rawLineRead " ,	"
				lblNumCars.text = filteredLine[2]
				numCars = filteredLine[2] as integer -- get number of cars
				
				btnCameraImport.enabled = false
				btnConfirmImport.enabled = true
				btnCancelImport.enabled = true
			)
		)
	)
	
	on btnConfirmImport pressed do
	(
		btnCameraImport.enabled = true
		btnConfirmImport.enabled = false
		btnCancelImport.enabled = false
		
		if cboxBall.checked == true do useBall = false
		if cboxCars.checked == true do useBall = false
		
		subframeScale = 60/spnFpsChange.value as float
		animTopRange = subframeScale * spnFrameCount.value
		animationRange = (interval 0 animTopRange) --this may need to adjust later to compensate for syncing new cameras. If the cameras have animation outside the range then change it, otherwise do nothing
		disableSceneRedraw
		
		metadataBool = true
		if metadataBool == true do --this is just to allow toggling of outlining for the metadata section
		(
			metadataDummy = Dummy name:"MetadataDummy" pos:[0,0,0]
			select metadataDummy
			attrHolder = EmptyModifier()
			attrHolder.name = "Metadata"
			addModifier metadataDummy (EmptyModifier())
			metadataDummy.modifiers[1].name = "Metadata"
			metadata = attributes dummymetadata
			(
				parameters params rollout:ro_dummymetadata
				(
					replayName type:#string ui:metaName
					replayID type:#string ui:metaID
					replayDate type:#string ui:metaDate
					replayFPS type:#integer ui:metaFPS
					replayFrames type:#integer ui:metaFrames
					replayCurrentFrame type:#integer ui:metaCurrentFrame
				)
				rollout ro_dummymetadata "Replay Metadata"
				(
					edittext metaName 		"Name: " pos:[5,5] width:152
					edittext metaID 			"ID:      " pos:[5,27] width: 152
					edittext metaDate 		"Date:  " pos:[5,49] width: 152
					spinner metaFPS 		"FPS:     " pos:[-18,71] range:[0,10000,0] type:#float width: 175
					spinner metaFrames 	"Replay Frames:  " pos:[2,93] range:[0,1000000,0] type:#integer width:155
					spinner metaCurrentFrame "Current frame: " pos:[-3,115] range:[0,1000000,0] type:#integer width:160
				)
			)
			custAttributes.add metadataDummy.modifiers[1] metadata
			rawLineRead = readline importedFile -- skip empty line
			rawLineRead = readline importedFile -- skip REPLAY METADATA line
			rawLineRead = readline importedFile
			filteredLine = filterString rawLineRead " ,	"
			/**/metadataDummy.modifiers[1].replayName = filteredLine[2] -- get replay name
			rawLineRead = readline importedFile
			filteredLine = filterString rawLineRead " ,	"
			/**/metadataDummy.modifiers[1].replayID = filteredLine[2] -- get replay ID
			rawLineRead = readline importedFile
			filteredLine = filterString rawLineRead " ,	"
			replayDateString = filteredLine[2]
			if gameState == "REPLAY" do
			(
				replayDateString += " " + filteredLine[3] -- get both parts of replay date
			)
			/**/metadataDummy.modifiers[1].replayDate = replayDateString
			rawLineRead = readline importedFile
			filteredLine = filterString rawLineRead " ,	"
			if filteredLine[2] == "NULL" then metadataDummy.modifiers[1].replayFPS = 0
			/**/else metadataDummy.modifiers[1].replayFPS = filteredLine[2] as float -- get replay fps
			rawLineRead = readline importedFile
			filteredLine = filterString rawLineRead " ,	"
			if filteredLine[2] == "NULL" then metadataDummy.modifiers[1].replayFrames = 0
			/**/else metadataDummy.modifiers[1].replayFrames = filteredLine[2] as integer -- get replay frames
			deselect metadataDummy
			freeze metadataDummy
			hide metadataDummy
		)
		
		
		ImportFile (relativePath + "/Assets/BallProxy.FBX") #noPrompt
		ball = $RL_BALL_PROXY
		ball.scale = [1,1,1]

		ImportFile (relativePath + "/Assets/StadiumProxy.FBX") #noPrompt
		field = $RL_STADIUM_PROXY
		field.scale = [1,1,1]

		ImportFile (relativePath + "/Assets/OctaneProxy.FBX") #noPrompt
		newCar = $RL_OCTANE_PROXY
		if numCars > 1 do
		(
			for i=1 to numCars do
			(
				car[i] = instance newCar
				car[i].scale = [1,1,1]
			)
		)
		if numCars == 1 do
		(
			car[1] = instance newCar
			car[1].scale = [1,1,1]
		)
		delete newCar
		
		newCamera = freecamera name:textCameraName.text
		set animate on
		
		rawLineRead = readline importedFile -- skip the empty line
		rawLineRead = readline importedFile -- skip the header line
		
		firstLine = true
		previousEuler = eulerangles 0 0 0
		currentEuler = eulerangles 0 0 0
		previousQuat = quat 0 0 0 0
		currentQuat = quat 0 0 0 0
		while not eof importedFile do 
		(
			rawLineRead = readline importedFile
			filteredLine = filterString rawLineRead " ,	"
			if filteredLine[1] == "END" then exit
			
			frame = filteredLine[1] as float*subframeScale
			replayFrame = filteredLine[2] as integer
			camFOV = filteredLine[3] as float
			camPosX = filteredLine[4] as float
			camPosY = filteredLine[5] as float
			camPosZ = filteredLine[6] as float
			camQX = filteredLine[7] as float
			camQY = filteredLine[8] as float
			camQZ = filteredLine[9] as float
			camQW = filteredLine[10] as float
			
			ballPosX = filteredLine[11] as float
			ballPosY = filteredLine[12] as float
			ballPosZ = filteredLine[13] as float
			
			at time frame
			(
				if gameState == "REPLAY" do metadataDummy.modifiers[1].replayCurrentFrame = replayFrame
				
				newCamera.rotation = quat -camQY -camQX -camQZ camQW
				
				/* THIS CODE CONSTRAINS THE ANIMATION WITHIN -180 to 180. NOT NECESSARY WHEN USING QUATERNIONS
				currentEuler = eulerAngles newCamera.rotation.x_rotation newCamera.rotation.y_rotation newCamera.rotation.z_rotation
				currentQuat = eulerToQuat currentEuler
				quatRatio = getEulerQuatAngleRatio previousQuat currentQuat previousEuler currentEuler
				
				previousEuler = currentEuler
				previousQuat = eulerToQuat previousEuler
				
				newCamera.rotation.x_rotation.controller.value = currentEuler.x
				newCamera.rotation.y_rotation.controller.value = currentEuler.y
				newCamera.rotation.z_rotation.controller.value = currentEuler.z
				EULER FILTER IMPLEMENTATION? http://web.archive.org/web/20170505034541/http://www.staff.city.ac.uk/~sbbh653/publications/euler.pdf
				*/
				
				newCamera.rotation.z_rotation.controller.value -= 90
				newCamera.rotation.x_rotation.controller.value += 90
				
				newCamera.fov = camFOV
				newCamera.pos = [camPosX, camPosY*-1, camPosZ]				
			)
			
			if cboxBall.checked == false do
			(
				qx = filteredLine[14] as float
				qy = filteredLine[15] as float
				qz = filteredLine[16] as float
				qw = filteredLine[17] as float
				localBallQuat = quat -qx qy -qz qw
				at time frame ball.rotation = localBallQuat
				at time frame ball.transform *= (rotateZmatrix 30)
				at time frame ball.pos = [ballPosX, ballPosY*-1, ballPosZ]
			)
			if cboxCars.checked == false do
			(
				i = 18 --Whatever number qw is for the ball +1
				
				for j=1 to numCars do
				(
					/*need to make this global*/carSpecShortcut = filteredLine[i] as integer
					i+=1
					carPosX = filteredLine[i] as float
					i+=1
					carPosY = filteredLine[i] as float
					i+=1
					carPosZ = filteredLine[i] as float
					i+=1
					carQX = filteredLine[i] as float
					i+=1
					carQY = filteredLine[i] as float
					i+=1
					carQZ = filteredLine[i] as float
					i+=1
					carQW = filteredLine[i] as float
					i+=1
					
					localCarQuat = quat -carQX carQY -carQZ carQW
					at time frame car[j].rotation = localCarQuat
					at time frame car[j].pos = [carPosX, carPosY*-1, carPosZ]
					j+=1
				)
			)
			firstLine = false
		)
		
		set animate off
		close importedFile
		enableSceneRedraw
		spnFpsChange.value = 0
		spnFrameCount.value = 0
		textCameraName.text = ""
		btnCameraImport.enabled = true
		btnConfirmImport.enabled = false
		btnCancelImport.enabled = false	
		cboxBall.checked = true
		cboxCars.checked = true
	)
	
	on btnCancelImport pressed do
	(
		close importedFile
		spnFpsChange.value = 0
		spnFrameCount.value = 0
		textCameraName.text = ""
		btnCameraImport.enabled = true
		btnConfirmImport.enabled = false
		btnCancelImport.enabled = false
	)
)

rollout cameraList "Camera List"
(
	listbox lboxCamAngles pos:[3,3] width:140 height:10
	button btnLoadScene "Load Scene" pos:[147,3] width:75 height:35
	button btnDeleteCamera "Delete" pos:[147,41] width:75 height:35
	button btnRenameCamera "Rename" pos:[147,78] width:75 height:35
	spinner spnSync "Sync" pos:[164,121] width:55 type:#integer
	
	
	--------------------------------Camera GroupBox Things--------------------------------
	on btnLoadScene pressed do
	(
	)
	
	on btnDeleteCamera pressed do
	(
	)
	
	on btnRenameCamera pressed do
	(
		/*
		if camera is selected in listbox do
		(
			rollout newCameraName "Camera Name" width:240
			(
				edittext cameraNameInitialize "Name:" pos:[10,10] width:220
				button cameraNameOK "OK" pos:[125,30] width:50
				button cameraNameCancel "Cancel" pos: [180, 30] width: 50
				on cameraNameOK pressed do
				(
					if cameraNameInitialize.text != "" do
					(
						--rename camera using text input--
						--bla bla bla = cameraNameInitialize.text										
						destroyDialog newCameraName
					)
					if cameraNameInitialize.text == "" do
					(
						---bla bla bla = "Unnamed Camera"
						destroyDialog newCameraName
					)				
				)
				on cameraNameCancel pressed do
				(					
					destroyDialog newCameraName
				)
			)
			createdialog newCameraName
			setFocus newCameraName.cameraNameInitialize
		)
		else
		(
			text above progress bar says "No camera is selected"
		)
		*/
	)
	
	on spnSync changed theValue do
	(
		spnSync.value = 0
	)
)

rollout exportToRL "Export Camera To Rocket League"
(
	-- Save timestamp as [framenumber] + . + [the number of times this frame has been repeated]
	-- Use FPS spinner to determine how many frames should be used.
	-- This ends up generating a somewhat hardcoded animation as before, but now its more interpolated (theoretically)
	
	edittext outputFilename "File Name:" pos:[3,5] width:220
	spinner spnExportFPS "Export FPS:" pos:[37,28] width:70 type:#integer range:[0,300,120]
	button btnExportCamToRL "Export camera to RL" pos:[110,26] width:110 height:22
	
	
	on btnExportCamToRL pressed do
	(
		if $MetadataDummy != undefined then
		(
			if Superclassof $ == camera then
			(
				disableSceneRedraw
				outputFilePath = relativePath
				outputFilePath = pathConfig.removePathLeaf outputFilePath
				outputFilePath = pathConfig.removePathLeaf outputFilePath
				outputFilePath += "/AnimationImports/" + outputFilename.text as string + ".txt"
				outFile = createfile outputFilePath
				format "REPLAY METADATA\n" to:outFile
				format "Name: %\n" $MetadataDummy.modifiers[1].replayName to:outFile
				format "ID: %\n" $MetadataDummy.modifiers[1].replayID to:outFile
				format "Date: %\n" $MetadataDummy.modifiers[1].replayDate to:outFile
				format "FPS: %\n" $MetadataDummy.modifiers[1].replayFPS to:outFile
				format "Frames: %\n\n" $MetadataDummy.modifiers[1].replayFrames to:outFile
				
				format "Timestamp\tCamera Position\t\t\tCamera Rotation\t\t\t\tFOV\tFocus\n" to:outFile
				
				camExportDummy = freecamera name:"CameraExportDummy" pos:[0,0,0]
				start = animationRange.start
				end = animationRange.end
				
				cbTimestamp = 0
				subframe = 0
				haverunfirststep = false
				
				undo off
				for i = start to end by 0.5f do at time i
				(
					if haverunfirststep == true do
					(
						if cbTimestamp == ($MetadataDummy.modifiers[1].replayCurrentFrame as string) then
						(
							-- the timestamp is the same as the previous frame, increment subframe
							subframe += 1
						)
						else
						(
							-- reset subframe to 0 for the next frame
							subframe = 0
						)
					)
					
					subframestring = ""
					if subframe >= 10 then
					(
						if subframe >= 100 then
						(
							subframestring = subframe as string
						)
						else
						(
							subframestring = "0" + subframe as string
						)
					)
					else
					(
						subframestring = "00" + subframe as string
					)
					
					cbTimestamp = $MetadataDummy.modifiers[1].replayCurrentFrame as string
					format "%.%\t\t"cbTimestamp subframestring to:outFile
					camPos = $.transform.pos * [1,-1,1]
					format "%,%,%\t" camPos.x camPos.y camPos.z to:outFile
					
					camExportDummy.rotation = $.rotation
					camExportDummy.rotation.x_rotation.controller.value -= 90
					camExportDummy.rotation.z_rotation.controller.value += 90
					
					--format "%,%,%,%\t" camExportDummy.rotation.x camExportDummy.rotation.y camExportDummy.rotation.z camExportDummy.rotation.w to:outFile
					format "%,%,%,%\t" -camExportDummy.rotation.y -camExportDummy.rotation.x -camExportDummy.rotation.z camExportDummy.rotation.w to:outFile
					
					
					
					--EXPORT RAW QUAT DATA AND REIMPORT RAW. SEE IF SOMETHING IS GOING WRONG WITH THE RAW DATA
					
					
					
					
					camFOV = $.fov
					format "%\t" camFOV to:outFile
					camFocus = $.mpassEffect.focalDepth
					format "%" camFocus to:outFile
					
					if i < end - 1 do
						format "\n" to:outFile
					
					haverunfirststep = true
				)
				delete camExportDummy
				close outFile
				undo on
				enableSceneRedraw
				messageBox ("Finished exporting camera path") beep:true
			)
			else
			(
				messageBox ("Selected object must be a camera") beep:true
			)
		)
		else
		(
			messageBox ("Import a scene first") beep:true
		)
	)
)

	
createdialog CBMaxWrapper style: #(#style_titlebar, #style_border, #style_sysmenu, #style_minimizebox)
addsubrollout CBMaxWrapper.allRollouts initialize
addsubrollout CBMaxWrapper.allRollouts cameraList
addsubrollout CBMaxWrapper.allRollouts exportToRL
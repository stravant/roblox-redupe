# Redupe

Plugin to create repeated geometry in Roblox Studio by dragging handles.

* [Functionality Demonstration Video on YouTube](https://www.youtube.com/watch?v=y9veFCNB-hM)
* [Roblox Creator Store Link](https://create.roblox.com/store/asset/73064993918325/Stravant-Redupe)

# Architecture

The core code is separated into three parts:

* A functionality layer that renders manipulators in the scene, places previews, and places the final copies of the selected objects.

  * `src/createRedupeSession.lua`
  * `src/createGhostPreview.lua`

* A settings layer to feed information about how to perform the operation into the functionality layer.

  * `src/Settings.lua`

* A UI layer written in React to feed data to the settings layer and tell the functionality layer when to start and stop doing stuff.

  * `src/MainGui.lua`
  * `src/HelpGui.lua`
  * `src/TutorialGui.lua`


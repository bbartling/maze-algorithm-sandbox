--[[
	Main server script to generate, build, and regenerate the maze.
	This script orchestrates the entire maze lifecycle and tracks player scores.
]]

--================== SERVICES & MODULES ==================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local MazeGenerator = require(ReplicatedStorage:WaitForChild("MazeGenerator"))
local MazeBuilder = require(ReplicatedStorage:WaitForChild("MazeBuilder"))

local CollectionService = game:GetService("CollectionService")

--================== REMOTE EVENTS ==================
local clearFootprintsEvent = ReplicatedStorage:WaitForChild("ClearFootprints")
local playCelebrationSoundEvent = ReplicatedStorage:WaitForChild("PlayCelebrationSound")
local showMazeMessageEvent = ReplicatedStorage:WaitForChild("ShowMazeMessage")
-- REMOVED: The updateCameraInfoEvent is no longer needed with a fixed wall height.


--================== CONFIGURATION ==================
local MAZE_WIDTH = 20
local MAZE_HEIGHT = 20
local CELL_SIZE = 10
local WALL_THICKNESS = 1
local NUM_OF_MONSTERS = 8
local MONSTER_SPAWN_HEIGHT = 5
local PLAYER_SPAWN_HEIGHT = 500 -- How high the player spawns for the skydive effect
local PLAYER_SPAWN_BUFFER = 30 -- How far away monsters must spawn from the start point (in studs)

-- Set a single, fixed wall height
local WALL_HEIGHT = 20


--================== SCRIPT STATE ==================
local isBuildingMaze = false

--================== FORWARD DECLARATIONS ==================
local buildMaze
local handleMazeCompletion


--================== FUNCTIONS ==================

local function createWallTemplate()
	local wall = Instance.new("Part")
	wall.Name = "WallTemplate"
	wall.Anchored = true
	wall.Color = Color3.fromRGB(82, 82, 82)
	wall.Material = Enum.Material.Concrete
	return wall
end

--- This function is called by MazeBuilder when a player wins.
-- @param winningPlayer The player who touched the end part.
handleMazeCompletion = function(winningPlayer)
	if isBuildingMaze then return end

	print("Handling maze completion for " .. winningPlayer.Name)

	playCelebrationSoundEvent:FireClient(winningPlayer)
	showMazeMessageEvent:FireClient(winningPlayer, "New Maze Generated...", 3)


	-- Increment the player's score
	local leaderstats = winningPlayer:FindFirstChild("leaderstats")
	if leaderstats then
		local mazesBeaten = leaderstats:FindFirstChild("MazesBeaten")
		if mazesBeaten then
			mazesBeaten.Value = mazesBeaten.Value + 1
		end
	end

	-- Call the build function directly. All teleport logic is now in buildMaze.
	buildMaze(winningPlayer)
end

--- Main function to orchestrate maze generation and building.
buildMaze = function(playerToTeleport)
	if isBuildingMaze then return end
	isBuildingMaze = true

	local oldMaze = Workspace:FindFirstChild("GeneratedMaze")
	if oldMaze then oldMaze:Destroy() end

	-- Clean up all tagged monsters
	for _, monster in ipairs(CollectionService:GetTagged("MazeMonster")) do
		if monster and monster:IsA("Model") then
			monster:Destroy()
		end
	end


	clearFootprintsEvent:FireAllClients()

	print("Generating new maze grid...")
	local mazeGrid = MazeGenerator.Generate(MAZE_WIDTH, MAZE_HEIGHT)

	local mazeFolder = Instance.new("Folder", Workspace)
	mazeFolder.Name = "GeneratedMaze"

	local wallTemplate = createWallTemplate()

	print("Building new maze parts with wall height:", WALL_HEIGHT)
	MazeBuilder.Build(mazeGrid, mazeFolder, wallTemplate, CELL_SIZE, WALL_HEIGHT, WALL_THICKNESS, handleMazeCompletion)
	print("New maze parts built.")

	wallTemplate:Destroy()

	-- Spawn new monsters from the template
	local monsterTemplate = game.ReplicatedStorage:FindFirstChild("MazeMonster")
	if monsterTemplate then
		local mazeFloor = mazeFolder:FindFirstChild("Floor")
		local startPart = mazeFolder:FindFirstChild("StartPoint")

		if mazeFloor and startPart then
			local startPosition = startPart.Position

			for i = 1, NUM_OF_MONSTERS do
				local newMonster = monsterTemplate:Clone()
				local spawnPosition

				-- Loop until we find a spawn point that is far enough away from the player's start
				repeat
					local floorSize = mazeFloor.Size
					local floorCFrame = mazeFloor.CFrame
					local randomX = math.random(-floorSize.X / 2, floorSize.X / 2)
					local randomZ = math.random(-floorSize.Z / 2, floorSize.Z / 2)
					spawnPosition = floorCFrame * CFrame.new(randomX, MONSTER_SPAWN_HEIGHT, randomZ)
				until (spawnPosition.Position - startPosition).Magnitude > PLAYER_SPAWN_BUFFER

				newMonster:SetPrimaryPartCFrame(spawnPosition)
				CollectionService:AddTag(newMonster, "MazeMonster")
				newMonster.Parent = Workspace
				print("New monster spawned at a safe location.")
			end
		end
	end

	-- This is the single point for the skydive teleport.
	if playerToTeleport then
		local newStartPart = mazeFolder:FindFirstChild("StartPoint")
		if newStartPart then
			local character = playerToTeleport.Character
			if character and character:FindFirstChild("HumanoidRootPart") then
				print("Teleporting " .. playerToTeleport.Name .. " to skydive position.")
				local dropPosition = newStartPart.Position + Vector3.new(0, PLAYER_SPAWN_HEIGHT, 0)
				character.HumanoidRootPart.CFrame = CFrame.new(dropPosition)
			end
		end
	end

	isBuildingMaze = false
end

--- Sets up the leaderstats and initial spawn for a new player.
local function onPlayerAdded(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local mazesBeaten = Instance.new("IntValue")
	mazesBeaten.Name = "MazesBeaten"
	mazesBeaten.Value = 0
	mazesBeaten.Parent = leaderstats

	player.CharacterAdded:Connect(function(character)
		task.wait(0.5)
		local mazeFolder = Workspace:FindFirstChild("GeneratedMaze")
		local startPart = mazeFolder and mazeFolder:FindFirstChild("StartPoint")

		if startPart then
			local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
			print("Teleporting new player " .. player.Name .. " to initial skydive position.")
			local dropPosition = startPart.Position + Vector3.new(0, PLAYER_SPAWN_HEIGHT, 0)
			humanoidRootPart.CFrame = CFrame.new(dropPosition)
		end
	end)

end


--================== SCRIPT EXECUTION ==================
buildMaze()
Players.PlayerAdded:Connect(onPlayerAdded)

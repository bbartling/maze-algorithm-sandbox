--[[
	This module takes a maze grid and builds it as physical parts in the workspace.
	It now uses a callback function when the maze is completed.
]]

local MazeBuilder = {}

function MazeBuilder.Build(grid, mazeFolder, wallTemplate, cellSize, wallHeight, wallThickness, onMazeCompleted)
	local width = #grid
	local height = #grid[1]

	-- Services needed for the spotlight
	local RunService = game:GetService("RunService")

	-- Create sub-folders for organization
	local wallsFolder = Instance.new("Folder")
	wallsFolder.Name = "Walls"
	wallsFolder.Parent = mazeFolder

	-- Create a floor for the maze
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(width * cellSize, wallThickness, height * cellSize)
	floor.Position = Vector3.new((width * cellSize) / 2, -wallThickness / 2, (height * cellSize) / 2)
	floor.Anchored = true
	floor.Color = Color3.fromRGB(128, 128, 128)
	floor.Material = Enum.Material.Concrete
	floor.Parent = mazeFolder

	local mazeOrigin = floor.Position - floor.Size/2

	-- Create walls based on the grid data
	for x = 1, width do
		for y = 1, height do
			local cell = grid[x][y]
			local cellCenter = mazeOrigin + Vector3.new((x - 0.5) * cellSize, wallHeight / 2, (y - 0.5) * cellSize)

			if cell.walls.Top then
				local wall = wallTemplate:Clone()
				wall.Size = Vector3.new(cellSize + wallThickness, wallHeight, wallThickness)
				wall.Position = cellCenter + Vector3.new(0, 0, -cellSize / 2)
				wall.Parent = wallsFolder
			end

			if cell.walls.Left then
				local wall = wallTemplate:Clone()
				wall.Size = Vector3.new(wallThickness, wallHeight, cellSize + wallThickness)
				wall.Position = cellCenter + Vector3.new(-cellSize / 2, 0, 0)
				wall.Parent = wallsFolder
			end

			if y == height and cell.walls.Bottom then
				local wall = wallTemplate:Clone()
				wall.Size = Vector3.new(cellSize + wallThickness, wallHeight, wallThickness)
				wall.Position = cellCenter + Vector3.new(0, 0, cellSize / 2)
				wall.Parent = wallsFolder
			end

			if x == width and cell.walls.Right then
				local wall = wallTemplate:Clone()
				wall.Size = Vector3.new(wallThickness, wallHeight, cellSize + wallThickness)
				wall.Position = cellCenter + Vector3.new(cellSize / 2, 0, 0)
				wall.Parent = wallsFolder
			end
		end
	end

	-- Create Start and End points
	local startPart = Instance.new("Part")
	startPart.Name = "StartPoint"
	startPart.Size = Vector3.new(cellSize, 1, cellSize)
	startPart.Position = mazeOrigin + Vector3.new(0.5 * cellSize, 1.25, 0.5 * cellSize)

	startPart.Anchored = true
	startPart.CanCollide = false
	startPart.Transparency = 0.5
	startPart.Color = Color3.fromRGB(0, 255, 0)
	startPart.Parent = mazeFolder

	local endPart = Instance.new("Part")
	endPart.Name = "EndPoint"
	endPart.Size = Vector3.new(cellSize, 1, cellSize)
	endPart.Position = mazeOrigin + Vector3.new((width - 0.5) * cellSize, 1.25, (height - 0.5) * cellSize)
	endPart.Anchored = true
	endPart.CanCollide = false
	endPart.Transparency = 0.5
	endPart.Color = Color3.fromRGB(255, 0, 0)
	endPart.Parent = mazeFolder

	-- =================================================================
	-- NEW: HOLLYWOOD SPOTLIGHT EFFECT
	-- =================================================================

	-- 1. Create an invisible anchor part high in the sky for the beam to point to.
	local spotlightAnchor = Instance.new("Part")
	spotlightAnchor.Name = "SpotlightAnchor"
	spotlightAnchor.Anchored = true
	spotlightAnchor.CanCollide = false
	spotlightAnchor.Transparency = 1
	spotlightAnchor.Size = Vector3.new(1, 1, 1)
	-- Position it directly above the end part, but very high up.
	spotlightAnchor.Position = endPart.Position + Vector3.new(0, 800, 0)
	spotlightAnchor.Parent = mazeFolder

	-- 2. Create the two attachments for the beam.
	local attachment0 = Instance.new("Attachment", endPart)
	local attachment1 = Instance.new("Attachment", spotlightAnchor)

	-- 3. Create and style the beam.
	local beam = Instance.new("Beam")
	beam.Name = "SpotlightBeam"
	beam.Attachment0 = attachment0
	beam.Attachment1 = attachment1
	beam.Texture = "rbxassetid://249492584" -- A common light beam texture
	beam.TextureMode = Enum.TextureMode.Static
	beam.TextureSpeed = 0
	beam.FaceCamera = true
	beam.Width0 = 8 -- Width at the base
	beam.Width1 = 40 -- Width at the end in the sky
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 50, 50))
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7), -- Semi-transparent at the base
		NumberSequenceKeypoint.new(1, 1)    -- Fades to fully transparent in the sky
	})
	beam.Parent = endPart

	-- 4. Create the animation loop in a separate thread so it doesn't stop the script.
	coroutine.wrap(function()
		while spotlightAnchor.Parent do
			-- Rotate the anchor part around the Y-axis to make the beam sweep in a circle.
			-- The numbers control the center of rotation and the speed.
			spotlightAnchor.CFrame = CFrame.new(endPart.Position) * CFrame.Angles(0, tick() * 0.5, 0) * CFrame.new(0, 800, 0)
			RunService.Heartbeat:Wait()
		end
	end)()

	-- =================================================================

	local debounce = {} 

	endPart.Touched:Connect(function(hit)
		local player = game.Players:GetPlayerFromCharacter(hit.Parent)
		if player and not debounce[player] then
			debounce[player] = true 

			print(player.Name .. " has reached the end of the maze!")

			-- Call the completion function and pass the winning player
			if typeof(onMazeCompleted) == "function" then
				onMazeCompleted(player)
			end

			task.wait(5)
			debounce[player] = nil
		end
	end)
end

return MazeBuilder

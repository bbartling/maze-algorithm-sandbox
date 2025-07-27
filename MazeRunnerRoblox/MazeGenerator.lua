--[[
	This module generates a maze layout using a recursive backtracking algorithm.
	It returns a 2D grid where each cell knows which of its walls are present.
]]

local MazeGenerator = {}

function MazeGenerator.Generate(width, height)
	-- 1. Create a grid of cells
	local grid = {}
	for x = 1, width do
		grid[x] = {}
		for y = 1, height do
			grid[x][y] = {
				x = x,
				y = y,
				visited = false,
				walls = {Top = true, Bottom = true, Left = true, Right = true}
			}
		end
	end

	-- Helper function to get unvisited neighbors of a cell
	local function getNeighbors(cell)
		local neighbors = {}
		local x, y = cell.x, cell.y

		-- Corrected: Changed &lt; and &gt; back to < and >
		if y > 1 and not grid[x][y - 1].visited then table.insert(neighbors, grid[x][y - 1]) end -- Top
		if y < height and not grid[x][y + 1].visited then table.insert(neighbors, grid[x][y + 1]) end -- Bottom
		if x > 1 and not grid[x - 1][y].visited then table.insert(neighbors, grid[x - 1][y]) end -- Left
		if x < width and not grid[x + 1][y].visited then table.insert(neighbors, grid[x + 1][y]) end -- Right

		return neighbors
	end

	-- Helper function to remove the wall between two adjacent cells
	local function removeWall(current, neighbor)
		local dx = current.x - neighbor.x
		if dx == 1 then -- neighbor is to the left
			current.walls.Left = false
			neighbor.walls.Right = false
		elseif dx == -1 then -- neighbor is to the right
			current.walls.Right = false
			neighbor.walls.Left = false
		end

		local dy = current.y - neighbor.y
		if dy == 1 then -- neighbor is on top
			current.walls.Top = false
			neighbor.walls.Bottom = false
		elseif dy == -1 then -- neighbor is on bottom
			current.walls.Bottom = false
			neighbor.walls.Top = false
		end
	end

	-- 2. Recursive backtracking algorithm
	local stack = {}
	local startCell = grid[1][1] -- Start at top-left
	startCell.visited = true
	table.insert(stack, startCell)

	while #stack > 0 do
		local currentCell = stack[#stack]
		local neighbors = getNeighbors(currentCell)

		if #neighbors > 0 then
			-- Pick a random neighbor
			local nextCell = neighbors[math.random(1, #neighbors)]

			-- Carve a path
			removeWall(currentCell, nextCell)

			-- Move to the neighbor
			nextCell.visited = true
			table.insert(stack, nextCell)
		else
			-- No unvisited neighbors, backtrack
			table.remove(stack)
		end
	end

	return grid
end

return MazeGenerator

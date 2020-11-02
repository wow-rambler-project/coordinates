-- WoW Rambler Project - Coordinates Addon
--
-- mailto: wow.rambler.project@gmail.com
--

local AddonName = ...

local mainFrame = CreateFrame("Frame", nil, UIParent)
mainFrame.events = {}

function mainFrame:SetupEvents()
	self:SetScript("OnEvent", function(self, event, ...)
		self.events[event](self, ...)
	end)

	for k, v in pairs(self.events) do
		self:RegisterEvent(k)
	end

	self.timeDelta = 0
	self:SetScript("OnUpdate", self.OnUpdate)
end

function mainFrame:SetupCoordinatesFrame()
	self.positionX = nil
	self.positionY = nil

	local function SetupFont(font, fontObject, xOffset)
		font:SetFontObject(fontObject)
		font:SetPoint("TOPLEFT", xOffset, 0)
		font:SetJustifyH("LEFT")
	end

	self:SetPoint("TOPRIGHT", -10, -3)

	local fontObject = ObjectiveTrackerBlocksFrame.QuestHeader.Text:GetFontObject()

	self.positionXText = self:CreateFontString(nil, "OVERLAY")
	self.positionYText = self:CreateFontString(nil, "OVERLAY")
	self.zoneText = self:CreateFontString(nil, "OVERLAY")

	SetupFont(self.positionXText, fontObject, 0)

	-- Measure max width of a single coordinate.
	self.positionXText:SetText("100.0")
	self.maxPositionWidth = self.positionXText:GetStringWidth()
	self.positionXText:SetText("")

	SetupFont(self.positionYText, fontObject, self.maxPositionWidth)
	SetupFont(self.zoneText, fontObject, self.maxPositionWidth * 2)

	self:SetHeight(self.positionXText:GetLineHeight())

	self.mapCoordinatesCache = {}
	self.playerMapPosition = CreateVector2D(0,0)
	self.zeroVector = CreateVector2D(0, 0)
	self.unitVector = CreateVector2D(1, 1)
end

function mainFrame:UpdateZoneInfo()
	self.isInInstance = IsInInstance()

	local zone = GetRealZoneText()
	local subZone = GetSubZoneText()

	if (subZone == "") then
		self.zoneText:SetText(zone)
	else
		self.zoneText:SetFormattedText("%s - %s", zone, subZone)
	end
end

function mainFrame:GetPlayerMapPosition(mapId)
	local worldPosition = self.mapCoordinatesCache[mapId]

	if not worldPosition then
		worldPosition = {}
		local _
		_, worldPosition[1] = C_Map.GetWorldPosFromMapPos(mapId, self.zeroVector)
		_, worldPosition[2] = C_Map.GetWorldPosFromMapPos(mapId, self.unitVector)

		-- Exile's Reach - North Sea: returns nil
		if not worldPosition[1] or not worldPosition[2] then
			return 0, 0
		end

		worldPosition[2]:Subtract(worldPosition[1])
		self.mapCoordinatesCache[mapId] = worldPosition
	end

	self.playerMapPosition.x, self.playerMapPosition.y = UnitPosition('player')

	if not self.playerMapPosition.x or not self.playerMapPosition.y then
		return 0, 0
	end

	self.playerMapPosition:Subtract(worldPosition[1])

	return (1 / worldPosition[2].y) * self.playerMapPosition.y, (1 / worldPosition[2].x) * self.playerMapPosition.x
end

function mainFrame:GetPlayerZonePosition()
	local mapId = C_Map.GetBestMapForUnit("player")

	if mapId then
		local x, y = self:GetPlayerMapPosition(mapId)
		
		-- This approach uses more memory.
		-- local mapPosObject = C_Map.GetPlayerMapPosition(mapId, "player")
		-- if mapPosObject then 
		-- 	x, y = mapPosObject:GetXY()
		-- end

		-- x = x or 0
		-- y = y or 0

		return math.floor(x * 1000), math.floor(y * 1000)
	end

	return 0, 0
end

function mainFrame:OnUpdate(timeDelta)
	self.timeDelta = self.timeDelta + timeDelta

	if self.timeDelta < (1 / 60) then
		return
	end
	
	self.timeDelta = 0

	if self.isInInstance then
		return
	end

	local x, y = self:GetPlayerZonePosition()

	if x ~= self.positionX then
		if x ~= 0 then
			self.positionXText:SetFormattedText("%.1f", x / 10)
		else
			self.positionXText:SetText("")
		end
		
		self.positionX = x
	end

	if y ~= self.positionY then
		if y ~= 0 then
			self.positionYText:SetFormattedText("%.1f", y / 10)
		else
			self.positionYText:SetText("")
		end

		self.positionY = y
	end
end

function mainFrame:OnZoneChange()
	self:UpdateZoneInfo()
	self:SetWidth(self.maxPositionWidth * 2 + self.zoneText:GetStringWidth())
end

function mainFrame.events:PLAYER_ENTERING_WORLD(...)
	self:OnZoneChange()

	if self.isInInstance then
		self.positionXText:SetText("")
		self.positionYText:SetText("")
	end
end

function mainFrame.events:ZONE_CHANGED(...)
	self:OnZoneChange()
end

function mainFrame.events:ZONE_CHANGED_NEW_AREA(...)
	self:OnZoneChange()
end

function mainFrame.events:ZONE_CHANGED_INDOORS(...)
	self:OnZoneChange()
end

mainFrame:SetupCoordinatesFrame()
mainFrame:SetupEvents()
